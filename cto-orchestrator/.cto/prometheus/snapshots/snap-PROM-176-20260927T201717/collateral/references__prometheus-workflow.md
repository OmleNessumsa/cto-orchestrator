# Prometheus × Dynamic Workflows — In-Session Scan & Evolve Playbook

*Burrrp* — when Rick runs inside a Claude Code session that has the **Workflow
tool** (dynamic workflows / "ultracode"), `Rick evolve` and `prometheus scan`
route through in-session multi-agent orchestration instead of the serial
`claude -p` subprocess loop. The Python engine stays the single authority for
state and safety (snapshots, ledger, rollback, self-protection); the Workflow
tool replaces only the *thinking* stages.

**Fallback rule:** headless contexts (sleepy mode, cron, plain terminal without
the Workflow tool) keep using `python scripts/prometheus.py scan` / `evolve`
unchanged. Never nest `claude -p "ultracode ..."` to fake a workflow from
Python — rejected by design (uncontrollable, unobservable).

## Why this exists (ledger evidence, 2026-07-28 audit)

- 27% of applies failed (timeouts + "false success" where a Morty changed nothing)
- 6× duplicate ideas across scan cycles, 4 of them re-applied
- `risk_score` was never consulted anywhere; scanners self-score (score gaming seen in PROM-048)
- Engine fixes died silently in the self-protection auto-reject (now: `needs-human/` queue)

## Hard rules

1. **Never write into `.cto/prometheus/` directly.** `prometheus.py ingest` is
   the only sanctioned write path for workflow-generated proposals. Serial
   ingest keeps PROM-ID generation and ledger appends race-free.
2. **Scanner self-scores are advisory only.** The verifier re-scores every
   candidate independently; verifier scores win.
3. **`MAX_AUTO_APPLIES_PER_RUN = 3` stays.** An in-session evolve run applies
   at most 3 proposals, each via `evolve --only PROM-NNN`.
4. **Check sleepy first.** If `sleepy_status` shows a run in progress, do not
   run an in-session evolve — the two would race on the same files.
5. **Reviewer is demote-only.** The post-apply reviewer can trigger a rollback
   of its own proposal; it never edits code or approves extra changes.

## Phase 0 — Pre-flight & triage

```bash
python scripts/prometheus.py history-index   # compact digest of all proposals
python scripts/prometheus.py status          # pending / needs-human overview
# + check sleepy is not mid-run (sleepy_status MCP tool or scripts/sleepy.py status)
```

If stale pending proposals exist (older than ~1 week), run the **triage flow**
first: one verifier agent per stale proposal (same verifier spec as Phase 2,
plus a staleness check against current code). Verdicts: `keep` (re-scored),
`duplicate-of PROM-XXX` (→ rejected), `stale` (→ rejected), `needs-human`.

## Phase 1 — Scan (parallel category agents)

One Workflow submission, `parallel()` over up to 6 category agents. Per agent:

- Prompt = `python scripts/prometheus.py prompt --category <c>` output
  (single-sourced — never re-write the prompt text in the skill), **plus** an
  injected dedup block: "Already proposed (do NOT re-propose): …" built from
  the `history-index` digest (id + title + status).
- Model: opus-class. Structured output schema (kills the regex-parse and
  empty-target failure classes):

```json
{
  "type": "object",
  "properties": {
    "proposals": {
      "type": "array", "maxItems": 5,
      "items": {
        "type": "object",
        "properties": {
          "title":            {"type": "string", "maxLength": 200},
          "source":           {"type": "string", "maxLength": 500},
          "description":      {"type": "string", "maxLength": 2000},
          "impact_score":     {"type": "integer", "minimum": 1, "maximum": 10},
          "risk_score":       {"type": "integer", "minimum": 1, "maximum": 10},
          "effort_score":     {"type": "integer", "minimum": 1, "maximum": 10},
          "target_files":     {"type": "array", "minItems": 1, "maxItems": 10,
                               "items": {"type": "string"}},
          "proposed_changes": {"type": "string", "maxLength": 3000}
        },
        "required": ["title", "source", "description", "impact_score",
                     "risk_score", "effort_score", "target_files",
                     "proposed_changes"]
      }
    }
  },
  "required": ["proposals"]
}
```

Side effect: a full-board scan drops from ~30 min serial to ~5 min wall-clock.

## Phase 2 — Verify (one verifier per candidate)

Pipeline each scanner's candidates straight into verification (no barrier).
One verifier agent per candidate:

- **Reads the declared target files.** Confirms they exist (or are plausibly
  new), and that `proposed_changes` is concrete enough for a sonnet Morty to
  execute without guessing.
- **Re-scores impact/risk/effort from scratch** — scanner self-scores are
  discarded before ingest; the verifier's scores are what `ingest` receives.
- **Sizes the change S/M/L.** L-sized proposals get verdict `split` (break into
  smaller proposals) or `needs-human` — never fed to a single evolve apply.
- Verdict schema: `{verdict: "ingest"|"reject"|"split"|"needs-human",
  reason, impact_score, risk_score, effort_score}`.

## Phase 3 — Ingest (serial, the only write path)

Write survivors per category to a scratch JSON array, then:

```bash
python scripts/prometheus.py ingest /path/scratch-<category>.json --category <c>
```

`ingest` re-runs sanitize / self-protection / score-clamp / low-value filters
**plus fuzzy-title dedup** (difflib ratio > 0.75) against the entire proposal
history — dedup is enforced in code, not in prompt text. Self-protected
targets land in `.cto/prometheus/needs-human/` for Elmo.

## Phase 4 — Evolve (ranked, one at a time, reviewed)

1. Rank pending by `impact − risk/2` (built into `evolve` since PROM-164).
2. For each pick (max 3): `python scripts/prometheus.py evolve --only PROM-NNN`
   — unchanged snapshot → delegate → syntax-check (.py/.json/.sh) → checksum →
   rollback pipeline.
3. After each apply, spawn a **reviewer agent**: compare `git diff` for the
   target files against `proposed_changes`. Schema:
   `{matches_intent: bool, undeclared_files_touched: [string], issues: [string]}`.
4. On `matches_intent: false` or undeclared files touched → Rick runs
   `python scripts/prometheus.py rollback PROM-NNN` and the proposal is moved
   to rejected with the reviewer's reason. Demote-only — the reviewer never
   fixes code itself.

Parallel applies (disjoint target_files) are deliberately deferred until 2-3
cycles prove the pipeline trustworthy.

## Success metrics (check ledger after 2-3 cycles)

- Apply-failure rate: 27% → **< 10%**
- Re-applied duplicate ideas: → **0**
- False-success events escaping the reviewer: → **0**

Only after these hold, consider loop-until-dry scanning or parallel
disjoint-target applies.
