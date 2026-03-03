# ADR-001: Claude CLI Communication Protocol

**Status:** Accepted
**Date:** 2026-02-13
**Deciders:** Rick Sanchez, Architect-Morty

## Context

RickTerminal IDE needs to communicate with Claude CLI processes to spawn and manage Morty agents. We need a reliable, real-time communication protocol.

## Decision

Use **stdin/stdout streaming with `--output-format stream-json`** as the primary communication method.

### Key Findings

1. **CLI Arguments for Programmatic Use:**
   ```bash
   claude -p "prompt" \
     --output-format stream-json \
     --input-format stream-json \
     --include-partial-messages \
     --verbose
   ```

2. **Event Types (NDJSON):**
   - `system` (init) → Session started
   - `assistant` → Claude response or tool use
   - `user` → Tool results
   - `stream_event` → Real-time token streaming
   - `result` → Session complete

3. **Tech Stack:**
   - `tokio::process` for async subprocess management
   - `serde_json` for NDJSON parsing
   - Tauri events for frontend notification

## Consequences

### Positive
- Native CLI support, no SDK dependency
- Real-time streaming out of the box
- Session resume capability via `--resume`
- Full control over tool permissions

### Negative
- Must handle edge case: missing final `result` event (GitHub #1920)
- Need timeout fallback mechanism

## Implementation

See: `src-tauri/src/claude_process.rs` (to be created)
