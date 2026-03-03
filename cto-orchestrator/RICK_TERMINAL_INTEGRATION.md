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
