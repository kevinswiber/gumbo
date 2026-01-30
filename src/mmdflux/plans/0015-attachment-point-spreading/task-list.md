# Attachment Point Spreading Task List

## Status: 🚧 IN PROGRESS

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Face Classification Infrastructure

- [ ] **1.1** Add `NodeFace` enum and `classify_face()` function to `intersect.rs`
  → [tasks/1.1-node-face-classification.md](./tasks/1.1-node-face-classification.md)

- [ ] **1.2** Add face extent helpers to `NodeBounds`
  → [tasks/1.2-face-extent-helpers.md](./tasks/1.2-face-extent-helpers.md)

- [ ] **1.3** Add `spread_points_on_face()` utility
  → [tasks/1.3-spread-points.md](./tasks/1.3-spread-points.md)

## Phase 2: Attachment Plan Computation

- [ ] **2.1** Implement `compute_attachment_plan()` pre-pass
  → [tasks/2.1-attachment-plan.md](./tasks/2.1-attachment-plan.md)

- [ ] **2.2** Sort edges within face groups by cross-axis position
  → [tasks/2.2-edge-sorting.md](./tasks/2.2-edge-sorting.md)

## Phase 3: Router Integration

- [ ] **3.1** Modify `route_edge()` to accept pre-computed attachment overrides
  → [tasks/3.1-route-edge-overrides.md](./tasks/3.1-route-edge-overrides.md)

- [ ] **3.2** Wire `route_all_edges()` to compute and use the attachment plan
  → [tasks/3.2-wire-route-all.md](./tasks/3.2-wire-route-all.md)

## Phase 4: Testing

- [ ] **4.1** Test TD/BT overlap: `multiple_cycles.mmd` and `complex.mmd`
  → [tasks/4.1-test-td-overlap.md](./tasks/4.1-test-td-overlap.md)

- [ ] **4.2** Test LR diamond: `ci_pipeline.mmd`
  → [tasks/4.2-test-lr-diamond.md](./tasks/4.2-test-lr-diamond.md)

- [ ] **4.3** Regression tests for single-edge nodes
  → [tasks/4.3-regression-tests.md](./tasks/4.3-regression-tests.md)

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Face Classification Infrastructure | Not Started | |
| 2 - Attachment Plan Computation | Not Started | |
| 3 - Router Integration | Not Started | |
| 4 - Testing | Not Started | |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Backward Edge Overlap | [research/archive/0004-backward-edge-overlap/SYNTHESIS.md](../../research/archive/0004-backward-edge-overlap/SYNTHESIS.md) |
| Related: Plan 0008 (Port-Based) | [plans/0008-port-based-attachment/](../0008-port-based-attachment/) |
| Related: Plan 0014 (Waypoint Edges) | [plans/0014-waypoint-backward-edges/](../0014-waypoint-backward-edges/) |
