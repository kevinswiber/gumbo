# Q1: Trace the Precomputed Label Position Pipeline for "git commit"

## Summary

The "git commit" label for the Staging->Local edge follows a 3-stage pipeline: (1) dagre assigns the label dummy node at position (200.00, 11.00) with dimensions (12.0, 1.0), producing center (206.00, 11.50) at rank 3; (2) `transform_label_positions_direct()` maps this to draw coordinates (45, 2) by snapping the primary axis (x) to `layer_starts[3]=45` and scaling the cross axis (y) to 2; (3) `draw_label_at_position()` centers the 10-character label at x=40 (45 - 10/2), producing the range [40..50]. This range overlaps with the Staging Area node at x=[30..46], causing the visible corruption in the rendered output.

## Where

- `/Users/kevin/src/mmdflux-label-dummy/src/dagre/normalize.rs` -- `get_label_position()` (lines 364-388)
- `/Users/kevin/src/mmdflux-label-dummy/src/render/layout.rs` -- `transform_label_positions_direct()` (lines 831-849), `compute_layout_direct()` (Phase H)
- `/Users/kevin/src/mmdflux-label-dummy/src/render/edge.rs` -- `draw_label_at_position()` (lines 760-783), `render_all_edges_with_labels()` (lines 686-757)
- `/Users/kevin/src/mmdflux-label-dummy/tests/fixtures/git_workflow.mmd`

## What

### Stage 1: Dagre Label Dummy Node (normalize.rs)

After layout, `get_label_position()` extracts the label dummy node's position:

| Edge (index) | Edge | Dummy pos (x,y) | Dummy dims (w,h) | Center (x,y) | Rank |
|---|---|---|---|---|---|
| 0 | Working->Staging | (75.00, 11.00) | (9.0, 1.0) | (79.50, 11.50) | 1 |
| 1 | **Staging->Local** | **(200.00, 11.00)** | **(12.0, 1.0)** | **(206.00, 11.50)** | **3** |
| 2 | Local->Remote | (326.00, 11.00) | (10.0, 1.0) | (331.00, 11.50) | 5 |
| 3 | Remote->Working | (200.00, 16.70) | (10.0, 1.0) | (205.00, 17.20) | 3 |

The "git commit" label is `label_width = len("git commit") + 2 = 12`, height 1.0. The dummy node at dagre rank 3 has center at (206.00, 11.50).

### Stage 2: Transform to Draw Coordinates (layout.rs)

TransformContext parameters:
- `scale_x = 0.2273`, `scale_y = 0.6667`
- `dagre_min = (10.00, 10.00)`
- `overhang = (5, 0)`, `padding = 1`, `left_label_margin = 0`
- `is_vertical = false` (LR layout)
- `ranks_doubled = true`

Layer starts (rank -> draw x-coordinate):
```
rank 0 -> 1,   rank 1 -> 15,  rank 2 -> 30,  rank 3 -> 45,
rank 4 -> 60,  rank 5 -> 74,  rank 6 -> 88,  rank 7 -> 88
```

For the "git commit" label (edge_idx=1, Staging->Local):
- Dagre center: (206.00, 11.50)
- Rank: 3
- `layer_pos = layer_starts[3] = 45`
- Scaled via `ctx.to_ascii()`: x = round((206.00 - 10.00) * 0.2273) + 5 + 1 + 0 = round(44.55) + 6 = 51; y = round((11.50 - 10.00) * 0.6667) + 0 + 1 = round(1.0) + 1 = 2
- **For LR layout**: primary axis is X, so the result is `(layer_pos, scaled_y)` = **(45, 2)**

### Stage 3: Draw Label at Position (edge.rs)

`draw_label_at_position()` receives precomputed position `(45, 2)`:
- Label text: "git commit" (10 characters)
- Centering: `label_x = 45 - 10/2 = 45 - 5 = 40`
- Label occupies columns **[40..50]** at row 2

### Node Bounds

| Node | x | y | width | height | right_edge |
|---|---|---|---|---|---|
| Working Dir | 1 | 3 | 15 | 3 | 16 |
| Staging Area | 30 | 1 | 16 | 3 | 46 |
| Local Repo | 60 | 1 | 14 | 3 | 74 |
| Remote Repo | 88 | 3 | 15 | 3 | 103 |

### The Overlap

The "git commit" label at **[40..50] row 2** overlaps with:
- **Staging Area** node at [30..46] rows [1..3] -- overlap region: **columns 40-45 on row 2** (6 characters)

The label also partially extends into the gap between Staging Area (ends at x=46) and Local Repo (starts at x=60), which is where it should ideally be placed.

### Rendered Output (corrupted)

