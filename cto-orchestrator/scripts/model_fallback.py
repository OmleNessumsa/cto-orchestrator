#!/usr/bin/env python3
"""Model fallback chains for `claude -p` subprocesses (stdlib only).

Maps a requested model family to an ordered list of fallback families passed
via the CLI's `--fallback-model` flag, so an overloaded Opus degrades to
Sonnet instead of killing the run. Also detects which model actually served
a stream-json run.

Override with CTO_FALLBACK_MODELS, e.g. ``opus=sonnet,haiku;sonnet=haiku;haiku=``
or ``off`` / ``none`` / ``0`` / ``false`` to disable globally.
"""

import os
import subprocess
from typing import Optional

FALLBACK_CHAINS: dict[str, list[str]] = {
    "opus": ["sonnet"],
    "sonnet": ["haiku"],
    "haiku": [],
}

_FAMILIES = ("opus", "sonnet", "haiku")
_OFF_VALUES = {"off", "none", "0", "false"}
_STRICT_ROLES = {"reviewer-morty"}  # PROM-174: reviewer gate must not degrade

_supported_cache: Optional[bool] = None


def normalise_model(model: Optional[str]) -> str:
    """Reduce a (possibly versioned) model name to its family; '' if unknown."""
    m = (model or "").lower()
    for fam in _FAMILIES:
        if fam in m:
            return fam
    return ""


def _parse_override(raw: str) -> Optional[dict[str, list[str]]]:
    """Parse CTO_FALLBACK_MODELS. Returns {} entries only for well-formed keys.

    Returns None when fallback is globally disabled.
    """
    raw = (raw or "").strip()
    if raw.lower() in _OFF_VALUES:
        return None
    result: dict[str, list[str]] = {}
    for entry in raw.split(";"):
        entry = entry.strip()
        if not entry or entry.count("=") != 1:
            continue
        key, _, val = entry.partition("=")
        key = normalise_model(key.strip())
        if not key:
            continue
        chain: list[str] = []
        valid = True
        for item in val.split(","):
            item = item.strip()
            if not item:
                continue
            fam = normalise_model(item)
            if not fam:
                valid = False
                break
            chain.append(fam)
        if valid:
            result[key] = chain
    return result


def fallback_chain_for(model: str, agent_role: Optional[str] = None) -> str:
    """Comma-joined fallback chain for `model`, or '' when none applies."""
    if agent_role in _STRICT_ROLES:
        return ""
    family = normalise_model(model)
    if not family:
        return ""
    chains = {k: list(v) for k, v in FALLBACK_CHAINS.items()}
    raw = os.environ.get("CTO_FALLBACK_MODELS", "")
    if raw.strip():
        override = _parse_override(raw)
        if override is None:
            return ""
        chains.update(override)
    out: list[str] = []
    for c in chains.get(family, []):
        if c != family and c not in out:
            out.append(c)
    return ",".join(out)


def fallback_supported() -> bool:
    """True if the installed claude CLI advertises --fallback-model (cached)."""
    global _supported_cache
    if _supported_cache is None:
        try:
            r = subprocess.run(["claude", "--help"], capture_output=True,
                               text=True, timeout=5)
            _supported_cache = "--fallback-model" in ((r.stdout or "") + (r.stderr or ""))
        except Exception:
            _supported_cache = False
    return _supported_cache


def fallback_args(model: str, agent_role: Optional[str] = None) -> list[str]:
    """CLI args enabling fallback, or [] when not applicable/supported."""
    chain = fallback_chain_for(model, agent_role)
    if chain and fallback_supported():
        return ["--fallback-model", chain]
    return []


def detect_model_used(event: dict, requested: Optional[str] = None) -> Optional[str]:
    """Extract the model that actually served a stream-json event, if present.

    For ``result.modelUsage`` with several models (e.g. subagents on other
    models), prefer the key matching the requested family; otherwise the key
    with the most output tokens.
    """
    if not isinstance(event, dict):
        return None
    etype = event.get("type")
    if etype == "system":
        if event.get("subtype", "init") == "init":
            m = event.get("model")
            return m if isinstance(m, str) and m else None
    elif etype == "assistant":
        msg = event.get("message")
        if isinstance(msg, dict):
            m = msg.get("model")
            return m if isinstance(m, str) and m else None
    elif etype == "result":
        usage = event.get("modelUsage")
        if isinstance(usage, dict) and usage:
            def _out(k):
                v = usage.get(k)
                return v.get("outputTokens", 0) if isinstance(v, dict) else 0
            req = normalise_model(requested)
            if req:
                matches = [k for k in usage if normalise_model(k) == req]
                if matches:
                    return max(matches, key=_out)
            return max(usage, key=_out)
    return None


def is_fallback(requested: str, used: Optional[str]) -> bool:
    """True when the serving model's family differs from the requested one."""
    if not used:
        return False
    req, got = normalise_model(requested), normalise_model(used)
    if not req or not got:
        return False
    return req != got
