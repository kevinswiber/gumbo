# Agent Instructions for Plans

**IMPORTANT**: Do *not* commit plans to the git repo!

When working on this project, follow these guidelines for creating and managing implementation plans.

## Creating Plans

When entering plan mode or creating an implementation plan:

1. **Create a new numbered subdirectory** in `plans/`:
   - Find the highest existing number (e.g., `0001-initial-mvp`)
   - Increment it for your new plan (e.g., `0002-rust-parser`)
   - Use lowercase kebab-case for the feature name

2. **Save your plan** to the new directory:
   - Main plan: `plans/NNNN-feature-name/implementation-plan.md`
   - Task list: `plans/NNNN-feature-name/task-list.md`
   - Task files: `plans/NNNN-feature-name/tasks/*.md`
   - State file: `plans/NNNN-feature-name/.plan-state.json`

3. **Include a status header** at the top of the plan:
   ```markdown
   ## Status: 🚧 IN PROGRESS
   ```

   Valid statuses:
   - `🚧 IN PROGRESS` - Active plan being implemented
   - `✅ COMPLETE` - Successfully implemented
   - `❌ CANCELLED` - Abandoned, superseded, or no longer needed

## State File (.plan-state.json)

Each plan has a `.plan-state.json` file for tracking session state:

```json
{
  "status": "in_progress",
  "created_at": "2026-01-24T10:30:00Z",
  "updated_at": "2026-01-24T10:30:00Z",
  "planning_agent_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "current_task": null,
  "last_session_notes": null,
  "progress": {
    "total": 12,
    "completed": 0
  }
}
```

**Fields:**
- `status` - Plan status: `"in_progress"`, `"complete"`, or `"cancelled"`
- `created_at` - When the plan was created (UTC ISO 8601)
- `updated_at` - Last time state was updated
- `planning_agent_id` - Agent ID from the original planning session (can be resumed for additional context)
- `current_task` - Task ID currently being worked on (e.g., "2.1")
- `last_session_notes` - Notes from the last session about progress/next steps
- `progress.total` - Total number of tasks
- `progress.completed` - Number of completed tasks

**Additional fields for archived plans:**
- `completed_at` - When the plan was completed (for complete status)
- `cancelled_at` - When the plan was cancelled (for cancelled status)
- `cancellation_reason` - Why the plan was cancelled
- `superseded_by` - Plan number that supersedes this one (e.g., "0005-dagre-module")

**Update the state file during implementation:**
- When starting a task: set `current_task`
- When completing a task: increment `progress.completed`, clear `current_task`
- Before ending a session: update `last_session_notes` and `updated_at`

## Draft Files

For work-in-progress notes that shouldn't be committed:

- Prefix files with `draft-`: e.g., `draft-implementation-plan.md`
- Draft files are gitignored and won't be committed
- Rename to remove the `draft-` prefix when ready to commit

## Test-Driven Development (TDD)

All implementation tasks follow strict TDD. For each task:

1. **🔴 Red:** Write failing test(s) that define expected behavior. Run to confirm they fail for the expected reason. No implementation code in this phase.
2. **🟢 Green:** Write the minimum code to make the test(s) pass. No more, no less. Run to confirm passing.
3. **🔵 Refactor:** Clean up code while keeping tests green. Commit after refactoring.

Task files in `tasks/` must specify:
- What test(s) to write first and what they assert
- The expected failure reason
- What minimal implementation satisfies the tests
- What refactoring opportunities exist

## During Implementation

- Update task list checkboxes as you complete tasks: `- [ ]` → `- [x]`
- Keep the plan document updated if the approach changes
- Update `.plan-state.json` with progress and session notes
- Follow TDD Red/Green/Refactor for every task with implementation code

## Findings

Record discoveries, diversions, and issues in a `findings/` subdirectory within the active plan directory. Write individual markdown files for:

- **Discoveries** — unexpected behavior, undocumented assumptions
- **Diversions** — where implementation diverged from the plan and why
- **Plan errors** — things the plan got wrong
- **Important notes** — context for future sessions or plans
- **TODOs** — deferred work identified during implementation
- **Cleanup items** — technical debt introduced or discovered

Use descriptive filenames like `findings/edge-case-diamond-routing.md`. These findings are used to create issues and provide feedback to research.

Finding file format:
```markdown
# Finding: Short Title

**Type:** discovery | diversion | plan-error | note | todo | cleanup
**Task:** 2.1
**Date:** YYYY-MM-DD

## Details
[What was found/changed/wrong]

## Impact
[How this affects the current plan or future work]

## Action Items
- [ ] Concrete next step (if any)
```

