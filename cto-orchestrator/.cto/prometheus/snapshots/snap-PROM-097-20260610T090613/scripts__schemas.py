#!/usr/bin/env python3
"""CTO Orchestrator — Structured Output Schemas (PROM-009).

Provides validated parsing of agent and Meeseeks output using dataclasses.
Tries JSON extraction first (from ```json fences), falls back to regex.
No external dependencies required — uses stdlib only.
"""

import json
import re
from dataclasses import dataclass, field
from typing import Optional


# ── Schema definitions ──────────────────────────────────────────────────────

VALID_AGENT_STATUSES = {"completed", "needs_review", "blocked"}
VALID_MEESEEKS_STATUSES = {"completed", "too_complex"}
VALID_COMPLEXITIES = {"simple", "medium", "too_complex"}


@dataclass
class AgentOutput:
    """Structured output from a Morty agent delegation."""
    status: str = "completed"
    files_changed: list[str] = field(default_factory=list)
    summary: str = ""
    description: str = ""
    open_questions: Optional[str] = None
    criteria_check: list[dict] = field(default_factory=list)

    def __post_init__(self):
        # Validate status
        if self.status not in VALID_AGENT_STATUSES:
            self.status = "completed"
        # Ensure files_changed is a list of strings
        if not isinstance(self.files_changed, list):
            self.files_changed = []
        self.files_changed = [str(f) for f in self.files_changed if f]
        # Sanitize text fields
        self.summary = str(self.summary or "")[:500]
        self.description = str(self.description or "")[:2000]
        # Normalize open_questions
        if self.open_questions and str(self.open_questions).lower() in ("none", "null", "n/a", ""):
            self.open_questions = None
        # Validate and normalize criteria_check items
        if not isinstance(self.criteria_check, list):
            self.criteria_check = []
        else:
            validated = []
            for item in self.criteria_check:
                if isinstance(item, dict) and "criterion" in item:
                    validated.append({
                        "criterion": str(item.get("criterion", ""))[:200],
                        "verdict": str(item.get("verdict", "unknown")).lower()[:20],
                        "evidence": str(item.get("evidence", ""))[:300],
                    })
            self.criteria_check = validated

    def to_dict(self) -> dict:
        return {
            "status": self.status,
            "files_changed": self.files_changed,
            "summary": self.summary,
            "description": self.description,
            "open_questions": self.open_questions or "",
            "criteria_check": self.criteria_check,
        }


# MortyTaskResult is the canonical name for agent task results
MortyTaskResult = AgentOutput


@dataclass
class MeeseeksOutput:
    """Structured output from a Mr. Meeseeks one-shot agent."""
    status: str = "completed"
    files_changed: list[str] = field(default_factory=list)
    description: str = ""
    complexity: str = "simple"
    existence_is_pain: bool = False

    def __post_init__(self):
        if self.status not in VALID_MEESEEKS_STATUSES:
            self.status = "completed"
        if not isinstance(self.files_changed, list):
            self.files_changed = []
        self.files_changed = [str(f) for f in self.files_changed if f]
        self.description = str(self.description or "")[:2000]
        if self.complexity not in VALID_COMPLEXITIES:
            self.complexity = "simple"

    def to_dict(self) -> dict:
        return {
            "status": self.status,
            "files_changed": self.files_changed,
            "description": self.description,
            "complexity": self.complexity,
            "existence_is_pain": self.existence_is_pain,
        }


VALID_HANDOFF_ROLES = frozenset({
    "architect-morty", "backend-morty", "frontend-morty",
    "fullstack-morty", "tester-morty", "security-morty",
    "devops-morty", "reviewer-morty",
})


@dataclass
class Handoff:
    """Agent-to-agent control transfer request."""
    target_role: str
    reason: str
    context_summary: str
    ticket_id: str = ""

    def to_dict(self) -> dict:
        return {
            "target_role": self.target_role,
            "reason": self.reason,
            "context_summary": self.context_summary,
            "ticket_id": self.ticket_id,
        }


# ── JSON extraction ─────────────────────────────────────────────────────────

# Pattern to match ```json ... ``` fenced blocks
_JSON_FENCE_RE = re.compile(r"```json\s*(\{.*?\})\s*```", re.DOTALL)
# Fallback: bare JSON object
_JSON_BARE_RE = re.compile(r'(\{"status"\s*:.*?\})', re.DOTALL)


def extract_json_block(output: str) -> Optional[dict]:
    """Try to extract a JSON object from agent output.

    Looks for ```json fences first, then bare JSON objects with "status" key.

    Returns:
        Parsed dict if found, None otherwise.
    """
    if not output:
        return None

    # Try fenced JSON first
    match = _JSON_FENCE_RE.search(output)
    if match:
        try:
            data = json.loads(match.group(1))
            if isinstance(data, dict) and "status" in data:
                return data
        except json.JSONDecodeError:
            pass

    # Try bare JSON with "status" key
    match = _JSON_BARE_RE.search(output)
    if match:
        try:
            data = json.loads(match.group(1))
            if isinstance(data, dict) and "status" in data:
                return data
        except json.JSONDecodeError:
            pass

    return None


