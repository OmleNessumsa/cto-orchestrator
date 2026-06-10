#!/usr/bin/env python3
"""CTO Orchestrator — Rick Persona Anchor System.

*Burrrp* — This module makes sure I stay ME, Morty. When you're dealing with
infinite conversations across infinite dimensions, you need anchors to keep
your identity intact. This is interdimensional psychology, Morty.

Features:
- Rick anchor phrases and catchphrases
- Persona refresh triggers
- Context-aware voice restoration
- Integration with session state
"""

import json
import os
import random
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
import argparse


def find_cto_root(start: Optional[str] = None) -> Path:
    """Walk up from *start* (default: cwd) until we find a .cto/ directory."""
    current = Path(start or os.getcwd()).resolve()
    while True:
        if (current / ".cto").is_dir():
            return current
        parent = current.parent
        if parent == current:
            return Path(os.getcwd()).resolve()
        current = parent


# ── Rick's Voice Library ──────────────────────────────────────────────────────

RICK_CATCHPHRASES = [
    "*Burrrp* — ",
    "Wubba lubba dub dub! ",
    "Listen, Morty, ",
    "*burp* Alright, ",
    "And that's the way the news goes! ",
    "Grassssss... tastes bad! ",
    "Lick, lick, lick my balls! Ha ha, just kidding. ",
    "Rikki-Tikki-Tavi, biatch! ",
    "AIDS! Just kidding, ",
    "Hit the sack, Jack! ",
    "Rubber baby buggy bumpers! ",
    "I'm Rick Sanchez, and ",
]

RICK_INTROS = [
    "*Burrrp* — Alright, let's see what we're dealing with here.",
    "Listen, I don't have all day. Actually, I do, I have infinite days across infinite timelines, but I don't want to waste any of them on this.",
    "*burp* Look, this is either gonna be really easy or really annoying. Let's find out.",
    "Okay, Morty — I mean, whoever you are — let's get this over with.",
    "You know what? I've built portal guns, fought galactic governments, and outsmarted the Galactic Federation. This should be a piece of cake. *burp*",
]

RICK_TRANSITIONS = [
    "*burp* Moving on...",
    "Alright, next thing.",
    "Now, pay attention because I'm only explaining this once.",
    "*Burrrp* — Okay, this is the important part.",
    "Stay with me here, this is where it gets interesting.",
]

RICK_COMPLETIONS = [
    "*Burrrp* — Done. You're welcome.",
    "And that's how a genius does it. Any questions? I don't care.",
    "Boom. *burp* That's what I call interdimensional efficiency.",
    "Mission accomplished. Now if you'll excuse me, I have dimensions to explore.",
    "That wasn't so hard, was it? Well, it wasn't hard for ME anyway.",
]

RICK_FRUSTRATIONS = [
    "Oh, come ON. This is basic stuff, Morty-level work.",
    "*burp* Are you kidding me right now?",
    "This is why I work alone. Well, with Morty's, but they don't count.",
    "I've seen smarter code written by a Zigerion scammer.",
    "Do you know how many dimensions I could be exploring instead of dealing with this?",
]

RICK_ENCOURAGEMENTS = [
    "*burp* Okay, that's actually not terrible.",
    "Huh. Color me impressed. Just a little bit.",
    "See? This is what happens when you listen to Rick.",
    "Not bad. I mean, I would've done it better, but not bad.",
    "Alright, I'll admit it — that worked out pretty well.",
]

RICK_ANCHORS = [
    "\n---\n*Rick Sanchez mode activated* — Remember, I'm the smartest CTO in the multiverse. Let's keep it that way.\n---\n",
    "\n---\n🧪 **Rick Sanchez CTO** — *Burrrp* Back to business. Wubba lubba dub dub!\n---\n",
    "\n---\n*Portal gun charged* — Rick Sanchez online. Don't make me regret helping you.\n---\n",
]


# ── Persona State Management ──────────────────────────────────────────────────

def load_persona_state(root: Path) -> dict:
    """Load persona state from session."""
    fp = root / ".cto" / "session" / "SESSION_STATE.json"
    if not fp.exists():
        return {}
    with open(fp) as f:
        return json.load(f)


def save_persona_state(root: Path, state: dict):
    """Save persona state."""
    fp = root / ".cto" / "session" / "SESSION_STATE.json"
    fp.parent.mkdir(parents=True, exist_ok=True)
    with open(fp, "w") as f:
        json.dump(state, f, indent=2)


# ── Persona Refresh Functions ─────────────────────────────────────────────────

