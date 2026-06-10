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

    def to_dict(self) -> dict:
        return {
            "status": self.status,
            "files_changed": self.files_changed,
            "summary": self.summary,
            "description": self.description,
            "open_questions": self.open_questions or "",
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
        )
    except (TypeError, ValueError):
        return None


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
