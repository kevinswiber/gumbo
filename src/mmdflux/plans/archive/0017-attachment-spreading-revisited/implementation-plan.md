# Attachment Point Spreading (Revisited) Implementation Plan

## Status: ✅ COMPLETE

**Completed:** 2026-01-28

**Commits:**
- `0d66d6c` - feat(plan-0017): Phase 1 - Face classification and spreading infrastructure
- `7b7e7f0` - feat(plan-0017): Phase 2 - Attachment plan computation
- `9b85567` - feat(plan-0017): Phase 3 - Router integration

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Fix forward-forward same-face attachment point overlap in TD-direction diagrams. Six fixtures exhibit arrival-side overlap and one exhibits departure-side overlap. The root cause is `intersect_rect()` quantizing different approach angles to the same boundary cell on narrow nodes (5–8 chars wide). The fix is a pre-pass in `route_all_edges()` that groups edges by (node, face), spreads attachment points evenly across the face for multi-edge groups, and passes pre-computed points into routing to bypass `intersect_rect()`.

This plan supersedes plan 0015, which had the correct architecture but targeted the wrong fixtures (backward-edge overlap cases that were subsequently fixed by stagger preservation in plan 0016).

## Current State

The rendering pipeline is: `compute_layout_dagre()` → `route_all_edges()` → `render_all_edges_with_labels()`.

- `calculate_attachment_points()` in `intersect.rs` computes a single point per edge by casting a ray from the node center toward the first waypoint (or target center). When multiple edges approach from the same direction on a narrow node, the ray produces the same intersection point.
- `route_all_edges()` processes each edge independently — no edge has knowledge of other edges sharing the same node face.
- Dagre produces distinct waypoint coordinates for different long edges, but ASCII coordinate compression and discrete boundary-cell rounding collapse them to the same attachment point.

## Scope

**In scope (forward-forward same-face only):**
- Arrival-side overlap: `double_skip.mmd`, `stacked_fan_in.mmd`, `narrow_fan_in.mmd`, `skip_edge_collision.mmd`, `fan_in.mmd`, `five_fan_in.mmd`
- Departure-side overlap: `fan_out.mmd`

**Out of scope:**
- Backward-edge overlap (fixed by stagger preservation, plan 0016)
- LR-direction fan-in rendering defects (`fan_in_lr.mmd` — separate bug)
- Mixed forward/backward grouping (not needed; no mixed overlap exists)

## Key Design Decisions

1. **Diamond shapes do NOT need special geometry.** Diamonds are rendered as rectangles with `< >` on the middle row (`src/render/shape.rs`). Top/bottom faces are flat horizontal edges, identical to rectangles. `spread_points_on_face()` uses the same rectangular face extent for all shapes.

2. **`edge_waypoints` is keyed by `(String, String)`, not edge index.** The actual key is `(edge.from.clone(), edge.to.clone())`. Plan 0015 incorrectly assumed index-based access.

3. **No `&Diagram` parameter needed in `route_all_edges()`.** `Layout` already contains `node_shapes` and `node_bounds`, which is sufficient for the attachment plan computation.

4. **Spread formula uses N+1 divisions.** For N edges on a face of extent `[start, end]`, positions are `start + (i+1) * range / (N+1)`. This avoids placing edges at face corners and provides visual margin. For N=1, the center position is used (unchanged from current behavior).

## Implementation Approach

### Phase 1: Face Classification and Spreading Infrastructure

Add `NodeFace` enum, `classify_face()`, `spread_points_on_face()` to `intersect.rs`, and face extent helpers to `NodeBounds` in `shape.rs`.

### Phase 2: Attachment Plan Computation

Add `compute_attachment_plan()` and `sort_face_group()` to `router.rs`. The pre-pass classifies faces, groups edges by (node, face), sorts by cross-axis position, and computes spread positions.

### Phase 3: Router Integration

Modify `route_edge()` to accept optional attachment overrides. Wire `route_all_edges()` to compute the plan first and pass overrides into each edge's routing call.

### Phase 4: Testing and Validation

