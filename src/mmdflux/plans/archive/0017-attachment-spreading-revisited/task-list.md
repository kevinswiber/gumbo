# Attachment Point Spreading (Revisited) Task List

## Status: ✅ COMPLETE

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Face Classification and Spreading Infrastructure

- [x] **1.1** Add `NodeFace` enum and `classify_face()` to `intersect.rs`
  → [tasks/1.1-node-face-classification.md](./tasks/1.1-node-face-classification.md)

- [x] **1.2** Add face extent helpers to `NodeBounds`
  → [tasks/1.2-face-extent-helpers.md](./tasks/1.2-face-extent-helpers.md)

- [x] **1.3** Add `spread_points_on_face()` utility
  → [tasks/1.3-spread-points.md](./tasks/1.3-spread-points.md)

## Phase 2: Attachment Plan Computation

- [x] **2.1** Implement `compute_attachment_plan()` pre-pass
  → [tasks/2.1-attachment-plan.md](./tasks/2.1-attachment-plan.md)

- [x] **2.2** Sort edges within face groups by cross-axis position
  → [tasks/2.2-edge-sorting.md](./tasks/2.2-edge-sorting.md)

## Phase 3: Router Integration

- [x] **3.1** Modify `route_edge()` to accept attachment overrides
  → [tasks/3.1-route-edge-overrides.md](./tasks/3.1-route-edge-overrides.md)

- [x] **3.2** Wire `route_all_edges()` to compute and use the attachment plan
  → [tasks/3.2-wire-route-all.md](./tasks/3.2-wire-route-all.md)

## Phase 4: Testing and Validation

- [x] **4.1** Test zero-gap overlap fixtures (`double_skip`, `stacked_fan_in`, `narrow_fan_in`)
  → [tasks/4.1-test-zero-gap.md](./tasks/4.1-test-zero-gap.md)

- [x] **4.2** Test near-overlap fixtures (`skip_edge_collision`, `fan_in`, `five_fan_in`)
  → [tasks/4.2-test-near-overlap.md](./tasks/4.2-test-near-overlap.md)

- [x] **4.3** Test departure-side overlap (`fan_out`)
  → [tasks/4.3-test-departure.md](./tasks/4.3-test-departure.md)

- [x] **4.4** Regression tests for non-overlapping fixtures
  → [tasks/4.4-regression-tests.md](./tasks/4.4-regression-tests.md)

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Face Classification Infrastructure | Complete | |
| 2 - Attachment Plan Computation | Complete | |
| 3 - Router Integration | Complete | |
| 4 - Testing and Validation | Complete | |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Attachment Spreading Revisited | [research/0010](../../research/0010-attachment-spreading-revisited/synthesis.md) |
| Research: Original (0009, archived) | [research/archive/0009](../../research/archive/0009-attachment-point-spreading/) |
| Superseded: Plan 0015 | [plans/0015](../0015-attachment-point-spreading/) |
