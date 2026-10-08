---
name: plan-review
description: Review an implementation plan for correctness, feasibility, completeness, and consistency.
---

# Plan Review

Review the plan as the implementer who will execute it from disk in a fresh session. Read the implementation plan, the architecture brief if present, every task file, and the state file, and ground findings against the live source tree. A reviewer can be wrong and a plan can be right: verify each claim before reporting it.

## Checks

1. **Claims about existing code.** Every symbol, signature, path, line anchor, and "already handled" the plan asserts is true at the current head. Stale claims are the findings that survive the most review rounds.
2. **Internal consistency.** Shared symbols agree across all files: one name, signature, visibility, path. The load-bearing invariants read the same wherever they are applied (a task's snippet, context, and acceptance criteria). No two invariants contradict each other, and none assumes data the plan never stores. Nothing states a value changed during iteration in its old form, including paraphrases such as counts and ownership claims in the brief or overview.
3. **Feasibility and order.** Snippets would plausibly compile: visibility across package, crate, or binary boundaries; arity; imports; variant shapes. Every consumed symbol is defined by an earlier task, so each task is buildable on its own. Existing tests the change breaks are accounted for.
4. **Test validity.** Each Red fails before the change for the stated reason and cannot pass vacuously; fixtures can be built; no race or ordering assumption hides in an assertion. Verification for non-TDD tasks is named and runnable.
5. **Behavior.** Failure paths, edge cases, and conflicting requirements the tasks do not handle; a rule that cannot protect what it claims to protect; an ordering that leaves the system broken between phases.
6. **Unknowns.** Anything the design rests on that source cannot confirm (host behavior, an external API, a UI) is listed under Unknowns and probes with a probe before the dependent tasks, not deferred to a final live check.
7. **Completeness and alignment.** The plan covers the request; each task-list item has a file or an adequate inline spec; verification matches each task; the plan honors the research, ADRs, and owner decisions it cites and does not quietly contradict one.

## Output

One finding per issue, grounded in `file:line`, with the minimal remedy. When the fix must land in several places, name them all. Severity: `blocking` (would not compile, run, or do what the request asks), `should-fix` (a real defect the implementer would otherwise reproduce), `nit` (optional).

Verdict: `approved` when no blocking or should-fix findings remain; `revise` when some do; `blocked` only when the review cannot be completed or a finding needs a decision the author cannot make (an owner choice, missing access). A missing definition or an unresolved symbol is `revise`, not `blocked`.

Do not rewrite the plan. If asked to apply fixes, make the minimal change, propagate it everywhere the value appears, and re-run checks 1 to 3 on the edited regions.
