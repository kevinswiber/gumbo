# Finding: Dagre compound layout is non-deterministic

**Type:** discovery
**Task:** 1.1
**Date:** 2026-01-30

## Details
The dagre compound layout produces different results across runs for the same input diagram (`subgraph_edges.mmd`). This is caused by HashMap iteration order in multiple places:

1. `diagram.subgraphs.keys()` — subgraph compound node insertion order
2. `diagram.nodes` iteration — parent relationship setup order
3. Internal dagre HashMap iteration in crossing reduction and positioning

The subgraph_edges.mmd fixture (2 subgraphs, 4 nodes, 2 cross-edges) alternates between producing overlapping and non-overlapping dagre bounds across runs.

## Impact
- End-to-end overlap tests using real diagrams are flaky
- Task 1.1's overlap test was changed from integration-level (real fixture) to unit-level (mock dagre Rects) for determinism
- The dagre bounds transformation itself is correct — when dagre produces non-overlapping Rects, the draw-coordinate bounds are also non-overlapping

## Action Items
- [ ] Investigate sorting node/subgraph insertion order in `compute_layout_direct` for deterministic dagre output
- [ ] Consider using BTreeMap instead of HashMap in Diagram's nodes/subgraphs fields
- [ ] Consider sorting inside dagre's internal algorithms
