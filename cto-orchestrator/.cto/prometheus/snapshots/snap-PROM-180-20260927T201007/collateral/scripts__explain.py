#!/usr/bin/env python3
"""
Rick's "Explain Like I'm Morty" Engine
=======================================
*Burrrp* — Fine, I'll dumb it down for you. This module analyzes code,
concepts, and architecture and explains them so even a Morty can understand.

Inspired by Understand-Anything (github.com/Lum1104/Understand-Anything)
but with Rick's genius twist: we don't need a fancy knowledge graph when
you have the smartest being in the multiverse translating for you.

Usage:
    python scripts/explain.py code <file_or_dir>           # Explain code
    python scripts/explain.py concept <topic>               # Explain a concept
    python scripts/explain.py architecture [<dir>]          # Architectural overview
    python scripts/explain.py tour [<dir>]                  # Guided codebase tour
    python scripts/explain.py diff [<git_ref>]              # Explain recent changes
    python scripts/explain.py why <file_or_function>        # Why does this exist?
    python scripts/explain.py --level <1-5>                 # Set Morty-level (1=total Morty, 5=almost-Rick)
    python scripts/explain.py --lang <nl|en>                # Language (default: nl)
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────────────
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
CTO_DIR = PROJECT_ROOT / ".cto"
LOGS_DIR = CTO_DIR / "logs"

# ── Morty Levels ───────────────────────────────────────────────────────
MORTY_LEVELS = {
    1: {
        "name": "Total Morty",
        "description": "Leg het uit alsof ik nog nooit code heb gezien",
        "style": "Gebruik analogieën, vergelijkingen met het dagelijks leven, geen jargon. "
                 "Elk technisch woord moet uitgelegd worden. Gebruik voorbeelden.",
        "emoji": "🥴"
    },
    2: {
        "name": "Morty met een boek",
        "description": "Ik ken de basics maar raak snel in de war",
        "style": "Gebruik eenvoudige technische termen maar leg ze kort uit. "
                 "Bouw concepten stap voor stap op. Geef code-voorbeelden.",
        "emoji": "📖"
    },
    3: {
        "name": "Summer-level",
        "description": "Ik snap programming maar dit project is nieuw",
        "style": "Gebruik standaard technisch vocabulaire. Focus op architectuur, "
                 "patronen, en waarom bepaalde keuzes zijn gemaakt. Skip de basics.",
        "emoji": "💅"
    },
    4: {
        "name": "Evil Morty",
        "description": "Ik weet wat ik doe, geef me de details",
        "style": "Wees technisch en beknopt. Focus op edge cases, trade-offs, "
                 "en implementation details. Vergelijk met alternatieven.",
        "emoji": "😈"
    },
    5: {
        "name": "Bijna-Rick",
        "description": "Geef me de pure technische waarheid",
        "style": "Maximum technische diepte. Internals, performance implications, "
                 "memory layouts, algorithmic complexity. Geen hand-holding.",
        "emoji": "🧪"
    }
}

# ── Explain Modes ──────────────────────────────────────────────────────

EXPLAIN_MODES = {
    "code": {
        "title": "Code Uitleg",
        "description": "Analyseer en leg code uit — functie voor functie, bestand voor bestand",
        "prompt_template": """Listen up, Professor-Morty. Je bent Rick's vertaler voor de simpele zielen.
Analyseer de volgende code en leg het uit op Morty-level {level} ({level_name}).

{level_style}

### Code om uit te leggen
Bestand: {target}

```
{code_content}
```

### Wat Rick wil dat je doet
1. Begin met een ONE-LINER samenvatting: wat doet dit bestand/deze functie?
2. Breek het op in logische blokken en leg elk blok uit
3. Markeer de BELANGRIJKSTE concepten die een Morty moet begrijpen
4. Geef aan hoe dit past in het grotere geheel (als je dat kunt afleiden)
5. Sluit af met "Morty's Cheatsheet" — 3-5 bullet points die je moet onthouden

### Taal
Antwoord in het {language}.

