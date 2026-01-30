# Label-as-Dummy-Node Regression Fix Task List

## Status: 🚧 IN PROGRESS

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Global minlen transformation

- [x] **1.1** Global minlen doubling in `make_space_for_edge_labels()`
  → [tasks/1.1-global-minlen.md](./tasks/1.1-global-minlen.md)

- [x] **1.2** Halve ranksep in scale factor computation
  → [tasks/1.2-halve-ranksep.md](./tasks/1.2-halve-ranksep.md)

- [x] **1.3** Integration test: labeled_edges vertical height is reasonable
  → [tasks/1.3-height-integration-test.md](./tasks/1.3-height-integration-test.md)

## Phase 2: Trust dagre's label positions

- [x] **2.1** Rewrite label position transform to use rank-based snapping
  → [tasks/2.1-label-rank-snapping.md](./tasks/2.1-label-rank-snapping.md)

## Phase 3: Exclude backward edges from dagre waypoints

- [x] **3.1** Strip dagre waypoints for backward edges
  → [tasks/3.1-strip-backward-waypoints.md](./tasks/3.1-strip-backward-waypoints.md)

- [x] **3.2** Verify backward edge routing on cycle fixtures
  → [tasks/3.2-backward-routing-tests.md](./tasks/3.2-backward-routing-tests.md)

## Phase 4: Fix arrow z-order bug

- [x] **4.1** Add node-content protection to `draw_arrow_with_entry()`
  → [tasks/4.1-arrow-zorder.md](./tasks/4.1-arrow-zorder.md)

- [x] **4.2** Verify diamond text integrity
  → [tasks/4.2-diamond-text-test.md](./tasks/4.2-diamond-text-test.md)

## Phase 5: Integration verification

- [x] **5.1** All-fixtures regression sweep and snapshot update
  → [tasks/5.1-regression-sweep.md](./tasks/5.1-regression-sweep.md)

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Global minlen transformation | Complete | f283ef3 |
| 2 - Trust dagre's label positions | Complete | a22f04e |
| 3 - Exclude backward edge waypoints | Complete | 77a5055 |
| 4 - Fix arrow z-order bug | Complete | 1297586 |
| 5 - Integration verification | Complete | eeace30 |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: 0018 Synthesis | [synthesis.md](../../research/0018-label-dummy-rendering-regression/synthesis.md) |
| Plan 0024 (original impl) | [plan-0024](../0024-label-as-dummy-node/implementation-plan.md) |
