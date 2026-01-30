# Claude Code Instructions for Issues

**IMPORTANT**: Do *not* commit issues to the git repo!

When working on this project, follow these guidelines for creating and managing issues.

## Issue Sources

Issues come from two primary sources:

1. **Plan findings** — Discoveries, TODOs, and problems recorded in `plans/NNNN-name/findings/` during implementation. Use `/plan:findings:resume` to triage findings into issues.
2. **Direct observation** — Issues identified through testing, visual comparison, or user reports.

## Directory Structure

Each issue set lives in a numbered subdirectory:

```
issues/
├── CLAUDE.md
├── 0001-lr-layout-and-backward-edge-issues/
│   └── issues.md
├── 0002-visual-comparison-issues/
│   ├── issues.md              # Issue index and summary
│   └── issues/                # Individual issue files
│       ├── issue-01-short-description.md
│       ├── issue-02-short-description.md
│       └── issue-03-short-description.md
```

## Creating an Issue Set

1. **Find the next issue set number** by checking `issues/` for the highest `NNNN-*` prefix.
2. **Create the subdirectory:** `issues/NNNN-kebab-description/`
3. **Write `issues.md`** — the index file summarizing all issues in the set.
4. **Create `issues/` subdirectory** for individual issue files (if more than 2-3 issues).
5. For small sets (1-2 issues), individual files can live directly in the set directory.

## Issue Index Format (issues.md)

```markdown
# Issues: Descriptive Title

## Date: YYYY-MM-DD

[Brief description of how these issues were identified]

**Source:** [e.g., "Plan 0020 findings", "Visual comparison", "User report"]

---

## Issue Index

| # | Issue | Severity | Category | Source Finding | File |
|---|-------|----------|----------|----------------|------|
| 1 | Short description | High/Medium/Low | Category | `finding-name.md` | [issue-01](issues/issue-01-name.md) |

---

## Categories

### A. Category Name (Issues N, M)

[Brief description of the category]

---

## Cross-References

- **Plan NNNN:** [Link to source plan]
- **Research NNNN:** [Link to related research]
```

## Individual Issue Format

```markdown
# Issue NN: Short Descriptive Title

**Severity:** High | Medium | Low
**Category:** [Category name]
**Status:** Open | In Progress | Fixed | Won't Fix
**Affected fixtures:** `fixture1`, `fixture2`
**Source finding:** [Link to plan finding if applicable]

## Description

[Clear description of the problem]

## Reproduction

[Steps or commands to reproduce]

## Expected behavior

[What should happen instead]

## Root cause hypothesis

[Best understanding of why this happens]

## Cross-References

- **Plan:** [Link to related plan]
- **Research:** [Link to related research]
```

## Severity Guidelines

- **High** — Visually broken output, incorrect behavior, data loss
- **Medium** — Suboptimal output, cosmetic issues affecting readability
- **Low** — Minor cosmetic issues, edge cases, nice-to-haves

## Numbering

- Issue sets use `NNNN-kebab-description` (e.g., `0003-tdd-phase-regressions`)
- Individual issues within a set use `issue-NN-kebab-description` (e.g., `issue-01-missing-arrow`)
- Numbers are zero-padded and sequential within their scope

## Cross-References

Issues should reference their source:
- Plan findings: `plans/NNNN-name/findings/finding-name.md`
- Research: `research/NNNN-name/`
- Other issue sets: `issues/NNNN-name/`