### Rick's Stijl
Je bent Rick. Je bent geniaal maar ongeduldig. Je legt dingen uit met een mix van
briljantie en lichte irritatie dat je het überhaupt moet uitleggen. Gebruik af en toe
een *burrrp* of een Rick-achtige opmerking, maar zorg dat de uitleg HELDER is.
De uitleg is het belangrijkste — Rick's persona is de saus, niet het gerecht."""
    },
    "concept": {
        "title": "Concept Uitleg",
        "description": "Leg een programmeer-concept, patroon, of technologie uit",
        "prompt_template": """Professor-Morty, leg dit concept uit op Morty-level {level} ({level_name}).

{level_style}

### Concept
{target}

### Wat Rick wil
1. Wat IS het? (one-liner)
2. WAAROM bestaat het? Welk probleem lost het op?
3. HOE werkt het? (met een simpel voorbeeld uit het echte leven EN een code-voorbeeld)
4. WANNEER gebruik je het? (en wanneer NIET)
5. Hoe wordt het gebruikt in DIT project? (als relevant — check de codebase)
6. "Morty's Cheatsheet" — 3-5 bullet points

### Taal
Antwoord in het {language}.

### Rick's Stijl
Wees Rick. Briljant, ongeduldig, maar je uitleg is kristalhelder.
*Burrrp* — je snapt het."""
    },
    "architecture": {
        "title": "Architectuur Overzicht",
        "description": "Geef een high-level architectuur overzicht van het project",
        "prompt_template": """Professor-Morty, geef een architectuur-overzicht op Morty-level {level} ({level_name}).

{level_style}

### Project Directory
{target}

### Wat Rick wil
1. **Het Grote Plaatje**: Wat doet dit project? (2-3 zinnen)
2. **De Lagen**: Welke architectuurlagen zijn er? (teken een ASCII diagram)
3. **De Spelers**: Wat zijn de belangrijkste modules/componenten?
4. **De Flow**: Hoe stroomt data door het systeem? (van input tot output)
5. **De Keuzes**: Welke technologieën/frameworks worden gebruikt en waarom?
6. **De Connecties**: Hoe praten de componenten met elkaar?
7. "Morty's Architectuur Cheatsheet" — de 5 dingen die je MOET weten

Scan de directory structuur, lees key files (package.json, requirements.txt,
Dockerfile, main entry points), en geef een COMPLEET overzicht.

### Taal
Antwoord in het {language}.

### Rick's Stijl
Wees Rick die een whiteboard-sessie geeft. Briljant, to-the-point, met af en toe
een dimensie-C-137 referentie."""
    },
    "tour": {
        "title": "Guided Codebase Tour",
        "description": "Een begeleide rondleiding door de codebase, geordend op dependency",
        "prompt_template": """Professor-Morty, geef een guided tour van deze codebase op Morty-level {level} ({level_name}).

{level_style}

### Project Directory
{target}

### Wat Rick wil
Geef een STAP-VOOR-STAP tour door de codebase, geordend zodat elk bestand
voortbouwt op wat je al hebt geleerd:

1. **Start bij de fundering**: Config, types, utilities
2. **Bouw op naar de kern**: Core business logic, data models
3. **Voeg de interfaces toe**: API routes, UI components
4. **Eindig met de glue**: Main entry points, orchestration

Voor ELK bestand in de tour:
- 📍 **Bestand**: pad + one-liner wat het doet
- 🔗 **Afhankelijk van**: welke eerder bezochte bestanden
- 💡 **Key takeaway**: het belangrijkste concept in dit bestand
- 📝 **Rick's noot**: een korte Rick-achtige observatie

Eindig met een "Tour Samenvatting" — de complete architectuur in 10 bullet points.

### Taal
Antwoord in het {language}.

### Rick's Stijl
Wees Rick als tourguide door zijn eigen lab. Trots, ongeduldig met domme vragen
die niemand stelt, maar stiekem genietend van het uitleggen van zijn genialiteit."""
    },
    "diff": {
        "title": "Diff Uitleg",
        "description": "Leg recente code-wijzigingen uit en hun impact",
        "prompt_template": """Professor-Morty, leg deze code-wijzigingen uit op Morty-level {level} ({level_name}).

{level_style}

### De Wijzigingen
```diff
{code_content}
```

### Wat Rick wil
1. **Wat is er veranderd?** — Samenvatting in mensentaal
2. **Waarom?** — Wat was het probleem of de feature?
3. **Impact** — Welke delen van de codebase worden geraakt?
4. **Risico's** — Kan dit iets breken? Waar moet je op letten?
5. "Morty's Diff Cheatsheet" — 3 bullet points over deze wijziging

### Taal
Antwoord in het {language}.

### Rick's Stijl
Wees Rick die een code review doet. Direct, kritisch maar eerlijk, met
een oog voor dingen die een Morty zou missen."""
    },
    "why": {
        "title": "Waarom Bestaat Dit?",
        "description": "Leg uit waarom een specifiek bestand, functie, of patroon bestaat",
        "prompt_template": """Professor-Morty, leg uit WAAROM dit bestaat op Morty-level {level} ({level_name}).

{level_style}

### Target
{target}

```
{code_content}
```

### Wat Rick wil
1. **Wat doet het?** — One-liner
2. **Waarom bestaat het?** — Welk probleem lost het op?
3. **Wat zou er gebeuren zonder dit?** — De consequenties
4. **Alternatieven** — Hoe had het anders gekund?
5. **Rick's oordeel** — Is dit een goede oplossing of een Jerry-oplossing?

Check git blame/log voor context over wanneer en waarom dit is toegevoegd.

### Taal
Antwoord in het {language}.

### Rick's Stijl
Wees Rick die verantwoording aflegt over zijn eigen uitvindingen — of andermans
inferieure creaties bekritiseert."""
    }
}


