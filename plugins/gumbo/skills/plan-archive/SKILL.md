---
name: plan-archive
description: Archive a completed implementation plan. Moves the plan to archive/ and updates its status to COMPLETE.
---

# Plan Archive

Archive an implementation plan after its work has landed. Shared rules are in `.gumbo/AGENTS.local.md`.

1. **Identify the plan.** The one the user named; otherwise scan `.gumbo/plans/NNNN-*/` (not `archive/`) for plans whose boxes are all checked or whose state says complete. Several candidates: ask.
2. **Verify.** Count the task-list checkboxes. If any are open, show "X/Y tasks complete. Archive anyway?" and wait. Verify the landing (the merge, the PR) when the plan recorded one.
3. **Update the files.**
   - `implementation-plan.md` header becomes `## Status: ✅ COMPLETE`, followed by `**Completed:** YYYY-MM-DD` and, when `commits` is non-empty, a `**Commits:**` list of SHA and message.
   - `task-list.md` header becomes `## Status: ✅ COMPLETE`.
   - `.plan-state.json`: `status: "complete"`, `completed_at`, `updated_at`; keep every other field, including `commits`.
4. **Move** the directory to `.gumbo/plans/archive/` and commit the move to the gumbo repo.
5. **Confirm** in a few lines: the archive path, task count, completion date, commit count. If findings were never triaged, point at `/plan-findings-resume`.
