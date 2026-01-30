# Dagre-Style Ordering Algorithm Task List

## Status: ✅ COMPLETE

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Add Bias Parameter

- [x] **1.1** Add `bias_right: bool` parameter to `reorder_layer()`, `sweep_down()`, `sweep_up()`
  → [tasks/1.1-add-bias-parameter.md](./tasks/1.1-add-bias-parameter.md)

- [x] **1.2** Add unit test verifying bias changes tie-breaking direction
  → [tasks/1.2-test-bias-parameter.md](./tasks/1.2-test-bias-parameter.md)

## Phase 2: DFS Initial Ordering

- [x] **2.1** Add `init_order()` function with iterative DFS
  → [tasks/2.1-dfs-initial-ordering.md](./tasks/2.1-dfs-initial-ordering.md)

- [x] **2.2** Add `layers_sorted_by_order()` helper
  → [tasks/2.2-layers-sorted-helper.md](./tasks/2.2-layers-sorted-helper.md)

- [x] **2.3** Add unit tests for DFS initial ordering
  → [tasks/2.3-test-dfs-init.md](./tasks/2.3-test-dfs-init.md)

## Phase 3: Dagre-Style Adaptive Loop

- [x] **3.1** Rewrite `run()` with Dagre-style adaptive loop
  → [tasks/3.1-adaptive-loop.md](./tasks/3.1-adaptive-loop.md)

- [x] **3.2** Add unit tests for the adaptive loop
  → [tasks/3.2-test-adaptive-loop.md](./tasks/3.2-test-adaptive-loop.md)

- [x] **3.3** Run full test suite and fix any regressions
  → [tasks/3.3-integration-validation.md](./tasks/3.3-integration-validation.md)

## Progress Tracking

| Phase               | Status      | Notes |
| ------------------- | ----------- | ----- |
| 1 - Bias Parameter  | ✅ Complete  |       |
| 2 - DFS Init Order  | ✅ Complete  |       |
| 3 - Adaptive Loop   | ✅ Complete  |       |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Initial Analysis | [research/archive/0007-ordering-algorithm/00-initial-analysis.md](../../research/archive/0007-ordering-algorithm/00-initial-analysis.md) |
| Research: Dagre Analysis | [research/archive/0007-ordering-algorithm/01-dagre-ordering-analysis.md](../../research/archive/0007-ordering-algorithm/01-dagre-ordering-analysis.md) |
| Research: mmdflux Analysis | [research/archive/0007-ordering-algorithm/02-mmdflux-ordering-analysis.md](../../research/archive/0007-ordering-algorithm/02-mmdflux-ordering-analysis.md) |
| Research: Synthesis | [research/archive/0007-ordering-algorithm/04-synthesis.md](../../research/archive/0007-ordering-algorithm/04-synthesis.md) |
| Dagre Reference | `/Users/kevin/src/dagre/lib/order/index.js` |
