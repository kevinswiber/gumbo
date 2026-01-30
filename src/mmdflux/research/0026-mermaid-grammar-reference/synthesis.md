# Research Synthesis: Mermaid Grammar Reference for Pest Translation

## Summary

The upstream Mermaid repo (`~/src/mermaid`) contains formal grammar definitions for all
23 diagram types, split between two parser technologies. Langium (7 diagrams) is the
newer, stricter, canonical grammar for migrated types. Jison (16 diagrams) is the older,
more permissive grammar for the majority of diagrams. When translating to Pest for
mmdflux, use the Langium file where one exists; otherwise use the Jison file.

## Key Findings

### 1. Two parser technologies, no overlap

No diagram has both a Langium and Jison grammar. When a diagram is migrated, the Jison
file is deleted. This means there is always exactly one canonical grammar file per
diagram type.

### 2. Canonical grammar source per diagram type

**Use Langium (in `~/src/mermaid/packages/parser/src/language/`):**

| Diagram | File |
|---------|------|
| Architecture | `architecture/architecture.langium` (+ `arch.langium`) |
| Git Graph | `gitGraph/gitGraph.langium` (+ `reference.langium`) |
| Info | `info/info.langium` |
| Packet | `packet/packet.langium` |
| Pie | `pie/pie.langium` |
| Radar | `radar/radar.langium` |
| Treemap | `treemap/treemap.langium` |
| (Shared rules) | `common/common.langium` |

**Use Jison (in `~/src/mermaid/packages/mermaid/src/diagrams/`):**

| Diagram | File |
|---------|------|
| Block | `block/parser/block.jison` |
| C4 | `c4/parser/c4Diagram.jison` |
| Class | `class/parser/classDiagram.jison` |
| ER | `er/parser/erDiagram.jison` |
| Flowchart | `flowchart/parser/flow.jison` |
| Gantt | `gantt/parser/gantt.jison` |
| Kanban | `kanban/parser/kanban.jison` |
| Mindmap | `mindmap/parser/mindmap.jison` |
| Quadrant Chart | `quadrant-chart/parser/quadrant.jison` |
| Requirement | `requirement/parser/requirementDiagram.jison` |
| Sankey | `sankey/parser/sankey.jison` |
| Sequence | `sequence/parser/sequenceDiagram.jison` |
| State | `state/parser/stateDiagram.jison` |
| Timeline | `timeline/parser/timeline.jison` |
| User Journey | `user-journey/parser/journey.jison` |
| XY Chart | `xychart/parser/xychart.jison` |

### 3. Langium grammars are stricter

Langium rejects inputs that Jison silently accepted:
- Unquoted spaces in bracketed values
- Leading zeros on numbers (`007`)
- `+`-prefixed positive numbers (`+5`)

For mmdflux, target Langium's strictness level where Langium grammars exist. For
Jison-only diagrams, match Jison's permissive behavior since that's what real users
rely on.

### 4. Jison actions contain implicit parsing logic

Jison grammars have inline JavaScript actions that can modify parsing behavior beyond
what the BNF rules express. When translating Jison grammars to Pest, read the actions
carefully — they may silently strip whitespace, normalize values, or conditionally
reject inputs in ways the grammar rules don't show.

### 5. The migration is ongoing but slow

Seven diagrams are migrated, two more have WIP PRs (flowchart, xychart), and one has
an experimental branch (mindmap). The remaining ~13 diagrams have no migration work
started. The Jison grammars will remain the authoritative source for these diagrams for
the foreseeable future.

## Recommendations

1. **Start Pest translation with the Langium diagrams** — they're smaller, cleaner,
   and have stricter rules that map well to PEG parsing. Good candidates to build out
   the translation workflow: pie, packet, info (simplest), then architecture, gitGraph.

2. **For Jison diagrams, read both the grammar AND the actions** — the inline JS in
   Jison production rules is part of the effective grammar. Don't just translate the
   BNF; understand what the actions do.

3. **Use Mermaid's own test suites as compliance tests** — the upstream repo has test
   fixtures for all diagram types. These are the ground truth for what inputs must parse
   correctly.

4. **Watch the migration** — if flowchart or sequence get migrated to Langium while
   you're working on their Pest grammars, the Langium version becomes the new canonical
   source and may have breaking changes.

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | `~/src/mermaid/packages/parser/src/language/` (Langium), `~/src/mermaid/packages/mermaid/src/diagrams/*/parser/` (Jison) |
| **What** | 23 diagram types, 7 Langium + 16 Jison, ~4,400 total lines of grammar |
| **How** | Langium: declarative EBNF-like, generates typed ASTs. Jison: LALR(1) with BNF + inline JS actions |
| **Why** | Jison is unmaintained; Langium provides LSP support, typed ASTs, better errors. Migration is incremental. |

## Relevant GitHub Links

| Resource | URL |
|----------|-----|
| Migration tracking issue | https://github.com/mermaid-js/mermaid/issues/4401 |
| Common grammar conflicts | https://github.com/mermaid-js/mermaid/issues/6694 |
| Flowchart migration (WIP) | https://github.com/mermaid-js/mermaid/pull/5892 |
| XY chart migration (draft) | https://github.com/mermaid-js/mermaid/pull/6572 |
| Langium bundling issue | https://github.com/mermaid-js/mermaid/issues/7094 |
| Error line/column numbers | https://github.com/mermaid-js/mermaid/pull/7333 |

## Next Steps

- [ ] Begin Pest translation with `pie.langium` (simplest Langium grammar)
- [ ] Set up compliance test harness using upstream Mermaid test fixtures
- [ ] Translate flowchart Jison grammar (most commonly used diagram type)
- [ ] Monitor upstream migration progress for diagrams in active WIP

## Source Files

| File | Question |
|------|----------|
| `q1-grammar-inventory.md` | Q1: Grammar file inventory |
| `q2-migration-status.md` | Q2: Migration status |
| `q3-syntax-differences.md` | Q3: Syntax differences |