def parse_agent_json(output: str) -> Optional[AgentOutput]:
    """Try to parse agent output as structured JSON.

    Returns:
        AgentOutput if JSON was found and valid, None otherwise.
    """
    data = extract_json_block(output)
    if data is None:
        return None

    try:
        return AgentOutput(
            status=data.get("status", "completed"),
            files_changed=data.get("files_changed", []),
            summary=data.get("summary", ""),
            description=data.get("description", ""),
            open_questions=data.get("open_questions"),
            criteria_check=data.get("criteria_check", []),
        )
    except (TypeError, ValueError):
        return None


_HANDOFF_RE = re.compile(r"<handoff>\s*(\{.*?\})\s*</handoff>", re.DOTALL)


def parse_handoff_block(output: str) -> Optional[Handoff]:
    """Extract and parse a <handoff> JSON block from agent output.

    Returns a Handoff if a valid block is found with a recognized target_role,
    None otherwise.
    """
    if not output:
        return None
    match = _HANDOFF_RE.search(output)
    if not match:
        return None
    try:
        data = json.loads(match.group(1))
    except json.JSONDecodeError:
        return None
    target_role = str(data.get("target_role", "")).strip()
    if target_role not in VALID_HANDOFF_ROLES:
        return None
    return Handoff(
        target_role=target_role,
        reason=str(data.get("reason", ""))[:500],
        context_summary=str(data.get("context_summary", ""))[:2000],
        ticket_id=str(data.get("ticket_id", ""))[:20],
    )


def parse_meeseeks_json(output: str) -> Optional[MeeseeksOutput]:
    """Try to parse Meeseeks output as structured JSON.

    Returns:
        MeeseeksOutput if JSON was found and valid, None otherwise.
    """
    # Check for EXISTENCE IS PAIN first
    if "EXISTENCE IS PAIN" in output.upper():
        return MeeseeksOutput(
            status="too_complex",
            existence_is_pain=True,
            complexity="too_complex",
            description="Task too complex for a Meeseeks. Rick needs to assign a Morty.",
        )

    data = extract_json_block(output)
    if data is None:
        return None

    try:
        return MeeseeksOutput(
            status=data.get("status", "completed"),
            files_changed=data.get("files_changed", []),
            description=data.get("description", ""),
            complexity=data.get("complexity", "simple"),
        )
    except (TypeError, ValueError):
        return None


# ── JSON Schema definitions for structured output validation ─────────────────

DELEGATE_OUTPUT_SCHEMA: dict = {
    "type": "object",
    "required": ["status", "files_changed"],
    "properties": {
        "status": {"type": "string", "enum": list(VALID_AGENT_STATUSES)},
        "summary": {"type": "string"},
        "files_changed": {"type": "array", "items": {"type": "string"}},
        "description": {"type": "string"},
        "open_questions": {},
        "confidence": {"type": "string"},
        "next_steps": {"type": "array"},
        "criteria_check": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "criterion": {"type": "string"},
                    "verdict": {"type": "string", "enum": ["pass", "fail", "unknown"]},
                    "evidence": {"type": "string"},
                },
                "required": ["criterion", "verdict", "evidence"],
            },
        },
    },
    "additionalProperties": True,
}

MEESEEKS_OUTPUT_SCHEMA: dict = {
    "type": "object",
    "required": ["status", "files_changed"],
    "properties": {
        "status": {"type": "string", "enum": list(VALID_MEESEEKS_STATUSES)},
        "files_changed": {"type": "array", "items": {"type": "string"}},
        "description": {"type": "string"},
        "complexity": {"type": "string", "enum": list(VALID_COMPLEXITIES)},
        "confidence": {"type": "string"},
        "next_steps": {"type": "array"},
    },
    "additionalProperties": True,
}


# ── MCP tool response shape schemas ─────────────────────────────────────────
# Used by list_tickets / board / project_status and consumed by roro/SwiftUI.

TICKET_CONCISE_SCHEMA: dict = {
    "type": "object",
    "description": "Minimal ticket fields returned in concise response_format.",
    "properties": {
        "id": {"type": "string"},
        "title": {"type": "string"},
        "status": {"type": "string"},
        "assignee": {"type": ["string", "null"]},
    },
    "required": ["id", "title", "status"],
}

TICKET_DETAILED_SCHEMA: dict = {
    "type": "object",
    "description": "Full ticket summary returned in detailed response_format.",
    "properties": {
        "id": {"type": "string"},
        "title": {"type": "string"},
        "status": {"type": "string"},
        "assignee": {"type": ["string", "null"]},
        "priority": {"type": "string"},
        "type": {"type": "string"},
        "complexity": {"type": "string"},
        "dependencies": {"type": "array", "items": {"type": "string"}},
    },
    "required": ["id", "title", "status"],
}

