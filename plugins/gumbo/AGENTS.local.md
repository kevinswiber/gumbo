## Planning and Task Tracking

Use `/plan:create` to create implementation plans and `/plan:resume` to continue in-progress work.
Plans follow strict TDD (Red/Green/Refactor) and record findings during implementation.
Use `/plan:findings-create` to retroactively extract findings from completed phases.
Use `/plan:findings-resume` to triage findings into issues and research updates.
See `.gumbo/plans/CLAUDE.md` for workflow details and conventions.

## Issues

Use `/plan:findings-resume` to triage plan findings into tracked issues.
Issues live in `.gumbo/issues/NNNN-description/` with an index file and individual issue files.
See `.gumbo/issues/CLAUDE.md` for format conventions.

## Research

Use `/research:create` to design a research plan with parallel investigation tasks.
Use `/research:resume` to spawn agents, check progress, or synthesize findings.
Use `/research:archive` to archive completed research.
See `.gumbo/research/CLAUDE.md` for workflow details and conventions.

## Git and .gumbo

The `.gumbo` directory in a code repo is a symlink to a private directory (e.g. `~/.gumbo/projects/<name>/`). It is **not** tracked by the code repo's git. When running git commands (log, add, commit, push) on plans, research, or issues in `.gumbo`:

1. Read `.gumbo/config.json` to find the project root and working directory.
2. Check if that project root is a git repo. If so, use it.
3. If not, check for a git repo in a higher directory (e.g. `~/.gumbo`). If one exists, use that repo but scope your `git add` and commits to only this project's subdirectory.
4. You may push to the `.gumbo` git remote as well.
5. **Never push the code repo** if the user only asked to push something in `.gumbo`. These are separate repos — keep operations scoped to whichever repo the user's request applies to.
