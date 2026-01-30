# Compound Graph (Subgraph) Support Implementation Plan

## Status: ✅ COMPLETE

**Completed:** 2026-01-29

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Add single-level subgraph support to mmdflux, following the dagre.js compound pipeline. This enables Mermaid `subgraph ... end` syntax to parse, lay out, and render as bordered groups in text output. Nested subgraphs are deferred to a follow-up.

## Current State

mmdflux has a four-stage pipeline (Parser -> Graph -> Layout -> Render) with no compound graph support. The parser handles only vertex statements and edges. The dagre layout engine implements the Sugiyama framework (acyclic, rank, normalize, order, position) for flat graphs only.

## Implementation Approach

Follow dagre.js's proven compound pipeline exactly, implementing incrementally across 5 phases:

- **Phase A:** Parser + Graph -- subgraph parsing and Diagram representation
- **Phase B:** Layout Core -- nesting graph, rank constraints, border segments
- **Phase C:** Layout Refinement -- compound-aware ordering, BK borderType guard
- **Phase D:** Rendering -- subgraph border rendering with z-ordering
- **Phase E:** Integration and polish

All compound logic is gated on `has_compound_nodes()` for zero overhead on simple graphs.

**Branch:** Create `feat/compound-graph-subgraphs` off `main` before starting implementation.

## Files to Modify/Create

### New Files
- `src/dagre/nesting.rs` -- nesting graph setup and cleanup
- `src/dagre/border.rs` -- border segment creation and removal
- `tests/fixtures/simple_subgraph.mmd`
- `tests/fixtures/subgraph_edges.mmd`
- `tests/fixtures/multi_subgraph.mmd`

### Modified Files
- `src/parser/grammar.pest` -- add subgraph grammar rules
- `src/parser/ast.rs` -- add SubgraphSpec struct and Statement::Subgraph variant
- `src/parser/flowchart.rs` -- add parse_subgraph() logic
- `src/graph/node.rs` -- add parent: Option<String> to Node
- `src/graph/diagram.rs` -- add Subgraph struct and subgraphs field
- `src/graph/builder.rs` -- process subgraph statements
- `src/dagre/graph.rs` -- extend DiGraph and LayoutGraph with compound fields
- `src/dagre/mod.rs` -- wire compound phases into pipeline
- `src/dagre/order.rs` -- compound-aware ordering constraints
- `src/dagre/bk.rs` -- borderType guard in Pass 2
- `src/dagre/types.rs` -- add subgraph_bounds to LayoutResult
- `src/render/layout.rs` -- pass subgraph bounds to render Layout
- `src/render/canvas.rs` -- add is_subgraph_border cell flag
- `src/render/mod.rs` -- insert subgraph border render pass
- `src/render/shape.rs` or new `src/render/subgraph.rs` -- border drawing

## Task Details

