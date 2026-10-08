# Gumbo conventions

Shared rules for every project that uses gumbo. Skills link here instead of restating these. If a skill and this file disagree, this file wins.

## Layout

- `.gumbo` in a code repo is a symlink to `~/.gumbo/projects/<name>/`; `.gumbo/config.json` holds the real paths. Plans live in `plans/NNNN-kebab/`, research in `research/NNNN-kebab/`, issues in `issues/NNNN-kebab/`. Finished plans and research move to `archive/` under their directory; issue sets stay in place. The next plan or research number is one more than the highest across active and archive; the next issue number is one more than the highest in `issues/`.
- Each artifact has a state file (`.plan-state.json`, `.research-state.json`). Consumers read `status`, `updated_at`, `current_task`, `last_session_notes`, `progress`, `commits`. Extra keys are allowed. Keep `last_session_notes` to a short paragraph; longer narrative belongs in findings or a handoff record. `planning_agent_id`, `agent_ids`, and `synthesis_agent_id` are optional legacy keys: omit them or write null, never invent a value.
- Skills: `/plan-create`, `/plan-resume`, `/plan-review`, `/plan-archive`, `/plan-cancel`, `/plan-findings-create`, `/plan-findings-resume`; `/research-create`, `/research-resume`, `/research-review`, `/research-archive`, `/research-cancel`; `/adr-create`, `/adr-review`; `/roadmap-create`; `/coordinator`; `/handoff`. File formats live in `.gumbo/{plans,research,issues}/AGENTS.md`.

## Git: the gumbo repo is separate from the code repo

The gumbo data root is its own private git repo, separate from the code repo. Find it once per session: read `root` from `.gumbo/config.json`, then take the nearest enclosing git repo of that path (usually `~/.gumbo`); call it the gumbo repo below. Plans, research, issues, findings, and ADR drafts are committed there; review-loop records under `loops/` are kept but gitignored. The code repo never tracks `.gumbo`.

- Address it explicitly: `git -C <gumbo repo> …`. The shell cwd resets between commands, so a bare `git` from the working directory targets the code repo.
- Scope every add and commit to this project's subdirectory, as a path relative to the gumbo repo (for the usual layout, `git -C ~/.gumbo add projects/<name>/…`). The index is shared with concurrent sessions; never `add -A`.
- Commit at coherent boundaries without asking: a plan saved or revised, a phase done, a synthesis written, a landing recorded. Follow the gumbo repo's existing message style (`<project>: <what>`). No co-author or session trailers.
- Push when asked or when the request implies it: `pull --rebase --autostash`, then push. On `index.lock`, wait a moment and retry once; another session holds it briefly.
- Never commit to or push the code repo for a gumbo-only change, and never push the gumbo repo when the request was about the code repo.
- Private identifiers stay out of public surfaces: plan and research numbers, task ids, finding names, loop dirs, and the word gumbo do not appear in commit messages, PR bodies, issue comments, code, tests, docs, or ADR text that lands in a repo. Record SHAs and PR numbers in the private state instead.

## Shared rules

- **Single source, then propagate.** State each shared rule, symbol, decided value, or contract once (a plan's invariants section, a research shared-contract block, an ADR's decision) and have other files reference it. When it changes, search the whole artifact set for the old form, including paraphrases (counts, ownership claims, summaries) and the places that apply the rule rather than state it. The review skills are the net for what the sweep misses.
- **Interface contract for parallel agents.** Agents fanned out in parallel cannot see each other. Give each the same contract block verbatim (decided values, vocabulary, seams, and "the file is the deliverable; return a terse summary"), plus its own output file path outside the block. Verify the seam held when they return.
- **Research and authoring delegates do not edit source repos or commit.** They write their artifact file and report; the orchestrator records and commits. Implementation is different: a session running `/plan-resume` with authorization, and implementers it fans out under the plan, edit the code repo as the plan directs.
- **Probe before you build on a guess.** When a design rests on behavior you cannot verify from source (a host, a UI, an external service), run the cheapest falsifying probe before the tasks that depend on it. Probe variants side by side, not in series; each serial guess costs an owner round trip.
- **Record decisions where they are made.** Owner decisions go into the artifact, dated (a plan's Decisions list, a synthesis's Decisions section, an ADR) before work proceeds on them.

## Findings

Record during implementation in the plan's `findings/`, one file per finding, named `<type>-<slug>.md`:

```markdown
# Finding: Short title

**Type:** discovery | diversion | plan-error | note | todo | cleanup
**Task:** 2.1
**Date:** YYYY-MM-DD
**Source:** commit abc1234 | review round 2 | live check (optional)

## Details
## Impact
## Action Items
- [ ] …
```

Corrections that come from a review are findings too. `/plan-findings-resume` triages findings into issues and research.

## Handoff records

`HANDOFF.md` (project level) and `handoff-*.md` (artifact level) are read-first documents for a fresh session. Keep each under about 300 lines: when a section becomes history, move it to the findings ledger or the archived artifact and leave one line pointing there. A record that cannot be read in one pass is not a handoff.
