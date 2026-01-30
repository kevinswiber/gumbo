# Nested Subgraph Support Task List

## Status: ✅ COMPLETE

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Builder — Subgraph Parent Tracking

- [x] **1.1** Add `parent` field to `Subgraph` struct
  → [tasks/1.1-subgraph-parent-field.md](./tasks/1.1-subgraph-parent-field.md)

- [x] **1.2** Propagate parent context in `process_statements`
  → [tasks/1.2-propagate-parent-context.md](./tasks/1.2-propagate-parent-context.md)

- [x] **1.3** Make `collect_node_ids` recurse into nested subgraphs
  → [tasks/1.3-recursive-collect-node-ids.md](./tasks/1.3-recursive-collect-node-ids.md)

- [x] **1.4** Add `subgraph_children()` and `subgraph_depth()` helpers to `Diagram`
  → [tasks/1.4-hierarchy-helpers.md](./tasks/1.4-hierarchy-helpers.md)

## Phase 2: Layout Wiring — `set_parent` for Nested Subgraphs

- [x] **2.1** Wire `set_parent(child_sg, parent_sg)` for nested subgraphs
  → [tasks/2.1-wire-set-parent.md](./tasks/2.1-wire-set-parent.md)

- [x] **2.2** Verify dagre handles multi-level nesting
  → [tasks/2.2-verify-dagre-nesting.md](./tasks/2.2-verify-dagre-nesting.md)

## Phase 3: Bounds Computation — Inside-Out Redesign

- [x] **3.1** Implement `build_children_map()` helper
  → [tasks/3.1-build-children-map.md](./tasks/3.1-build-children-map.md)

- [x] **3.2** Implement inside-out bounds computation
  → [tasks/3.2-inside-out-bounds.md](./tasks/3.2-inside-out-bounds.md)

- [x] **3.3** Test bounds containment for nested subgraphs
  → [tasks/3.3-bounds-containment-test.md](./tasks/3.3-bounds-containment-test.md)

## Phase 4: Nested-Aware Overlap Resolution

- [x] **4.1** Add `is_ancestor()` helper
  → [tasks/4.1-is-ancestor-helper.md](./tasks/4.1-is-ancestor-helper.md)

- [x] **4.2** Skip nested pairs in overlap resolution
  → [tasks/4.2-nested-overlap-skip.md](./tasks/4.2-nested-overlap-skip.md)

## Phase 5: Z-Order Border Rendering

- [x] **5.1** Sort subgraphs by nesting depth before rendering
  → [tasks/5.1-zorder-border-rendering.md](./tasks/5.1-zorder-border-rendering.md)

## Phase 6: Integration Tests

- [x] **6.1** Create nested subgraph test fixtures
  → [tasks/6.1-test-fixtures.md](./tasks/6.1-test-fixtures.md)

- [x] **6.2** Add integration tests
  → [tasks/6.2-integration-tests.md](./tasks/6.2-integration-tests.md)

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Builder Parent Tracking | Complete | |
| 2 - Layout Wiring | Complete | |
| 3 - Bounds Computation | Complete | |
| 4 - Overlap Resolution | Complete | Implemented alongside Phase 3 |
| 5 - Z-Order Rendering | Complete | |
| 6 - Integration Tests | Complete | |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Nested Subgraphs | [research/0025-nested-subgraphs/synthesis.md](../../research/0025-nested-subgraphs/synthesis.md) |
