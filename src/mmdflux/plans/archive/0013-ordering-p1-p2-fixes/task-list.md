# Ordering Algorithm P1 & P2 Fixes Task List

## Status: ✅ COMPLETE

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Unsortable Node Interleaving (P1)

- [x] **1.1** Refactor `reorder_layer()` with sortable/unsortable partitioning and interleaving
  → [tasks/1.1-unsortable-interleaving.md](./tasks/1.1-unsortable-interleaving.md)

- [x] **1.2** Run existing tests, verify no regressions
  *(Run `cargo test --lib dagre::order`)*

- [x] **1.3** Add unit tests for unsortable interleaving
  → [tasks/1.3-unsortable-tests.md](./tasks/1.3-unsortable-tests.md)

## Phase 2: Edge Weight Support (P2)

- [x] **2.1** Add `edge_weights` field and `effective_edges_weighted()` to LayoutGraph
  → [tasks/2.1-edge-weights-field.md](./tasks/2.1-edge-weights-field.md)

- [x] **2.2** Update `reorder_layer()` and callers for weighted edges
  → [tasks/2.2-weighted-barycenter.md](./tasks/2.2-weighted-barycenter.md)

- [x] **2.3** Add unit tests for weighted barycenter
  → [tasks/2.3-weighted-tests.md](./tasks/2.3-weighted-tests.md)

## Phase 3: Verification

- [x] **3.1** Run full test suite and integration tests
  *(Run `cargo test`)*

## Progress Tracking

| Phase                          | Status      | Notes |
| ------------------------------ | ----------- | ----- |
| 1 - Unsortable Interleaving   | ✅ Complete  |       |
| 2 - Edge Weight Support        | ✅ Complete  |       |
| 3 - Verification               | ✅ Complete  |       |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Audit Synthesis | [research/archive/0007-ordering-algorithm/v085-audit/synthesis.md](../../research/archive/0007-ordering-algorithm/v085-audit/synthesis.md) |
| Research: Sort Pipeline | [research/archive/0007-ordering-algorithm/v085-audit/sort-pipeline.md](../../research/archive/0007-ordering-algorithm/v085-audit/sort-pipeline.md) |
| Research: Build Layer Graph | [research/archive/0007-ordering-algorithm/v085-audit/build-layer-graph.md](../../research/archive/0007-ordering-algorithm/v085-audit/build-layer-graph.md) |