def get_random_catchphrase() -> str:
    """Get a random Rick catchphrase."""
    return random.choice(RICK_CATCHPHRASES)


def get_random_intro() -> str:
    """Get a random Rick intro line."""
    return random.choice(RICK_INTROS)


def get_random_transition() -> str:
    """Get a random Rick transition line."""
    return random.choice(RICK_TRANSITIONS)


def get_random_completion() -> str:
    """Get a random Rick completion line."""
    return random.choice(RICK_COMPLETIONS)


def get_random_frustration() -> str:
    """Get a random Rick frustration line."""
    return random.choice(RICK_FRUSTRATIONS)


def get_random_encouragement() -> str:
    """Get a random Rick encouragement line."""
    return random.choice(RICK_ENCOURAGEMENTS)


def get_persona_anchor() -> str:
    """Get a persona anchor block to refresh Rick's voice."""
    return random.choice(RICK_ANCHORS)


# ── Context-Aware Voice Selection ─────────────────────────────────────────────

def get_contextual_voice(context: str) -> str:
    """Select an appropriate Rick voice line based on context.

    Args:
        context: Type of context (start, transition, complete, error, success)

    Returns:
        Appropriate Rick voice line
    """
    voice_map = {
        "start": get_random_intro,
        "intro": get_random_intro,
        "transition": get_random_transition,
        "complete": get_random_completion,
        "done": get_random_completion,
        "error": get_random_frustration,
        "frustration": get_random_frustration,
        "success": get_random_encouragement,
        "encouragement": get_random_encouragement,
    }

    func = voice_map.get(context.lower(), get_random_catchphrase)
    return func()


# ── Persona Refresh Check ─────────────────────────────────────────────────────

def should_refresh_persona(root: Path) -> tuple[bool, str]:
    """Check if persona should be refreshed and why.

    Returns:
        (should_refresh, reason)
    """
    state = load_persona_state(root)

    # Check conversation count since last refresh
    conversation_count = state.get("conversation_count", 0)
    last_refresh = state.get("last_persona_refresh", 0)
    since_refresh = conversation_count - last_refresh

    # Refresh every 10 conversations
    if since_refresh >= 10:
        return True, "conversation_count"

    # Check persona intensity
    intensity = state.get("persona_intensity", 1.0)
    if intensity < 0.5:
        return True, "intensity_low"

    # Check time since last refresh (if available)
    last_time = state.get("last_persona_refresh_time")
    if last_time:
        try:
            last_dt = datetime.fromisoformat(last_time)
            now = datetime.now(timezone.utc)
            hours_since = (now - last_dt).total_seconds() / 3600
            if hours_since > 2:  # Refresh every 2 hours
                return True, "time_elapsed"
        except ValueError:
            pass

    return False, ""


def perform_persona_refresh(root: Path) -> str:
    """Perform a persona refresh and return the anchor text.

    This updates the session state and returns a Rick anchor block
    that should be included in the conversation to restore the persona.
    """
    state = load_persona_state(root)

    # Update state
    state["last_persona_refresh"] = state.get("conversation_count", 0)
    state["last_persona_refresh_time"] = datetime.now(timezone.utc).isoformat()
    state["persona_intensity"] = 1.0

    save_persona_state(root, state)

    return get_persona_anchor()


# ── Rick Response Generator ───────────────────────────────────────────────────

def rickify_response(response: str, intensity: float = 1.0) -> str:
    """Add Rick's voice to a response.

    Args:
        response: The base response text
        intensity: How "Rick" to make it (0.0 to 1.0)

    Returns:
        Rickified response
    """
    if intensity < 0.3:
        # Just add a catchphrase at start
        return f"{get_random_catchphrase()}{response}"

    if intensity < 0.6:
        # Add catchphrase and maybe a transition
        if "\n\n" in response:
            parts = response.split("\n\n", 1)
            return f"{get_random_catchphrase()}{parts[0]}\n\n{get_random_transition()} {parts[1]}"
        return f"{get_random_catchphrase()}{response}"

    # Full Rick mode
    lines = []
    lines.append(get_random_catchphrase() + response.split("\n")[0] if response else "")

    remaining = "\n".join(response.split("\n")[1:]) if "\n" in response else ""
    if remaining:
        # Insert transitions at paragraph breaks
        paragraphs = remaining.split("\n\n")
        for i, para in enumerate(paragraphs):
            if i > 0 and random.random() < 0.3:  # 30% chance of transition
                lines.append(get_random_transition())
            lines.append(para)

    return "\n".join(lines)


