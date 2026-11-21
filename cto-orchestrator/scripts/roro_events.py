#!/usr/bin/env python3
"""CTO Orchestrator — roro Event Emitter Module.

*Burrrp* Real-time observability for Rick's genius operations.
Emits events to roro's webhook endpoint for monitoring the Morty army.

Features:
- Fire-and-forget HTTP POST to roro webhook
- Optional SSE server for persistent streaming (opt-in via roro.sse_enabled)
- Circuit breaker pattern for graceful degradation
- Config loading from .cto/config.json or environment variables
- Decorator and context manager for easy event emission
"""

import collections
import json
import os
import queue
import threading
import time
from contextlib import contextmanager
from datetime import datetime, timezone
from functools import wraps
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any, Callable, Optional
from urllib.parse import parse_qs, urlparse

# Try to import urllib.request for HTTP without external dependencies
import urllib.error
import urllib.request
import atexit

try:
    from security_utils import validate_webhook_endpoint as _validate_webhook_endpoint
except ImportError:
    _validate_webhook_endpoint = None  # graceful degradation if module unavailable

try:
    from schemas import RoroEvent as _RoroEvent
    from schemas import RORO_SCHEMA_VERSION as _RORO_SCHEMA_VERSION
except ImportError:
    _RoroEvent = None  # graceful degradation; falls back to legacy payload shape
    _RORO_SCHEMA_VERSION = 1


# ── Thread Tracking (prevents SIGSEGV on exit) ────────────────────────────────

_pending_threads: list[threading.Thread] = []
_threads_lock = threading.Lock()


def flush(timeout: float = 1.0):
    """Wait for pending event threads to complete.

    Call this before exiting to prevent SIGSEGV from daemon threads
    being killed mid-request.

    Args:
        timeout: Max seconds to wait per thread (default: 1.0)
    """
    _flush_all_tokens()

    with _threads_lock:
        threads = _pending_threads.copy()
        _pending_threads.clear()

    for t in threads:
        if t.is_alive():
            t.join(timeout=timeout)


def _cleanup_finished_threads():
    """Remove finished threads from tracking list."""
    with _threads_lock:
        _pending_threads[:] = [t for t in _pending_threads if t.is_alive()]


def _track_thread(thread: threading.Thread):
    """Add thread to tracking list."""
    with _threads_lock:
        # Cleanup old threads first (keep list small)
        _pending_threads[:] = [t for t in _pending_threads if t.is_alive()]
        _pending_threads.append(thread)


# Auto-flush on exit to prevent SIGSEGV
atexit.register(lambda: flush(timeout=0.5))


# ── Configuration ─────────────────────────────────────────────────────────────

# Default configuration
# SECURITY NOTE: localhost endpoints use HTTP for development convenience.
# For production, configure HTTPS endpoints via environment variables:
#   RORO_ENDPOINT=https://your-roro-server.com/hooks/agent-event
#   RORO_REQUIRE_HTTPS=true
DEFAULT_CONFIG = {
    "enabled": True,
    "endpoint": "http://localhost:3067/hooks/agent-event",  # Use HTTPS in production
    "rick_terminal_endpoint": "http://localhost:3068",  # Use HTTPS in production
    "timeout": 2.0,
    "verbose": False,
    "require_https": False,  # Set to True in production
    "sse_enabled": False,
    "sse_port": 3069,
}

# Environment variable overrides
ENV_PREFIX = "RORO_"


def _get_env_config() -> dict:
    """Get configuration from environment variables."""
    config = {}

    if os.environ.get(f"{ENV_PREFIX}ENABLED"):
        config["enabled"] = os.environ[f"{ENV_PREFIX}ENABLED"].lower() in ("true", "1", "yes")

    if os.environ.get(f"{ENV_PREFIX}ENDPOINT"):
        config["endpoint"] = os.environ[f"{ENV_PREFIX}ENDPOINT"]

    if os.environ.get(f"{ENV_PREFIX}TIMEOUT"):
        try:
            config["timeout"] = float(os.environ[f"{ENV_PREFIX}TIMEOUT"])
        except ValueError:
            pass

    if os.environ.get(f"{ENV_PREFIX}VERBOSE"):
        config["verbose"] = os.environ[f"{ENV_PREFIX}VERBOSE"].lower() in ("true", "1", "yes")

    return config


