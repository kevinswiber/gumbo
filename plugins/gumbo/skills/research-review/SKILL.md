---
name: research-review
description: Review a research effort for grounding, internal consistency, and synthesis fidelity before its conclusions are relied on — and to catch the contradictions that iteration introduces across question files and the synthesis. Reports findings; does not auto-fix unless asked.
---

# Research Review Skill

Review research the way a skeptical reader would: confirm the claims are grounded, the question files don't contradict each other, and the synthesis faithfully represents what the questions actually found. This is the **reactive net** for the drift that creeps in as research is iterated (the proactive side is the propagate-on-edit rule in `research-resume`).

## When to use

- Before a research synthesis is relied on (to feed a plan, an ADR, or a decision).
- After the research has been **iterated** — a review applied, a late finding added, an owner direction folded in — the moment most likely to have left one file contradicting another.
- When asked to "review" or "sanity-check" research.

## What to check

Verify each load-bearing claim against the actual files and source before reporting it.

1. **Internal consistency (the drift net — the highest-value pass).**
   - **No contradictions across question files.** A decided value, rule, or vocabulary term stated in one question must read the same in every other question that references it. (The classic failure: a rule is sharpened in one file but its echo in another file's takeaways/table still states the old form.)
   - **The synthesis faithfully represents the findings.** Every claim in `synthesis.md` traces to a question file; the synthesis does not invent, overstate, or quietly resolve a contradiction the questions left open. Where questions disagreed, the synthesis says so (or the disagreement was reconciled in the questions first).
   - **No stale references.** Grep across all question files *and* the synthesis for any value changed during iteration (a renamed term, a superseded recommendation, an old number) and reconcile every occurrence.
2. **Grounding.** Claims are cited to source — `file:line` for codebase facts, precise citations (RFC numbers, spec sections, doc URLs) for prior art. Load-bearing claims are actually verifiable, not asserted.
3. **Completeness.** Each investigation question is genuinely answered (not deflected); open questions are surfaced rather than buried; recommendations are supported by the findings, with a clear recommendation per decision rather than a survey.

## How

- Read every question file and the synthesis. Build a small map of the shared terms/decided values and check each one reads consistently everywhere it appears.
- For each value changed in iteration, **grep all files** for the old form. For each synthesis claim, confirm it traces to a question.
- Spot-check load-bearing source citations against the actual source.
- Ground every finding in a specific file + location and state the **minimal** remedy.

## Output

Report findings grouped by severity, each with location and a minimal fix — do **not** rewrite the research unless explicitly asked to apply fixes:

```
**[Blocking]** <contradiction / unsupported claim> — `q5-…md:NN` vs `q2-…md:NN`. <why it matters> Fix: <minimal reconcile>.
**[Should-fix]** …
**[Nit]** …
```

Close with a one-line verdict (sound / sound-with-fixes / needs-reconciliation). If asked to **apply** the fixes, make the minimal change and re-sweep all files (per `research-resume`'s propagate-on-edit rule) so the fix propagates everywhere the value appears.
