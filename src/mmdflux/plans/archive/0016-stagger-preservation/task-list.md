# Dagre Stagger Preservation Task List

## Status: ✅ COMPLETE

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Cross-Axis Coordinate Scaling

- [x] **1.1** Extract dagre cross-axis positions per node
  → [tasks/1.1-extract-dagre-cross-axis.md](./tasks/1.1-extract-dagre-cross-axis.md)

- [x] **1.2** Compute scaled cross-axis draw positions from dagre coordinates
  → [tasks/1.2-compute-scaled-cross-axis.md](./tasks/1.2-compute-scaled-cross-axis.md)

- [x] **1.3** Integrate stagger into `grid_to_draw_vertical()` for TD/BT
  → [tasks/1.3-integrate-vertical.md](./tasks/1.3-integrate-vertical.md)

- [x] **1.4** Integrate stagger into `grid_to_draw_horizontal()` for LR/RL
  → [tasks/1.4-integrate-horizontal.md](./tasks/1.4-integrate-horizontal.md)

## Phase 2: Edge Cases and Waypoint Mapping

- [x] **2.1** Update `map_cross_axis()` anchors to use stagger-aware draw positions
  → [tasks/2.1-update-anchors.md](./tasks/2.1-update-anchors.md)

- [x] **2.2** Handle canvas sizing to accommodate stagger offsets
  → [tasks/2.2-canvas-sizing.md](./tasks/2.2-canvas-sizing.md)

## Phase 3: Testing

- [x] **3.1** Add stagger integration tests
  → [tasks/3.1-stagger-tests.md](./tasks/3.1-stagger-tests.md)

- [x] **3.2** Visual regression testing across all fixtures
  → [tasks/3.2-visual-regression.md](./tasks/3.2-visual-regression.md)

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Cross-Axis Scaling | ✅ Complete | |
| 2 - Edge Cases | ✅ Complete | |
| 3 - Testing | ✅ Complete | |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Stagger Preservation Analysis | [research/archive/0009-attachment-point-spreading/stagger-preservation-analysis.md](../../research/archive/0009-attachment-point-spreading/stagger-preservation-analysis.md) |
| Research: Attachment Point Synthesis | [research/archive/0009-attachment-point-spreading/SYNTHESIS.md](../../research/archive/0009-attachment-point-spreading/SYNTHESIS.md) |
| Related: Plan 0015 (Port Spreading) | [plans/0015-attachment-point-spreading/](../0015-attachment-point-spreading/) |