def _load_project_config(start_path: Optional[Path] = None) -> dict:
    """Load roro config from .cto/config.json if available."""
    current = Path(start_path or os.getcwd()).resolve()

    while True:
        config_path = current / ".cto" / "config.json"
        if config_path.exists():
            try:
                with open(config_path) as f:
                    project_config = json.load(f)
                    return project_config.get("roro", {})
            except (json.JSONDecodeError, IOError):
                return {}

        parent = current.parent
        if parent == current:
            return {}
        current = parent


def get_config() -> dict:
    """Get merged configuration (defaults < project config < env vars)."""
    config = DEFAULT_CONFIG.copy()
    config.update(_load_project_config())
    config.update(_get_env_config())
    return config


# ── Circuit Breaker ───────────────────────────────────────────────────────────

class CircuitBreaker:
    """Circuit breaker for graceful degradation when roro is unavailable.

    States:
    - CLOSED: Normal operation, requests go through
    - OPEN: Requests blocked, cooldown active
    - HALF_OPEN: Testing if service recovered
    """

    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half_open"

    def __init__(self, failure_threshold: int = 3, cooldown_seconds: float = 30.0):
        self.failure_threshold = failure_threshold
        self.cooldown_seconds = cooldown_seconds
        self.state = self.CLOSED
        self.failure_count = 0
        self.last_failure_time: Optional[float] = None
        self._lock = threading.Lock()

    def can_execute(self) -> bool:
        """Check if request should be allowed."""
        with self._lock:
            if self.state == self.CLOSED:
                return True

            if self.state == self.OPEN:
                # Check if cooldown has passed
                if self.last_failure_time and (time.time() - self.last_failure_time) >= self.cooldown_seconds:
                    self.state = self.HALF_OPEN
                    return True
                return False

            # HALF_OPEN: allow one request to test
            return True

    def record_success(self):
        """Record a successful request."""
        with self._lock:
            self.failure_count = 0
            self.state = self.CLOSED

    def record_failure(self):
        """Record a failed request."""
        with self._lock:
            self.failure_count += 1
            self.last_failure_time = time.time()

            if self.failure_count >= self.failure_threshold:
                self.state = self.OPEN

    def reset(self):
        """Reset the circuit breaker."""
        with self._lock:
            self.state = self.CLOSED
            self.failure_count = 0
            self.last_failure_time = None


# Global circuit breaker instance
_circuit_breaker = CircuitBreaker()


# ── SSE Server ────────────────────────────────────────────────────────────────

_SSE_BUFFER_SIZE = 50
_sse_event_buffer: collections.deque = collections.deque(maxlen=_SSE_BUFFER_SIZE)
_sse_event_counter = 0
_sse_buffer_lock = threading.Lock()
_sse_clients: list[queue.Queue] = []
_sse_clients_lock = threading.Lock()
_sse_server_instance: Optional["_SSEServerWrapper"] = None
_sse_server_start_lock = threading.Lock()


_SSE_RETRY_MS = 3000
_SSE_PING_EVERY = 50
_SSE_PING = "ping"  # queue marker: heartbeat comment for typed clients only


def _format_sse_event(event_id: int, payload: dict, typed: bool = False) -> bytes:
    """Format a payload dict as an SSE message frame.

    Untyped frames carry only ``id:`` and ``data:`` (the original wire format).
    Typed frames add an ``event:`` line with the payload's event type.
    """
    data = json.dumps(payload)
    if typed:
        name = str(payload.get("type") or payload.get("eventType") or "").replace("\r", "").replace("\n", "")
        if name:
            return f"id: {event_id}\nevent: {name}\ndata: {data}\n\n".encode("utf-8")
    return f"id: {event_id}\ndata: {data}\n\n".encode("utf-8")


