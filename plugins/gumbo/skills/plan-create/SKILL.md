---
name: plan-create
description: Create implementation plans following project conventions. Use when planning new features, refactors, or significant changes.
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*)
---

# Planning Skill

Plan the requested feature or change using the project's planning conventions.

## Process

1. **Ground the implementation approach in the relevant code and constraints.** Read the areas needed for the requested change. Delegate bounded investigation only when authorized and useful; use available capabilities rather than assuming a particular agent API.

2. **After planning is complete**, save the plan to the project's plans directory:
   - Find the next plan number by checking both `.gumbo/plans/` and `.gumbo/plans/archive/` for the highest `NNNN-*` prefix
   - Create `.gumbo/plans/NNNN-feature-name/` directory (use lowercase kebab-case)
   - Write `implementation-plan.md` with the full plan
   - Write `task-list.md` with checkboxes for each task (each linking to a task file)
   - Create `tasks/` subdirectory with detailed task files (see format below)
   - Write `.plan-state.json` with initial state (see format below)
   - **Optionally** write `architecture-brief.md` for plans that warrant it (see step 5b below)
   - Check `.gumbo/research/` at the project root for prior research relevant to this plan and link to it

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

   ## Load-bearing invariants (single source of truth)
   [OPTIONAL but strongly recommended when the plan has cross-cutting rules that would otherwise be
   restated across many tasks — an API contract or return-type shape, a visibility/boundary rule, a
   "never do X" safety rule, a shared test convention. State each such rule ONCE here, canonically,
   with exact symbol names and signatures, and declare this section authoritative: "task files apply
   these in context but must not restate them differently; if a task snippet disagrees, this section
   wins and the snippet is stale." A single referent stops the same rule drifting between a task's
   Green snippet, its Context, and its acceptance criteria — the most common source of
   contradict-and-patch churn.]

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
   [If prior research exists in the project's .gumbo/research/ directory, link to relevant documents here]
   - [research-doc-name.md](../../research/topic/research-doc-name.md)

   ## Testing Strategy
   [Verification appropriate to the change and repository gates; use TDD when required or useful for behavior evidence]
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
   | Research: Topic Name | [.gumbo/research/topic/doc.md](../../research/topic/doc.md) |
   ```

   Each task item links to a detailed task file in `tasks/`. The Quick Links section at the bottom provides easy access to the implementation plan and any relevant research documents.

5. **Create a `tasks/` subdirectory** with `{task-number}-{kebab-case-name}.md` files for substantive tasks. Describe the objective, affected paths, implementation approach, relevant context, acceptance criteria, and verification.

   Use TDD when the project requires it or a failing regression test usefully defines the behavior: specify the assertion and expected failure, implement the fix, and rerun affected checks. For documentation or mechanical tasks, specify suitable validation instead. Refactor only when a concrete clarity problem warrants it.

   **Guidelines for task files:**
   - Include exact symbols, signatures, or code snippets when they settle a load-bearing contract; otherwise let the implementer choose routine details.
   - Reference relevant research and shared constraints rather than copying whole documents into every task.
   - Small or self-explanatory tasks can be described inline in the task list with `*(Covered in X.Y)*` or a brief note.
   - **Single-source each shared rule and symbol.** When a rule or a symbol (a function name, signature, type, or visibility) is introduced in one task and consumed by others, fix exactly one spelling for it — in the plan's invariants section or its owning task — and have other tasks *reference* it rather than restate it. Restated copies drift: a later edit fixes one and leaves the others contradicting, which an implementer then copies verbatim.
   - **Verify cross-boundary visibility.** When a plan spans a package/crate or binary↔library boundary, state explicitly which symbols are public vs internal, and confirm every symbol a task consumes is visible from the consumer's location (e.g. a binary/CLI crate cannot see a library's `pub(crate)`/private items; a sibling module can). Getting this wrong produces won't-compile plans that look fine on the page.
   - **Every consumed symbol must be defined by some task.** If task B uses `foo()`/`Bar`, some task must actually create it (don't write "owned by an earlier phase" against a symbol no task defines). Reconcile the producer and the consumer on one name, signature, and visibility.

5b. **Optionally write `architecture-brief.md`** — a spatial/ownership map of the change, complementing the *load-bearing invariants* section (which states the shared **rules**; the brief states the shared **shape**). Write one when the plan is large, spans multiple modules, has cross-task dependencies at shared seams, or will be implemented or task-authored by more than one agent in parallel. Skip it for small, single-module plans. It contains:
   - **Module map** — the files/modules the plan touches and what each is for (a one-line orientation per module).
   - **Task ownership** — which task owns which module/symbol/seam, so two tasks never edit the same seam without one being declared the owner. (This is what keeps parallel implementers from colliding.)
   - **Cross-task seams** — every place two tasks meet (a shared trait/function signature, a new public API, a data shape passed between phases), with the exact contract at each seam stated once. A seam's contract is a load-bearing invariant; reference the invariants section rather than restating it.
   - **Data/control flow** (optional) — a short narrative or diagram of how the pieces connect at runtime.

   The brief is the map an implementer (or a reviewer) reads first to understand *where* things go before reading *what* each task does. Link it from `implementation-plan.md`'s Overview and from `task-list.md`'s Quick Links.

5c. **Parallelizing authoring or implementation (optional, for large plans).** When fanning out task-file authoring or implementation across multiple agents, give **every** agent one identical **interface-contract block** in its prompt — the load-bearing invariants plus the relevant cross-task seams from the architecture brief, verbatim. Parallel agents cannot see each other's output, so a shared contract is the only thing that stops them drifting on a symbol name, a signature, or a seam's shape. After parallel work returns, run the self-consistency pass (step 7) across all outputs to verify the seam held, and reconcile any drift before presenting.

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

7. **Run a self-consistency pass before presenting.** A plan is read top-to-bottom and copy-pasted by an implementer, so an internal contradiction becomes a bug or a wasted review round. After all files are written and before presenting, sweep for self-contradictions rather than leaving them for review to find:
   - For each load-bearing invariant, search **every** task file for its *anti-pattern* (the wrong return type, a private symbol called from a layer that can't see it, a forbidden fallback, a test doing something a test rule forbids) and reconcile every hit — the rule must read the same in the Green snippet, the Context, and the acceptance criteria.
   - Verify shared symbols agree across tasks: one name, one signature, one visibility, one file path. A symbol defined in one task and used in another must match exactly and be visible from the consumer.
   - Confirm no task references a symbol that no task defines.
   - When code snippets are in a known language, sanity-check they would plausibly compile (variant shapes, argument arity, import paths, visibility) — these are the errors reviewers catch most often.

   Fix every contradiction now. The goal is a copy-paste-safe plan, not one that survives one reviewer pass.

8. **Do not commit the plan files**

9. **Present the plan** to the user for approval before any implementation begins

10. **Provide enhanced continuation output** after saving the plan:

   Output format:
   ```
   **Plan saved to:** `.gumbo/plans/NNNN-feature-name/`
   **Created:** YYYY-MM-DD HH:MM UTC
   **Tasks:** 0/N complete
   **Planning agent:** `{agentId}` (resume for additional context)

   **First tasks:**
   - [ ] **1.1** First task description
   - [ ] **1.2** Second task description
   - [ ] **1.3** Third task description

   *Plan summary: Brief description of what the plan is about*
   ```

## Example Output

---

**Plan saved to:** `.gumbo/plans/0006-rust-parser/`
**Created:** 2026-01-24 10:30 UTC
**Tasks:** 0/12 complete
**Planning agent:** `a1b2c3d4-e5f6-7890-abcd-ef1234567890` (resume for additional context)

**First tasks:**
- [ ] **1.1** Create RustParser struct implementing ErrorParser trait
- [ ] **1.2** Add Rust variant to Language enum
- [ ] **1.3** Implement panic message regex patterns

*Plan summary: Add support for parsing Rust panic stack traces*

---