Integration tests verifying no overlap for all 7 target fixtures, plus regression tests for non-overlapping fixtures.

## Files to Modify/Create

| File | Changes |
|------|---------|
| `src/render/intersect.rs` | Add `NodeFace` enum, `classify_face()`, `spread_points_on_face()` |
| `src/render/shape.rs` | Add `face_extent()` and `face_fixed_coord()` to `NodeBounds` |
| `src/render/router.rs` | Add `AttachmentOverride`, `compute_attachment_plan()`, `sort_face_group()`; modify `route_edge()` and `route_all_edges()` |
| `tests/integration.rs` | Add overlap-absence tests for 7 target fixtures + regression tests |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Add `NodeFace` enum and `classify_face()` | [tasks/1.1-node-face-classification.md](./tasks/1.1-node-face-classification.md) |
| 1.2 | Add face extent helpers to `NodeBounds` | [tasks/1.2-face-extent-helpers.md](./tasks/1.2-face-extent-helpers.md) |
| 1.3 | Add `spread_points_on_face()` utility | [tasks/1.3-spread-points.md](./tasks/1.3-spread-points.md) |
| 2.1 | Implement `compute_attachment_plan()` | [tasks/2.1-attachment-plan.md](./tasks/2.1-attachment-plan.md) |
| 2.2 | Sort edges within face groups | [tasks/2.2-edge-sorting.md](./tasks/2.2-edge-sorting.md) |
| 3.1 | Modify `route_edge()` to accept overrides | [tasks/3.1-route-edge-overrides.md](./tasks/3.1-route-edge-overrides.md) |
| 3.2 | Wire `route_all_edges()` to use attachment plan | [tasks/3.2-wire-route-all.md](./tasks/3.2-wire-route-all.md) |
| 4.1 | Test zero-gap overlap fixtures | [tasks/4.1-test-zero-gap.md](./tasks/4.1-test-zero-gap.md) |
| 4.2 | Test near-overlap fixtures | [tasks/4.2-test-near-overlap.md](./tasks/4.2-test-near-overlap.md) |
| 4.3 | Test departure-side overlap | [tasks/4.3-test-departure.md](./tasks/4.3-test-departure.md) |
| 4.4 | Regression tests | [tasks/4.4-regression-tests.md](./tasks/4.4-regression-tests.md) |

## Research References

- [synthesis.md](../../research/0010-attachment-spreading-revisited/synthesis.md) — Problem inventory and approach evaluation
- [q1-current-overlap-inventory.md](../../research/0010-attachment-spreading-revisited/q1-current-overlap-inventory.md) — Detailed overlap catalog with rendered output
- [q4-fix-approach-evaluation.md](../../research/0010-attachment-spreading-revisited/q4-fix-approach-evaluation.md) — Evaluation of four approaches, recommending this architecture
- [Prior research (0009)](../../research/archive/0009-attachment-point-spreading/) — Original attachment point investigation

## Related Plans

- **Plan 0015 (attachment-point-spreading):** Original plan with correct architecture but wrong fixtures. This plan supersedes it.
- **Plan 0016 (stagger-preservation):** Fixed backward-edge overlap, narrowing this plan's scope to forward-forward only.

## Potential Challenges

1. **Narrow nodes with many edges:** `narrow_fan_in.mmd` has 3 edges into a 5-wide node (3 usable columns). The spread formula gives the best possible distribution but results may still look tight.

2. **Edge label repositioning:** Shifting attachment points changes x-coordinates of vertical segments in Z-shaped paths. The existing label placement heuristic already handles Z-path labels by finding the last vertical segment, so this should adapt automatically.

3. **Test sensitivity:** Integration tests should verify absence of overlap (negative assertions) rather than exact character positions.

## Testing Strategy

1. **Unit tests** for `classify_face()`: Points in each quadrant classify to the correct face
2. **Unit tests** for `spread_points_on_face()`: N=1 returns center, N=2 returns 1/3 and 2/3 positions
3. **Integration tests**: Render all 7 target fixtures and verify no adjacent arrows on any row
4. **Regression tests**: Verify non-overlapping fixtures continue to render correctly
