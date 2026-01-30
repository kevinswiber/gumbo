# Q2: Jison-to-Langium Migration Status

## Summary

Mermaid is incrementally migrating all parsers from Jison to Langium, tracked in GitHub
issue #4401. Seven simpler/newer diagram types have been migrated. The heavyweight
diagrams (flowchart, sequence, class, state, ER, gantt) remain on Jison with only
early WIP attempts for flowchart and XY chart.

## Where

- Tracking issue: https://github.com/mermaid-js/mermaid/issues/4401
- Flowchart WIP: https://github.com/mermaid-js/mermaid/pull/5892
- XY chart WIP: https://github.com/mermaid-js/mermaid/pull/6572
- Common grammar conflicts: https://github.com/mermaid-js/mermaid/issues/6694
- Bundling issue: https://github.com/mermaid-js/mermaid/issues/7094

## What

### Fully Migrated to Langium

| Diagram | Migration Commit/PR | Date |
|---------|-------------------|------|
| Info | Early adoption | — |
| Packet | Early adoption | — |
| Pie | PR #4751 | — |
| Architecture | Commit `cb302a08b` | April 2024 |
| Git Graph | Commit `1d0e98dd6` | July 2024 |
| Radar | Built natively in Langium | — |
| Treemap | Built natively in Langium | — |

### In Progress / Draft

| Diagram | PR | Status |
|---------|-----|--------|
| Flowchart | #5892 | WIP/Draft |
| XY Chart | #6572 | Draft, has documented breaking changes |
| Mindmap | Branch `mindmap-langium-2` exists | Not merged |

### Not Yet Started (Still Jison Only)

Block, C4, Class, ER, Gantt, Kanban, Quadrant Chart, Requirement, Sankey, Sequence,
State, Timeline, User Journey

## How

The migration process for each diagram:
1. Write a `.langium` grammar in `packages/parser/src/language/<diagram>/`
2. Register it in `packages/parser/langium-config.json`
3. Langium generates TypeScript AST types
4. Update the diagram's parser module to use `parse()` from `@mermaid-js/parser`
5. Port existing Jison test cases to validate equivalent behavior
6. Delete the `.jison` file once the Langium parser is stable

## Why

Motivations for the migration (from issue #4401):
1. **Jison is unmaintained** — no bug fixes or updates
2. **LSP support** — Langium enables Language Server Protocol features (autocompletion, hover, etc.)
3. **Typed ASTs** — Langium generates TypeScript types from grammars
4. **Better error reporting** — line/column numbers in parse errors (PR #7333)
5. **Cleaner grammar syntax** — more maintainable than Jison's Bison-derived format

## Key Takeaways

- The migration is a long-term effort; most diagrams are still on Jison
- Migrated diagrams have NO Jison fallback — the `.jison` file is deleted
- A known issue (#6694) with `common.langium` causing grammar conflicts may slow
  migration of more complex diagrams
- A bundling issue (#7094) with Langium's `vscode-jsonrpc` dependency affects
  Next.js/Webpack users

## Open Questions

- Will the flowchart migration (#5892) introduce breaking syntax changes?
- Is there a target timeline for completing the full migration?