| Task | Description | Details |
| ---- | ----------- | ------- |
| 1.1  | Add Subgraph AST type | [tasks/1.1-subgraph-ast-type.md](./tasks/1.1-subgraph-ast-type.md) |
| 1.2  | Add subgraph grammar rules | [tasks/1.2-subgraph-grammar-rules.md](./tasks/1.2-subgraph-grammar-rules.md) |
| 1.3  | Add subgraph parsing logic | [tasks/1.3-subgraph-parsing-logic.md](./tasks/1.3-subgraph-parsing-logic.md) |
| 1.4  | Add Subgraph struct and parent field to graph layer | [tasks/1.4-graph-layer-subgraph.md](./tasks/1.4-graph-layer-subgraph.md) |
| 1.5  | Update build_diagram to process subgraphs | [tasks/1.5-builder-subgraphs.md](./tasks/1.5-builder-subgraphs.md) |
| 1.6  | Add test fixtures for subgraphs | [tasks/1.6-test-fixtures.md](./tasks/1.6-test-fixtures.md) |
| 2.1  | Extend LayoutGraph and DiGraph with compound fields | [tasks/2.1-compound-graph-fields.md](./tasks/2.1-compound-graph-fields.md) |
| 2.2  | Wire subgraph info from Diagram to DiGraph | [tasks/2.2-diagram-to-digraph.md](./tasks/2.2-diagram-to-digraph.md) |
| 2.3  | Implement nesting graph module | [tasks/2.3-nesting-graph.md](./tasks/2.3-nesting-graph.md) |
| 2.4  | Implement assign_rank_minmax | [tasks/2.4-rank-minmax.md](./tasks/2.4-rank-minmax.md) |
| 2.5  | Implement border segment module | [tasks/2.5-border-segments.md](./tasks/2.5-border-segments.md) |
| 3.1  | Compound-aware ordering constraints | [tasks/3.1-compound-ordering.md](./tasks/3.1-compound-ordering.md) |
| 3.2  | BK borderType guard in Pass 2 | [tasks/3.2-bk-border-guard.md](./tasks/3.2-bk-border-guard.md) |
| 3.3  | Integrate compound phases into layout pipeline | [tasks/3.3-pipeline-integration.md](./tasks/3.3-pipeline-integration.md) |
| 4.1  | Add is_subgraph_border flag to Canvas Cell | [tasks/4.1-canvas-cell-flag.md](./tasks/4.1-canvas-cell-flag.md) |
| 4.2  | Add SubgraphBounds to render Layout struct | [tasks/4.2-subgraph-bounds.md](./tasks/4.2-subgraph-bounds.md) |
| 4.3  | Implement render_subgraph_borders | [tasks/4.3-render-borders.md](./tasks/4.3-render-borders.md) |
| 4.4  | Wire subgraph rendering into render pipeline | [tasks/4.4-render-pipeline.md](./tasks/4.4-render-pipeline.md) |
| 5.1  | Update integration tests with subgraph fixtures | [tasks/5.1-integration-tests.md](./tasks/5.1-integration-tests.md) |
| 5.2  | Update README with subgraph example | *(Inline: add subgraph input/output example to README)* |

## Research References

- [Synthesis](../../research/0016-compound-graph-subgraphs/synthesis.md) -- overall compound graph research synthesis
- [Q1: Mermaid subgraph syntax](../../research/0016-compound-graph-subgraphs/q1-mermaid-subgraph-syntax.md)
- [Q2: dagre.js compound pipeline](../../research/0016-compound-graph-subgraphs/q2-dagre-compound-pipeline.md)
- [Q3: Parser extension design](../../research/0016-compound-graph-subgraphs/q3-parser-extension-design.md)
- [Q4: Graph layer design](../../research/0016-compound-graph-subgraphs/q4-graph-layer-design.md)
- [Q5: Dagre pipeline changes](../../research/0016-compound-graph-subgraphs/q5-dagre-pipeline-changes.md)
- [Q6: Rendering pipeline changes](../../research/0016-compound-graph-subgraphs/q6-rendering-pipeline-changes.md)

## Testing Strategy

All tasks follow TDD Red/Green/Refactor. Key test levels:

1. **Unit tests:** Each new struct, function, and module has focused unit tests
2. **Integration tests:** Fixture-based tests verify parse -> build -> layout -> render pipeline
3. **Regression:** Existing test suite must pass unchanged (compound logic is gated)
4. **Fixtures:** `simple_subgraph.mmd`, `subgraph_edges.mmd`, `multi_subgraph.mmd`

## Key Design Decisions

1. **Single-level subgraphs only** -- nested subgraphs deferred to follow-up
2. **Zero overhead for simple graphs** -- all compound logic gated on `has_compound_nodes()`
3. **dagre.js pipeline order** -- nesting -> rank -> cleanup -> minmax -> normalize -> borders -> order -> position -> remove borders
4. **Z-order via render sequence** -- subgraph borders render BEFORE nodes
5. **Recursive AST, flat graph** -- parser produces tree; builder flattens to Diagram with parent refs
6. **Title above top-left corner** -- matches Mermaid convention
