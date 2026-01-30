---
name: create
description: Create implementation plans following project conventions. Use when planning new features, refactors, or significant changes.
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*)
---

# Planning Skill

Plan the requested feature or change using the project's planning conventions.

## Process

1. **Invoke the Plan subagent** using the Task tool with `subagent_type=Plan` to thoroughly research the codebase and design an implementation approach. The prompt should include the user's feature request and ask for a complete implementation plan. **Capture the `agentId`** from the Task result - this allows resuming the planning agent for additional context.

2. **After planning is complete**, save the plan to the project's plans directory:
   - Find the next plan number by checking both `.thoughts/plans/` and `.thoughts/plans/archive/` for the highest `NNNN-*` prefix
   - Create `.thoughts/plans/NNNN-feature-name/` directory (use lowercase kebab-case)
   - Write `implementation-plan.md` with the full plan
   - Write `task-list.md` with checkboxes for each task (each linking to a task file)
   - Create `tasks/` subdirectory with detailed task files (see format below)
   - Write `.plan-state.json` with initial state (see format below)
   - Check `.thoughts/research/` at the project root for prior research relevant to this plan and link to it

3. **Use this format for implementation-plan.md:**
   ```markdown
   # Feature Name Implementation Plan

   ## Status: 🚧 IN PROGRESS

   **Task List:** [task-list.md](./task-list.md)

   ---

   ## Overview
   [Brief description of the feature]

   ## Current State
   [Analysis of existing code]

   ## Implementation Approach
   [Detailed plan with phases]

   ## Files to Modify/Create
   [List of files with descriptions]

   ## Task Details

   | Task | Description      | Details                                            |
   | ---- | ---------------- | -------------------------------------------------- |
   | 1.1  | Task description | [tasks/1.1-task-name.md](./tasks/1.1-task-name.md) |
   | 1.2  | Task description | [tasks/1.2-task-name.md](./tasks/1.2-task-name.md) |

   ## Research References
   [If prior research exists in the project's .thoughts/research/ directory, link to relevant documents here]
   - [research-doc-name.md](../../.thoughts/research/topic/research-doc-name.md)

   ## Testing Strategy
   [How to test the changes — all tasks follow TDD Red/Green/Refactor]
   ```

