# Q4: What Causes the Stray Segment Between "Staging Area" and "Local Repo"?

## Summary

The stray segment `─┴─────┘` on row 5 between "Staging Area" and "Local Repo" is drawn by the **Staging -> Local** edge ("git commit"). The edge has a label dummy waypoint at `(45, 2)` which falls exactly on the right boundary cell of the "Staging Area" node. The `nudge_colliding_waypoints()` function detects this collision and pushes the waypoint's y-coordinate down to y=5 (just below the node). This causes the edge to route through a detour: right face of Staging at y=2, down to y=5, across horizontally, back up to y=2, then on to Local Repo -- producing a visible U-shaped artifact on row 5.

## Where

- `/Users/kevin/src/mmdflux-label-dummy/src/render/layout.rs` -- `nudge_colliding_waypoints()` (lines 736-762), `transform_waypoints_direct()` (lines 796-831), `compute_layout_direct()` (Phase H and Phase I.5)
- `/Users/kevin/src/mmdflux-label-dummy/src/render/router.rs` -- `route_edge_with_waypoints()` (lines 305-358), `build_orthogonal_path_with_waypoints()` (lines 786-818)
- `/Users/kevin/src/mmdflux-label-dummy/src/dagre/normalize.rs` -- label dummy node creation and denormalization

## What

### The edge producing the stray segment

The **Staging -> Local** edge (label: "git commit") creates the artifact. It has a single label dummy waypoint that becomes the routing problem.

### Node bounds (after collision repair)

| Node | x | y | width | height | right_edge |
|------|---|---|-------|--------|------------|
| Staging | 30 | 1 | 16 | 3 | 45 |
| Local | 60 | 1 | 14 | 3 | 73 |

### Waypoint transformation

The label dummy for the Staging->Local edge is at dagre rank 3, which maps to `layer_starts[3] = 45` in the LR layout. For horizontal layouts, waypoint x-coordinate is set to the layer_start value: x=45. The cross-axis (y) is scaled from dagre coordinates to y=2.

So the waypoint after transformation is **(45, 2)**.

### The collision

The "Staging Area" node spans x=30..45, y=1..3 (inclusive). The waypoint at (45, 2) falls on the rightmost column of the Staging node's bounding box. The `nudge_colliding_waypoints()` function detects `bounds.contains(45, 2) == true` for the Staging node.

For horizontal layouts (`is_vertical=false`), nudging pushes the y-coordinate to `bounds.y + bounds.height + 1 = 1 + 3 + 1 = 5`.

The waypoint becomes **(45, 5)**.

### The resulting route

With waypoint at (45, 5), `route_edge_with_waypoints()` produces 6 segments for Staging->Local:

```
seg[0]: Horizontal { y: 2, x_start: 45, x_end: 46 }   -- connector from node boundary
seg[1]: Vertical   { x: 46, y_start: 2, y_end: 5 }     -- DOWN to waypoint row
seg[2]: Horizontal { y: 5, x_start: 46, x_end: 45 }    -- LEFT to waypoint x
seg[3]: Horizontal { y: 5, x_start: 45, x_end: 52 }    -- RIGHT past waypoint toward target
seg[4]: Vertical   { x: 52, y_start: 5, y_end: 2 }     -- UP back to target row
seg[5]: Horizontal { y: 2, x_start: 52, x_end: 59 }    -- RIGHT to target attachment
```

Segments 1-4 form the visible `─┴─────┘` artifact on row 5. The edge detours down two rows, goes across horizontally, then comes back up -- all because the label dummy waypoint was nudged below the Staging node.

## How

The mechanism is a chain of three steps:

1. **Label dummy placement**: The normalization phase places a label dummy node at the midpoint rank between Staging and Local. In the LR layout with doubled ranks, this becomes dagre rank 3.

2. **Waypoint transformation**: `transform_waypoints_direct()` maps rank 3 to `layer_starts[3] = 45` for the x-coordinate. This value coincides exactly with the Staging node's right boundary (x=30 + width=16 - 1 = 45). The y-coordinate scales to y=2, which is within the Staging node's vertical span (y=1..3).

3. **Nudge collision resolution**: `nudge_colliding_waypoints()` finds the waypoint (45, 2) inside the Staging node and pushes y to 5 (below the node). The router then faithfully routes through this displaced waypoint, creating the U-shaped detour.

## Why

The root cause is that the label dummy's rank maps to a layer_start coordinate that falls on the source node's boundary in LR layouts. This happens because:

- **Layer starts are derived from node draw positions**: `layer_starts_raw` uses the minimum primary-axis coordinate of nodes in each layer. For the Staging node at x=30 with width 16, the right edge is x=45.
- **Odd-rank interpolation puts labels between layers**: With ranks doubled, rank 3 interpolates to `(layer_starts_raw[1] + layer_starts_raw[2]) / 2 = (30 + 60) / 2 = 45`. This value equals the Staging node's right boundary exactly.
- **Nudging is a blunt fix**: The nudge function pushes waypoints fully below (or right of) the colliding node, creating a large detour rather than a minimal adjustment.

The fundamental problem is that the label dummy waypoint's primary-axis coordinate (x in LR) is computed from rank interpolation, which can land exactly on a node boundary when layer gaps are tight. The nudge function then makes things worse by pushing the waypoint far away along the cross-axis.

## Key Takeaways

- The stray segment is produced by the **Staging -> Local** edge, not by any other edge or rendering artifact.
- The immediate cause is `nudge_colliding_waypoints()` pushing a label dummy waypoint from y=2 to y=5, creating a visible U-shaped routing detour on row 5.
- The deeper cause is that rank-to-coordinate mapping via `layer_starts` interpolation can produce waypoint coordinates that fall exactly on node boundaries, triggering collision nudging.
- The `contains()` check uses inclusive boundaries, so a waypoint at the exact right edge of a node (x = node.x + node.width - 1) is considered inside the node.
- The nudge strategy (push to `bounds.y + bounds.height + 1`) creates large detours for LR layouts when the collision is only at the boundary edge.

## Open Questions

- Should waypoints at the exact boundary cell (edge pixel) be considered "inside" the node? Using exclusive right/bottom boundaries (`x < bounds.x + bounds.width` rather than `x <= bounds.x + bounds.width - 1`) might avoid this specific collision.
- Should the nudge function try a smaller displacement first (e.g., push to `bounds.x + bounds.width` rather than `+ 1`) to minimize visual impact?
- Could the label dummy waypoint be filtered out entirely for short forward edges in LR layout, where the label is placed by the precomputed label position system and the waypoint serves no routing purpose?
- Would adding a +1 offset to the odd-rank layer_starts interpolation prevent the exact boundary coincidence?
