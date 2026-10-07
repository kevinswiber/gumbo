# Plans

Implementation plans live here, one directory per plan. Shared rules (git, propagation, findings, privacy) are in the project's `AGENTS.local.md`; the skills are `/plan-create`, `/plan-resume`, `/plan-review`, `/plan-archive`, `/plan-cancel`, `/plan-findings-create`, `/plan-findings-resume`. This file records the formats those skills read and write.

## Layout

```
plans/
├── NNNN-feature-name/           # active plan
│   ├── implementation-plan.md
│   ├── task-list.md
│   ├── .plan-state.json
│   ├── tasks/                   # optional; one file per substantive task
│   ├── findings/                # recorded during implementation
│   ├── architecture-brief.md    # optional; large or multi-agent plans
│   ├── adr-drafts/              # optional; decisions produced by this plan
│   └── draft-*.md               # scratch notes; delete or rename before archiving
└── archive/                     # complete and cancelled plans
```

Numbers are zero-padded and increase across active plans and the archive. Names are lowercase kebab-case.

## Status header

Both `implementation-plan.md` and `task-list.md` open with a status line, read by the skills:

- `## Status: 🚧 IN PROGRESS`
- `## Status: ✅ COMPLETE` (followed by `**Completed:** YYYY-MM-DD` and, when known, a `**Commits:**` list)
- `## Status: ❌ CANCELLED` (followed by `**Cancelled:**`, `**Reason:**`, `**Superseded by:**`)

## implementation-plan.md

Sections in order: status, a link to `task-list.md`, Overview, Current State (verified against the current head), Unknowns and probes (what the design rests on that source cannot confirm, each with its probe and status; omitted only when empty), Decisions (dated owner decisions, appended as made), Load-bearing invariants, Implementation Approach by phase, Files to Modify/Create, Task Details (table of id, description, link or "inline"), Research References (relative links such as `../../research/NNNN-topic/synthesis.md`), Testing Strategy.

The **Load-bearing invariants** section is the single source of truth for cross-cutting rules: exact symbols, signatures, shapes, visibility, forbidden fallbacks, test conventions. Task files apply these rules but never restate them differently; if a task snippet disagrees, the invariants win and the snippet is stale.

## task-list.md

```markdown
# Feature Name Task List

## Status: 🚧 IN PROGRESS

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

## Phase 1: Description

- [ ] **1.1** Task description
  → [tasks/1.1-task-name.md](./tasks/1.1-task-name.md)
- [ ] **1.2** Small task, specified inline: change X in `path`, verify with Y
- [x] **1.3** Earlier design *(superseded by 1.4; see findings/plan-error-….md)*

## Progress

| Phase | Status | Notes |
| ----- | ------ | ----- |
| 1 - Description | Not Started | |
```

`- [ ]` and `- [x]` with the bold task id are what `/plan-resume` and `/plan-archive` count. A task needs its own file in `tasks/` only when its spec runs past a few lines; a plan of five or fewer small tasks usually needs none.

## tasks/N.M-slug.md

Objective; Location (paths); Implementation (snippets only where they settle a contract, otherwise by reference to the invariants); Context (links to research, edge cases); Acceptance Criteria; Verification (TDD with the Red's assertion and expected failure when the project requires it or a failing test pins the behavior, otherwise the concrete check). Superseded task files keep their text with a one-line banner at the top pointing at the replacement.

## .plan-state.json

```json
{
  "status": "in_progress",
  "created_at": "2026-01-24T10:30:00Z",
  "updated_at": "2026-01-24T10:30:00Z",
  "current_task": null,
  "last_session_notes": null,
  "progress": { "total": 12, "completed": 0 },
  "commits": []
}
```

- `status`: `in_progress`, `complete`, or `cancelled`. Archived plans add `completed_at`, or `cancelled_at`, `cancellation_reason`, `superseded_by`.
- `current_task`: the task id in progress, cleared when it is done.
- `last_session_notes`: a short paragraph: what landed, what is mid-flight, the next action.
- `progress`: `total` tracks the task list, including tasks added by amendments.
- `commits`: SHAs landed in the code repo, appended as phases complete.
- Extra keys are allowed (a PR number, a worktree, review records). `planning_agent_id` is a legacy optional key; omit it or write null.

Update `current_task` when starting a task, `progress.completed` when finishing one, and `last_session_notes` with `updated_at` before a session ends.

## During implementation

Tick boxes as tasks complete, keep the plan in lockstep with the code (a change to anything shared is propagated to every file that states or applies it), record findings as they happen (format in `AGENTS.local.md`), record only checks that actually ran, and amend the plan when evidence supersedes tasks rather than improvising around it (`/plan-resume` describes the amendment steps). Plan approval alone does not authorize implementation.
