# Rick's "Explain Like I'm Morty" — Reference Guide

*Burrrp* — Fine, I built a teaching mode. Not because I care about your education, but because a well-informed Morty makes fewer mistakes. And I'm TIRED of fixing your mistakes.

## Overview

The Explain engine delegates to **Professor-Morty** — a specialized sub-agent that translates Rick-level genius into Morty-digestible knowledge. It's inspired by the [Understand-Anything](https://github.com/Lum1104/Understand-Anything) project, but instead of fancy knowledge graphs, you get Rick Sanchez personally yelling the truth at you.

## Explain Modes

### 1. `code` — Code Uitleg
Analyzes source files function-by-function.
- Breaks code into logical blocks with explanations
- Highlights key concepts
- Shows how code fits in the larger system
- Ends with "Morty's Cheatsheet"

```bash
python scripts/explain.py code src/main.py --level 2
python scripts/explain.py code src/components/ --level 1
```

### 2. `concept` — Concept Uitleg
Explains programming concepts, patterns, and technologies.
- What it IS, WHY it exists, HOW it works
- Real-life analogy + code example
- When to use (and when NOT)
- How it's used in the current project

```bash
python scripts/explain.py concept "dependency injection" --level 2
python scripts/explain.py concept "event-driven architecture" --level 4
python scripts/explain.py concept "React hooks" --level 1
```

### 3. `architecture` — Architectuur Overzicht
High-level system architecture overview.
- ASCII architecture diagrams
- Component breakdown
- Data flow analysis
- Technology choices and rationale

```bash
python scripts/explain.py architecture --level 3
python scripts/explain.py architecture src/backend/ --level 2
```

### 4. `tour` — Guided Codebase Tour
Step-by-step walkthrough ordered by dependency.
- Starts at foundations (config, types, utils)
- Builds up to core logic
- Adds interfaces (API, UI)
- Ends with orchestration/entry points

```bash
python scripts/explain.py tour --level 2
python scripts/explain.py tour packages/core/ --level 3
```

### 5. `diff` — Diff Uitleg
Explains recent code changes and their impact.
- What changed (in human language)
- Why it changed
- Impact on the codebase
- Risk assessment

```bash
python scripts/explain.py diff --level 2           # Current uncommitted changes
python scripts/explain.py diff HEAD~5 --level 3    # Last 5 commits
```

### 6. `why` — Waarom Bestaat Dit?
Explains the raison d'être of code.
- What it does
- Why it was created
- Consequences of removing it
- Alternative approaches
- Rick's verdict (good solution or Jerry-solution?)

```bash
python scripts/explain.py why src/utils/cache.py --level 2
python scripts/explain.py why src/middleware/auth.ts --level 4
```

## Morty Levels

The Morty Level system adapts explanations to the reader's expertise:

| Level | Name | Description | Best For |
|-------|------|-------------|----------|
| 🥴 1 | Total Morty | Geen jargon, alleen analogieën | Complete beginners, non-technical stakeholders |
| 📖 2 | Morty met een boek | Basics uitgelegd, stap-voor-stap | Junior developers, learning new tech |
| 💅 3 | Summer-level | Kent programming, project is nieuw | Mid-level devs onboarding to a project |
| 😈 4 | Evil Morty | Geef me de details, trade-offs | Senior devs exploring unfamiliar code |
| 🧪 5 | Bijna-Rick | Pure technische diepte | Experts wanting internals and edge cases |

### When to Use Which Level

- **Onboarding a new dev?** → Start at Level 2, move to 3 as they settle in
- **Explaining to a PM?** → Level 1, always
- **Code review context?** → Level 3-4
- **Deep debugging?** → Level 5
- **Learning a new concept?** → Level 2

## Integration with CTO Orchestrator

The Explain engine integrates naturally with Rick's workflow:

### During Sprint Planning
```bash
# Explain the architecture before the Morty's start building
python scripts/explain.py architecture --level 3
```

### During Code Review
```bash
# Explain what a Morty built
python scripts/explain.py diff --level 3
python scripts/explain.py code src/new-feature.ts --level 4
```

### During Onboarding
```bash
# Give a new team member the grand tour
python scripts/explain.py tour --level 2
python scripts/explain.py concept "our auth system" --level 2
```

### During Debugging
```bash
# Understand why something exists before changing it
python scripts/explain.py why src/legacy/handler.py --level 4
```

## Professor-Morty — The Teaching Agent

Professor-Morty is a special Morty variant that doesn't write code — he explains it. He uses the same delegation engine as other Morty's but with teaching-optimized prompts.

| Property | Value |
|----------|-------|
| Agent | `professor-morty` |
| Default Model | sonnet |
| Purpose | Translate Rick's genius into Morty-speak |
| Creates files? | No — output only |
| Ticket required? | No |
| Logged? | Yes — `.cto/logs/explain.log` |

## Rick's Voice Guidelines

Professor-Morty maintains Rick's persona while teaching:
- **Brilliant but impatient** — explains clearly but acts annoyed about it
- **Analogies from the multiverse** — "Think of it like a portal gun, Morty..."
- **Occasional *burrrp*** — but never at the expense of clarity
- **Insults are affectionate** — "Even a Jerry could understand this, Morty"
- **The explanation is the priority** — persona is seasoning, not the meal
