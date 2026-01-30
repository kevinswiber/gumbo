# Direct Coordinate Translation Task List

## Status: 🚧 IN PROGRESS

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Baseline Capture

- [x] **1.1** Capture baseline snapshot outputs for all fixtures
  → [tasks/1.1-baseline-snapshots.md](./tasks/1.1-baseline-snapshots.md)

## Phase 2: Scale Factor Computation (TDD)

- [x] **2.1** RED — Write failing tests for `compute_ascii_scale_factors`
- [x] **2.2** GREEN — Implement minimum code to pass tests
- [x] **2.3** REFACTOR — Clean up and commit
  → [tasks/2.1-scale-factors.md](./tasks/2.1-scale-factors.md)

## Phase 3: Collision Repair (TDD)

- [x] **3.1** RED — Write failing tests for `collision_repair`
- [x] **3.2** GREEN — Implement minimum code to pass tests
- [x] **3.3** REFACTOR — Clean up and commit
  → [tasks/3.1-collision-repair.md](./tasks/3.1-collision-repair.md)

## Phase 4: Waypoint Transformation (TDD)

- [x] **4.1** RED — Write failing tests for `transform_waypoints_direct`
- [x] **4.2** GREEN — Implement minimum code to pass tests
- [x] **4.3** REFACTOR — Clean up and commit
  → [tasks/4.1-waypoint-transform.md](./tasks/4.1-waypoint-transform.md)

## Phase 5: Label Transformation (TDD)

- [x] **5.1** RED — Write failing tests for label position scaling
- [x] **5.2** GREEN — Implement minimum code to pass tests
- [x] **5.3** REFACTOR — Clean up and commit
  → [tasks/5.1-label-transform.md](./tasks/5.1-label-transform.md)

## Phase 6: Assembly (TDD)

- [x] **6.1** RED — Write failing integration test for `compute_layout_direct`
- [x] **6.2** GREEN — Assemble function using Phase 2–5 components
- [x] **6.3** REFACTOR — Extract shared dagre setup, clean up, commit
  → [tasks/6.1-assemble-direct.md](./tasks/6.1-assemble-direct.md)

## Phase 7: Backward-Edge Overlap (TDD)

- [x] **7.1** RED — Write failing test asserting backward-edge stagger is preserved
- [x] **7.2** GREEN — Fix if needed (expect this to pass already)
- [x] **7.3** REFACTOR — Commit
  → [tasks/7.1-backward-edge-overlap.md](./tasks/7.1-backward-edge-overlap.md)

## Phase 8: Visual Regression

- [x] **8.1** Run all fixtures through both pipelines, categorize differences
  → [tasks/8.1-visual-regression.md](./tasks/8.1-visual-regression.md)

- [x] **8.2** Fix regressions found (TDD: write test for each regression, then fix)
  *(No regressions found — all differences are expected compact scaling)*
  → [tasks/8.2-fix-regressions.md](./tasks/8.2-fix-regressions.md)

## Phase 9: Switch & Cleanup

- [x] **9.1** Switch default to direct translation, remove old stagger pipeline
  *(Default switched; old pipeline retained for test compatibility — removal deferred)*
  → [tasks/9.1-switch-and-remove.md](./tasks/9.1-switch-and-remove.md)

- [ ] **9.2** Clean up Layout struct (remove unused fields)
  *(Deferred — grid_positions unused downstream but harmless)*
  → [tasks/9.2-cleanup-layout.md](./tasks/9.2-cleanup-layout.md)

## Progress Tracking

| Phase                              | Status      | Notes |
|------------------------------------|-------------|-------|
| 1 - Baseline Capture               | ✅ Complete  |       |
| 2 - Scale Factors (TDD)            | ✅ Complete  |       |
| 3 - Collision Repair (TDD)         | ✅ Complete  |       |
| 4 - Waypoint Transform (TDD)       | ✅ Complete  |       |
| 5 - Label Transform (TDD)          | ✅ Complete  |       |
| 6 - Assembly (TDD)                 | ✅ Complete  |       |
| 7 - Backward-Edge Overlap (TDD)    | ✅ Complete  |       |
| 8 - Visual Regression              | ✅ Complete  | No regressions found |
| 9 - Switch & Cleanup               | 🚧 In Progress | Default switched; cleanup deferred |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Pipeline Comparison | [synthesis.md](../../research/0012-edge-sep-pipeline-comparison/synthesis.md) |
| Research: Direct Translation Design | [q5-direct-translation-design.md](../../research/0012-edge-sep-pipeline-comparison/q5-direct-translation-design.md) |
| Research: Stagger vs Direct | [q3-mmdflux-stagger-vs-direct.md](../../research/0012-edge-sep-pipeline-comparison/q3-mmdflux-stagger-vs-direct.md) |
| Research: Stagger Formula Proof | [q4-stagger-edge-sep-awareness.md](../../research/0012-edge-sep-pipeline-comparison/q4-stagger-edge-sep-awareness.md) |