def _format_sse_ping() -> bytes:
    """Comment frame letting typed clients detect stale connections."""
    return f": ping {datetime.now(timezone.utc).isoformat()}\n\n".encode("utf-8")


def _push_to_sse(payload: dict):
    """Add event to ring buffer and deliver to all connected SSE clients.

    The ring buffer and client queues hold (event_id, payload) so each client
    can be served the frame format it opted into.
    """
    global _sse_event_counter

    with _sse_buffer_lock:
        _sse_event_counter += 1
        event_id = _sse_event_counter
        _sse_event_buffer.append((event_id, payload))

    with _sse_clients_lock:
        dead = []
        for q in _sse_clients:
            try:
                q.put_nowait((event_id, payload))
                if event_id % _SSE_PING_EVERY == 0:
                    q.put_nowait(_SSE_PING)
            except queue.Full:
                dead.append(q)
        for q in dead:
            _sse_clients.remove(q)


class _SSEHandler(BaseHTTPRequestHandler):
    """HTTP handler for SSE connections on /events."""

    def log_message(self, format, *args):  # noqa: A002
        """Suppress default per-request logging."""
        pass

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path != "/events":
            self.send_response(404)
            self.end_headers()
            return

        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()

        # Typed frames (event: line) are opt-in: EventSource only fires
        # onmessage for unnamed events.
        typed = parse_qs(parsed.query).get("typed", [""])[0] == "1"

        if typed:
            try:
                self.wfile.write(f"retry: {_SSE_RETRY_MS}\n\n".encode("utf-8"))
            except (BrokenPipeError, ConnectionResetError, OSError):
                return

        # Replay events missed since Last-Event-ID
        last_id_str = self.headers.get("Last-Event-ID", "")
        last_id = int(last_id_str) if last_id_str.isdigit() else 0

        with _sse_buffer_lock:
            missed = [(eid, p) for eid, p in _sse_event_buffer if eid > last_id]

        try:
            for eid, p in missed:
                self.wfile.write(_format_sse_event(eid, p, typed))
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, OSError):
            return

        client_q: queue.Queue = queue.Queue(maxsize=100)
        with _sse_clients_lock:
            _sse_clients.append(client_q)

        try:
            while True:
                try:
                    item = client_q.get(timeout=15.0)
                    if item is _SSE_PING:
                        if not typed:
                            continue
                        data = _format_sse_ping()
                    else:
                        data = _format_sse_event(item[0], item[1], typed)
                    self.wfile.write(data)
                    self.wfile.flush()
                except queue.Empty:
                    # Keepalive comment to detect dead connections
                    self.wfile.write(b": keepalive\n\n")
                    self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, OSError):
            pass
        finally:
            with _sse_clients_lock:
                try:
                    _sse_clients.remove(client_q)
                except ValueError:
                    pass


class _SSEServerWrapper:
    """Wraps HTTPServer to run in a background daemon thread."""

    def __init__(self, port: int):
        self.port = port
        self._server: Optional[HTTPServer] = None
        self._thread: Optional[threading.Thread] = None

    def start(self):
        try:
            self._server = HTTPServer(("localhost", self.port), _SSEHandler)
            self._thread = threading.Thread(
                target=self._server.serve_forever,
                daemon=True,
                name="roro-sse-server",
            )
            self._thread.start()
        except OSError:
            # Port already in use or other bind error — degrade silently
            self._server = None

    def stop(self):
        if self._server:
            self._server.shutdown()
            self._server = None

    @property
    def running(self) -> bool:
        return self._server is not None


def _ensure_sse_server(port: int):
    """Start the global SSE server if not already running (lazy singleton)."""
    global _sse_server_instance
    with _sse_server_start_lock:
        if _sse_server_instance is None or not _sse_server_instance.running:
            wrapper = _SSEServerWrapper(port)
            wrapper.start()
            if wrapper.running:
                _sse_server_instance = wrapper
                atexit.register(wrapper.stop)


