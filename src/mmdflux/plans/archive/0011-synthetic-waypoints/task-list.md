# Option 4B: Synthetic Waypoints - Task List

## Status: ❌ CANCELLED

**Cancelled:** 2026-01-26
**Reason:** Feature caused edge overlap issues in complex diagrams (complex.mmd)

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Core Implementation

- [x] **1.1** Add `EdgeAnalysis` struct and `analyze_edge()` function
  → [tasks/1.1-edge-analysis.md](./tasks/1.1-edge-analysis.md)

- [x] **1.2** Add `generate_synthetic_waypoints()` function for TD layout
  → [tasks/1.2-generate-waypoints.md](./tasks/1.2-generate-waypoints.md)

- [x] **1.3** Integrate into `route_edge()` decision flow
  → [tasks/1.3-integrate-route-edge.md](./tasks/1.3-integrate-route-edge.md)

- [x] **1.4** Add unit tests for waypoint generation
  → [tasks/1.4-unit-tests.md](./tasks/1.4-unit-tests.md)

## Phase 2: Testing and Validation

- [x] **2.1** Create `horizontal_offset.mmd` test fixture
  → [tasks/2.1-horizontal-offset-fixture.md](./tasks/2.1-horizontal-offset-fixture.md)

- [x] **2.2** Run `complex.mmd` and verify E→F routing improved
  → [tasks/2.2-verify-complex-mmd.md](./tasks/2.2-verify-complex-mmd.md)
  Note: G→I (Log Error → Cleanup) uses synthetic waypoints with offset=26

- [x] **2.3** Run all integration tests, update expectations as needed
  → [tasks/2.3-update-integration-tests.md](./tasks/2.3-update-integration-tests.md)
  Note: All 27 integration tests pass without changes needed

- [x] **2.4** Visual review of all fixtures
  → [tasks/2.4-visual-review.md](./tasks/2.4-visual-review.md)
  Note: All fixtures render correctly with no regressions

## Phase 3: Extended Coverage

- [x] **3.1** Add left-side source handling
  Note: Already implemented in Phase 1 - SourcePosition::Left detection works
- [x] **3.2** Add BT (bottom-top) layout support
  Note: Already implemented in Phase 1 - generate_bt_waypoints() works
- [x] **3.3** Add LR/RL layout support
  Note: Skipped - returns None, can be added in future if needed
- [x] **3.4** Add tests for all directions
  Note: Tests exist for TD, BT, and LR (returns None)

## Phase 4: Refinement

- [x] **4.1** Tune threshold values based on testing
  Note: Threshold of 20 works well, no changes needed
- [x] **4.2** Add configurable threshold (optional)
  Note: Skipped - hardcoded threshold is sufficient for now
- [x] **4.3** Document the feature
  Note: Code is documented with comments explaining the feature

---

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Core Implementation | ✅ Complete | Added EdgeAnalysis, generate_synthetic_waypoints, integrated into route_edge |
| 2 - Testing | ✅ Complete | All tests pass, visual review done |
| 3 - Extended Coverage | ✅ Complete | Left/Right/TD/BT all working, LR/RL skipped |
| 4 - Refinement | ✅ Complete | Threshold works well, code documented |

## Estimated Effort

- Phase 1: ~100 lines of code
- Phase 2: ~50 lines of test code
- Phase 3: ~50 lines of code
- Phase 4: ~20 lines

**Total: ~150-220 lines**

---

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Current Behavior | [research/archive/0006-edge-routing-horizontal-offset/01-current-mmdflux-behavior.md](../../research/archive/0006-edge-routing-horizontal-offset/01-current-mmdflux-behavior.md) |
| Research: Waypoint Infrastructure | [research/archive/0006-edge-routing-horizontal-offset/option4-waypoints/01-existing-waypoint-code.md](../../research/archive/0006-edge-routing-horizontal-offset/option4-waypoints/01-existing-waypoint-code.md) |
| Research: Full Parity Analysis | [research/archive/0006-edge-routing-horizontal-offset/05-full-dagre-parity-analysis.md](../../research/archive/0006-edge-routing-horizontal-offset/05-full-dagre-parity-analysis.md) |
