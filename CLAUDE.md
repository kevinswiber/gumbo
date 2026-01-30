# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Gumbo is a Claude Code plugin that manages development workflow artifacts (plans, research, issues) outside of code repos. Data lives in `~/.gumbo/projects/<name>/` and gets symlinked into code repos as `.gumbo`. The plugin is distributed as a marketplace plugin with 11 skills.

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

Directory names use hyphens. Skill names in SKILL.md front matter use colons (e.g., `name: plan:create`).

## Skill structure

Each skill is a directory containing `SKILL.md` with YAML front matter:

```yaml
---
name: plan:create
description: What this skill does
allowed-tools: Bash(git add:*), Read, Write, Edit
---
```

The body of SKILL.md contains instructions the agent follows when the skill is invoked.

## Init script

`plugins/gumbo/skills/gumbo-init/scripts/init.sh` takes `<gumbo-root> <project-path> [project-name]`. It:
- Creates the project directory and copies template files (idempotent -- won't overwrite existing)
- Writes `config.json` with name, workingDirectory, root
- Symlinks AGENTS.local.md and creates the `.gumbo` symlink
- Uses `jq` for JSON manipulation

## Template files

`plugins/gumbo/skills/gumbo-init/template/` contains CLAUDE.md files that get copied into each project's `.gumbo/{plans,research,issues}/` directories. These define the conventions for plan structure, TDD workflow, research questions, issue tracking, etc.

## Conventions

- Plans and research use `NNNN-kebab-case` numbered directories
- Plans follow strict TDD (Red/Green/Refactor) with commits per phase
- Research spawns parallel subagents, one per question, using a where/what/how/why framework
- State tracked in `.plan-state.json` and `.research-state.json`
- Draft files prefixed with `draft-` are gitignored
- `AGENTS.local.md` is a single source of truth symlinked into all projects

## Git

- Do not add Claude as a co-author on commits
