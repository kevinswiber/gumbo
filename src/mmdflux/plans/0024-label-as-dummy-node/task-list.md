# Label-as-Dummy-Node Task List

## Status: 🚧 IN PROGRESS

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 0: Setup

- [x] **0.1** Create git worktree off main
  → [tasks/0.1-worktree-setup.md](./tasks/0.1-worktree-setup.md)

## Phase 1: Add Per-Edge `minlen` Support

- [x] **1.1** Add `minlen` field to `LayoutGraph` edges
  → [tasks/1.1-minlen-field.md](./tasks/1.1-minlen-field.md)

- [x] **1.2** Update longest-path ranking to respect `minlen`
  → [tasks/1.2-ranking-minlen.md](./tasks/1.2-ranking-minlen.md)

## Phase 2: Make Space for Edge Labels

- [x] **2.1** Implement `make_space_for_edge_labels()`
  → [tasks/2.1-make-space.md](./tasks/2.1-make-space.md)

- [x] **2.2** Wire into layout pipeline
  → [tasks/2.2-pipeline-wiring.md](./tasks/2.2-pipeline-wiring.md)

## Phase 3: Verify Label Dummy Creation

- [x] **3.1** Verify label dummies for formerly-short edges
  → [tasks/3.1-verify-short-edge-dummies.md](./tasks/3.1-verify-short-edge-dummies.md)

- [x] **3.2** Verify label dummies for already-long edges
  → [tasks/3.2-verify-long-edge-dummies.md](./tasks/3.2-verify-long-edge-dummies.md)

## Phase 4: Verify Coordinate Assignment and Denormalization

- [x] **4.1** Verify BK handles label dummy dimensions
  → [tasks/4.1-verify-bk-dimensions.md](./tasks/4.1-verify-bk-dimensions.md)

- [x] **4.2** Verify denormalization extracts label positions
  → [tasks/4.2-verify-denorm-positions.md](./tasks/4.2-verify-denorm-positions.md)

## Phase 5: Fix ASCII Coordinate Transform

- [x] **5.1** Fix ASCII coordinate transform for labels
  → [tasks/5.1-fix-coordinate-transform.md](./tasks/5.1-fix-coordinate-transform.md)

## Phase 6: Update Edge Rendering

- [x] **6.1** Prefer precomputed label positions in rendering
  → [tasks/6.1-precomputed-rendering.md](./tasks/6.1-precomputed-rendering.md)

- [x] **6.2** Handle edge routing with label waypoints
  → [tasks/6.2-routing-label-waypoints.md](./tasks/6.2-routing-label-waypoints.md)

## Phase 7: Integration Testing and Cleanup

- [x] **7.1** Integration tests with existing fixtures
  → [tasks/7.1-fixture-tests.md](./tasks/7.1-fixture-tests.md)

- [x] **7.2** Edge case testing
  → [tasks/7.2-edge-cases.md](./tasks/7.2-edge-cases.md)

- [x] **7.3** Simplify heuristic fallback code
  → [tasks/7.3-simplify-heuristics.md](./tasks/7.3-simplify-heuristics.md)
  *(Deferred — heuristic retained as fallback, margin cleanup left for follow-up)*

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 0 - Setup | Not Started | Git worktree creation |
| 1 - minlen Support | Not Started | Foundation for label spacing |
| 2 - Make Space | Not Started | Core label-as-dummy mechanism |
| 3 - Verify Dummies | Not Started | Confirm normalization works |
| 4 - Verify Layout | Not Started | BK + denormalization |
| 5 - Coordinate Transform | Not Started | ASCII position accuracy |
| 6 - Rendering | Not Started | Wire precomputed positions |
| 7 - Integration & Cleanup | Not Started | End-to-end verification |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Architecture Audit | [synthesis.md](../../research/0017-architecture-algorithm-audit/synthesis.md) |
| Research: Q7 Edge Routing & Labels | [q7-edge-routing-labels.md](../../research/0017-architecture-algorithm-audit/q7-edge-routing-labels.md) |
| Prior Plan: Edge Label Spacing | [implementation-plan.md](../archive/0010-edge-label-spacing/implementation-plan.md) |
