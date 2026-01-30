# thoughts

Version-controlled development thoughts, plans, research, and issues -- separated from code repos.

## Why

Keep your inner dev loop artifacts (implementation plans, research, issue tracking) out of your code repos while still version-controlling them. Each project gets a `.thoughts` symlink pointing into this repo.

## Structure

```
thoughts/
├── init.sh              # Project initialization script
├── rules/
│   └── AGENTS.local.md  # Shared agent rules symlinked into each project
├── template/            # Template copied to new projects
│   ├── plans/
│   │   └── CLAUDE.md
│   ├── research/
│   │   └── CLAUDE.md
│   └── issues/
│       └── CLAUDE.md
└── src/                 # Per-project thought directories
    ├── mmdflux/
    │   ├── AGENTS.local.md -> ../../rules/AGENTS.local.md
    │   ├── plans/
    │   ├── research/
    │   └── issues/
    └── other-project/
        ├── AGENTS.local.md -> ../../rules/AGENTS.local.md
        ├── plans/
        ├── research/
        └── issues/
```

## Setup

Each directory in `src/` corresponds to a repo in `~/src/`. For example:

- `~/src/thoughts/src/mmdflux/` serves `~/src/mmdflux/`
- `~/src/thoughts/src/myapp/` serves `~/src/myapp/`

The code repo has `.thoughts` in its `.gitignore` and a symlink:

```
~/src/mmdflux/.thoughts -> ~/src/thoughts/src/mmdflux
```

## Initialize a project

```bash
./init.sh ~/src/myproject
```

This will:

1. Create `~/src/thoughts/src/myproject/` (if it doesn't exist)
2. Copy the template directories (`plans/`, `research/`, `issues/`) with their `CLAUDE.md` files
3. Symlink `AGENTS.local.md` to the shared `rules/AGENTS.local.md`
4. Create a symlink at `~/src/myproject/.thoughts` pointing to the thoughts directory
5. Add `.thoughts` to the project's `.gitignore`

## Claude Skills

User-scoped Claude Skills in `~/.claude/skills` drive this workflow:

- `/plan:create` -- Create an implementation plan
- `/plan:resume` -- Resume an in-progress plan
- `/plan:archive` -- Archive a completed plan
- `/plan:cancel` -- Cancel a plan
- `/plan:findings:create` -- Extract findings from completed phases
- `/plan:findings:resume` -- Triage findings into issues/research
- `/research:create` -- Create a research plan with parallel investigation
- `/research:resume` -- Resume or synthesize research
- `/research:archive` -- Archive completed research
- `/research:cancel` -- Cancel research

These skills read the `CLAUDE.md` files in each directory to understand conventions.

## AGENTS.local.md

`rules/AGENTS.local.md` contains shared agent instructions (planning, research, and issue workflows) that apply to all projects. Each project gets a symlink at `.thoughts/AGENTS.local.md` pointing to this single source of truth, so updates propagate to every project automatically.

## Directories

### plans/

Implementation plans with task lists, TDD workflows, and progress tracking. See `template/plans/CLAUDE.md` for conventions.

### research/

Research investigations with parallel question-based exploration. See `template/research/CLAUDE.md` for conventions.

### issues/

Issue sets sourced from plan findings or direct observation. See `template/issues/CLAUDE.md` for conventions.