4. **Use this format for task-list.md:**
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

   ## Phase 2: Description

   - [ ] **2.1** Task description
     → [tasks/2.1-task-name.md](./tasks/2.1-task-name.md)

   ## Progress Tracking

   | Phase          | Status      | Notes |
   | -------------- | ----------- | ----- |
   | 1 - Phase Name | Not Started |       |
   | 2 - Phase Name | Not Started |       |

   ## Quick Links

   | Resource             | Path                                                 |
   | -------------------- | ---------------------------------------------------- |
   | Implementation Plan  | [implementation-plan.md](./implementation-plan.md)   |
   | Research: Topic Name | [.thoughts/research/topic/doc.md](../../.thoughts/research/topic/doc.md) |
   ```

   Each task item links to a detailed task file in `tasks/`. The Quick Links section at the bottom provides easy access to the implementation plan and any relevant research documents.

5. **Create a `tasks/` subdirectory** with a file for each substantive task. Use the naming convention `{task-number}-{kebab-case-name}.md`. Each task file follows strict **Test-Driven Development (TDD)** and must include explicit Red/Green/Refactor phases:

   ```markdown
   # Task 1.1: Short Task Title

   ## Objective
   [What this task accomplishes]

   ## Location
   [File(s) to create or modify, e.g. "New file: `src/module/foo.rs`" or "Modify: `src/module/bar.rs`"]

   ## TDD Phases

   ### 🔴 Red: Write Failing Tests

   Write these test(s) first, before any implementation code:

   ```rust
   #[test]
   fn test_expected_behavior() {
       // Arrange
       let input = ...;
       // Act
       let result = function_under_test(input);
       // Assert - this defines the expected behavior
       assert_eq!(result, expected_value);
   }
   ```

   **What the failing test asserts:** [Describe what behavior the test defines]
   **Expected failure reason:** [e.g., "function_under_test does not exist yet" or "returns wrong value because logic is missing"]

   Run the test to confirm it fails for the expected reason. Do not write any implementation code during this phase.

   ### 🟢 Green: Minimal Implementation

   Write the minimum code necessary to make the test(s) pass:

   ```rust
   pub fn function_under_test(input: Type) -> OutputType {
       // Minimal implementation — just enough to pass the test
   }
   ```

   Run the test to confirm it passes. No more code than necessary.

   ### 🔵 Refactor: Clean Up

   [Describe refactoring opportunities, e.g.:]
   - Extract helper function for [repeated logic]
   - Rename [variable] for clarity
   - Consolidate [duplicated code] with existing [function]

   Run tests after refactoring to confirm they still pass. Commit after this phase.

   ## Context
   [Any additional notes: imports needed, related functions, edge cases to handle.
   Link to research docs if relevant: see [research-doc.md](../../../.thoughts/research/topic/doc.md)]

   ## Acceptance Criteria
   - [ ] Failing test written and confirmed red
   - [ ] Minimal implementation passes the test
   - [ ] Code refactored with tests still green
   - [ ] [Additional criteria specific to this task]
   ```

   **Guidelines for task files:**
   - Every task with implementation code must have explicit Red/Green/Refactor phases
   - The Red phase must specify what tests to write, what they assert, and why they should fail
   - The Green phase must describe only the minimal code to pass — no extras
   - The Refactor phase should identify concrete cleanup opportunities
   - Include enough code detail that implementation can proceed without re-reading the full codebase
   - Show specific file paths, function signatures, struct definitions, and key logic
   - Reference related research documents from `.thoughts/research/` when applicable
   - Not every task-list item needs a task file — small or self-explanatory tasks (e.g., "run tests") can be described inline in the task list with `*(Covered in X.Y)*` or a brief note

6. **Use this format for .plan-state.json:**
   ```json
   {
     "status": "in_progress",
     "created_at": "2026-01-24T10:30:00Z",
     "updated_at": "2026-01-24T10:30:00Z",
     "planning_agent_id": "abc-123-def",
     "current_task": null,
     "last_session_notes": null,
     "progress": {
       "total": 12,
       "completed": 0
     },
     "commits": []
   }
   ```
   - `status` is always `"in_progress"` for new plans
   - Use the current UTC timestamp for `created_at` and `updated_at`
   - Set `planning_agent_id` to the agentId from the Plan subagent Task result
   - Set `total` to the actual number of tasks in task-list.md
   - `current_task` and `last_session_notes` start as null
   - `commits` is an array that will accumulate commit SHAs as phases complete

7. **Do not commit the plan files**

8. **Present the plan** to the user for approval before any implementation begins

9. **Provide enhanced continuation output** after saving the plan:

   Output format:
   ```
   **Plan saved to:** `.thoughts/plans/NNNN-feature-name/`
   **Created:** YYYY-MM-DD HH:MM UTC
   **Tasks:** 0/N complete
   **Planning agent:** `{agentId}` (resume for additional context)

   **First tasks:**
   - [ ] **1.1** First task description
   - [ ] **1.2** Second task description
   - [ ] **1.3** Third task description

   To continue with implementation, run `/clear` then run `/plan:resume` or paste:

   [continuation prompt code block]

   *Plan summary: Brief description of what the plan is about*
   ```

10. **Use this continuation prompt template:**
   ````
   Continue implementing the plan in .thoughts/plans/NNNN-feature-name/

   Read the implementation-plan.md and task-list.md files, then read the detailed task file in tasks/ for the first incomplete task before beginning implementation.

   As you work:
   - Read the task file in tasks/ for each task before starting it
   - Follow strict TDD for each task: 🔴 Red (write failing test, run it) → 🟢 Green (minimal implementation, run test) → 🔵 Refactor (clean up, run tests, commit)
   - Update task-list.md checkboxes (change `- [ ]` to `- [x]`) when completing tasks
   - Update .plan-state.json with current_task and progress.completed count

   When completing a phase:
   - Create a commit with message: "feat(plan-NNNN): Phase N - <phase description>"
   - Add the commit SHA to the `commits` array in .plan-state.json

   Record findings during implementation:
   - Write discoveries, diversions from the plan, things the plan got wrong, important notes, TODOs, and cleanup items to `findings/` in the plan directory
   - Use descriptive filenames like `findings/edge-case-diamond-routing.md` or `findings/todo-cleanup-unused-helpers.md`
   - These findings will be used to create issues and provide feedback to research

   Before ending the session, update .plan-state.json with last_session_notes about progress and next steps.

   If you need additional context from the original planning discussion, the planning agent ID is stored in .plan-state.json and can be resumed.
   ````

## Example Output

---

**Plan saved to:** `.thoughts/plans/0006-rust-parser/`
**Created:** 2026-01-24 10:30 UTC
**Tasks:** 0/12 complete
**Planning agent:** `a1b2c3d4-e5f6-7890-abcd-ef1234567890` (resume for additional context)

**First tasks:**
- [ ] **1.1** Create RustParser struct implementing ErrorParser trait
- [ ] **1.2** Add Rust variant to Language enum
- [ ] **1.3** Implement panic message regex patterns

To continue with implementation, run `/clear` and then `/plan:resume` or paste:

```
Continue implementing the plan in .thoughts/plans/0006-rust-parser/

Read the implementation-plan.md and task-list.md files, then begin with the first incomplete task.

As you work:
- Update task-list.md checkboxes (change `- [ ]` to `- [x]`) when completing tasks
- Update .plan-state.json with current_task and progress.completed count

When completing a phase:
- Create a commit with message: "feat(plan-0006): Phase N - <phase description>"
- Add the commit SHA to the `commits` array in .plan-state.json

Before ending the session, update .plan-state.json with last_session_notes about progress and next steps.

If you need additional context from the original planning discussion, the planning agent ID is stored in .plan-state.json and can be resumed.
```

*Plan summary: Add support for parsing Rust panic stack traces*

---
