# Q1: Render-Only Title Space Approach

## Summary
A pure render-only approach of adding title_extra padding to subgraph bounds is **not sufficient** to prevent title-edge collisions. Waypoints come from dagre's layout algorithm and don't respect modifications to subgraph bounds. While waypoints could theoretically be adjusted in the render layer, this would require complex collision detection and nudging logic that doesn't exist and would be fragile.

## Where
- **`src/render/layout.rs`**: `convert_subgraph_bounds()` (lines 789-908), `compute_layout_direct()` Phase D-H (lines 264-528), `nudge_colliding_waypoints()` (lines 1006-1034), `transform_waypoints_direct()` (lines 1079-1119)
- **`src/render/router.rs`**: `route_edge()` (lines 220-299), `generate_backward_waypoints()` (lines 168-207)
- **`src/render/subgraph.rs`**: `render_subgraph_borders()` (lines 14-77) showing title placement at bounds.y
- **`src/render/edge.rs`**: Edge rendering with waypoints (lines 40-62)

## What

### (a) How subgraph bounds are computed
`convert_subgraph_bounds()` computes bounds from member-node draw positions:
- Uses fixed 2-cell border padding on all sides (line 805)
- Finds min/max from member node positions: `min_x`, `min_y`, `max_x`, `max_y` (lines 812-820)
- Enforces title-width minimum by expanding horizontally if needed (lines 839-849)
- Expands for backward edges if present (lines 851-887)

**Critical detail**: The bounds are entirely derived from member node positions. The title itself is only a visual element placed at `bounds.y` in the border rendering phase.

### (b) Where titles are actually rendered
`render_subgraph_borders()` in `subgraph.rs` lines 25-56 shows:
- Title is embedded **directly in the top border row** at `y = bounds.y`
- Text like "─ Title ─" is drawn as part of the horizontal border line
- There is **no extra row above** the border for the title — it's embedded

### (c) How waypoints are computed and transformed
Waypoints follow this pipeline:

1. **Dagre computation**: Dagre's normalization creates dummy nodes for long edges, assigns them to ranks
2. **Transform to draw coords**: `transform_waypoints_direct()` (lines 1102-1110):
   - Primary axis (Y for TD): snapped to `layer_starts[rank_idx]` — the draw position of that rank
   - Cross axis (X): uniform scaling from dagre coordinates
3. **Layer positioning**: `layer_starts` is computed from **node draw positions**, not subgraph bounds

**Critical insight**: Waypoints map to layers based on **where dagre placed nodes**, not based on subgraph bounds. Adding extra padding to bounds doesn't shift node positions or waypoint ranks.

### (d) Edge routing and waypoint usage
`route_edge()` in `router.rs` (lines 250-274):
- Uses waypoints directly from `layout.edge_waypoints` if available
- Falls through to synthetic generation for backward edges without waypoints
- Waypoints are not aware of subgraph bounds or titles — they're treated as opaque coordinates

### (e) Current collision avoidance mechanisms
`nudge_colliding_waypoints()` (lines 1011-1034):
- Detects if waypoint falls inside a **node** bounding box
- Nudges waypoint perpendicular to collision axis
- **Only checks node bounds** — no logic for subgraph title rows

## How

### Trace example: External → TitledSubgraph edge

Suppose we have:
```
D[External]
↓
A[Process] ← inside subgraph sg1[Title]
```

1. **Dagre layout phase**: D ranks at 0, A at rank 2 (two-rank skip)
2. **Normalization**: Adds dummy node at rank 1
3. **Member node positions**: After layout, A's draw position is `(x_a, y_a)`. sg1's bounds are computed as `{x: x_a-2, y: y_a-2, width: ..., height: ...}`
4. **Title rendering**: Title appears at `y = y_a - 2` (top border row)
5. **Waypoint transform**: Dummy waypoint at rank 1 maps to `layer_starts[1]`, which is determined from nodes at rank 1. If there are nodes at rank 1, `layer_starts[1]` might be much lower than `y_a - 2`.
6. **Edge drawing**: Segments follow waypoints, potentially at Y coordinates that pass through or below the title row

**The gap**: Waypoints come from dagre's rank system, not from subgraph bounds. The title lives at `bounds.y = y_a - 2`, but waypoints use `layer_starts[rank]` which is independent of this calculation.

## Why

The render layer's design philosophy:
- **Subgraph bounds** are metrics used for border rendering and overlap resolution
- **Edge routing** relies entirely on dagre waypoints
- **These two systems are decoupled**

Adding padding to bounds affects only the visual border size, not the waypoint coordinates. For a render-only fix to work:

1. We'd need to detect which waypoints pass through a subgraph's title row
2. Check if the waypoint is at Y == `subgraph_bounds.y` (title row)
3. Nudge the waypoint above or below
4. Handle cases where waypoints approach the title from different angles
5. Handle multiple waypoints on the same path

This is **not impossible** but requires new logic and is inherently fragile because:
- Waypoints are meant to be invariant (from dagre)
- Adding collision avoidance for titles post-hoc introduces a second collision system (first is for nodes)
- Edge cases: what if title row falls between two member nodes? What if waypoint is exactly at title row but shouldn't be nudged?

## Key Takeaways
- **Waypoints are computed before subgraph bounds**: Dagre ranks nodes, normalization adds dummies, waypoints are transformed to draw coords. Subgraph bounds are computed afterward from member positions. Waypoints don't know about bounds.
- **Title position is embedded in border, not separate**: The title is drawn as part of the top-border line at `bounds.y`, not above it. There's no structural space for it in the layout — it's purely visual.
- **Member node positions drive subgraph bounds, not vice versa**: Padding added to bounds doesn't move the nodes or affect waypoints. It only affects the border visual extent.
- **Collision avoidance exists for nodes, not subgraph features**: The `nudge_colliding_waypoints()` function only checks against node bounding boxes. There's a gap for subgraph features like titles.
- **A render-only fix would require new waypoint nudging logic**: We could add post-transform waypoint adjustment for subgraph title rows, but it would be a second collision system and fragile.

## Open Questions
- Could we push member nodes down in Phase D (after dagre layout, before draw position computation) to reserve space for titles? This would shift waypoints transitively.
- Would modifying `layer_starts` computation to account for subgraph title space be feasible?
- Is there a way to detect at render time whether a waypoint conflicts with a title and adjust it safely?

**Recommendation**: The render-only approach is **not viable as a complete solution**. The structural approach (dagre title nodes) is better conceptually but requires solving the multi-subgraph rank collision via either rank reassignment (Q2) or alternative nesting topology (Q3).
