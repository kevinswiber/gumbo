---
name: plan-cancel
description: Cancel an implementation plan. Moves the plan to archive/ with CANCELLED status. Use when a plan is superseded, abandoned, or no longer needed.
---

# Plan Cancel

Cancel a plan that is no longer being pursued. Shared rules are in `.gumbo/AGENTS.local.md`.

1. **Identify the plan.** Only the one the user named; never auto-cancel. If none was named, list in-progress plans and ask.
2. **Ask for the reason** if not given, and which plan supersedes it if any.
3. **Update the files.**
   - `implementation-plan.md` header becomes `## Status: ❌ CANCELLED`, followed by `**Cancelled:** YYYY-MM-DD`, `**Reason:** …`, and `**Superseded by:** NNNN-name` when applicable.
   - `task-list.md` header becomes `## Status: ❌ CANCELLED`.
   - `.plan-state.json`: `status: "cancelled"`, `cancelled_at`, `updated_at`, `cancellation_reason`, `superseded_by` (or null); keep every other field.
4. **Move** the directory to `.gumbo/plans/archive/` (if it is already there, update the status only) and commit to the gumbo repo.
5. **Confirm** in a few lines: the archive path, the reason, progress at cancellation.
