---
name: plan-resume
description: Resume working on an in-progress implementation plan. Finds incomplete plans and provides context to continue.
---

# Plan Resume

Continue an implementation plan from disk. Shared rules are in `.gumbo/AGENTS.local.md`.

## 1. Resolve the plan

Use the plan the user named or the one this session is already on. Otherwise list `.gumbo/plans/NNNN-*/` (not `archive/`) whose `.plan-state.json` has `status: in_progress`; a plan whose state says complete belongs in the archive, not in the candidates, even if a box is unchecked. A plan with no state file is a candidate when its task list has unchecked boxes; rebuild the state file from the task list (`progress` from the boxes, `current_task` null) before continuing. One candidate: resume it. Several: list them with progress and ask. None: say so and point at `/plan-create`.

## 2. Orient

Read `.plan-state.json` (`current_task`, `last_session_notes`, `progress`, `commits`), the task list, the plan's invariants, decisions, and unknowns, the current task file, and the newest findings. Compare the plan's claims about the code with the current head before touching the task; the plan may have aged since it was written.

Report in a few lines: the plan path, progress, last notes, the next tasks, and any unknowns still open. Then continue only within what the user authorized; a status check is not implementation, and plan approval alone does not authorize it either.

## 3. Implement

- One task at a time. Set `current_task`; implement with the task's verification (where the plan says TDD, the Red fails for the stated reason before the change); record only checks that ran; then tick the box, bump `progress.completed`, clear `current_task`, and set `updated_at`.
- Commit the code repo at coherent boundaries when authorized, in that repo's convention, and record the SHAs in `commits`. Private identifiers stay out of public commit messages.
- Record findings as they happen (format in AGENTS.local.md), including corrections that arrive through a review.
- Propagate every change. When implementation changes something shared (a symbol, a signature, a decided value, a contract at a seam), update every place in the plan that states or applies it in the same step: the invariants, other task files, the brief, acceptance criteria, the plan summary. A plan that lags the code is a trap for the next session.

## 4. Amend the plan when evidence supersedes it

A probe or a live check will sometimes invalidate tasks. Amend the plan rather than improvising around it:

1. Record the evidence as a finding (`discovery` or `plan-error`) and the resulting owner decision, dated, in the plan's Decisions list.
2. Rewrite the invariants the evidence changed; they remain the single source of truth.
3. Mark superseded tasks in the task list as `- [x] **1.2** … *(superseded by 1.4; see findings/…)*` and leave their files as history with a one-line banner at the top. Add the replacement tasks with their own files or inline spec.
4. Recompute `progress.total` and `progress.completed` from the amended task list (superseded tasks count as done), clear or redirect `current_task` if it pointed at a superseded task, and update the Task Details table, the brief if any, and `last_session_notes`.
5. Commit the amended plan to the gumbo repo before continuing. If the amendment is large, run `/plan-review` on it first.

## 5. End of session

Set `last_session_notes` (what landed, what is mid-flight, the single next action) and `updated_at`, and commit the plan state to the gumbo repo. When every task is done, `/plan-archive`.
