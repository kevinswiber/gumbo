---
name: research-cancel
description: Cancel a research plan. Updates status to CANCELLED and moves to archive/. Use when research is no longer needed or has been superseded.
---

# Research Cancel

Cancel research that is no longer being pursued. Shared rules are in `.gumbo/AGENTS.local.md`.

1. **Identify the research.** Only the one the user named; never auto-cancel. If none was named, list active research and ask.
2. **Ask for the reason** if not given, and what supersedes it if anything.
3. **Update the files.** `research-plan.md` header becomes `## Status: CANCELLED` with `**Cancelled:** YYYY-MM-DD`, `**Reason:** …`, and `**Superseded by:** …` when applicable; `.research-state.json` gets `status: "cancelled"`, `cancelled_at`, `updated_at`, `cancellation_reason`, `superseded_by` (or null), keeping every other field.
4. **Move** the directory to `.gumbo/research/archive/`; partial findings stay for reference. If investigations are still running, say so; their output will not be synthesized.
5. **Commit** to the gumbo repo and confirm in a few lines: the archive path, the reason, questions answered at cancellation.
