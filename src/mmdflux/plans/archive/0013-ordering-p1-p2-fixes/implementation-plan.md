# Ordering Algorithm P1 & P2 Fixes Implementation Plan

## Status: ✅ COMPLETE

**Completed:** 2026-01-27

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Fix two behavioral gaps in our dagre-style ordering algorithm (`src/dagre/order.rs`) found during the v0.8.5 audit:

- **P1:** Unsortable node interleaving — nodes with no neighbors in the fixed layer should be interleaved at their original positions, not given synthetic barycenters
- **P2:** Edge weight support in barycenter — use weighted barycenters (`sum(weight * order) / sum(weight)`) instead of unweighted averages

## Current State

The `reorder_layer()` function (order.rs lines 162-221) handles all nodes uniformly:
- Nodes with no neighbors get `graph.order[node] as f64` as a synthetic barycenter
- All nodes participate in a single sort by barycenter
- Barycenter is unweighted: `sum(order) / count`

Dagre v0.8.5 handles these differently:
- Nodes without neighbors are "unsortable" — they are interleaved at their original positions via `consumeUnsortable()` in `sort.js`
- Barycenter is weighted: `sum(edge.weight * node.order) / sum(edge.weight)` in `barycenter.js`

Edge storage: `LayoutGraph.edges` is `Vec<(usize, usize, usize)>` (from, to, original_edge_index). No weight field exists. `effective_edges()` returns `Vec<(usize, usize)>`.

## Implementation Approach

### Phase 1: Unsortable Node Interleaving (P1)

Refactor `reorder_layer()` to:
1. Partition nodes into sortable (have neighbors) and unsortable (no neighbors)
2. Sort sortable by barycenter with bias-aware tie-breaking (existing logic)
3. Sort unsortable by descending original index (for stack-style popping)
4. Interleave using dagre's `consumeUnsortable()` pattern: pop unsortable entries whose original index `i <= vsIndex` between each sortable entry

### Phase 2: Edge Weight Support (P2)

1. Add `edge_weights: Vec<f64>` field to `LayoutGraph`, initialized to all 1.0
2. Add `effective_edges_weighted()` method returning `Vec<(usize, usize, f64)>`
3. Update `reorder_layer()` to accept weighted edges and compute weighted barycenters
4. Update callers (`sweep_up`, `sweep_down`, `run`) to use weighted edges

### Phase 3: Testing

- Verify existing 9 unit tests still pass after each phase
- Add targeted tests for unsortable interleaving edge cases
- Add tests for weighted barycenter computation
- Run full integration suite

## Files to Modify/Create

| File | Change |
|------|--------|
| `src/dagre/order.rs` | Refactor `reorder_layer()` for P1 interleaving, update for P2 weighted edges |
| `src/dagre/graph.rs` | Add `edge_weights` field and `effective_edges_weighted()` method |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Refactor `reorder_layer()` with sortable/unsortable partitioning | [tasks/1.1-unsortable-interleaving.md](./tasks/1.1-unsortable-interleaving.md) |
| 1.2 | Run existing tests, verify no regressions | *(Run `cargo test --lib dagre::order`)* |
| 1.3 | Add unit tests for unsortable interleaving | [tasks/1.3-unsortable-tests.md](./tasks/1.3-unsortable-tests.md) |
| 2.1 | Add `edge_weights` field and `effective_edges_weighted()` to LayoutGraph | [tasks/2.1-edge-weights-field.md](./tasks/2.1-edge-weights-field.md) |
| 2.2 | Update `reorder_layer()` and callers for weighted edges | [tasks/2.2-weighted-barycenter.md](./tasks/2.2-weighted-barycenter.md) |
| 2.3 | Add unit tests for weighted barycenter | [tasks/2.3-weighted-tests.md](./tasks/2.3-weighted-tests.md) |
| 3.1 | Run full test suite and integration tests | *(Run `cargo test`)* |

## Research References

- [v0.8.5 Audit Synthesis](../../research/archive/0007-ordering-algorithm/v085-audit/synthesis.md) — prioritized findings
- [Sort Pipeline Audit](../../research/archive/0007-ordering-algorithm/v085-audit/sort-pipeline.md) — dagre's sort.js algorithm details (P1 reference)
- [Build Layer Graph Audit](../../research/archive/0007-ordering-algorithm/v085-audit/build-layer-graph.md) — edge weight analysis (P2 reference)
- [Index Loop Audit](../../research/archive/0007-ordering-algorithm/v085-audit/index-loop.md) — main loop comparison

## Testing Strategy

1. **Regression testing:** All 9 existing `order::tests` must pass after each phase
2. **P1 targeted tests:** Unsortable nodes at edges, in middle, all-unsortable, all-sortable, mixed scenarios
3. **P2 targeted tests:** Uniform weights match unweighted, non-uniform weights produce correct weighted average
4. **Integration:** Full `cargo test` including integration tests to verify no visual regressions