# ── Agent ID Generation ───────────────────────────────────────────────────────

def get_agent_id(role: str, team_id: Optional[str] = None) -> str:
    """Generate a hierarchical agent ID for roro.

    Agent ID Strategy:
    - Rick: cto:rick
    - Solo Morty: cto:morty:{role} (e.g., cto:morty:backend-morty)
    - Team Morty: cto:team:{team_id}:{role} (e.g., cto:team:TEAM-001:frontend-morty)
    - Meeseeks: cto:meeseeks:{timestamp}

    Args:
        role: Agent role (e.g., "rick", "backend-morty", "meeseeks")
        team_id: Optional team session ID for team context

    Returns:
        Hierarchical agent ID string
    """
    if role == "rick":
        return "cto:rick"

    if role == "meeseeks" or role.startswith("meeseeks"):
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
        return f"cto:meeseeks:{timestamp}"

    if team_id:
        return f"cto:team:{team_id}:{role}"

    return f"cto:morty:{role}"


# ── Event Emission ────────────────────────────────────────────────────────────

def _send_event(endpoint: str, payload: dict, timeout: float, verbose: bool):
    """Send event via HTTP POST (runs in background thread)."""
    try:
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            endpoint,
            data=data,
            headers={"Content-Type": "application/json"},
            method="POST"
        )

        with urllib.request.urlopen(req, timeout=timeout) as response:
            if response.status == 200:
                _circuit_breaker.record_success()
                if verbose:
                    print(f"[roro] Event sent: {payload.get('type')}")
            else:
                _circuit_breaker.record_failure()
                if verbose:
                    print(f"[roro] Event failed: HTTP {response.status}")

    except urllib.error.URLError as e:
        _circuit_breaker.record_failure()
        if verbose:
            print(f"[roro] Event failed: {e}")
    except Exception as e:
        _circuit_breaker.record_failure()
        if verbose:
            print(f"[roro] Event failed: {e}")


