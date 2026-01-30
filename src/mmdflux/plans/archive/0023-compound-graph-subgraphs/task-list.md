# Compound Graph (Subgraph) Support Task List

## Status: ✅ COMPLETE

**Completed:** 2026-01-29

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase A: Parser + Graph

- [x] **1.1** Add Subgraph AST type
  -> [tasks/1.1-subgraph-ast-type.md](./tasks/1.1-subgraph-ast-type.md)

- [x] **1.2** Add subgraph grammar rules
  -> [tasks/1.2-subgraph-grammar-rules.md](./tasks/1.2-subgraph-grammar-rules.md)

- [x] **1.3** Add subgraph parsing logic
  -> [tasks/1.3-subgraph-parsing-logic.md](./tasks/1.3-subgraph-parsing-logic.md)

- [x] **1.4** Add Subgraph struct and parent field to graph layer
  -> [tasks/1.4-graph-layer-subgraph.md](./tasks/1.4-graph-layer-subgraph.md)

- [x] **1.5** Update build_diagram to process subgraphs
  -> [tasks/1.5-builder-subgraphs.md](./tasks/1.5-builder-subgraphs.md)

- [x] **1.6** Add test fixtures for subgraphs
  -> [tasks/1.6-test-fixtures.md](./tasks/1.6-test-fixtures.md)

## Phase B: Layout Core

- [x] **2.1** Extend LayoutGraph and DiGraph with compound fields
  -> [tasks/2.1-compound-graph-fields.md](./tasks/2.1-compound-graph-fields.md)

- [x] **2.2** Wire subgraph info from Diagram to DiGraph
  -> [tasks/2.2-diagram-to-digraph.md](./tasks/2.2-diagram-to-digraph.md)

- [x] **2.3** Implement nesting graph module
  -> [tasks/2.3-nesting-graph.md](./tasks/2.3-nesting-graph.md)

- [x] **2.4** Implement assign_rank_minmax
  -> [tasks/2.4-rank-minmax.md](./tasks/2.4-rank-minmax.md)

- [x] **2.5** Implement border segment module
  -> [tasks/2.5-border-segments.md](./tasks/2.5-border-segments.md)

## Phase C: Layout Refinement

- [x] **3.1** Compound-aware ordering constraints
  -> [tasks/3.1-compound-ordering.md](./tasks/3.1-compound-ordering.md)

- [x] **3.2** BK borderType guard in Pass 2
  -> [tasks/3.2-bk-border-guard.md](./tasks/3.2-bk-border-guard.md)

- [x] **3.3** Integrate compound phases into layout pipeline
  -> [tasks/3.3-pipeline-integration.md](./tasks/3.3-pipeline-integration.md)

## Phase D: Rendering

- [x] **4.1** Add is_subgraph_border flag to Canvas Cell
  -> [tasks/4.1-canvas-cell-flag.md](./tasks/4.1-canvas-cell-flag.md)

- [x] **4.2** Add SubgraphBounds to render Layout struct
  -> [tasks/4.2-subgraph-bounds.md](./tasks/4.2-subgraph-bounds.md)

- [x] **4.3** Implement render_subgraph_borders
  -> [tasks/4.3-render-borders.md](./tasks/4.3-render-borders.md)

- [x] **4.4** Wire subgraph rendering into render pipeline
  -> [tasks/4.4-render-pipeline.md](./tasks/4.4-render-pipeline.md)

## Phase E: Integration and Polish

- [x] **5.1** Update integration tests with subgraph fixtures
  -> [tasks/5.1-integration-tests.md](./tasks/5.1-integration-tests.md)

- [x] **5.2** Update README with subgraph example
  *(Inline: add subgraph input/output example to README)*

## Progress Tracking

| Phase                    | Status      | Notes |
| ------------------------ | ----------- | ----- |
| A - Parser + Graph       | Complete    |       |
| B - Layout Core          | Complete    |       |
| C - Layout Refinement    | Complete    |       |
| D - Rendering            | Complete    |       |
| E - Integration & Polish | Complete    |       |

## Quick Links

| Resource             | Path                                                                     |
| -------------------- | ------------------------------------------------------------------------ |
| Implementation Plan  | [implementation-plan.md](./implementation-plan.md)                       |
| Research: Synthesis  | [synthesis.md](../../research/0016-compound-graph-subgraphs/synthesis.md) |
| Research: Q2 Pipeline | [q2-dagre-compound-pipeline.md](../../research/0016-compound-graph-subgraphs/q2-dagre-compound-pipeline.md) |
| Research: Q5 Layout  | [q5-dagre-pipeline-changes.md](../../research/0016-compound-graph-subgraphs/q5-dagre-pipeline-changes.md) |