```
                             +----------------+              +--------------+
           git add---+       | Staging Area |mmit  +-------->| Local Repo |push--+
+--------------+     +------>+----------------+    |       +--------------+     +------>+--------------+
| Working Dir  |                              |    |                                   | Remote Repo  |
+--------------+                             -+----+                                   +--------------+
```

The "mmit" fragment after "Staging Area" is the tail of "git commit" -- the first 6 characters ("git co") are suppressed by `draw_label_at_position()`'s `!cell.is_node` guard, but the remaining 4 characters ("mmit") at columns 46-49 are written to non-node cells.

## How

The pipeline works step by step:

1. **make_space_for_edge_labels()** doubles all edge minlens when any edge has a label, creating rank gaps. The "git commit" edge gets minlen=2.

2. **Ranking** assigns Working=0, Staging=2, Local=4, Remote=6 (doubled). The label dummy gets rank=(0+2)/2 = 1... wait, actually with global minlen doubling, all edges get minlen=2. So ranks: Working=0, Staging=2, Local=4, Remote=6. The Staging->Local edge spans ranks 2 to 4; label_rank = (2+4)/2 = 3.

3. **Normalization** inserts a label dummy node at rank 3 with dimensions (12.0, 1.0). The dummy participates in ordering and position assignment.

4. **Position assignment (Brandes-Kopf)** places the dummy at dagre coordinates (200.00, 11.00). The center is (200 + 12/2, 11 + 1/2) = (206.00, 11.50).

5. **Transform**: For LR layout, the primary axis is X. The transform **snaps X to layer_starts[rank]** and **scales Y uniformly**. For rank 3, `layer_starts[3] = 45`, so the label position becomes (45, 2).

6. **Centering**: `draw_label_at_position()` centers the label by subtracting `label_len/2` from x. With label_len=10, label_x = 45 - 5 = 40.

7. **Writing**: Each character is checked against `!cell.is_node`. Characters at columns 40-45 on row 2 fall inside the Staging Area node (x=30..46) and are skipped. Characters at columns 46-49 are NOT inside any node, so "mmit" gets written -- corrupting the output.

## Why

The root cause is that `layer_starts[3] = 45` places the label center at x=45, which is the **midpoint between the Staging Area node (layer_start=30) and the Local Repo node (layer_start=60)**. This midpoint is at `(30+60)/2 = 45`, but the Staging Area node extends from x=30 to x=46 (16 chars wide). So the midpoint falls **inside** the source node's bounding box.

For LR layouts, the primary axis snap via `layer_starts` is correct in principle -- it places the label at the intermediate rank position. But the label centering in `draw_label_at_position()` shifts the label leftward by `label_len/2`, pushing it back into the source node.

The key insight: **the label position pipeline has no collision detection for precomputed positions**. Unlike the heuristic path in `draw_edge_label_with_tracking()` which calls `find_safe_label_position()` with node collision checks, `draw_label_at_position()` writes directly without any collision avoidance. It only has a per-character `!cell.is_node` guard which prevents overwriting node cells but still writes to cells just outside the node boundary, creating the "mmit" artifact.

## Key Takeaways

- The label position pipeline has 3 stages: dagre dummy center -> rank-snapped draw coordinates -> centered draw position. Each stage is individually correct but the composition can produce positions that overlap with nodes.
- For LR layout, the primary axis (X) is snapped to `layer_starts[rank]`, which is the midpoint between adjacent real-node layers. When a node is wide, this midpoint can fall inside the node's bounding box.
- `draw_label_at_position()` has NO collision avoidance -- it trusts the precomputed position completely. The per-character `!cell.is_node` guard prevents overwriting node characters but does not prevent writing label fragments in the gap just past the node edge.
- The waypoint for the same edge is also affected: the edge route goes through (45, 5) which gets nudged to (45, **4** after nudge -- actually wait, the waypoint is at (45, 5) which is the column just inside the Staging Area node's right edge. The `nudge_colliding_waypoints()` pushes it to `bounds.y + bounds.height + 1 = 1 + 3 + 1 = 5`, which explains the detour path through y=5.
- The overlap is fundamentally a problem of the cross-axis centering (`x - label_len/2`) not accounting for nearby node boundaries.

## Open Questions

- Should `draw_label_at_position()` run the same `find_safe_label_position()` collision avoidance that `draw_edge_label_with_tracking()` uses? This would shift labels that overlap nodes.
- Would it be better to adjust the dagre-level label position (e.g., bias toward target node) rather than fixing it at the rendering stage?
- Is the issue specific to LR/RL layouts where nodes are wide relative to the rank gap, or can it also occur in TD/BT layouts?
- How does the `nudge_colliding_waypoints()` affect the edge routing for this same edge? The waypoint at (45, 5) was inside the Staging node bounds and got nudged -- does this create the Z-shaped detour visible in the routing output?
