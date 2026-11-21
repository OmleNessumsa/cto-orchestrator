# Rick Terminal Integration Guide

## Voor Rick (CTO-Orchestrator)

*Burrrp* — Luister goed, want dit is belangrijk. Als je in Rick Terminal draait, moet je ervoor zorgen dat de UI wordt bijgewerkt wanneer je Morty's aan het werk zet.

## Webhook Endpoint

Rick Terminal luistert op **`http://localhost:3068`** voor real-time updates.

De `roro_events.py` module stuurt al events naar deze endpoint via de `rick_terminal_endpoint` config.

## Kritieke Events die je MOET sturen

### 1. Wanneer je een Morty spawnt

**Event:** `cto.morty.delegation.started`

```python
from roro_events import emit

emit("cto.morty.delegation.started", {
    "ticket_id": ticket["id"],      # VERPLICHT - bijv. "DM-001"
    "title": ticket.get("title"),   # Ticket titel
    "agent": agent,                  # VERPLICHT - bijv. "backend-morty"
    "model": model,                  # optioneel
    "team_id": team_id,             # optioneel
}, role=agent, team_id=team_id)
```

**Dit zorgt ervoor dat:**
- Een Morty column verschijnt in "Active Agents"
- Het ticket automatisch naar "In Progress" verplaatst op het Kanban board

### 2. Wanneer een Morty klaar is

**Event:** `cto.morty.delegation.completed`

```python
emit("cto.morty.delegation.completed", {
    "ticket_id": ticket["id"],
    "agent": agent,
    "status": "completed",  # of "needs_review"
    "files_changed": ["file1.py", "file2.py"],
    "description": "Wat er gedaan is",
}, role=agent, team_id=team_id)
```

### 3. Wanneer een Morty faalt

**Event:** `cto.morty.delegation.failed`

```python
emit("cto.morty.delegation.failed", {
    "ticket_id": ticket["id"],
    "agent": agent,
    "error": "Wat er mis ging",
}, role=agent, team_id=team_id)
```

### 4. Ticket status changes

**Event:** `cto.ticket.status.changed`

```python
emit("cto.ticket.status.changed", {
    "ticket_id": ticket_id,
    "new_status": "in_progress",  # of: "todo", "in_review", "blocked", "done"
}, role="rick")
```

## Checklist voor delegate.py

Zorg dat `delegate.py` deze events stuurt op de juiste momenten:

- [ ] `cto.morty.delegation.started` — direct NA het starten van `claude -p`
- [ ] `cto.morty.delegation.completed` — wanneer Morty succesvol klaar is
- [ ] `cto.morty.delegation.failed` — wanneer Morty faalt of timeout
- [ ] `cto.morty.delegation.timeout` — specifiek bij timeout

## Verbose Mode voor Debugging

```bash
export RORO_VERBOSE=true
```

Dan zie je in de terminal of events worden verstuurd.

## Test of het werkt

```bash
# Stuur een test event
curl -X POST http://localhost:3068 \
  -H "Content-Type: application/json" \
  -d '{"agentId":"cto:morty:test","eventType":"cto.morty.delegation.started","timestamp":"2024-01-15T10:00:00.000Z","data":{"ticket_id":"TEST-001","agent":"test-morty","title":"Test"}}'
```

Als Rick Terminal draait, zou je een "Worker Morty" of "Test Morty" moeten zien verschijnen.

## Bekende Agent Rollen

Deze agent namen worden correct herkend en krijgen eigen iconen:

| Agent Name | Display Name | Icon |
|------------|--------------|------|
| `architect-morty` | Architect Morty | 🏗️ |
| `backend-morty` | Backend Morty | ⚙️ |
| `frontend-morty` | Frontend Morty | 🎨 |
| `fullstack-morty` | Fullstack Morty | 🔧 |
| `tester-morty` | Tester Morty | 🧪 |
| `security-morty` | Security Morty | 🔒 |
| `devops-morty` | DevOps Morty | 🚀 |
| `reviewer-morty` | Reviewer Morty | 👀 |

Andere namen worden weergegeven als "Worker Morty".

## Client rendering guidance

`cto.morty.token` events are coalesced on the Python side: tokens are buffered per agent and sent as one event with `{"text": "...", "chunks": n}` every 100ms (or when the buffer exceeds 2KB). Tune with `RICK_TOKEN_COALESCE_MS` (`0` disables batching). Any other event from the same agent flushes the buffer first, so ordering is preserved.

Matching client patterns for the SwiftUI feed:

- Use `List` rather than `LazyVStack` for the event and log feed.
- Cap the feed to a ring buffer of about 5k rows; drop the oldest rows first.
- Use `@Observable` per-agent models so one Morty's tokens don't re-render the whole board.
- Append coalesced token text to the last row instead of adding a new row per event.
- Avoid `scrollPosition(id:)` on long dynamic stacks.

## SSE stream: typed frames, retry en schema_version

Alle events (webhook en SSE) dragen `schema_version` (`RORO_SCHEMA_VERSION` in `schemas.py`, nu `1`). Het wordt gebumpt bij een wijziging van de envelope-vorm, niet bij nieuwe event types.

**Typed frames (opt-in).** Verbind met `GET /events?typed=1` om per frame een `event:` regel te krijgen, zodat de client kan routeren zonder eerst JSON te decoden:

```
id: 42
event: cto.morty.done
data: {"schema_version":1,"type":"cto.morty.done",...}
```

Zonder `?typed=1` is het frame byte-voor-byte ongewijzigd (`id:` + `data:`). Dit moet opt-in blijven: standaard `EventSource`-clients vuren `onmessage` alleen voor ongenaamde events; benoemde events vereisen `addEventListener(type, ...)`. De ring buffer bewaart payloads, dus replay via `Last-Event-ID` gebruikt het formaat dat de verbonden client heeft gekozen.

**Alleen voor typed clients:**

- Bij connect eenmalig `retry: 3000` (vóór de `Last-Event-ID` replay): reconnect-interval in ms.
- Elke 50 events een comment `: ping <iso-timestamp>`. Toon een "stale connection"-indicator als er te lang geen frame of ping binnenkomt (de algemene `: keepalive` komt elke 15s).

**Version-mismatch banner.** Vergelijk `schema_version` van binnenkomende events met de versie die de app kent. Is die hoger, toon dan een banner "orchestrator newer than app — update Rick Terminal" en val terug op de `unknown`-weergave voor velden/events die niet te decoden zijn, in plaats van stil te falen.

## Upgrade Instructie

Als Rick zichzelf moet upgraden om beter met Rick Terminal te integreren:

1. **Lees dit document** — `/cto-orchestrator/RICK_TERMINAL_INTEGRATION.md`
2. **Check delegate.py** — Zorg dat alle events correct worden gestuurd
3. **Test met verbose mode** — `export RORO_VERBOSE=true`
4. **Verifieer in Rick Terminal** — Agents moeten verschijnen, tickets moeten verplaatsen

## Samenvatting

```
Rick spawnt Morty → emit("cto.morty.delegation.started") → Agent verschijnt in UI + Ticket naar In Progress
Morty klaar      → emit("cto.morty.delegation.completed") → Agent wordt groen
Morty faalt      → emit("cto.morty.delegation.failed")    → Agent wordt rood
```

*Wubba lubba dub dub!*
