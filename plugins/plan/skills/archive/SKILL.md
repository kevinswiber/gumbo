---
name: archive
description: Archive a completed implementation plan. Moves the plan to archive/ and updates its status to COMPLETE.
---

# Archive Skill

Archive a completed implementation plan after successful implementation.

## Process

1. **Identify the plan to archive:**
   - If the user specifies a plan number/name, use that
   - Otherwise, scan `.thoughts/plans/*/` (exclude `archive/`) for plans that appear complete:
     - All task checkboxes marked done (`- [x]`)
     - Or user explicitly states it's complete
   - If multiple candidates found, ask user to specify which one

2. **Verify completion:**
   - Read the `task-list.md` and count checkboxes
   - If not all tasks are complete, ask user to confirm they want to archive anyway
   - Display: "Plan has X/Y tasks complete. Archive anyway?"

3. **Update plan files:**

   **Update `implementation-plan.md` status header:**
   ```markdown
   ## Status: ✅ COMPLETE

   **Completed:** YYYY-MM-DD

   **Commits:**
   - `abc1234` - feat(plan-NNNN): Phase 1 - Description
   - `def5678` - feat(plan-NNNN): Phase 2 - Description
   ```
   (Include commits section if the `commits` array in .plan-state.json is non-empty. List each SHA with its commit message.)

   **Update `task-list.md` status:**
   ```markdown
   ## Status: ✅ COMPLETE
   ```

   **Update `.plan-state.json`:**
   ```json
   {
     "status": "complete",
     "completed_at": "2026-01-25T10:30:00Z",
     "updated_at": "2026-01-25T10:30:00Z",
     "commits": ["abc1234", "def5678"],
     ...existing fields...
   }
   ```
   (The `commits` array should already be populated during implementation. Preserve it in the final state.)

4. **Move to archive:**
   ```bash
   mv .thoughts/plans/NNNN-feature-name .thoughts/plans/archive/
   ```

5. **Confirm to user:**
   ```
   **Archived:** `.thoughts/plans/archive/NNNN-feature-name/`
   **Status:** ✅ COMPLETE
   **Tasks:** X/Y complete
   **Completed:** YYYY-MM-DD
   **Commits:** N commits (list SHAs if present)
   ```

## Example Usage

### Archive a specific plan
```
User: /plan:archive 0005
```

### Archive with auto-detection
```
User: /plan:archive

(Claude finds the plan with all tasks complete and archives it)
```

### Confirm incomplete plan
```
User: /plan:archive 0003

Claude: Plan 0003-backward-edge-routing has 8/12 tasks complete.
Archive as complete anyway? (y/n)

User: yes

(Claude archives with status showing partial completion)
```
