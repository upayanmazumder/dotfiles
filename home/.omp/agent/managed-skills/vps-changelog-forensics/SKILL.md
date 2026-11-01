---
name: vps-changelog-forensics
description: How to log a forensic changelog entry for the upayanmazumder/vps k8s cluster repo — use whenever making or reviewing ANY change (git-tracked or break-glass kubectl) to that cluster
---

## When this applies

Only for the `upayanmazumder/vps` GitOps repo (k3s cluster on Hetzner, ArgoCD-managed). If you're
about to run a `kubectl` command against that cluster, or commit a change under `k8s/` in that
repo, you MUST also append a changelog entry — no exceptions, including "trivial" fixes and
read-only investigations that led to a change.

The repo also carries its own copy of this convention at `changelog/README.md` and
`.claude/skills/changelog/SKILL.md` — if those drift from this memory, the repo copy wins.

## Where

`changelog/YYYY-MM.md`, newest entries at the top of the current month's file. If the month's
file doesn't exist yet, create it (see `changelog/README.md` "Starting a new month") and add a
row to the index table in `changelog/README.md`.

Never edit/delete a past entry — append a correction entry instead.

## Entry template

```
### ~HH:MM IST — <short title>
- **Actor:** human | agent (session/name)
- **Type:** git commit `<sha>` | break-glass kubectl | incident
- **Trigger:** why this happened (user request, alert, invoice, etc.) — omit if obvious
- **Change:** exactly what changed, concretely (resource names, sizes, files)
- **Reason:** why this change, not just what
- **Verification:** the specific command/output that proved it worked (not "seems fine")
- **Cost impact:** if it touches billed resources (volumes, servers, IPs), quantify it
- **Rollback:** how to undo — git revert SHA, or restore-from-backup path, or "N/A: nothing to revert"
```

Break-glass `kubectl` entries are the ONLY record of that action (git has nothing to show) — be
exhaustive: full investigation trail, exact resource names/UUIDs, and how you confirmed no
data was lost before anything destructive.

## Workflow

1. Make the change (or investigate first if destructive/risky).
2. Write the changelog entry in the same turn/commit as the change — never defer to "later".
3. For git-tracked changes: changelog entry + the actual manifest edit go in the same commit.
4. For break-glass kubectl: commit the changelog entry to git immediately after (or before, if
   there's time to plan) — this is the only audit trail since kubectl bypasses git.
