# Q3: LR Edge Label Placement

## Summary

Label detachment in LR layouts occurs because the label placement algorithm uses `mid_y = (routed.start.y + routed.end.y) / 2` (line 107 in `edge.rs`) for all Z-shaped paths, but backward LR edges have waypoints that create complex multi-segment paths where the actual visual path doesn't follow a simple vertical midpoint. Unlike TD/BT layouts which use `select_label_segment()` for segment-aware placement, LR/RL uses a naive midpoint formula that doesn't consult actual segment geometry.

## Where

- `src/render/edge.rs` lines 104-124 — LR label placement logic in `draw_edge_label_with_tracking()`
- `src/render/edge.rs` lines 43-174 — main label drawing function
- `src/render/edge.rs` lines 222-281 — `find_safe_label_position()` collision detection
- `src/render/edge.rs` lines 349-384 — `select_label_segment()` (used by TD/BT but NOT by LR/RL)
- `src/render/router.rs` lines 540-563 — `build_orthogonal_path_for_direction()` H-V-H Z-shape construction
- `src/render/router.rs` lines 169-224 — `route_edge_with_waypoints()` waypoint-based routing
- `src/render/router.rs` lines 569-603 — `build_orthogonal_path_with_waypoints()` multi-segment path building
- `issues/0001-lr-layout-and-backward-edge-issues/issues.md` lines 140-162 — Issues 5 and 6

## What

### LR Label Placement Algorithm

The label placement for LR direction (lines 104-124 of `edge.rs`):

```rust
Direction::LeftRight => {
    let mid_y = (routed.start.y + routed.end.y) / 2;
    let max_label_end = routed.end.x.saturating_sub(1);
    let min_x = routed.start.x.saturating_add(1);
    let available = max_label_end.saturating_sub(routed.start.x);
    let label_x = if available >= label_len {
        let centered = routed.start.x + (available - label_len) / 2;
        let max_x = max_label_end.saturating_sub(label_len);
        centered.max(min_x).min(max_x)
    } else {
        min_x
    };
    (label_x, mid_y)
}
```

Key assumption: `mid_y = (start.y + end.y) / 2` — this assumes the path is a simple line where the midpoint between start/end Y coordinates corresponds to where the edge actually exists on canvas.

### Z-Path Segment Structure for LR

From `build_orthogonal_path_for_direction()` (lines 540-563), LR edges use H-V-H (Z-shaped) paths:
1. Horizontal segment at `y = start.y` (from source)
2. Vertical segment at `x = mid_x` (connecting Y levels)
3. Horizontal segment at `y = end.y` (to target)

### Backward Edge Complexity

For backward LR edges with waypoints (`route_edge_with_waypoints()`, lines 169-224), paths are 6+ segments weaving around the diagram. The waypoint Y-coordinates don't match `(start.y + end.y) / 2`.

Example for backward LR edge (Remote Repo → Working Dir in git_workflow.mmd):
- Source at Y=1, end at Y=3 → `mid_y = 2`
- Actual path goes down to Y=4, left along Y=5, up to Y=3
- Label placed at Y=2 doesn't correspond to any actual edge segment

### TD/BT vs LR/RL Asymmetry

TD/BT layouts use `select_label_segment()` (lines 349-384) to intelligently choose the longest vertical segment for label placement, handling both forward and backward edges correctly. LR/RL does not use this approach — it blindly uses the midpoint formula.

## How

**Algorithm flow for LR label placement:**

1. **Calculate base position** (lines 54-147): Use `mid_y = (start.y + end.y) / 2`, center label X in available horizontal space
2. **Find safe position** (lines 150-151): Call `find_safe_label_position()` which checks for collisions with nodes, edges, and previously placed labels
3. **Write label to canvas** (lines 157-167): Place characters, skip if would overwrite arrow

**Critical issue in collision detection:** For backward LR edges, edge segments are drawn at waypoint Y-coordinates (not at `mid_y`), so the label at `mid_y` doesn't collide with edge cells. The collision detection returns false, and the label is placed in empty space — floating above the actual path.

## Why

**Root cause:** The LR label placement assumes simple two-point path geometry but doesn't account for actual segment positions in waypoint-based routing.

**Specific issues:**

1. **Assumption mismatch**: `mid_y = (start.y + end.y) / 2` is only appropriate for simple direct paths, not complex multi-segment backward edge paths
2. **No segment awareness**: LR placement doesn't consult actual segments (unlike TD/BT which uses `select_label_segment()`)
3. **Backward edge complexity**: Backward LR edges have 6+ segments weaving around the diagram with intermediate waypoint Y-coordinates that vary widely from the midpoint
4. **No fallback**: Collision detection succeeds (label doesn't hit nodes), but this doesn't mean the label is near an actual edge segment

## Key Takeaways

- TD/BT uses segment-aware placement via `select_label_segment()`; LR/RL uses naive midpoint — this asymmetry is the root cause
- Forward LR edges often work because short waypoint paths don't deviate far from midpoint; backward edges route around the entire diagram with large deviations
- The fix should implement segment-aware label placement for LR/RL, choosing the longest horizontal segment (analogous to how TD/BT chooses the longest vertical segment)
- Alternatively, compute label position based on actual path segments instead of start/end midpoint

## Open Questions

- Was the asymmetry between TD/BT and LR/RL label placement an oversight or intentional simplification?
- For LR/RL waypoint paths, should the label be placed on the longest horizontal segment or the middle segment by count?
- Would a "snap to nearest edge cell" approach be more robust than geometric computation?
