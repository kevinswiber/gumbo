# Direct Dagre-to-ASCII Coordinate Translation

## Status: 🚧 IN PROGRESS

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Replace the 6-step stagger pipeline (`compute_stagger_positions` + `compute_grid_positions` + `grid_to_draw_vertical/horizontal` + `map_cross_axis` + `rank_cross_anchors`) with a 3-step direct translation pipeline:

1. Compute per-axis ASCII scale factors
2. Apply uniform scaling + rounding to all dagre coordinates
3. Enforce minimum spacing via collision repair

This eliminates the provably-wrong `dagre_range / nodesep` formula (25–70% error for dummy-heavy layers) and natively preserves `edge_sep` effects because uniform scaling maintains the ratio between `edge_sep` and `node_sep` gaps.

## TDD Methodology

Every implementation task follows strict Red-Green-Refactor:

1. **Red:** Write a failing test that defines expected behavior. Add a minimal function stub (signature + `unimplemented!()`) so the test compiles. Run `cargo test` to confirm the test fails at the assertion (not at compilation).
2. **Green:** Write the minimum code to make the test pass. No more. Run `cargo test` to confirm it passes.
3. **Refactor:** Clean up while keeping tests green. Commit after refactoring.

In Rust, "Red" requires a compilable stub because non-existent function references are compile errors, not test failures. The stub returns a dummy value or panics — either way the test fails for the right reason (wrong output or panic, not missing symbol).

## Current State

The current pipeline in `src/render/layout.rs` transforms dagre's float coordinates to ASCII draw coordinates through a 6-step process. The stagger formula divides by `nodesep` regardless of whether a layer contains dummy nodes (which use `edge_sep`), causing 25–70% error for dummy-heavy layers. Both dagre.js and Mermaid use dagre's output coordinates directly.

## Scale Factor Formulas

| Axis | TD/BT | LR/RL |
|------|-------|-------|
| **Primary** (rank direction) | `(max_h + v_spacing) / (max_h + rank_sep)` | `(max_w + h_spacing) / (max_w + rank_sep)` |
| **Cross** (within-rank) | `(avg_w + h_spacing) / (avg_w + node_sep)` | `(avg_h + v_spacing) / (avg_h + node_sep)` |

## Files to Modify/Create

| File | Action | Description |
|------|--------|-------------|
| `src/render/layout.rs` | Modify | Add `compute_ascii_scale_factors()`, `collision_repair()`, `transform_waypoints_direct()`, `compute_layout_direct()`; later remove old stagger pipeline |
| `src/render/mod.rs` | Modify | Switch from `compute_layout_dagre` to new direct path |
| `tests/integration.rs` | Modify | Add snapshot tests, comparison tests, regression tests |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Capture baseline snapshots | [tasks/1.1-baseline-snapshots.md](./tasks/1.1-baseline-snapshots.md) |
| 2.1 | Scale factors — RED | [tasks/2.1-scale-factors.md](./tasks/2.1-scale-factors.md) |
| 2.2 | Scale factors — GREEN | *(Covered in 2.1)* |
| 2.3 | Scale factors — REFACTOR + commit | *(Covered in 2.1)* |
| 3.1 | Collision repair — RED | [tasks/3.1-collision-repair.md](./tasks/3.1-collision-repair.md) |
| 3.2 | Collision repair — GREEN | *(Covered in 3.1)* |
| 3.3 | Collision repair — REFACTOR + commit | *(Covered in 3.1)* |
| 4.1 | Waypoint transform — RED | [tasks/4.1-waypoint-transform.md](./tasks/4.1-waypoint-transform.md) |
| 4.2 | Waypoint transform — GREEN | *(Covered in 4.1)* |
| 4.3 | Waypoint transform — REFACTOR + commit | *(Covered in 4.1)* |
| 5.1 | Label transform — RED | [tasks/5.1-label-transform.md](./tasks/5.1-label-transform.md) |
| 5.2 | Label transform — GREEN | *(Covered in 5.1)* |
| 5.3 | Label transform — REFACTOR + commit | *(Covered in 5.1)* |
| 6.1 | Assemble compute_layout_direct — RED | [tasks/6.1-assemble-direct.md](./tasks/6.1-assemble-direct.md) |
| 6.2 | Assemble compute_layout_direct — GREEN | *(Covered in 6.1)* |
| 6.3 | Assemble compute_layout_direct — REFACTOR + commit | *(Covered in 6.1)* |
| 7.1 | Backward-edge overlap — RED | [tasks/7.1-backward-edge-overlap.md](./tasks/7.1-backward-edge-overlap.md) |
| 7.2 | Backward-edge overlap — GREEN | *(Covered in 7.1)* |
| 7.3 | Backward-edge overlap — REFACTOR + commit | *(Covered in 7.1)* |
| 8.1 | Visual regression — all fixtures | [tasks/8.1-visual-regression.md](./tasks/8.1-visual-regression.md) |
| 8.2 | Fix regressions | [tasks/8.2-fix-regressions.md](./tasks/8.2-fix-regressions.md) |
| 9.1 | Switch default + remove old code | [tasks/9.1-switch-and-remove.md](./tasks/9.1-switch-and-remove.md) |
| 9.2 | Clean up Layout struct | [tasks/9.2-cleanup-layout.md](./tasks/9.2-cleanup-layout.md) |

## Research References

- [synthesis.md](../../research/0012-edge-sep-pipeline-comparison/synthesis.md) — full analysis and recommendations
- [q5-direct-translation-design.md](../../research/0012-edge-sep-pipeline-comparison/q5-direct-translation-design.md) — design sketch with scale factor derivation
- [q3-mmdflux-stagger-vs-direct.md](../../research/0012-edge-sep-pipeline-comparison/q3-mmdflux-stagger-vs-direct.md) — current pipeline documentation
- [q4-stagger-edge-sep-awareness.md](../../research/0012-edge-sep-pipeline-comparison/q4-stagger-edge-sep-awareness.md) — mathematical proof the formula is wrong
- [stagger-preservation-analysis.md](../../research/archive/0009-attachment-point-spreading/stagger-preservation-analysis.md) — backward-edge overlap context
- [synthesis.md (0010)](../../research/archive/0010-attachment-spreading-revisited/synthesis.md) — attachment spreading analysis

## Testing Strategy

Each implementation unit is test-driven:
- Unit tests for pure functions (scale factors, collision repair, waypoint transform, label transform)
- Integration test for the assembled `compute_layout_direct()` against simple diagrams
- Property-based assertions (backward-edge stagger preserved, no node overlaps)
- Visual regression comparing all 26 fixtures between old and new pipelines