def emit(
    event_type: str,
    data: dict,
    agent_id: Optional[str] = None,
    role: str = "rick",
    team_id: Optional[str] = None,
):
    """Emit an event to roro's webhook endpoint.

    Fire-and-forget: Events are sent asynchronously in a background thread.
    The main thread never blocks waiting for roro.

    Args:
        event_type: Event type (e.g., "cto.ticket.created")
        data: Event payload data
        agent_id: Optional explicit agent ID (overrides role-based generation)
        role: Agent role for ID generation (default: "rick")
        team_id: Optional team session ID for team context

    Example:
        emit("cto.ticket.created", {"ticket_id": "PROJ-001", "title": "Build API"})
    """
    # Keep ordering: buffered tokens go out before any other event of this agent
    if event_type != _TOKEN_EVENT:
        _flush_tokens(agent_id or get_agent_id(role, team_id))

    config = get_config()

    # Check if roro is enabled
    if not config.get("enabled", True):
        return

    # Check circuit breaker
    if not _circuit_breaker.can_execute():
        if config.get("verbose"):
            print(f"[roro] Circuit breaker open, skipping event: {event_type}")
        return

    endpoint = config.get("endpoint", "")

    # SECURITY: Enforce HTTPS in production if require_https is set
    require_https = config.get("require_https", False) or os.environ.get("RORO_REQUIRE_HTTPS", "").lower() == "true"
    if require_https and endpoint and not endpoint.startswith("https://"):
        # Allow localhost for development
        if "localhost" not in endpoint and "127.0.0.1" not in endpoint:
            if config.get("verbose"):
                print(f"[roro] SECURITY: Skipping non-HTTPS endpoint: {endpoint}")
            return

    # Generate agent ID if not provided
    if not agent_id:
        agent_id = get_agent_id(role, team_id)

    # Build versioned event envelope
    ts = datetime.now(timezone.utc).isoformat()
    if _RoroEvent is not None:
        event = _RoroEvent(
            type=event_type,
            ts=ts,
            payload=data,
            ticket_id=data.get("ticket_id") if isinstance(data, dict) else None,
            agent_id=agent_id,
        )
        payload = event.to_dict()
    else:
        # Legacy fallback when schemas module is unavailable
        payload = {
            "agentId": agent_id,
            "eventType": event_type,
            "timestamp": ts,
            "data": data,
        }
    payload.setdefault("schema_version", _RORO_SCHEMA_VERSION)

    # Push to SSE stream if enabled (opt-in)
    if config.get("sse_enabled"):
        sse_port = int(config.get("sse_port", 3069))
        _ensure_sse_server(sse_port)
        _push_to_sse(payload)

    # Send to roro endpoint in background thread (fire-and-forget)
    if endpoint:
        # SSRF prevention: validate endpoint before sending (allow localhost for dev)
        if _validate_webhook_endpoint is not None:
            try:
                _validate_webhook_endpoint(endpoint, allow_localhost=True)
            except ValueError as ssrf_err:
                if config.get("verbose"):
                    print(f"[roro] SECURITY: Blocked SSRF endpoint: {ssrf_err}")
                endpoint = ""

    if endpoint:
        thread = threading.Thread(
            target=_send_event,
            args=(endpoint, payload, config["timeout"], config.get("verbose", False)),
            daemon=True,
        )
        _track_thread(thread)
        thread.start()

    # Also send to Rick Terminal if endpoint is configured
    rick_endpoint = config.get("rick_terminal_endpoint")
    if rick_endpoint:
        # Also enforce HTTPS for Rick Terminal endpoint if required
        if require_https and not rick_endpoint.startswith("https://"):
            if "localhost" not in rick_endpoint and "127.0.0.1" not in rick_endpoint:
                if config.get("verbose"):
                    print(f"[roro] SECURITY: Skipping non-HTTPS Rick endpoint: {rick_endpoint}")
                rick_endpoint = None

        # SSRF prevention: validate Rick Terminal endpoint before sending
        if rick_endpoint and _validate_webhook_endpoint is not None:
            try:
                _validate_webhook_endpoint(rick_endpoint, allow_localhost=True)
            except ValueError as ssrf_err:
                if config.get("verbose"):
                    print(f"[roro] SECURITY: Blocked SSRF Rick endpoint: {ssrf_err}")
                rick_endpoint = None

        if rick_endpoint:
            rick_thread = threading.Thread(
                target=_send_event,
                args=(rick_endpoint, payload, config["timeout"], config.get("verbose", False)),
                daemon=True,
            )
            _track_thread(rick_thread)
            rick_thread.start()


# ── Progress Event Helpers ────────────────────────────────────────────────────

# Rate limiter state: maps resolved agent_id → last emit timestamp
_progress_last_emit: dict[str, float] = {}
_progress_lock = threading.Lock()
_PROGRESS_MIN_INTERVAL = 2.0  # max 1 progress event per 2 seconds per agent


def emit_progress(
    percentage: float,
    current_step: str,
    output_lines: int,
    elapsed_seconds: float,
    agent_id: Optional[str] = None,
    role: str = "rick",
    team_id: Optional[str] = None,
):
    """Emit a cto.morty.delegation.progress event with rate limiting.

    Rate-limited to max 1 event per 2 seconds per agent to avoid flooding.

    Args:
        percentage: Progress percentage (0-100)
        current_step: Description of what the agent is currently doing
        output_lines: Number of output lines produced so far
        elapsed_seconds: Seconds elapsed since delegation started
        agent_id: Optional explicit agent ID (overrides role-based generation)
        role: Agent role for ID generation
        team_id: Optional team session ID
    """
    resolved_id = agent_id or get_agent_id(role, team_id)

    with _progress_lock:
        last = _progress_last_emit.get(resolved_id, 0.0)
        now = time.time()
        if now - last < _PROGRESS_MIN_INTERVAL:
            return
        _progress_last_emit[resolved_id] = now

    emit(
        "cto.morty.delegation.progress",
        {
            "percentage": max(0.0, min(100.0, float(percentage))),
            "current_step": current_step[:200],
            "output_lines": output_lines,
            "elapsed_seconds": round(elapsed_seconds, 1),
        },
        agent_id=resolved_id,
        role=role,
        team_id=team_id,
    )