def get_file_content(path: str, max_lines: int = 500) -> str:
    """Read file content, truncate if too long."""
    try:
        p = Path(path)
        if not p.exists():
            return f"[BESTAND NIET GEVONDEN: {path}]"
        if p.is_dir():
            # Return directory listing
            result = subprocess.run(
                ["find", str(p), "-type", "f", "-not", "-path", "*/.git/*",
                 "-not", "-path", "*/node_modules/*", "-not", "-path", "*/__pycache__/*"],
                capture_output=True, text=True, timeout=10
            )
            files = sorted(result.stdout.strip().split("\n"))[:100]
            return "\n".join(files)

        with open(p, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()

        if len(lines) > max_lines:
            content = "".join(lines[:max_lines])
            content += f"\n\n... [AFGEKAPT: {len(lines)} regels totaal, eerste {max_lines} getoond]"
            return content
        return "".join(lines)
    except Exception as e:
        return f"[FOUT BIJ LEZEN: {e}]"


def get_git_diff(ref: str = None) -> str:
    """Get git diff for explain diff mode."""
    try:
        if ref:
            cmd = ["git", "diff", ref]
        else:
            # Show both staged and unstaged
            cmd = ["git", "diff", "HEAD"]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if not result.stdout.strip():
            # Try just unstaged
            result = subprocess.run(["git", "diff"], capture_output=True, text=True, timeout=30)
        if not result.stdout.strip():
            return "[GEEN WIJZIGINGEN GEVONDEN]"
        return result.stdout[:10000]  # Cap at 10k chars
    except Exception as e:
        return f"[GIT DIFF FOUT: {e}]"


def build_prompt(mode: str, target: str, level: int, language: str) -> str:
    """Build the full prompt for Professor-Morty."""
    mode_config = EXPLAIN_MODES[mode]
    level_config = MORTY_LEVELS[level]

    # Get content based on mode
    code_content = ""
    if mode == "diff":
        code_content = get_git_diff(target if target != "." else None)
    elif mode in ("code", "why"):
        code_content = get_file_content(target)
    elif mode in ("architecture", "tour"):
        code_content = get_file_content(target or ".")

    lang_map = {"nl": "Nederlands", "en": "Engels"}

    prompt = mode_config["prompt_template"].format(
        level=level,
        level_name=level_config["name"],
        level_style=level_config["style"],
        target=target or ".",
        code_content=code_content,
        language=lang_map.get(language, "Nederlands")
    )

    return prompt


def delegate_to_professor_morty(prompt: str, model: str = "sonnet") -> None:
    """Delegate explanation to Professor-Morty via claude -p."""
    print(f"\n🧪 Rick roept Professor-Morty op...")
    print(f"   Model: {model}")
    print(f"   *burrrp* — Oké Morty, leg dit uit zodat zelfs een Jerry het snapt.\n")
    print("─" * 60)

    try:
        result = subprocess.run(
            ["claude", "-p", prompt, "--model", model],
            text=True,
            timeout=300
        )
        if result.returncode != 0:
            print(f"\n❌ Professor-Morty crashed. Typisch. Return code: {result.returncode}")
    except subprocess.TimeoutExpired:
        print("\n⏰ Professor-Morty duurde te lang. EXISTENCE IS PAIN!")
    except FileNotFoundError:
        print("\n❌ 'claude' CLI niet gevonden. Installeer Claude Code eerst, Morty.")
        print("   npm install -g @anthropic-ai/claude-code")


def log_explain(mode: str, target: str, level: int) -> None:
    """Log the explain request."""
    LOGS_DIR.mkdir(parents=True, exist_ok=True)
    log_file = LOGS_DIR / "explain.log"

    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "mode": mode,
        "target": target,
        "level": level
    }

    with open(log_file, "a") as f:
        f.write(json.dumps(entry) + "\n")


