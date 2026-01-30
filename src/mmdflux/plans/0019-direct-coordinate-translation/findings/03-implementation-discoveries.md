# Implementation Discoveries

## 1. compute_layout_direct() Internal Structure

The assembly function (`compute_layout_direct`) ended up with 10 distinct phases,
labeled A through J in the code:

```
A. Build dagre input graph
B. Run dagre layout
C. Extract node dimensions and layer structure
D. Compute per-axis ASCII scale factors
E. Scale and round node positions
F. Run collision repair
G. Compute canvas dimensions
H. Build draw_positions map (node_id -> (x, y) in canvas coords)
I. Transform waypoints to ASCII coordinates
J. Transform label positions to ASCII coordinates
```

This is more structured than the plan's 3-step "scale → round → repair" description,
but the additional phases are all necessary setup and output assembly.

## 2. Layer Extraction from Dagre Results

The direct pipeline needs to know which nodes share a layer for collision repair.
This information isn't directly available in dagre's `LayoutResult` — it must be
reconstructed by grouping nodes by their rank/layer assignment.

The implementation extracts this from `layout_result.node_positions` by grouping
nodes with the same primary-axis coordinate (y for TD/BT, x for LR/RL). This
works because dagre's BK algorithm assigns the same primary coordinate to all
nodes in the same rank.

## 3. Direction-Aware Coordinate Mapping

The implementation must handle four layout directions (TD, BT, LR, RL), and the
meaning of "primary axis" and "cross axis" flips:

| Direction | Primary Axis | Cross Axis | Primary Coord | Cross Coord |
|-----------|-------------|------------|---------------|-------------|
| TD        | Y (top→down) | X         | node.y        | node.x      |
| BT        | Y (bottom→up) | X        | node.y        | node.x      |
| LR        | X (left→right) | Y       | node.x        | node.y      |
| RL        | X (right→left) | Y       | node.x        | node.y      |

This was handled correctly by the scale factor computation (which already
distinguished TD/BT vs LR/RL) and the collision repair (which operates on
the cross-axis within same-primary-axis groups).

## 4. Waypoint Transformation Uses layer_starts

The waypoint transformation function (`transform_waypoints_direct`) uses a
`layer_starts` map to snap waypoint primary-axis coordinates to the nearest
layer boundary. This is more precise than uniform scaling because waypoints
should align with the layers they pass through, not with interpolated positions.

For the cross-axis, uniform scaling is applied since waypoints can be at
arbitrary cross-axis positions (not snapped to node centers).

## 5. Collision Repair Sorting Matters

The collision repair function sorts nodes within each layer by their cross-axis
position before checking for overlaps. This ensures that pushes cascade in one
direction (increasing cross-axis) rather than creating oscillating adjustments.

Without sorting, two nodes at positions [10, 8] with minimum spacing 5 could be
processed as: node at 10 is fine, node at 8 overlaps node at 10, push 8→15.
With sorting: node at 8 is fine, node at 10 is fine (8+5=13 ≤ 10? no, 13 > 10,
so push 10→13). The sorted approach produces more compact layouts.

## 6. Canvas Dimension Computation

Canvas dimensions are computed as:
```
width = max(node_x + node_width) + 1
height = max(node_y + node_height) + 1
```

The `+1` accounts for the canvas being 0-indexed while dimensions are 1-based.
This matches the old pipeline's behavior. The "vertical trimming" fix from
plan 0018 (Phase 1) was already applied before this plan started, so no
additional trimming was needed.

## 7. Edge Label Position Scaling

Edge label positions from dagre are scaled using the same uniform scale factors
as node positions. This works because dagre places labels at the midpoint of
edges, and uniform scaling preserves relative positions.

The plan originally proposed a more complex label-aware transformation, but
uniform scaling turned out to be sufficient for all test cases.

## 8. The Old Pipeline's grid_positions Is a Lossy Quantization

Examining both pipelines side-by-side confirmed the research's characterization:
the old pipeline's `compute_grid_positions` step quantizes float coordinates to
integer grid indices, losing relative spacing information. For example, three
nodes at dagre positions [0.0, 2.5, 10.0] become grid positions [0, 1, 2],
which are then expanded to uniform draw positions [0, 8, 16]. The direct pipeline
instead produces [0, 3, 12] (approximately), preserving the proportional spacing.

## 9. Test Helper Functions

The implementation added three reusable test helpers to `tests/integration.rs`:

- `parse_and_build(fixture)` — reads a `.mmd` fixture and returns a `Diagram`
- `layout_fixture(fixture)` — computes a `Layout` using the direct pipeline
- `render_with_layout(diagram, layout)` — renders a diagram with a pre-computed layout

These are useful for future tests that need to inspect layout properties or
compare pipelines.