# ── Token Coalescing ──────────────────────────────────────────────────────────
# One cto.morty.token event per content_block_delta floods Rick Terminal's
# SwiftUI feed. Buffer per agent and flush as one event every
# RICK_TOKEN_COALESCE_MS (default 100, 0 disables) or once the buffer
# exceeds _TOKEN_BUFFER_MAX bytes.

_TOKEN_EVENT = "cto.morty.token"
_TOKEN_COALESCE_DEFAULT_MS = 100
_TOKEN_BUFFER_MAX = 2048


class _TokenBuffer:
    __slots__ = ("text", "chunks", "first_ts", "timer", "role", "team_id")

    def __init__(self, role: str, team_id: Optional[str]):
        self.text = ""
        self.chunks = 0
        self.first_ts = time.time()
        self.timer: Optional[threading.Timer] = None
        self.role = role
        self.team_id = team_id


# agent_id → buffer
_token_buffers: dict[str, _TokenBuffer] = {}
_token_lock = threading.Lock()


def _token_coalesce_ms() -> int:
    try:
        return max(0, int(os.environ.get("RICK_TOKEN_COALESCE_MS", _TOKEN_COALESCE_DEFAULT_MS)))
    except ValueError:
        return _TOKEN_COALESCE_DEFAULT_MS


def _flush_tokens(agent_id: str):
    """Emit and clear the buffered token text for one agent (no-op if empty)."""
    with _token_lock:
        buf = _token_buffers.pop(agent_id, None)
    if buf is None:
        return
    if buf.timer is not None:
        buf.timer.cancel()
    if buf.text:
        emit(
            _TOKEN_EVENT,
            {"kind": "morty.token", "text": buf.text, "chunks": buf.chunks},
            agent_id=agent_id,
            role=buf.role,
            team_id=buf.team_id,
        )


def _flush_all_tokens():
    with _token_lock:
        agent_ids = list(_token_buffers)
    for agent_id in agent_ids:
        _flush_tokens(agent_id)


def _buffer_token(text: str, role: str, team_id: Optional[str], interval_ms: int):
    agent_id = get_agent_id(role, team_id)
    with _token_lock:
        buf = _token_buffers.get(agent_id)
        if buf is None:
            buf = _token_buffers[agent_id] = _TokenBuffer(role, team_id)
        buf.text += text
        buf.chunks += 1
        overflow = len(buf.text) > _TOKEN_BUFFER_MAX
        if buf.timer is None and not overflow:
            buf.timer = threading.Timer(interval_ms / 1000.0, _flush_tokens, args=(agent_id,))
            buf.timer.daemon = True
            _track_thread(buf.timer)
            buf.timer.start()
    if overflow:
        _flush_tokens(agent_id)


_STREAM_KIND_TO_EVENT: dict = {
    "tool_use": "cto.morty.tool",
    "tool_result": "cto.morty.tool_result",
    "morty.token": "cto.morty.token",
}


def emit_stream_progress(
    event_kind: str,
    event_data: dict,
    role: str = "rick",
    team_id: Optional[str] = None,
):
    """Emit a typed roro event from a streaming claude agent event.

    Maps stream-json event kinds to specific roro event types:
    - tool_use       → cto.morty.tool
    - morty.token    → cto.morty.token  (content_block_delta text, coalesced
                       per agent; see RICK_TOKEN_COALESCE_MS)
    - anything else  → cto.morty.progress

    Args:
        event_kind: Stream event kind ("tool_use", "morty.token", "text_delta", …)
        event_data: Event-specific data (e.g. {"tool": "Read"} or {"phase": "Reading files"})
        role: Agent role for ID generation
        team_id: Optional team session ID
    """
    event_type = _STREAM_KIND_TO_EVENT.get(event_kind, "cto.morty.progress")
    if event_type == _TOKEN_EVENT:
        interval_ms = _token_coalesce_ms()
        text = event_data.get("text")
        if interval_ms > 0 and isinstance(text, str):
            _buffer_token(text, role, team_id, interval_ms)
            return
    emit(
        event_type,
        {"kind": event_kind, **event_data},
        role=role,
        team_id=team_id,
    )


