# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## What this is

Gumbo is a Claude Code plugin that manages development workflow artifacts (plans, research, issues) outside of code repos. Data lives in `~/.gumbo/projects/<name>/` and gets symlinked into code repos as `.gumbo`. The plugin is distributed as a marketplace plugin with 18 skills.

## Repository layout

```
.claude-plugin/marketplace.json    # Marketplace catalog (single "gumbo" plugin entry)
plugins/gumbo/
  .claude-plugin/plugin.json       # Plugin manifest
  AGENTS.local.md                  # Shared agent instructions, symlinked into each project
  skills/
    gumbo-init/                    # Project initialization (has scripts/ and template/)
    plan-{create,resume,archive,cancel}/
    plan-findings-{create,resume}/
    research-{create,resume,archive,cancel}/
```

Directory names and skill names both use hyphens (e.g., `name: plan-create`).

## Skill structure

Each skill is a directory containing `SKILL.md` with YAML front matter:

```yaml
---
name: plan-create
description: What this skill does
allowed-tools: Bash(git add:*), Read, Write, Edit
---
```

The body of SKILL.md contains instructions the agent follows when the skill is invoked.

## Init script

`plugins/gumbo/skills/gumbo-init/scripts/init.sh` takes `<gumbo-root> <project-path> [project-name]`. It:
- Creates the project directory and copies template files (idempotent -- won't overwrite existing)
- Writes `config.json` with name, workingDirectory, root
- Copies AGENTS.local.md to `<gumbo-root>/AGENTS.local.md` (refreshed each run), symlinks each project to it relatively, creates CLAUDE compatibility symlinks, and creates the `.gumbo` symlink
- Reports when a project's template AGENTS.md copies have drifted from the plugin template (it never overwrites them)
- Uses `jq` for JSON manipulation

## Template files

`plugins/gumbo/skills/gumbo-init/template/` contains AGENTS.md files that get copied into each project's `.gumbo/{plans,research,issues}/` directories, with CLAUDE.md compatibility symlinks. These define the conventions for plan structure, TDD workflow, research questions, issue tracking, etc.

## Conventions

- Plans and research use `NNNN-kebab-case` numbered directories
- Plans list unknowns and probes before tasks, state cross-cutting rules once in a load-bearing invariants section, and define task-appropriate verification; task files are optional for small plans
- Research uses a where/what/how/why framework; independent questions may run concurrently when delegation is authorized
- State tracked in `.plan-state.json` and `.research-state.json`; the skills read `status`, `current_task`, `last_session_notes`, `progress`, `commits`, and tolerate extra keys
- The review skills (`plan-review`, `research-review`, `adr-review`) are embedded verbatim into Codex prompts by the owner's review-loop skills; keep them self-contained and keep the `blocking|should-fix|nit` severities and `approved|revise|blocked` verdicts
- `AGENTS.local.md` is the shared conventions reference (git discipline, propagation, interface contracts, finding format, privacy); skills link to it instead of restating rules. `CLAUDE.local.md` is only a compatibility symlink

## Git

- Do not add Claude as a co-author on commits
