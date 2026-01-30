# Label-as-Dummy-Node Regression Fix Implementation Plan

## Status: 🚧 IN PROGRESS

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Fix four rendering regressions introduced by Plan 0024's label-as-dummy-node implementation. The label-dummy approach is architecturally correct but the current implementation uses selective minlen inflation (only labeled edges) instead of the global transformation dagre.js uses. This breaks rank-spacing invariants that all downstream Sugiyama phases depend on.

**Worktree:** All work executes in `~/src/mmdflux-label-dummy` (branch: `label-dummy-experiment`).

## Current State

Plan 0024 implemented label-as-dummy-node with a targeted `minlen=2` strategy for labeled edges only. Research 0018 diagnosed four root causes of the resulting rendering regression:

1. **Selective minlen breaks invariants** — Mixed rank spacing (some gaps of 1, some of 2) breaks the uniform rank grid that normalization, ordering, and positioning depend on
2. **Render layer discards dagre's label positions** — `transform_label_positions_direct()` uses a gap-midpoint heuristic instead of rank-based snapping
3. **Backward edges get inflated dagre waypoints** — Backward edges receive dagre normalization dummies that create tall vertical columns
4. **Arrow z-order bug** — `draw_arrow_with_entry()` overwrites node content unconditionally

## Implementation Approach

### Phase 1: Global minlen transformation

Change `make_space_for_edge_labels()` to double ALL edge minlens (not just labeled ones) when any edge has a label. Halve the effective ranksep in the scale factor computation to keep diagram height approximately unchanged.

**Conditional activation:** Only applies when `edge_labels` is non-empty. Label-free diagrams are completely unaffected.

### Phase 2: Trust dagre's label positions

Rewrite `transform_label_positions_direct()` to use rank-based snapping via `layer_starts[rank]`, matching how `transform_waypoints_direct()` works for waypoints.

### Phase 3: Exclude backward edges from dagre waypoints

Strip dagre-assigned waypoints from backward edges in the render layer, so the router falls through to synthetic compact routing via `generate_backward_waypoints()`.

### Phase 4: Fix arrow z-order bug

Add node-content protection to `draw_arrow_with_entry()`, checking `canvas.get().is_node` before overwriting.

### Phase 5: Integration verification

Full regression sweep across all fixtures. Verify all labels visible, compact layout, correct node text.

## Files to Modify/Create

| File | Changes |
|------|---------|
| `src/dagre/mod.rs` | Global minlen doubling in `make_space_for_edge_labels()` |
| `src/render/layout.rs` | Halve ranksep in scale factors; rewrite label position transform; strip backward edge waypoints |
| `src/render/edge.rs` | Arrow z-order fix in `draw_arrow_with_entry()` |
| `tests/integration.rs` | Integration tests verifying all fixes |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Global minlen doubling | [tasks/1.1-global-minlen.md](./tasks/1.1-global-minlen.md) |
| 1.2 | Halve ranksep in scale factors | [tasks/1.2-halve-ranksep.md](./tasks/1.2-halve-ranksep.md) |
| 1.3 | Integration test: vertical height | [tasks/1.3-height-integration-test.md](./tasks/1.3-height-integration-test.md) |
| 2.1 | Rank-based label position snapping | [tasks/2.1-label-rank-snapping.md](./tasks/2.1-label-rank-snapping.md) |
| 3.1 | Strip backward edge dagre waypoints | [tasks/3.1-strip-backward-waypoints.md](./tasks/3.1-strip-backward-waypoints.md) |
| 3.2 | Verify backward edge routing on cycle fixtures | [tasks/3.2-backward-routing-tests.md](./tasks/3.2-backward-routing-tests.md) |
| 4.1 | Node-content protection in arrow drawing | [tasks/4.1-arrow-zorder.md](./tasks/4.1-arrow-zorder.md) |
| 4.2 | Verify diamond text integrity | [tasks/4.2-diamond-text-test.md](./tasks/4.2-diamond-text-test.md) |
| 5.1 | All-fixtures regression sweep | [tasks/5.1-regression-sweep.md](./tasks/5.1-regression-sweep.md) |
| 5.2 | Update snapshot baselines | *(Covered in 5.1)* |

## Research References

- [Research 0018 Synthesis](../../research/0018-label-dummy-rendering-regression/synthesis.md) — Root cause analysis of all four regressions
- [Q1: dagre.js makeSpaceForEdgeLabels](../../research/0018-label-dummy-rendering-regression/q1-dagre-make-space-analysis.md) — Global minlen + ranksep halving analysis
- [Q2: Pipeline invariant analysis](../../research/0018-label-dummy-rendering-regression/q2-pipeline-invariant-analysis.md) — Why selective minlen breaks downstream phases
- [Q3: Render layer analysis](../../research/0018-label-dummy-rendering-regression/q3-render-layer-analysis.md) — Label position heuristic vs rank-based snapping
- [Q4: Visual defect diagnosis](../../research/0018-label-dummy-rendering-regression/q4-visual-defect-diagnosis.md) — Per-defect root cause mapping
- [Plan 0024](../0024-label-as-dummy-node/implementation-plan.md) — Original label-as-dummy-node implementation (this plan fixes its regressions)

## Key Design Decisions

1. **Conditional activation** — Global minlen doubling only activates when `edge_labels.is_empty()` returns false. Label-free diagrams are completely unaffected.

2. **Ranksep halving in render layer only** — The dagre layout engine keeps `rank_sep=50.0` for positioning. Halving applies only in `compute_ascii_scale_factors()`. Layout spaces ranks normally; the render layer compresses by 2x.

3. **Backward edge waypoint stripping in render layer** — Rather than modifying dagre normalization to skip reversed edges (risky), strip dagre waypoints after the fact. The router's existing `generate_backward_waypoints()` handles compact routing.

4. **Arrow z-order is a simple guard** — `canvas.get()` + `cell.is_node` check, consistent with how label drawing already protects node cells.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Scale factor change affects non-label diagrams | Low — conditional on `edge_labels.is_empty()` | Only activates when labels present |
| Backward edge labels lost when waypoints stripped | Medium — labels placed via routed path, not dagre waypoints | `draw_edge_label_with_tracking` uses routed segments |
| BK algorithm x-jitter with doubled ranks | Low — more dummy nodes means more BK alignment constraints | Existing BK implementation handles this |
| Existing tests break from layout changes | Medium — rank structure changes affect positioning | Phase 5 regression sweep catches these |

## Testing Strategy

All tasks follow TDD (Red/Green/Refactor). Testing is layered:
- **Unit tests**: Each task tests the specific function being changed
- **Integration tests**: Phases 1.3, 3.2, 4.2, 5.1 run full pipeline on fixtures
- **Key fixtures**: `labeled_edges.mmd` (primary regression), `simple_cycle.mmd`, `multiple_cycles.mmd`, `label_spacing.mmd`
