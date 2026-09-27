# Ticket Schema

Tickets are stored as individual JSON files in `.cto/tickets/`. Each file is named `{TICKET_ID}.json`.

## Data Model

```json
{
  "id": "PROJ-001",
  "title": "Implement user authentication",
  "description": "Detailed description of what needs to be done",
  "type": "feature|bug|task|spike|epic",
  "status": "backlog|todo|in_progress|in_review|testing|done|blocked",
  "priority": "critical|high|medium|low",
  "assigned_agent": "architect|frontend-dev|backend-dev|fullstack-dev|tester|security|devops|code-reviewer|null",
  "parent_ticket": "PROJ-000 or null (for sub-tickets under epics)",
  "dependencies": ["PROJ-002", "PROJ-003"],
  "acceptance_criteria": ["Criterion 1", "Criterion 2"],
  "estimated_complexity": "XS|S|M|L|XL",
  "created_at": "ISO 8601 timestamp",
  "updated_at": "ISO 8601 timestamp",
  "completed_at": "ISO 8601 timestamp or null",
  "agent_output": "Summary of what the agent delivered",
  "review_notes": "CTO review notes",
  "files_touched": ["path/to/file.py"]
}
```

## Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Auto-generated from config prefix + sequential number |
| `title` | Yes | Short descriptive title |
| `description` | Yes | Detailed description — this is what the agent works from |
| `type` | Yes | `epic` (container), `feature` (new), `bug` (fix), `task` (chore), `spike` (research) |
| `status` | Yes | Current workflow state (see Status Flow below) |
| `priority` | Yes | Determines execution order within sprint |
| `assigned_agent` | No | Set when ticket is delegated |
| `parent_ticket` | No | Links sub-ticket to its epic |
| `dependencies` | No | Ticket IDs that must be `done` before this can start |
| `acceptance_criteria` | No | Checklist for completion verification |
| `estimated_complexity` | No | T-shirt sizing for effort estimation |
| `agent_output` | No | Filled by agent after completion |
| `review_notes` | No | Filled during review or when blocked |
| `files_touched` | No | Filled by agent — list of modified file paths |

## Status Flow

```
backlog → todo → in_progress → in_review → done
                      ↓              ↓
                   blocked      todo (rework)
                      ↓
                 todo (unblocked)
```

- **backlog**: Created but not yet prioritized
- **todo**: Ready to be picked up
- **in_progress**: Currently being worked on by an agent
- **in_review**: Agent completed, awaiting CTO/reviewer check
- **testing**: Under test (optional step)
- **done**: Completed and approved
- **blocked**: Cannot proceed — reason in `review_notes`

## Priority Order

1. `critical` — must be done first, blocks everything
2. `high` — important for sprint goal
3. `medium` — standard priority
4. `low` — nice to have

## Complexity Estimates

| Size | Typical Scope |
|------|---------------|
| XS | Single file, < 20 lines changed |
| S | 1-2 files, straightforward |
| M | 2-5 files, moderate logic |
| L | 5-10 files, complex feature |
| XL | 10+ files, major feature or refactor |