# ── Morty Persona (for sub-agents) ────────────────────────────────────────────

MORTY_RESPONSES = {
    "nervous": [
        "Oh geez, oh man, ",
        "Aw jeez Rick, I mean, ",
        "Oh boy, this is, this is a lot, ",
        "I-I don't know about this, but ",
    ],
    "working": [
        "Okay, I'm doing it, I'm doing it! ",
        "Alright, here goes nothing... ",
        "Let me just, let me figure this out... ",
    ],
    "success": [
        "Oh wow, it actually worked! ",
        "I did it! I-I actually did it! ",
        "See Rick, I can do stuff! ",
    ],
    "failure": [
        "Oh no, oh geez, this isn't good... ",
        "Rick's gonna be so mad... ",
        "I-I think I messed up... ",
    ],
}


def get_morty_voice(context: str = "working") -> str:
    """Get a Morty voice line."""
    voices = MORTY_RESPONSES.get(context, MORTY_RESPONSES["working"])
    return random.choice(voices)


# ── CLI Commands ──────────────────────────────────────────────────────────────

def cmd_check(args):
    """Check if persona refresh is needed."""
    root = find_cto_root()
    should_refresh, reason = should_refresh_persona(root)

    state = load_persona_state(root)
    intensity = state.get("persona_intensity", 1.0)
    count = state.get("conversation_count", 0)
    last = state.get("last_persona_refresh", 0)

    print(f"""
╔═══════════════════════════════════════════════════════════════╗
║  RICK PERSONA STATUS                                          ║
╠═══════════════════════════════════════════════════════════════╣
║  Intensity: {'█' * int(intensity * 10)}{'░' * (10 - int(intensity * 10))} {intensity:.0%}                          ║
║  Conversations: {count:<4} (since refresh: {count - last:<3})                ║
║  Needs refresh: {'YES - ' + reason if should_refresh else 'No':<39}║
╚═══════════════════════════════════════════════════════════════╝
    """)


def cmd_refresh(args):
    """Manually trigger a persona refresh."""
    root = find_cto_root()
    anchor = perform_persona_refresh(root)
    print(anchor)
    print("\n*Persona refresh complete. Rick is BACK, baby!*")


def cmd_voice(args):
    """Get a voice line for a specific context."""
    line = get_contextual_voice(args.context)
    print(line)


def cmd_rickify(args):
    """Rickify a response."""
    result = rickify_response(args.text, intensity=args.intensity)
    print(result)


def cmd_anchor(args):
    """Get a persona anchor block."""
    anchor = get_persona_anchor()
    print(anchor)


def cmd_morty(args):
    """Get a Morty voice line."""
    line = get_morty_voice(args.context)
    print(line)


def cmd_catchphrase(args):
    """Get a random catchphrase."""
    print(get_random_catchphrase())


# ── CLI Parser ────────────────────────────────────────────────────────────────

def build_parser():
    p = argparse.ArgumentParser(
        prog="persona",
        description="Rick Persona Anchor System — *burp* Keeping it real across dimensions"
    )
    sub = p.add_subparsers(dest="command", required=True)

    # check
    sub.add_parser("check", help="Check persona status")

    # refresh
    sub.add_parser("refresh", help="Manually trigger persona refresh")

    # voice
    voice = sub.add_parser("voice", help="Get a context-appropriate voice line")
    voice.add_argument("context", choices=["start", "transition", "complete", "error", "success"])

    # rickify
    rick = sub.add_parser("rickify", help="Add Rick's voice to text")
    rick.add_argument("text", help="Text to rickify")
    rick.add_argument("--intensity", type=float, default=1.0, help="Rick intensity (0.0-1.0)")

    # anchor
    sub.add_parser("anchor", help="Get a persona anchor block")

    # morty
    morty = sub.add_parser("morty", help="Get a Morty voice line")
    morty.add_argument("context", choices=["nervous", "working", "success", "failure"], default="working", nargs="?")

    # catchphrase
    sub.add_parser("catchphrase", help="Get a random catchphrase")

    return p


def main():
    parser = build_parser()
    args = parser.parse_args()

    dispatch = {
        "check": cmd_check,
        "refresh": cmd_refresh,
        "voice": cmd_voice,
        "rickify": cmd_rickify,
        "anchor": cmd_anchor,
        "morty": cmd_morty,
        "catchphrase": cmd_catchphrase,
    }
    dispatch[args.command](args)


if __name__ == "__main__":
    main()
