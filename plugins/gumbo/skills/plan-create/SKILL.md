---
name: plan-create
description: Create implementation plans following project conventions. Use when planning new features, refactors, or significant changes.
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*)
---

# Plan Create

Write an implementation plan that an implementer in a fresh session can execute from disk. Shared rules (git, propagation, findings, privacy) are in `.gumbo/AGENTS.local.md`; file formats in `.gumbo/plans/AGENTS.md`.

## 1. Ground the plan

Read the code the change touches and any research or ADR it builds on (`.gumbo/research/`, the repo's `docs/adr/`). Verify every claim the plan makes about existing code (a symbol, a signature, a line anchor, "already handled") against the current head rather than from memory. Stale claims about existing code are the review findings that survive the most rounds.

## 2. Unknowns first

Before writing tasks, list what the design rests on that source cannot confirm: host or framework behavior, an external API, a UI the test kit cannot see, a performance threshold. For each, name the cheapest falsifying probe (a throwaway branch, a one-command experiment, an owner check that draws several labeled variants side by side). Either run the probe now or make it the first task and write the dependent tasks as provisional. A design stacked on a guess with the live check as the last task costs an owner round trip per wrong guess.

Record them in the plan under **Unknowns and probes**, each with its status. Omit the section only when there are none.

## 3. Write the plan directory

`.gumbo/plans/NNNN-feature-name/`, next number across active plans and `archive/`:

- `implementation-plan.md`, in this order: `## Status: 🚧 IN PROGRESS`, a link to the task list, Overview, Current State (verified against head), Unknowns and probes, Decisions (dated owner decisions, appended as they are made), Load-bearing invariants, Implementation Approach by phase, Files to Modify/Create, Task Details (a table of task id, description, and link or "inline"), Research References, Testing Strategy.
- `task-list.md`: `## Status: 🚧 IN PROGRESS`, a link to the plan, phases with `- [ ] **1.1** description` items that either link a task file or carry their spec inline, and a Progress table by phase. `/plan-resume` and `/plan-archive` read the status header and the checkboxes; keep those exact.
- `tasks/N.M-slug.md` only for tasks that need more than a few lines: objective, paths, the contract it implements (by reference to the invariants, not restated), acceptance criteria, verification. A plan of five or fewer small tasks usually needs no task files.
- `.plan-state.json`:
  ```json
  {"status": "in_progress", "created_at": "<UTC>", "updated_at": "<UTC>", "current_task": null,
   "last_session_notes": null, "progress": {"total": N, "completed": 0}, "commits": []}
  ```
- `architecture-brief.md`, optional, when the plan spans modules or several agents will implement it: module map, task ownership, and the cross-task seams, each seam's contract stated once by reference to the invariants.

### Load-bearing invariants

This section pays for itself: reviewers find real defects against it, and the fixes are single edits. State each cross-cutting rule once, canonically, with exact symbol names, signatures, return shapes, visibility, forbidden fallbacks, and test conventions. Declare it authoritative: task files apply these rules in context but never restate them differently; if a task snippet disagrees, the invariants win and the snippet is stale.

Keep it to rules. Owner decisions go in the Decisions list; probed facts about the environment go under Unknowns and probes. Then read the section once as the implementer would: two invariants that contradict each other, or one that assumes data the plan never stores, is the first thing a reviewer finds.

### Task guidelines

- Give exact symbols and snippets only where they settle a contract; leave routine detail to the implementer.
- Each consumed symbol is defined by an earlier task, with one name, one signature, and one visibility, and is visible from the consumer's crate or package.
- Choose verification per task. Use TDD when the project requires it or a failing test usefully pins the behavior; say what the Red asserts and why it fails before the change. Name a concrete check for documentation and mechanical tasks. A Red that passes before the code exists, or a fixture that cannot be built, is a plan defect.
- When several agents author or implement tasks in parallel, give each the same interface-contract block verbatim (the invariants plus the seams it touches) and reconcile the outputs when they return.

## 4. Self-check, commit, present

Read the plan once as the implementer: the invariants, each task's snippets, and the acceptance criteria say the same thing; every consumed symbol is defined earlier and visible; the snippets would plausibly compile; the plan covers the request. Fix contradictions now rather than leaving them for review.

Commit the plan directory to the gumbo repo when you save it and after each revision; a plan under review is still worth versioning. Then present a short summary: the path, the task count, the unknowns still open, and the first tasks. Plan approval is not implementation authorization; wait for the user before `/plan-resume`.
