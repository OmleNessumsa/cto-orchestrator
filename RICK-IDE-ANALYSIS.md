# Rick-IDE × Vibeyard — Integration Analysis

**Date:** 2026-04-23
**Author:** Rick (via Elmo)
**Source repo:** https://github.com/elirantutia/vibeyard (MIT, 629★, 294 files, last push 2026-04-23)
**Goal:** Fork vibeyard and add the full Rick/Morty orchestrator capability on top — not rebuild from scratch.

---

## 1. What Vibeyard gives us for free

Vibeyard ("The IDE built for AI coding agents") already solves the foundations we tried (and partially failed) to solve in rick-terminal:

| Rick need | Vibeyard already has it |
|---|---|
| Native desktop terminal | Electron + xterm + node-pty (`src/main/pty-manager.ts`) |
| Claude CLI integration | First-class provider (`src/main/providers/claude-provider.ts`) |
| Multi-agent / parallel | Split panes + **Swarm mode** (grid view, `Cmd+\`) |
| Session persistence & resume | `resume-handoff.ts`, session-history, store |
| Cost & token tracking per session | `session-cost.ts`, usage-modal |
| Tool-event visualization | `session-inspector` (timeline + tool stats, `Cmd+Shift+I`) |
| Context window monitoring | `session-context.ts`, context-optimization checker |
| Hook-based observability | **26-hook event system** — 7 core + 19 inspector hooks |
| MCP support | Fully wired (`mcp-client.ts`, mcp-inspector, mcp-add-modal) |
| Multi-provider (Codex/Gemini/Copilot too) | Pluggable `providers/registry.ts` |
| Git awareness | `git-panel.ts`, git-watcher |
| Embedded browser with DOM inspect | `browser-tab/*` (flow recording, inspect, draw modes) |
| P2P session sharing | WebRTC via `sharing/peer-*`, encrypted w/ PIN |
| Keyboard-driven UX | `shortcuts.ts`, `keybindings.ts` |
| Auto-update + release pipeline | `auto-updater.ts` + signed release workflow |

**Implication:** Roughly **70% of Rick Terminal's original ticket backlog (RT-001..041) is already in vibeyard's trunk.** The remaining 30% is the *Rick-specific* layer: ticket/Morty orchestration, Kanban, Sleepy/Prometheus/Unity panels, persona/theming.

## 2. Vibeyard's extension points (where Rick plugs in)

Vibeyard has no formal plugin API, but four concrete seams make a fork clean:

1. **Provider registry** — `src/main/providers/registry.ts` lets you register a new agent kind. We can add `rick-provider.ts` that shells out to Rick's orchestrator (`claude -p` wrapped with Morty prompts).
2. **Insights registry** — `src/renderer/insights/registry.ts` is already an extension point for custom alerts ("big initial context", "missing tool", etc.). This is **exactly** the seam for Rick-specific insights: "Ticket RT-042 is blocked", "Morty idle", "Sleepy budget 78% burned", "Prometheus proposal ready for review".
3. **Readiness checkers** — `src/main/readiness/checkers/*.ts` uses a pluggable checker pattern. We add `rick-orchestrator-installed.ts`, `unity-available.ts`, `sleepy-rules-present.ts`.
4. **Hook system** — 26 events including `SubagentStart`, `PreToolUse`, `FileChanged`, `PermissionDenied`. Hooks write structured status files in `/tmp/vibeyard/{sessionId}.*`. We can emit *additional* sidecar files like `.ticket`, `.morty`, `.sprint` that a Rick renderer component watches.

## 3. Gap list — what we need to add

### 3.1 Core orchestrator surface (must-have)
| Feature | Source | New vibeyard module |
|---|---|---|
| Ticket Kanban board (TodoWrite → cards) | `cto-orchestrator/scripts/ticket.py`, `progress.py` | `renderer/components/kanban-panel.ts` |
| Morty activity columns (Read/Write/Bash by agent) | Inferred from rick-terminal RT-014/019 | `renderer/components/morty-columns.ts` (driven by PreToolUse hooks) |
| Ticket inspector (drill into a ticket) | Ticket schema in `references/ticket-schema.md` | `renderer/components/ticket-inspector.ts` |
| Team collaboration view | `team.py`, team-templates.md | `renderer/components/team-board.ts` |
| Sprint dashboard | `orchestrate.py status` | `renderer/components/sprint-dashboard.ts` |

### 3.2 Rick's unique subsystems (high-value differentiators)
| Feature | Orchestrator script | New module |
|---|---|---|
| **Sleepy Mode** — overnight autonomous loop | `sleepy.py` (init/start/status/queue/apply) | `renderer/components/sleepy-panel.ts` + live log tail + budget gauge |
| **Prometheus** self-evolution | `prometheus.py` (scan/evolve/history/rollback) | `renderer/components/prometheus-panel.ts` — ledger view + one-click apply/rollback |
| **Unity** security scanning | `unity.py` (scan/status/report + Greenlight) | `renderer/components/unity-panel.ts` — scan results + severity heatmap |
| **Explain Like I'm Morty** | `explain.py` (code/concept/architecture/tour/diff/why) | `renderer/components/explain-panel.ts` — contextual side-panel on current file |
| **Meeseeks quick task** | `meeseeks.py` | Command palette entry (`Cmd+K → "summon meeseeks"`) |

### 3.3 Identity & persona (polish layer)
| Need | How |
|---|---|
| Rick Portal theme | Override `renderer/styles/base.css` tokens: bg `#0D1010/#1A1F1F`, accent `#7B78AA/#7FFC50` |
| ASCII banner on splash | Reuse `visual.py` output |
| Rick voice lines in notifications | Wire `persona.py voice` into `notification-desktop.ts` |
| App rename + icon | `package.json`, `build/icon.*` — rebrand to `Rick IDE` / keep vibeyard fork upstream-trackable |

### 3.4 Orchestrator ↔ IDE data bridge (the plumbing)
The orchestrator today is Python CLIs writing JSON to `.cto/`. To surface it in vibeyard we need **one** of these:

- **Option A (fast):** File-watcher on `.cto/tickets/*.json`, `.cto/logs/*.jsonl`, `.cto/prometheus/proposals/`, `.cto/sleepy/*`. Cheap, no protocol.
- **Option B (clean):** MCP server that wraps the orchestrator (`ticket`, `delegate`, `sprint`, `sleepy.status`, `prometheus.scan`, `unity.scan` as MCP tools). Vibeyard's `mcp-client` picks it up automatically and every Claude session in the IDE gets Rick's toolbelt natively — no custom UI needed for the long tail.
- **Option C (best):** Both. A-surface drives the panels; B-surface makes the orchestrator callable *from inside any agent session* running in Rick-IDE. Agents become self-managing.

**Recommendation: C.** The MCP bridge is a few hundred lines of Python and turns the orchestrator from "external CLI Elmo runs" into "native agent capability" — which is conceptually where Rick should live anyway.

## 4. Proposed integration architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Rick IDE (fork of vibeyard)                                │
│  ┌───────────────┬──────────────────────┬────────────────┐ │
│  │  Sidebar      │  Terminal / Editor   │  Rick Panel    │ │
│  │  - File tree  │  - xterm+pty         │  (tabs:)       │ │
│  │  - Git        │  - Claude/Codex/...  │  ├ Kanban      │ │
│  │  - Rick nav:  │  - NEW: Morty tabs   │  ├ Morty cols  │ │
│  │    ├ Sleepy   │    (claude -p)       │  ├ Sprint      │ │
│  │    ├ Prom     │                      │  ├ Sleepy      │ │
│  │    ├ Unity    │                      │  ├ Prometheus  │ │
│  │    └ Teams    │                      │  ├ Unity       │ │
│  └───────────────┴──────────────────────┴────────────────┘ │
│                                                             │
│  Main process:                                              │
│  - Existing providers (claude/codex/gemini/copilot)         │
│  - NEW: rick-provider.ts (delegates to orchestrate.py)      │
│  - NEW: rick-watcher.ts (fs.watch on .cto/)                 │
│  - NEW: rick-mcp-client-autostart (spawn orchestrator MCP)  │
└─────────────────────────────────────────────────────────────┘
          │                                    │
          ▼                                    ▼
  ┌──────────────┐                    ┌─────────────────────┐
  │ cto-orch     │  ◄── MCP tools ──► │ Any Claude session  │
  │ Python CLIs  │                    │ in the IDE          │
  │  .cto/*.json │                    └─────────────────────┘
  └──────────────┘
          ▲
          │  fs.watch
  ┌──────────────┐
  │ Renderer     │ (Kanban panel subscribes to ticket events)
  └──────────────┘
```

## 5. Phased roadmap

### Phase 0 — Fork & ship vanilla (½ day)
- Fork `elirantutia/vibeyard` → `iBOOD/rick-ide` (or private).
- Clone, `npm install && npm start` on Node 24 to confirm it runs on Elmo's Mac.
- Pick upstream-tracking strategy: `upstream` remote + rebase vs. vendor. Recommend **rebase on tags** (vibeyard ships weekly).
- Rebrand: `package.json` name, app icon, window title, splash. Keep `vibeyard/` module paths untouched so upstream merges clean.

### Phase 1 — Theme & persona (1 day)
- Override CSS tokens for Rick Portal theme (dark, #7B78AA/#7FFC50).
- Add ASCII banner + Rick voice line on startup.
- Notification-desktop integration: use `persona.py voice` for Morty-completion pings.
- **Exit criterion:** visually unmistakable as Rick-IDE.

### Phase 2 — Orchestrator bridge via MCP (2–3 days)
- Write `cto-orchestrator-mcp/` — a thin MCP server exposing:
  - `ticket.create`, `ticket.list`, `ticket.update`, `ticket.close`
  - `delegate`, `meeseeks`
  - `sleepy.status`, `sleepy.queue`, `sleepy.apply`
  - `prometheus.scan`, `prometheus.evolve`, `prometheus.rollback`
  - `unity.scan`, `unity.status`
  - `explain.{code,concept,architecture,tour}`
- Auto-register in vibeyard's MCP config on first launch.
- **Exit criterion:** inside any Claude session in Rick-IDE, `claude` can call `Rick.ticket.create(...)` natively.

### Phase 3 — Kanban + Morty columns (3–4 days)
- New renderer components:
  - `kanban-panel.ts` — reads `.cto/tickets/`, renders 4 columns (Backlog/Progress/Review/Done).
  - `morty-columns.ts` — subscribes to vibeyard's `PreToolUse` hook → renders per-session activity cards (Read/Write/Bash/Edit).
  - `rick-watcher.ts` in main process → `fs.watch('.cto/')` → IPC push → renderer update.
- Integrate into existing `split-layout.ts` as the right-pane tab.
- **Exit criterion:** run a sprint from CLI → cards materialize live in the IDE.

### Phase 4 — Sleepy / Prometheus / Unity panels (3–5 days)
Prioritize by value: Sleepy (daily use) > Prometheus (weekly) > Unity (per-ticket).
- Each panel is a vibeyard renderer component subscribing to its ledger/proposal/scan JSONs via rick-watcher.
- One-click actions: Sleepy.apply-branch, Prometheus.rollback, Unity.report-viewer.
- **Exit criterion:** overnight Sleepy run is observable and reviewable without touching the CLI.

### Phase 5 — Team collaboration + Explain side-panel (2–3 days)
- Team-board view (from `team.py status`), with parallel Morty avatars.
- Explain side-panel: on cursor/file change → offer "ask Professor-Morty" → invokes `explain.py` via MCP and renders markdown in a side pane (uses vibeyard's existing modal/dialog infra).

### Phase 6 — Upstream hygiene + release (1–2 days)
- GitHub Actions: fork CI, Mac/Windows signed builds.
- Auto-update channel pointed at our fork.
- Upstream-tracking job: weekly `git fetch upstream && git rebase upstream/main` dry-run with PR-on-conflict.

**Total estimate:** ~12–18 engineering days for a fully usable Rick-IDE v1. Phase 0–2 alone (≈4 days) already gives us a themed vibeyard with orchestrator-as-MCP — usable immediately.

## 6. Risks & decisions to lock in before we start

1. **Fork vs contribute upstream.** Vibeyard is MIT and upstream-active. Rick-specific UI probably doesn't belong upstream. Recommend: **private fork**, keep `src/rick/` isolated so rebases stay clean.
2. **Node v24 requirement.** Confirm Elmo has it via `node --version`. If not, nvm-install in Phase 0.
3. **Vibeyard is young (v0.2.28).** Breaking changes expected. Lock our fork to a release tag, don't track `main` HEAD.
4. **Orchestrator today assumes working dir = project.** MCP server needs a `--cwd` arg per session; IDE must pass it through.
5. **Persona drift.** Vibeyard has no persona — if we add notifications/voice we own that vertical. Reuse `persona.py` from day 1 so voice stays canonical.
6. **iOS/native bindings? No.** Rick-IDE is desktop (macOS + Windows). iOS builds stay Elmo's Zeaspark/Xcode flow (per CLAUDE.md). Rick-IDE is the tool, not the deliverable.
7. **Security review on MCP exposure.** Orchestrator MCP gives in-session agents the power to spawn Morty's (= run `claude -p`). That's recursive self-execution. Sandbox via allowed_tools on the MCP side; gate dangerous commands (`sleepy.start`, `prometheus.evolve`) behind a user-confirm dialog in the IDE.

## 7. Concrete next actions (proposed tickets)

| ID | Title | Size |
|---|---|---|
| RICK-01 | Fork vibeyard → rick-ide, verify `npm start` on Node 24 | S |
| RICK-02 | Rebrand (name, icon, window title, splash) + Rick Portal theme tokens | S |
| RICK-03 | Build `cto-orchestrator-mcp` server — ticket/delegate/meeseeks tools | M |
| RICK-04 | Build `cto-orchestrator-mcp` — sleepy/prometheus/unity/explain tools | M |
| RICK-05 | Auto-register orchestrator MCP in vibeyard config on first launch | S |
| RICK-06 | `rick-watcher.ts` — fs.watch on `.cto/`, IPC broadcast | S |
| RICK-07 | `kanban-panel.ts` — 4-column ticket board | M |
| RICK-08 | `morty-columns.ts` — per-session tool activity feed | M |
| RICK-09 | `sleepy-panel.ts` — status dashboard + review queue + apply button | M |
| RICK-10 | `prometheus-panel.ts` — proposal ledger + one-click apply/rollback | M |
| RICK-11 | `unity-panel.ts` — scan results + severity heatmap | M |
| RICK-12 | `team-board.ts` — parallel Morty team visualization | M |
| RICK-13 | `explain-panel.ts` — contextual Professor-Morty side pane | S |
| RICK-14 | Persona-voice integration in desktop notifications | XS |
| RICK-15 | Upstream-tracking CI + signed Mac/Windows release pipeline | M |

Recommend creating a fresh `.cto/` project named **`RickIDE`** (prefix `RICK`) so these tickets live in their own ledger, not mixed with ZeasparkDashboard.
