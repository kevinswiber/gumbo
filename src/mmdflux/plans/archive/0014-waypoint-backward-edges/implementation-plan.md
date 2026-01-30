# Waypoint-Based Backward Edge Routing

## Status: ✅ COMPLETE

**Completed:** 2026-01-27

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Replace the corridor-based backward edge routing system (which adds extra canvas space on the right/bottom perimeter) with dagre waypoint-based routing (which routes backward edges through the layout area using dummy node positions from dagre's crossing-minimization). This unifies forward and backward edge routing through the same infrastructure and produces output that matches Mermaid's edge layout more closely.

## Current State

### Corridor System (what we're replacing)
- Backward edges exit from the RIGHT side (TD/BT) or BOTTOM (LR/RL) of source nodes
- Travel through dedicated corridor zones appended to the canvas perimeter
- Each backward edge gets its own lane (`corridor_width=3` chars each)
- Adds 3-6+ characters of canvas width/height
- Three hardcoded segments: H-V-H (TD) or V-H-V (LR)
- Arrow always enters from Right (TD) or Bottom (LR)

### Waypoint System (forward edges only, currently)
- Forward long edges use `edge_waypoints` from dagre's denormalization
- `route_edge_with_waypoints()` routes through waypoints using `calculate_attachment_points()` for intersection-based entry/exit
- Waypoint positions come from dagre's dummy node placement (crossing-minimization optimized)

### Critical Gap: Cross-Axis Coordinate Transformation
The waypoint coordinate transform in `compute_layout_dagre()` (layout.rs:440-468) currently uses **linear interpolation** for the cross-axis (x for TD/BT). This ignores dagre's actual dummy node x-position, which is fine for forward edges (interpolation is a reasonable approximation) but wrong for backward edges where dagre places dummies to the **side** of other nodes. Phase 1 fixes this.

## Implementation Approach

### Phase 1: Fix Waypoint Cross-Axis Coordinate Transformation
Use dagre's actual dummy node cross-axis position instead of linear interpolation. Build a per-rank mapping from dagre coordinate space to draw coordinate space using real node positions as anchors.

### Phase 2: Route Backward Edges Through Waypoints
Modify `route_edge()` to check for waypoints before checking for backward edges. Reverse the waypoint list for backward edges (dagre stores them in effective/forward order). Remove corridor-based routing functions.

### Phase 3: Remove Corridor Infrastructure
Remove `backward_corridors`, `corridor_width`, `backward_edge_lanes` from `Layout` struct. Remove canvas expansion. Remove `assign_backward_edge_lanes()`.

### Phase 4: Clean Up Edge Label Placement
Remove corridor-aware backward edge label logic from `edge.rs`. Backward edges now have the same segment structure as forward edges.

### Phase 5: Edge Case Handling
Add collision detection for waypoints that overlap nodes. Handle short backward edges (no waypoints).

### Phase 6: Update Tests
Fix broken test assertions, add new test cases for backward edge waypoint routing.

## Files to Modify

| File | Changes |
|------|---------|
| `src/render/layout.rs` | Phase 1: Fix waypoint coordinate transform. Phase 3: Remove corridor fields, canvas expansion, lane assignment |
| `src/render/router.rs` | Phase 2: Unify routing dispatch, add waypoint reversal, remove corridor routing functions |
| `src/render/edge.rs` | Phase 4: Remove corridor-specific backward edge label logic |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Build per-rank dagre-to-draw coordinate mapping | [tasks/1.1-rank-coordinate-mapping.md](./tasks/1.1-rank-coordinate-mapping.md) |
| 1.2 | Replace linear interpolation with anchor-based mapping | [tasks/1.2-replace-interpolation.md](./tasks/1.2-replace-interpolation.md) |
| 2.1 | Unify routing dispatch in route_edge() | [tasks/2.1-unify-routing-dispatch.md](./tasks/2.1-unify-routing-dispatch.md) |
| 2.2 | Remove corridor routing functions | [tasks/2.2-remove-corridor-routing.md](./tasks/2.2-remove-corridor-routing.md) |
| 3.1 | Remove corridor fields and canvas expansion | [tasks/3.1-remove-corridor-infrastructure.md](./tasks/3.1-remove-corridor-infrastructure.md) |
| 4.1 | Clean up backward edge label placement | [tasks/4.1-clean-label-placement.md](./tasks/4.1-clean-label-placement.md) |
| 5.1 | Add waypoint-node collision detection | [tasks/5.1-collision-detection.md](./tasks/5.1-collision-detection.md) |
| 6.1 | Update existing backward edge tests | [tasks/6.1-update-existing-tests.md](./tasks/6.1-update-existing-tests.md) |
| 6.2 | Add new backward edge waypoint tests | [tasks/6.2-add-new-tests.md](./tasks/6.2-add-new-tests.md) |
| 6.3 | Run full test suite and verify fixtures | [tasks/6.3-verify-fixtures.md](./tasks/6.3-verify-fixtures.md) |

## Research References

- [01-mermaid-edge-rendering.md](../../research/archive/0008-waypoint-backward-edges/01-mermaid-edge-rendering.md) -- How dagre produces edge waypoints from dummy nodes
- [02-mmdflux-normalize-waypoints.md](../../research/archive/0008-waypoint-backward-edges/02-mmdflux-normalize-waypoints.md) -- What waypoint data our normalize already produces
- [03-corridor-routing-system.md](../../research/archive/0008-waypoint-backward-edges/03-corridor-routing-system.md) -- Current corridor system architecture
- [04-dagre-edge-points.md](../../research/archive/0008-waypoint-backward-edges/04-dagre-edge-points.md) -- Dagre's edge point computation pipeline
- [05-ascii-routing-feasibility.md](../../research/archive/0008-waypoint-backward-edges/05-ascii-routing-feasibility.md) -- ASCII routing feasibility analysis
- [06-synthesis.md](../../research/archive/0008-waypoint-backward-edges/06-synthesis.md) -- Synthesized findings and approach
- [07-backward-edge-clustering.md](../../research/archive/0007-ordering-algorithm/07-backward-edge-clustering.md) -- Why Mermaid produces two-cluster layouts

## Testing Strategy

1. **Unit tests**: Update existing corridor-based backward edge tests to verify waypoint-based routing. Add new tests for backward edge waypoint reversal, short backward edges, entry direction.
2. **Integration tests**: Existing `all_fixtures_render` and cycle-containing fixture tests must continue passing.
3. **Manual verification**: Run `cargo run -- tests/fixtures/simple_cycle.mmd`, `multiple_cycles.mmd`, and `complex.mmd` before and after. Backward edges should route through the layout area instead of through corridors.
4. **Direction coverage**: Test backward edges in all 4 directions (TD, BT, LR, RL).

## Commit Strategy

| Commit | Phases | Description |
|--------|--------|-------------|
| A | 1 | Fix waypoint cross-axis coordinate transformation |
| B | 2 + 3 + 4 | Switch to waypoint routing, remove corridors, clean labels |
| C | 5 + 6 | Edge case handling and test updates |