## After Completion

Use `/archive` to archive a completed plan. It will:
- Update the status header to `✅ COMPLETE`
- Update `.plan-state.json` with completion timestamp
- Move the plan to `plans/archive/`

Manual steps (if not using the skill):

1. **Update the status header:**
   ```markdown
   ## Status: ✅ COMPLETE

   **Completed:** [Date]
   ```

2. **Move to archive:**
   ```bash
   mv plans/NNNN-feature-name plans/archive/
   ```

## Cancelling Plans

Use `/cancel` when a plan is superseded, abandoned, or no longer needed. It will:
- Update the status header to `❌ CANCELLED`
- Record the cancellation reason and superseding plan (if any)
- Update `.plan-state.json` with cancellation details
- Move the plan to `plans/archive/`

Example cancelled plan header:
```markdown
## Status: ❌ CANCELLED

**Cancelled:** 2026-01-25
**Reason:** Superseded by 0005-dagre-module
```

## Example Directory Structure

```
plans/
├── archive/                    # Completed plans
│   └── 0001-initial-mvp/
│       ├── implementation-plan.md
│       ├── task-list.md
│       ├── .plan-state.json
│       └── tasks/
│           ├── 1.1-data-model.md
│           └── 1.2-parser-setup.md
├── 0002-rust-parser/           # In-progress plan
│   ├── draft-notes.md          # Gitignored draft
│   ├── implementation-plan.md
│   ├── task-list.md
│   ├── .plan-state.json        # Session state
│   ├── tasks/                  # Detailed task files
│   │   ├── 1.1-module-structures.md
│   │   ├── 1.2-helper-functions.md
│   │   └── 2.1-core-algorithm.md
│   └── findings/               # Implementation findings
│       ├── edge-case-empty-input.md
│       └── todo-cleanup-error-types.md
```

## Task List Format

Use this format for task lists. Each task item links to a detailed task file in `tasks/`:

```markdown
# Feature Name Task List

## Status: 🚧 IN PROGRESS

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Description

- [ ] **1.1** Task description
  → [tasks/1.1-task-name.md](./tasks/1.1-task-name.md)

- [ ] **1.2** Another task
  → [tasks/1.2-task-name.md](./tasks/1.2-task-name.md)

- [x] **1.3** Completed task
  *(Covered in 1.1)*

## Progress Tracking

| Phase          | Status        | Notes      |
| -------------- | ------------- | ---------- |
| 1 - Phase Name | 🚧 In Progress | Notes here |
| 2 - Phase Name | Not Started   |            |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Topic Name | [research/topic/doc.md](../../research/topic/doc.md) |
```

The `implementation-plan.md` should also link back to the task list and include a Task Details table linking to individual task files.

## Task Files (tasks/ subdirectory)

Each plan should have a `tasks/` subdirectory containing detailed files for substantive tasks. Use the naming convention `{task-number}-{kebab-case-name}.md`.

**Task file format:**

```markdown
# Task 1.1: Short Task Title

## Objective
[What this task accomplishes]

## Location
[File(s) to create or modify, with full paths]

## Implementation
[Code snippets showing specific code to write or change]

## Context
[Notes, imports, edge cases. Link to research if relevant:
see [doc.md](../../../research/topic/doc.md)]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
```

**Guidelines:**
- Include enough code detail (file paths, function signatures, struct definitions, key logic) that implementation can proceed without re-reading the full codebase
- Reference related research documents from the project root `research/` directory when applicable
- Not every task needs its own file — small or self-explanatory tasks can use `*(Covered in X.Y)*` in the task list

## Cross-References

Plans should maintain cross-references between their files:

- **implementation-plan.md** links to:
  - `task-list.md` (near the top, after status header)
  - Individual task files via a Task Details table
  - Research documents in `research/` at the project root

- **task-list.md** links to:
  - `implementation-plan.md` (near the top, after status header)
  - Individual task files (arrow `→` under each task item)
  - Research documents via Quick Links table at the bottom

- **Task files** link to:
  - Research documents when relevant for context

## Research References

Prior research lives in the `research/` directory at the project root (not under `plans/`). When creating a plan that builds on prior research, link to relevant documents using relative paths like `../../research/topic/doc.md`.

## Resuming Work

Use `/resume` to find and continue in-progress plans. It will:
- Scan `plans/` for incomplete task lists
- Show progress and context from `.plan-state.json`
- Provide a continuation prompt with state tracking instructions
