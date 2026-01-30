## Planning and Task Tracking

Use `/plan:create` to create implementation plans and `/plan:resume` to continue in-progress work.
Plans follow strict TDD (Red/Green/Refactor) and record findings during implementation.
Use `/plan:findings:create` to retroactively extract findings from completed phases.
Use `/plan:findings:resume` to triage findings into issues and research updates.
See `.thoughts/plans/CLAUDE.md` for workflow details and conventions.

## Issues

Use `/plan:findings:resume` to triage plan findings into tracked issues.
Issues live in `.thoughts/issues/NNNN-description/` with an index file and individual issue files.
See `.thoughts/issues/CLAUDE.md` for format conventions.

## Research

Use `/research:create` to design a research plan with parallel investigation tasks.
Use `/research:resume` to spawn agents, check progress, or synthesize findings.
Use `/research:archive` to archive completed research.
See `.thoughts/research/CLAUDE.md` for workflow details and conventions.
