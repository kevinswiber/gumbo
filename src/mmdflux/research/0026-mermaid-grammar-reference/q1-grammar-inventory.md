# Q1: Mermaid Grammar File Inventory

## Summary

Mermaid has ~23 diagram types with formal grammar definitions spread across two parser
technologies: Langium (7 diagrams, newer) and Jison (16 diagrams, older). The grammars
total ~4,400 lines across 26+ files.

## Where

All paths relative to `~/src/mermaid/`.

## What

### Langium Grammar Files

**Package:** `packages/parser/`
**Config:** `packages/parser/langium-config.json`
**Technology:** Langium 3.3.1 (with Chevrotain 11.0.3 for tokenization)

| Diagram | Grammar File(s) |
|---------|----------------|
| Common (shared) | `packages/parser/src/language/common/common.langium` |
| Architecture | `packages/parser/src/language/architecture/architecture.langium`, `arch.langium` |
| Git Graph | `packages/parser/src/language/gitGraph/gitGraph.langium`, `reference.langium` |
| Info | `packages/parser/src/language/info/info.langium` |
| Packet | `packages/parser/src/language/packet/packet.langium` |
| Pie | `packages/parser/src/language/pie/pie.langium` |
| Radar | `packages/parser/src/language/radar/radar.langium` |
| Treemap | `packages/parser/src/language/treemap/treemap.langium` |

**Integration pattern:** Diagram parsers import from `@mermaid-js/parser` and call
`parse('diagramType', input)` to get a typed AST.

### Jison Grammar Files

**Package:** `packages/mermaid/`
**Technology:** Jison 0.4.18 (Bison/Yacc-style, unmaintained)

| Diagram | Grammar File |
|---------|-------------|
| Block | `src/diagrams/block/parser/block.jison` |
| C4 | `src/diagrams/c4/parser/c4Diagram.jison` |
| Class | `src/diagrams/class/parser/classDiagram.jison` |
| ER | `src/diagrams/er/parser/erDiagram.jison` |
| Flowchart | `src/diagrams/flowchart/parser/flow.jison` |
| Gantt | `src/diagrams/gantt/parser/gantt.jison` |
| Kanban | `src/diagrams/kanban/parser/kanban.jison` |
| Mindmap | `src/diagrams/mindmap/parser/mindmap.jison` |
| Quadrant Chart | `src/diagrams/quadrant-chart/parser/quadrant.jison` |
| Requirement | `src/diagrams/requirement/parser/requirementDiagram.jison` |
| Sankey | `src/diagrams/sankey/parser/sankey.jison` |
| Sequence | `src/diagrams/sequence/parser/sequenceDiagram.jison` |
| State | `src/diagrams/state/parser/stateDiagram.jison` |
| Timeline | `src/diagrams/timeline/parser/timeline.jison` |
| User Journey | `src/diagrams/user-journey/parser/journey.jison` |
| XY Chart | `src/diagrams/xychart/parser/xychart.jison` |

**Also:** `packages/mermaid-example-diagram/src/parser/exampleDiagram.jison` (reference example)

## How

Jison grammars use a `%lex` / `%% ... %%` structure with explicit token definitions and
BNF-style production rules. These map relatively directly to PEG grammar rules, though
PEG is ordered-choice (no ambiguity) while Jison uses LALR(1) parsing.

Langium grammars use a declarative syntax with terminal/rule definitions that generate
typed TypeScript ASTs. The grammar syntax is closer to EBNF.

## Why

The split exists because Mermaid is mid-migration. Jison is unmaintained, and Langium
was chosen as the replacement for its LSP support, typed ASTs, and better error
reporting. The migration is tracked in GitHub issue #4401.

## Key Takeaways

- For the 7 Langium diagrams, use the `.langium` files as the canonical source
- For the 16 Jison diagrams, use the `.jison` files (no Langium alternative exists yet)
- No diagram has both a Jison and Langium grammar; the Jison file is deleted upon migration
- The `common.langium` file contains shared rules (strings, accessibility directives)
  that apply to all Langium-based diagrams

## Open Questions

- How closely do the Jison grammars match actual runtime behavior? (Jison actions can
  contain arbitrary JS that modifies parsing behavior beyond what the grammar expresses)
