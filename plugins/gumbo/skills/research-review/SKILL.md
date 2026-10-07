---
name: research-review
description: Review research findings and synthesis for grounding, consistency, and fidelity to sources.
---

# Research Review

Review research as a skeptical reader who will act on it. Read every question file, the synthesis, `research-plan.md`, the state file, and any shared-contract, decisions, or ADR-draft files in the directory. Ground findings against the actual sources: code at the current head, the cited documents. A reviewer can be wrong and the research can be right: verify before reporting.

## Checks

1. **Grounding.** Load-bearing claims trace to a source a reader could open: `file:line` for code, a precise citation for prior art, the command and its output for a measurement. Prior-art claims are checked against the upstream text, not only cited. Headline numbers and denominators are re-derived once from the stated data.
2. **Consistency.** A decided value, rule, or term reads the same in every file that states it: the question files, the synthesis, `research-plan.md`, the Sources and Expected Outputs tables, the status headers, and the state file. A value changed during iteration is gone in its old form everywhere.
3. **Synthesis fidelity.** Every synthesis claim traces to a question file; disagreements between questions are reported, not silently resolved; recommendations are supported and decisive rather than a survey.
4. **Method.** A proposed experiment or protocol can observe what it predicts, and the sources consulted can answer the question asked.
5. **Completeness.** Each question is answered rather than deflected; open questions and owner decisions are surfaced; the research says what a plan should do next.
6. **Corrections.** On a later round, re-read each corrected passage for overshoot: a fix that now overstates, or a sibling file that still says the old thing.

## Output

One finding per issue, with its location (`q5-….md:NN`, or two locations for a contradiction) and the minimal reconcile. Severity: `blocking` (a conclusion rests on it), `should-fix` (a reader would be misled), `nit`.

Verdict: `approved` when no blocking or should-fix findings remain; `revise` when some do; `blocked` only when the review cannot be completed or a finding needs a decision the author cannot make.

Do not rewrite the research. If asked to apply fixes, make the minimal change, sweep every file for the old form, and re-read the edited passages for overshoot.