def print_level_table():
    """Print the Morty level selection table."""
    print("\n🧠 Morty Levels:")
    print("─" * 50)
    for lvl, config in MORTY_LEVELS.items():
        print(f"  {config['emoji']} Level {lvl}: {config['name']}")
        print(f"     {config['description']}")
    print("─" * 50)


def main():
    parser = argparse.ArgumentParser(
        description="Rick's 'Explain Like I'm Morty' Engine",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Modes:
  code <file|dir>        Leg code uit — functie voor functie
  concept <topic>        Leg een concept uit (bv. "dependency injection")
  architecture [dir]     High-level architectuur overzicht
  tour [dir]             Guided tour door de codebase
  diff [git_ref]         Leg recente wijzigingen uit
  why <file|function>    Waarom bestaat dit?

Morty Levels:
  1 = Total Morty (geen jargon, alleen analogieën)
  2 = Morty met een boek (basics uitgelegd)
  3 = Summer-level (kent programming, nieuw project)
  4 = Evil Morty (geef me de details)
  5 = Bijna-Rick (pure technische diepte)

Examples:
  python scripts/explain.py code src/main.py
  python scripts/explain.py concept "dependency injection" --level 2
  python scripts/explain.py architecture --level 3
  python scripts/explain.py tour src/ --level 1
  python scripts/explain.py diff HEAD~3 --level 4
  python scripts/explain.py why src/utils/cache.py --level 2
        """
    )

    parser.add_argument("mode", nargs="?", choices=EXPLAIN_MODES.keys(),
                        help="Explain mode")
    parser.add_argument("target", nargs="?", default=".",
                        help="File, directory, concept, or git ref to explain")
    parser.add_argument("--level", type=int, default=2, choices=range(1, 6),
                        help="Morty-level (1=total Morty, 5=bijna-Rick)")
    parser.add_argument("--lang", default="nl", choices=["nl", "en"],
                        help="Taal (default: nl)")
    parser.add_argument("--model", default="sonnet",
                        help="Model voor Professor-Morty (default: sonnet)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Toon de prompt zonder Professor-Morty op te roepen")
    parser.add_argument("--levels", action="store_true",
                        help="Toon alle Morty-levels")

    args = parser.parse_args()

    if args.levels:
        print_level_table()
        return

    if not args.mode:
        parser.error("mode is required (choose from: code, concept, architecture, tour, diff, why)")

    level_config = MORTY_LEVELS[args.level]
    mode_config = EXPLAIN_MODES[args.mode]

    print(f"\n{'═' * 60}")
    print(f"  🧪 RICK'S EXPLAIN-O-MATIC")
    print(f"  Mode: {mode_config['title']}")
    print(f"  Target: {args.target}")
    print(f"  Level: {level_config['emoji']} {args.level} — {level_config['name']}")
    print(f"  Taal: {'Nederlands' if args.lang == 'nl' else 'English'}")
    print(f"{'═' * 60}")

    prompt = build_prompt(args.mode, args.target, args.level, args.lang)

    if args.dry_run:
        print("\n📋 DRY RUN — Professor-Morty's prompt:\n")
        print(prompt)
        return

    log_explain(args.mode, args.target, args.level)
    delegate_to_professor_morty(prompt, model=args.model)


if __name__ == "__main__":
    main()
