# CTO-Orchestrator Session Log

## Session: 2026-02-16 - Rick Terminal Integration

### Samenvatting
Integratie tussen Rick Terminal (macOS app) en CTO-Orchestrator verbeterd zodat:
1. **Active Agents** - Morty's verschijnen in de UI wanneer ze gespawned worden
2. **Kanban Board** - Tickets verplaatsen automatisch naar "In Progress" wanneer een Morty eraan begint

### Wat er gedaan is

#### 1. Webhook Integratie (RoroWebhookClient)
- Rick Terminal luistert op **port 3068** voor CTO events
- Events worden ontvangen via HTTP POST met JSON payload
- Format: `{"agentId": "...", "eventType": "...", "timestamp": "...", "data": {...}}`

#### 2. CTOEventBridge Verbeteringen
- **Agent columns**: Bij `cto.morty.delegation.started` wordt automatisch een agent column aangemaakt
- **Ticket move**: Tickets worden automatisch naar "In Progress" verplaatst wanneer een Morty begint
- **Status changes**: `cto.ticket.status.changed` events verplaatsen cards op het Kanban board

#### 3. Event Types die Rick Terminal verwacht

| Event Type | Actie in Rick Terminal |
|------------|----------------------|
| `cto.morty.delegation.started` | Agent column + ticket naar In Progress |
| `cto.morty.delegation.completed` | Agent column marked done |
| `cto.morty.delegation.failed` | Agent column marked error |
| `cto.ticket.status.changed` | Kanban card verplaatst |
| `cto.ticket.created` | Nieuwe Kanban card |
| `cto.ticket.completed` | Card naar Done |

#### 4. Vereiste Event Data

**Voor delegation events:**
```json
{
  "agentId": "cto:morty:backend-morty",
  "eventType": "cto.morty.delegation.started",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "data": {
    "ticket_id": "DM-001",
    "title": "Implement feature X",
    "agent": "backend-morty"
  }
}
```

**Voor status change events:**
```json
{
  "agentId": "cto:rick",
  "eventType": "cto.ticket.status.changed",
  "timestamp": "2024-01-15T10:35:00.000Z",
  "data": {
    "ticket_id": "DM-001",
    "new_status": "in_progress"
  }
}
```

### Bekende Issues

1. **Dubbele webhook start** - `.onAppear` wordt soms 2x aangeroepen, tweede keer faalt gracefully
2. **Events voor webhook ready** - Events gestuurd voordat webhook klaar is worden gemist
3. **Agent name mapping** - Sommige agent names worden als "Worker Morty" weergegeven i.p.v. specifieke rol

### Bestanden Gewijzigd

**Rick Terminal (Swift):**
- `RickTerminal/CTO/CTOEventBridge.swift` - Event handling + auto-move tickets
- `RickTerminal/CTO/RoroWebhookClient.swift` - Webhook listener
- `RickTerminal/Agent/AgentColumnsManager.swift` - Column creation
- `RickTerminal/MainWindowView.swift` - Initialization flow

**CTO-Orchestrator (Python):**
- `scripts/roro_events.py` - Heeft al `rick_terminal_endpoint` op port 3068

### Debug Logging
- Debug output gaat naar `~/rick_webhook_debug.log`
- Verbose mode: `export RORO_VERBOSE=true`

### Volgende Stappen
1. Rick's delegate.py moet consistent events sturen
2. AgentRole mapping verbeteren voor correcte Morty namen
3. Events bufferen als webhook nog niet klaar is