def emit_review_event(
    status: str,
    ticket_id: str,
    issues: Optional[list] = None,
    role: str = "rick",
    team_id: Optional[str] = None,
):
    """Emit a reviewer-morty reflection-loop event.

    Args:
        status: One of "started", "passed", "failed" — maps to
                cto.ticket.review_{status}
        ticket_id: Ticket being reviewed
        issues: Reviewer-reported issues (only meaningful for "failed")
        role: Agent role for ID generation
        team_id: Optional team session ID
    """
    data = {"ticket_id": ticket_id}
    if issues:
        data["issues"] = [str(i) for i in issues][:10]
    emit(f"cto.ticket.review_{status}", data, role=role, team_id=team_id)


def emit_permission_denied(
    tool_name: str,
    input_summary: str = "",
    role: str = "rick",
    team_id: Optional[str] = None,
):
    """Emit a cto.morty.permission_denied event for a tool call the CLI denied.

    Args:
        tool_name: Name of the denied tool (e.g. "Bash")
        input_summary: Short, already-redacted summary of the tool input
        role: Agent role for ID generation
        team_id: Optional team session ID
    """
    emit(
        "cto.morty.permission_denied",
        {"tool_name": tool_name, "input_summary": input_summary},
        role=role,
        team_id=team_id,
    )


def emit_morty_done(
    total_cost_usd: Optional[float] = None,
    duration_ms: Optional[int] = None,
    num_turns: Optional[int] = None,
    role: str = "rick",
    team_id: Optional[str] = None,
):
    """Emit a cto.morty.done event from the final result event in stream-json output.

    Called when the 'result' event arrives at end of stream, surfacing accurate
    cost and turn metadata reported by the Claude CLI.

    Args:
        total_cost_usd: Actual USD cost reported by the result event (or None)
        duration_ms: Wall-clock duration in milliseconds reported by the result event
        num_turns: Number of agentic turns in the session
        role: Agent role for ID generation
        team_id: Optional team session ID
    """
    emit(
        "cto.morty.done",
        {
            "total_cost_usd": total_cost_usd,
            "duration_ms": duration_ms,
            "num_turns": num_turns,
        },
        role=role,
        team_id=team_id,
    )


def emit_morty_api_retry(
    ticket_id: Optional[str] = None,
    attempt: Optional[int] = None,
    max_retries: Optional[int] = None,
    retry_delay_ms: Optional[int] = None,
    error: Optional[str] = None,
    role: str = "rick",
    team_id: Optional[str] = None,
):
    """Emit morty.api_retry for a system/api_retry stream event (overload / rate-limit backoff).

    Makes API retries visible so a backing-off Morty doesn't look hung.
    """
    emit(
        "morty.api_retry",
        {
            "ticket_id": ticket_id,
            "attempt": attempt,
            "max_retries": max_retries,
            "retry_delay_ms": retry_delay_ms,
            "error": error,
        },
        role=role,
        team_id=team_id,
    )


def emit_task_event(
    event: str,
    task_id: str,
    kind: str,
    status: str,
    ticket_id: Optional[str] = None,
    role: str = "rick",
):
    """Emit a cto.task.created / cto.task.updated event for the MCP task lifecycle.

    Args:
        event: "created" or "updated"
        task_id: MCP task handle (.cto/tasks/<task_id>.json)
        kind: Tool that spawned the task (delegate, meeseeks, prometheus_scan, unity_scan)
        status: working / input_required / completed / failed / cancelled
        ticket_id: Ticket the task works on, if any
        role: Agent role for ID generation
    """
    emit(
        f"cto.task.{event}",
        {"task_id": task_id, "kind": kind, "status": status, "ticket_id": ticket_id},
        role=role,
    )


