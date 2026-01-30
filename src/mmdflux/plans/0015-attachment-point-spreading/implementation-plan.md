# Attachment Point Spreading Implementation Plan

## Status: 🚧 IN PROGRESS

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Fix shared/overlapping attachment points on nodes where multiple edges connect to the same face of a node. Two specific issues:

1. **Forward + backward edges share attachment points (TD/BT):** In `multiple_cycles.mmd` and `complex.mmd`, forward and backward edges both attach to the center of the same node face, causing one edge to overwrite the other on the canvas.

2. **Multiple forward edges from diamond share attachment points (LR):** In `ci_pipeline.mmd`, two outgoing edges from the "Deploy?" diamond both exit from the same right-boundary point.

## Current State

The rendering pipeline is: `compute_layout_dagre()` → `route_all_edges()` → `render_all_edges_with_labels()`.

- `calculate_attachment_points()` in `intersect.rs` computes a single point per edge by casting a ray from the node center toward the first waypoint (or target center). When multiple edges approach from the same direction, the ray produces the same intersection point.
- `route_all_edges()` processes each edge independently — no edge has knowledge of other edges sharing the same node face.
- Plan 0008 (port-based attachment) was designed for this but never implemented. This plan supersedes it with a simpler approach using the current intersect/routing architecture.

## Implementation Approach

### Pre-Pass Attachment Point Allocation

Add a **pre-pass** that runs inside `route_all_edges()` before individual edge routing. This pre-pass:

1. Classifies which face of each node each edge uses (top, bottom, left, right)
2. Groups edges by (node, face)
3. For groups with >1 edge, spreads attachment points evenly across the face
4. Passes pre-computed attachment points into each edge's routing call

This avoids per-edge routing needing global state — the pre-pass computes everything, then routing consumes it.

### Phase 1: Face Classification Infrastructure

Add a `NodeFace` enum and a `classify_face()` function to `intersect.rs`. This determines which face of a node an edge attaches to, given the approach direction (first waypoint or other node center).

### Phase 2: Attachment Plan Computation

Add `compute_attachment_plan()` to `router.rs` that:
- For each edge, determines source face and target face using `classify_face()`
- Builds a map of `(node_id, face) → Vec<edge_indices>`
- For groups with >1 edge, computes spread positions along the face
- Sorts edges within a face group by cross-axis position of the other endpoint to minimize crossings
- Returns a map of `edge_index → (source_attach_point, target_attach_point)`

### Phase 3: Router Integration

Modify `route_edge()` and its variants to accept optional pre-computed attachment points, bypassing `calculate_attachment_points()` when provided. Wire `route_all_edges()` to compute the plan first, then pass overrides into each edge.

### Phase 4: Testing and Edge Cases

Verify with `multiple_cycles.mmd`, `complex.mmd`, and `ci_pipeline.mmd`. Handle edge cases: small nodes with many edges, diamond shapes, single-edge faces (center, no change).

## Files to Modify/Create

| File | Changes |
|------|---------|
| `src/render/intersect.rs` | Add `NodeFace` enum, `classify_face()`, `spread_points_on_face()` |
| `src/render/router.rs` | Add `compute_attachment_plan()`, modify `route_edge()` to accept overrides, update `route_all_edges()` |
| `src/render/shape.rs` | Add face extent helper methods to `NodeBounds` |
| `tests/integration.rs` | Add regression tests for overlapping attachment fixtures |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Add `NodeFace` enum and `classify_face()` | [tasks/1.1-node-face-classification.md](./tasks/1.1-node-face-classification.md) |
| 1.2 | Add face extent helpers to `NodeBounds` | [tasks/1.2-face-extent-helpers.md](./tasks/1.2-face-extent-helpers.md) |
| 1.3 | Add `spread_points_on_face()` utility | [tasks/1.3-spread-points.md](./tasks/1.3-spread-points.md) |
| 2.1 | Implement `compute_attachment_plan()` | [tasks/2.1-attachment-plan.md](./tasks/2.1-attachment-plan.md) |
| 2.2 | Sort edges within face groups | [tasks/2.2-edge-sorting.md](./tasks/2.2-edge-sorting.md) |
| 3.1 | Modify `route_edge()` to accept attachment overrides | [tasks/3.1-route-edge-overrides.md](./tasks/3.1-route-edge-overrides.md) |
| 3.2 | Wire `route_all_edges()` to use attachment plan | [tasks/3.2-wire-route-all.md](./tasks/3.2-wire-route-all.md) |
| 4.1 | Test with `multiple_cycles.mmd` and `complex.mmd` | [tasks/4.1-test-td-overlap.md](./tasks/4.1-test-td-overlap.md) |
| 4.2 | Test with `ci_pipeline.mmd` (LR diamond) | [tasks/4.2-test-lr-diamond.md](./tasks/4.2-test-lr-diamond.md) |
| 4.3 | Regression tests for single-edge nodes | [tasks/4.3-regression-tests.md](./tasks/4.3-regression-tests.md) |

## Research References

- [backward-edge-overlap/SYNTHESIS.md](../../research/archive/0004-backward-edge-overlap/SYNTHESIS.md) — Analysis of overlap root causes and solution options
- [backward-edge-overlap/solution-proposals.md](../../research/archive/0004-backward-edge-overlap/solution-proposals.md) — Detailed solution proposals including port-based attachment
- [edge-routing-deep-dive/](../../research/archive/0003-edge-routing-deep-dive/) — Edge routing architecture analysis

## Related Plans

- **Plan 0008 (port-based-attachment):** Designed for forward-forward collisions only, never implemented. This plan supersedes it with a unified approach covering both forward-backward and forward-forward overlap.
- **Plan 0014 (waypoint-backward-edges):** Recently completed. The waypoint system provides the approach direction data that `classify_face()` needs.

## Testing Strategy

1. **Unit tests** for `classify_face()`: Verify correct face for points in each quadrant around rect and diamond nodes
2. **Unit tests** for `spread_points_on_face()`: Verify N=1 returns center, N=2 returns 1/3 and 2/3 positions, etc.
3. **Integration tests**: Render `multiple_cycles.mmd`, `complex.mmd`, `ci_pipeline.mmd` and verify no two edges share the same attachment cell on any node
4. **Regression**: Ensure single-edge-per-face nodes produce identical output to current behavior
