---
name: research-resume
description: Resume a research plan through investigation, progress checks, and synthesis within the requested scope.
---

# Research Resume

Carry a research plan through investigation and synthesis within the scope the user authorized. Shared rules are in `.gumbo/AGENTS.local.md`; file formats in `.gumbo/research/AGENTS.md`.

## 1. Resolve the target

Use the research the user named or the one this session is on. Otherwise list `.gumbo/research/NNNN-*/` (not `archive/`) whose state is not `synthesized`, `archived`, or `cancelled`; a directory with no state file is active, and its state is inferred from which outputs exist before a state file is written. One: continue it. Several: list them and ask. None: point at `/research-create`. A status request is not authorization to investigate.

## 2. Act on the state

**planned.** Investigate each question: in parallel when delegation is authorized and the questions are independent, otherwise serially in this session. Each investigation gets the question's where/what/how/why, the sources, the shared-contract block verbatim if the plan has one, the output path `.gumbo/research/NNNN-topic/qN-slug.md`, the findings format from `research/AGENTS.md`, and the rules: write the file end to end, read-only on source repos, no commits, return a terse summary. Dependent questions start after their inputs land and read those files. Set the state to `in_progress` and the plan's status header and Expected Outputs rows to match.

**in_progress.** Check each output: a file that exists is not necessarily finished; confirm its worker has returned or explicitly handed off, then read it and confirm it answers the question. Update the Expected Outputs table and report complete and pending questions. Continue collecting within the budget; at a blocker, keep partial results and name the next action. A partial synthesis is labeled partial.

**all questions complete.** Sweep the question files for agreement on shared terms and decided values and reconcile drift there first. Then write `synthesis.md`: Summary; Key Findings (cross-cutting, each traceable to question files); Decisions (owner decisions made during the research, dated, and the questions still open for the owner); Recommendations (one per decision, with the rationale); Next Steps (what a plan or ADR should do); Source Files. Set the state to `synthesized`, the plan status to SYNTHESIZED, and the `synthesis.md` row in Expected Outputs to Complete.

**synthesized.** Show the summary and offer `/plan-create` from it, `/adr-create` for a decision worth recording, deeper research in a subdirectory with its own plan and state, or `/research-archive`.

## 3. Propagate

Research is iterated: a review, a late finding, an owner direction. When a decided value, term, or recommendation changes, update every file that states it: the question files, the synthesis, `research-plan.md`, the Sources and Expected Outputs tables, the state notes. Re-read each corrected passage once for overshoot. `/research-review` is the net for what the sweep misses.

## 4. End of session

Set `updated_at` and a short `last_session_notes` (what landed, the next action), and commit the directory to the gumbo repo.
