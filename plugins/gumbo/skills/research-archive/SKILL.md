---
name: research-archive
description: Archive completed research. Moves the research to archive/ and updates its status.
---

# Research Archive

Archive research after its synthesis has been consumed. Shared rules are in `.gumbo/AGENTS.local.md`.

1. **Identify the research.** The one the user named; otherwise scan `.gumbo/research/NNNN-*/` (not `archive/`, not unnumbered legacy directories) for state `synthesized`. Several candidates: ask.
2. **Verify.** `synthesis.md` exists and each question has a findings file. If the synthesis is missing, ask "Research has no synthesis yet. Archive anyway?" and wait.
3. **Update the files.** `research-plan.md` header becomes `## Status: ARCHIVED` with `**Archived:** YYYY-MM-DD`; `.research-state.json` gets `status: "archived"`, `archived_at`, `updated_at`, keeping every other field.
4. **Move** the directory to `.gumbo/research/archive/`. Links from active plans, roadmaps, and handoffs that used the old path now break; grep the project for `research/NNNN-` and repoint them in the same commit.
5. **Commit** to the gumbo repo and confirm in a few lines: the archive path, the question count, whether a synthesis exists.
