#!/usr/bin/env python3
"""CTO Orchestrator — roro Event Emitter Module.

*Burrrp* Real-time observability for Rick's genius operations.
Emits events to roro's webhook endpoint for monitoring the Morty army.

Features:
- Fire-and-forget HTTP POST to roro webhook
- Circuit breaker pattern for graceful degradation
- Config loading from .cto/config.json or environment variables
- Decorator and context manager for easy event emission
"""

import json
import os
import threading
import time
from datetime import datetime, timezone
from functools import wraps
from pathlib import Path
from typing import Any, Callable, Optional
from contextlib import contextmanager

# Try to import urllib.request for HTTP without external dependencies
import urllib.request
import urllib.error


# ── Configuration ─────────────────────────────────────────────────────────────

# Default configuration
DEFAULT_CONFIG = {
    "enabled": True,
    "endpoint": "http://localhost:3067/hooks/agent-event",
    "timeout": 2.0,
    "verbose": False,
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
                    print(f"[roro] Event sent: {payload.get('eventType')}")
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
    config = get_config()

    # Check if roro is enabled
    if not config.get("enabled", True):
        return

    # Check circuit breaker
    if not _circuit_breaker.can_execute():
        if config.get("verbose"):
            print(f"[roro] Circuit breaker open, skipping event: {event_type}")
        return

    # Generate agent ID if not provided
    if not agent_id:
        agent_id = get_agent_id(role, team_id)

    # Build event payload
    payload = {
        "agentId": agent_id,
        "eventType": event_type,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "data": data,
    }

    # Send in background thread (fire-and-forget)
    thread = threading.Thread(
        target=_send_event,
        args=(config["endpoint"], payload, config["timeout"], config.get("verbose", False)),
        daemon=True,
    )
    thread.start()


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
