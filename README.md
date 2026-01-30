# thoughts

Version-controlled development thoughts, plans, research, and issues -- separated from code repos.

## Why

Keep your inner dev loop artifacts (implementation plans, research, issue tracking) out of your code repos while still version-controlling them. Each project gets a `.thoughts` symlink pointing into this repo.

## Structure

```
thoughts/
├── .claude-plugin/
│   └── marketplace.json    # Plugin marketplace catalog
├── plugins/
│   ├── plan/               # Implementation planning plugin
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   └── skills/
│   │       ├── create/
│   │       ├── resume/
│   │       ├── archive/
│   │       ├── cancel/
│   │       ├── findings-create/
│   │       └── findings-resume/
│   ├── research/           # Research investigation plugin
│   │   ├── .claude-plugin/
│   │   │   └── plugin.json
│   │   └── skills/
│   │       ├── create/
│   │       ├── resume/
│   │       ├── archive/
│   │       └── cancel/
│   └── thoughts/           # Project initialization plugin
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── AGENTS.local.md # Shared agent rules symlinked into each project
│       └── skills/
│           └── init/
│               ├── SKILL.md
│               ├── scripts/
│               │   └── init.sh
│               └── template/
│                   ├── plans/
│                   ├── research/
│                   └── issues/
└── src/                    # Per-project thought directories
    └── mmdflux/
        ├── AGENTS.local.md -> ../../plugins/thoughts/AGENTS.local.md
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

## Install plugins

Add the marketplace and install plugins:

```bash
claude plugin marketplace add kevinswiber/thoughts
claude plugin install plan@thoughts
claude plugin install research@thoughts
claude plugin install thoughts@thoughts
```

## Initialize a project

Use the `/thoughts:init` skill or run the script directly:

```bash
plugins/thoughts/skills/init/scripts/init.sh ~/src/myproject
```

This will:

1. Create `~/src/thoughts/src/myproject/` (if it doesn't exist)
2. Copy the template directories (`plans/`, `research/`, `issues/`) with their `CLAUDE.md` files
3. Symlink `AGENTS.local.md` to the shared copy in the thoughts plugin
4. Create a symlink at `~/src/myproject/.thoughts` pointing to the thoughts directory
5. Add `.thoughts` to the project's `.gitignore`

## Skills

### plan

- `/plan:create` -- Create an implementation plan
- `/plan:resume` -- Resume an in-progress plan
- `/plan:archive` -- Archive a completed plan
- `/plan:cancel` -- Cancel a plan
- `/plan:findings-create` -- Extract findings from completed phases
- `/plan:findings-resume` -- Triage findings into issues/research

### research

- `/research:create` -- Create a research plan with parallel investigation
- `/research:resume` -- Resume or synthesize research
- `/research:archive` -- Archive completed research
- `/research:cancel` -- Cancel research

### thoughts

- `/thoughts:init` -- Initialize a thoughts directory for a project

## AGENTS.local.md

`plugins/thoughts/AGENTS.local.md` contains shared agent instructions (planning, research, and issue workflows) that apply to all projects. Each project gets a symlink at `.thoughts/AGENTS.local.md` pointing to this single source of truth, so updates propagate to every project automatically.

## Directories

### plans/

Implementation plans with task lists, TDD workflows, and progress tracking. See the template `plans/CLAUDE.md` for conventions.

### research/

Research investigations with parallel question-based exploration. See the template `research/CLAUDE.md` for conventions.

### issues/

Issue sets sourced from plan findings or direct observation. See the template `issues/CLAUDE.md` for conventions.
