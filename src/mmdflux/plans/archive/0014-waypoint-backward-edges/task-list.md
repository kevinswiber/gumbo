# Waypoint-Based Backward Edge Routing — Task List

## Status: ✅ COMPLETE

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Fix Waypoint Cross-Axis Coordinate Transformation

- [x] **1.1** Build per-rank dagre-to-draw coordinate mapping
  → [tasks/1.1-rank-coordinate-mapping.md](./tasks/1.1-rank-coordinate-mapping.md)

- [x] **1.2** Replace linear interpolation with anchor-based mapping
  → [tasks/1.2-replace-interpolation.md](./tasks/1.2-replace-interpolation.md)

## Phase 2: Route Backward Edges Through Waypoints

- [x] **2.1** Unify routing dispatch in `route_edge()` — check waypoints before backward detection
  → [tasks/2.1-unify-routing-dispatch.md](./tasks/2.1-unify-routing-dispatch.md)

- [x] **2.2** Remove corridor routing functions from `router.rs`
  → [tasks/2.2-remove-corridor-routing.md](./tasks/2.2-remove-corridor-routing.md)

## Phase 3: Remove Corridor Infrastructure

- [x] **3.1** Remove corridor fields from `Layout`, canvas expansion, and `assign_backward_edge_lanes()`
  → [tasks/3.1-remove-corridor-infrastructure.md](./tasks/3.1-remove-corridor-infrastructure.md)

## Phase 4: Clean Up Edge Label Placement

- [x] **4.1** Remove corridor-specific backward edge label logic from `edge.rs`
  → [tasks/4.1-clean-label-placement.md](./tasks/4.1-clean-label-placement.md)

## Phase 5: Edge Case Handling

- [x] **5.1** Add waypoint-node collision detection and nudging
  → [tasks/5.1-collision-detection.md](./tasks/5.1-collision-detection.md)

## Phase 6: Test Updates

- [x] **6.1** Update existing backward edge tests for waypoint-based routing
  → [tasks/6.1-update-existing-tests.md](./tasks/6.1-update-existing-tests.md)

- [x] **6.2** Add new backward edge waypoint test cases
  → [tasks/6.2-add-new-tests.md](./tasks/6.2-add-new-tests.md)

- [x] **6.3** Run full test suite and verify cycle-containing fixtures
  → [tasks/6.3-verify-fixtures.md](./tasks/6.3-verify-fixtures.md)

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Coordinate Transform | ✅ Complete | |
| 2 - Waypoint Routing | ✅ Complete | |
| 3 - Remove Corridors | ✅ Complete | |
| 4 - Label Cleanup | ✅ Complete | |
| 5 - Edge Cases | ✅ Complete | |
| 6 - Tests | ✅ Complete | |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Synthesis | [research/archive/0008-waypoint-backward-edges/06-synthesis.md](../../research/archive/0008-waypoint-backward-edges/06-synthesis.md) |
| Research: Corridor System | [research/archive/0008-waypoint-backward-edges/03-corridor-routing-system.md](../../research/archive/0008-waypoint-backward-edges/03-corridor-routing-system.md) |
| Research: Dagre Edge Points | [research/archive/0008-waypoint-backward-edges/04-dagre-edge-points.md](../../research/archive/0008-waypoint-backward-edges/04-dagre-edge-points.md) |
| Research: ASCII Feasibility | [research/archive/0008-waypoint-backward-edges/05-ascii-routing-feasibility.md](../../research/archive/0008-waypoint-backward-edges/05-ascii-routing-feasibility.md) |
