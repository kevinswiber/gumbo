---
name: plan-review
description: Review an implementation plan for correctness, feasibility, completeness, and internal consistency before it is approved or implemented — and to catch the reference drift that iteration introduces. Reports findings; does not auto-fix unless asked.
---

# Plan Review Skill

Review a plan the way a careful implementer or reviewer would: read it top-to-bottom, and catch what would otherwise become a bug, a wasted review round, or a won't-compile surprise. This is the **reactive net** for the drift that creeps in as a plan is iterated (the proactive side is the propagate-on-edit rule in `plan-resume` and single-sourcing in `plan-create`).

## When to use

- Before a plan is approved or handed to implementation.
- After a plan has been **iterated** (a review applied, a task reworked, a decision changed) — the moment most likely to have left stale references behind.
- When asked to "review" or "sanity-check" a plan.

## What to check

Verify each load-bearing claim against the actual plan and source before reporting it — a reviewer can be wrong and a plan can be right.

1. **Internal consistency (the drift net — the highest-value pass).**
   - **Shared symbols agree** across all task files: one name, one signature, one visibility, one file path. A symbol defined in one task and used in another must match exactly.
   - **Every consumed symbol is defined** by some task (no "owned by an earlier phase" against a symbol no task creates).
   - **Load-bearing invariants read the same everywhere** — for each invariant, search every task file for its *anti-pattern* (the wrong return type, a forbidden fallback, a private symbol called across a boundary, a test doing what a test rule forbids) and flag every hit. The rule must read identically in the Green snippet, the Context, and the acceptance criteria.
   - **No stale references.** Grep the whole plan for any value that was changed during iteration (an old symbol name, a superseded decision, a renamed field) — these are the leftovers iteration leaves behind. The architecture brief's seams must match the current task files.
2. **Feasibility.** Would the code plausibly compile? Check visibility across package/crate or binary↔library boundaries, argument arity, import paths, variant shapes. Is each task's Green achievable from its Red?
3. **Completeness.** Every task-list item has a task file or a justified inline note; the plan actually covers the request; TDD Red/Green/Refactor phases are present where there's implementation code.
4. **Alignment.** The plan honors the research and ADRs it cites and the constraints/invariants it declares; it doesn't quietly contradict an approved decision.

## How

- Read the plan top-to-bottom (implementation plan → architecture brief → every task file → state).
- For each invariant, **grep for its anti-pattern** across the task files; for each shared symbol, confirm the producer and every consumer agree; for each value changed in iteration, grep for the old form.
- Ground every finding in a specific `file:line` and state the **minimal** remedy.

## Output

Report findings grouped by severity, each with location and a minimal fix — do **not** rewrite the plan unless explicitly asked to apply fixes:

```
**[Blocking]** <one-line issue> — `tasks/2.1-…md:NN`. <why it breaks> Fix: <minimal remedy>.
**[Should-fix]** …
**[Nit]** …
```

Close with a one-line verdict (approve / approve-with-fixes / needs-changes). If asked to **apply** the fixes, make the minimal change and re-run the consistency checks (per `plan-resume`'s propagate-on-edit rule) so the fix itself doesn't introduce new drift.