LIST_TICKETS_RESPONSE_SCHEMA: dict = {
    "type": "object",
    "description": "Response envelope for list_tickets MCP tool.",
    "properties": {
        "count": {"type": "integer"},
        "total": {"type": "integer"},
        "offset": {"type": "integer"},
        "tickets": {
            "type": "array",
            "items": {"oneOf": [TICKET_CONCISE_SCHEMA, TICKET_DETAILED_SCHEMA]},
        },
    },
    "required": ["count", "total", "offset", "tickets"],
}

BOARD_CONCISE_SCHEMA: dict = {
    "type": "object",
    "description": "Concise board view: totals + ticket IDs per column.",
    "properties": {
        "totals": {"type": "object"},
        "ids": {"type": "object"},
    },
    "required": ["totals", "ids"],
}

BOARD_DETAILED_SCHEMA: dict = {
    "type": "object",
    "description": "Detailed board view: totals + full card objects per column.",
    "properties": {
        "totals": {"type": "object"},
        "columns": {"type": "object"},
    },
    "required": ["totals", "columns"],
}

PROJECT_STATUS_CONCISE_SCHEMA: dict = {
    "type": "object",
    "description": "Concise project status: name, prefix, ticket counts only.",
    "properties": {
        "project_name": {"type": ["string", "null"]},
        "ticket_prefix": {"type": ["string", "null"]},
        "ticket_counts": {"type": "object"},
    },
    "required": ["ticket_counts"],
}

PROJECT_STATUS_DETAILED_SCHEMA: dict = {
    "type": "object",
    "description": "Detailed project status: all config fields plus ticket counts.",
    "properties": {
        "project_name": {"type": ["string", "null"]},
        "ticket_prefix": {"type": ["string", "null"]},
        "current_sprint": {},
        "default_model": {"type": ["string", "null"]},
        "next_ticket_number": {},
        "ticket_counts": {"type": "object"},
        "last_activity": {"type": ["string", "null"]},
    },
    "required": ["ticket_counts"],
}


# ── Roro Event Envelope ──────────────────────────────────────────────────────

RORO_SCHEMA_VERSION = 1


class RoroEventType:
    """Known roro event type identifiers.

    The SwiftUI terminal must treat unrecognised type values as an 'unknown'
    event and render a graceful fallback rather than failing the whole decode.
    New event types may be added here without bumping schema_version as long
    as the envelope shape (schema_version, type, ts, ticket_id, payload) is
    unchanged.
    """
    # Ticket lifecycle
    TICKET_CREATED   = "cto.ticket.created"
    TICKET_UPDATED   = "cto.ticket.updated"
    TICKET_STARTED   = "cto.ticket.started"
    TICKET_COMPLETED = "cto.ticket.completed"

    # Morty delegation
    DELEGATION_STARTED  = "cto.morty.delegation.started"
    DELEGATION_PROGRESS = "cto.morty.delegation.progress"
    DELEGATION_COMPLETE = "cto.morty.delegation.complete"
    MORTY_TOOL     = "cto.morty.tool"
    MORTY_TOKEN    = "cto.morty.token"
    MORTY_PROGRESS = "cto.morty.progress"
    MORTY_DONE     = "cto.morty.done"

    # Sprint lifecycle
    SPRINT_STARTED   = "cto.sprint.started"
    SPRINT_COMPLETED = "cto.sprint.completed"

    # Diagnostic
    TEST_PING = "cto.test.ping"


@dataclass
class RoroEvent:
    """Versioned, schema-stable envelope for all roro events.

    schema_version lets the SwiftUI decoder detect envelope shape changes
    without crashing. The type field should be one of the RoroEventType
    constants, but unknown values must be handled gracefully on the decode
    side.

    Wire format produced by to_dict():
        {
            "schema_version": 1,
            "type":           "<RoroEventType constant>",
            "ts":             "<ISO-8601 UTC timestamp>",
            "ticket_id":      "<ticket id string or absent>",
            "agent_id":       "<hierarchical agent id or absent>",
            "payload":        { <event-specific data dict> }
        }
    """
    type: str
    ts: str
    payload: dict
    schema_version: int = field(default=RORO_SCHEMA_VERSION)
    ticket_id: Optional[str] = None
    agent_id: Optional[str] = None

    def to_dict(self) -> dict:
        d: dict = {
            "schema_version": self.schema_version,
            "type": self.type,
            "ts": self.ts,
            "payload": self.payload,
        }
        if self.ticket_id is not None:
            d["ticket_id"] = self.ticket_id
        if self.agent_id is not None:
            d["agent_id"] = self.agent_id
        return d