# ── Decorator ─────────────────────────────────────────────────────────────────

def emit_event(
    event_type: str,
    data_extractor: Optional[Callable[..., dict]] = None,
    role: str = "rick",
    team_id_arg: Optional[str] = None,
):
    """Decorator to emit an event when a function is called.

    Args:
        event_type: Event type to emit
        data_extractor: Optional function to extract event data from function args/result
                       Signature: (result, *args, **kwargs) -> dict
        role: Agent role for ID generation
        team_id_arg: Name of the kwarg containing team_id (if any)

    Example:
        @emit_event("cto.ticket.created", lambda r, *a, **kw: {"ticket_id": r})
        def create_ticket(title):
            ...
            return ticket_id
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            result = func(*args, **kwargs)

            # Extract team_id if specified
            team_id = kwargs.get(team_id_arg) if team_id_arg else None

            # Extract event data
            if data_extractor:
                try:
                    data = data_extractor(result, *args, **kwargs)
                except Exception:
                    data = {"result": str(result) if result else None}
            else:
                data = {"result": str(result) if result else None}

            # Emit the event
            emit(event_type, data, role=role, team_id=team_id)

            return result

        return wrapper
    return decorator


# ── Context Manager ───────────────────────────────────────────────────────────

@contextmanager
def EventScope(
    start_event: str,
    end_event: str,
    data: dict,
    role: str = "rick",
    team_id: Optional[str] = None,
):
    """Context manager for emitting start/end event pairs.

    Emits start_event on enter, end_event on exit (with success/error status).

    Args:
        start_event: Event type for scope start
        end_event: Event type for scope end
        data: Base event data (shared between start and end)
        role: Agent role for ID generation
        team_id: Optional team session ID

    Example:
        with EventScope("cto.sprint.started", "cto.sprint.completed",
                       {"sprint_id": 1}, role="rick"):
            run_sprint()
    """
    start_data = {**data, "status": "started"}
    emit(start_event, start_data, role=role, team_id=team_id)

    error = None
    try:
        yield
    except Exception as e:
        error = e
        raise
    finally:
        if error:
            end_data = {**data, "status": "failed", "error": str(error)[:200]}
        else:
            end_data = {**data, "status": "completed"}

        emit(end_event, end_data, role=role, team_id=team_id)


# ── Utility Functions ─────────────────────────────────────────────────────────

def reset_circuit_breaker():
    """Reset the circuit breaker (useful for testing)."""
    _circuit_breaker.reset()


def is_enabled() -> bool:
    """Check if roro event emission is enabled."""
    return get_config().get("enabled", True)


def get_circuit_state() -> str:
    """Get current circuit breaker state."""
    return _circuit_breaker.state


# ── CLI for Testing ───────────────────────────────────────────────────────────

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Test roro event emission")
    parser.add_argument("--event", default="cto.test.ping", help="Event type")
    parser.add_argument("--data", default='{"message": "ping"}', help="Event data (JSON)")
    parser.add_argument("--role", default="rick", help="Agent role")
    parser.add_argument("--verbose", action="store_true", help="Verbose output")
    args = parser.parse_args()

    # Enable verbose mode for testing
    if args.verbose:
        os.environ["RORO_VERBOSE"] = "true"

    config = get_config()
    print(f"roro config: {json.dumps(config, indent=2)}")
    print(f"Circuit breaker state: {get_circuit_state()}")

    try:
        data = json.loads(args.data)
    except json.JSONDecodeError:
        data = {"message": args.data}

    print(f"Sending event: {args.event}")
    emit(args.event, data, role=args.role)

    # Wait a moment for the background thread to complete
    time.sleep(1)
    print(f"Circuit breaker state after: {get_circuit_state()}")
    print("Done!")
