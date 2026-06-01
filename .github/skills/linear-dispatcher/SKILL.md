---
name: linear-dispatcher
description: 'Dispatch the next highest-priority Linear issue into an open lane using Linear native priority. Use when the user says "dispatch", "next ticket", "what should I work on", or a lane is empty and needs filling.'
argument-hint: 'Say "dispatch" or "next ticket" to pull the highest-priority item from the queue'
---

# Linear Dispatcher Skill

Pull the next highest-priority `flow:queue` issue and assign it to an open lane.

## Priority Model

Dispatch order is driven by **Linear's native priority field**, not Eisenhower scoring.

| Priority | Linear Value | Dispatch Order |
|----------|-------------|----------------|
| Urgent | 1 | 1st |
| High | 2 | 2nd |
| Medium | 3 | 3rd |
| Low | 4 | 4th |
| No Priority | 0 | Last |

Tiebreak within the same priority tier: oldest `createdAt` first.

**Due-date override:** Any issue due within 2 days is promoted to the front of the queue. Among multiple due-soon issues, sort by `dueDate` ascending, then `priority` ascending, then `createdAt` ascending.

Note: Eisenhower `urgency:N` / `importance:N` labels may remain on tickets for personal scoring reference but are **not used for dispatch ordering**.

## Dispatch Workflow

### Step 1 — Check WIP

```bash
cat /tmp/rounds-claims.json 2>/dev/null || echo "{}"
```

Count occupied lanes (lanes 1–5). If all 5 are occupied, tell the user — no dispatch until a lane clears.

### Step 2 — Query the queue

```bash
cd /home/wweeks/git/projects && export $(grep -v '^#' .env | xargs)
python3 scripts/linear_search.py --label flow:queue
```

Also check if any lanes have `flow:waiting` issues that freed up (waiting doesn't count against WIP).

### Step 3 — Score and rank

Read already-claimed ticket keys from the claims file:
```python
import json, os
claims = json.loads(open('/tmp/rounds-claims.json').read()) if os.path.exists('/tmp/rounds-claims.json') else {}
claimed_keys = {v['key'] for v in claims.values() if isinstance(v, dict) and 'key' in v}
```

**Exclude any queue issue whose key is already in `claimed_keys`.** A ticket already active in any lane must never be dispatched into a second lane.

For each remaining queue issue:
1. Read Linear's native `priority` field (1=Urgent, 2=High, 3=Medium, 4=Low, 0=No Priority)
2. Check `dueDate` — override to front of queue if within 2 days; among due-soon issues sort by `dueDate` ascending, then `priority` ascending, then `createdAt` ascending
3. Sort remaining issues: Urgent → High → Medium → Low → No Priority, tiebreak by `createdAt` ascending (oldest first)

Present top 3 as options; default dispatch is the top item.

### Step 4 — Activate

```bash
python3 scripts/linear_set_flow.py --key {KEY} --flow active
```

Update the claim file:
```bash
echo '{"lane1": "{KEY}", ...}' > /tmp/rounds-claims.json
```

**Refresh the daily note immediately after activating:**
```bash
python3 scripts/daily_note.py --refresh
```
Skip silently if no daily note exists yet.

### Step 5 — Create local stub if missing

```bash
ls /home/wweeks/git/projects/issues/ | grep {KEY}
# If missing:
python3 scripts/linear_create_stub.py --key {KEY}
```

### Step 6 — Report

```
✓ Dispatched {KEY} → Lane {N}

{KEY} — {title}
Priority: {Urgent|High|Medium|Low|No Priority} | due: {due}
State: In Progress
```

## WIP Limit

Max 5 active issues (one per lane). `flow:waiting` does not count. Enforce strictly — do not dispatch if all 5 lanes are filled.
