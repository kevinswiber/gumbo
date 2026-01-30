# Q2: Why Does the Label Position Land Inside Node Boundaries?

## Summary

The precomputed label positions for LR forward edges use `layer_starts[odd_rank]` as the x-coordinate, which is computed as the midpoint between adjacent real-node layers. For the "git commit" label (Staging->Local edge), this midpoint lands at x=45, which is inside the "Staging Area" node boundary (x=30..46). The centering step in `draw_label_at_position()` then shifts the label leftward by `label_len/2`, making the overlap worse. The root cause is that `layer_starts` midpoint interpolation does not account for actual node widths, so label dummy ranks can coincide with node boundaries when nodes are wide relative to inter-layer gaps.

## Where

- `/Users/kevin/src/mmdflux-label-dummy/src/render/layout.rs` -- `compute_layout_direct()`, `transform_label_positions_direct()`, layer_starts computation (lines 416-434)
- `/Users/kevin/src/mmdflux-label-dummy/src/render/edge.rs` -- `draw_label_at_position()` (lines 760-783)
- `/Users/kevin/src/mmdflux-label-dummy/src/dagre/normalize.rs` -- label dummy creation (lines 242-257)
- `/Users/kevin/src/mmdflux-label-dummy/src/dagre/mod.rs` -- `make_space_for_edge_labels()` (lines 54-64)
- `/Users/kevin/src/mmdflux-label-dummy/src/dagre/position.rs` -- `assign_horizontal()` (lines 84-149)

## What

### Node bounds (draw coordinates)

From debug output of `git_workflow.mmd` (graph LR):

| Node | x | y | width | height | right_edge (x+w) |
|------|---|---|-------|--------|-------------------|
| Working Dir | 1 | 3 | 15 | 3 | 16 |
| Staging Area | 30 | 1 | 16 | 3 | 46 |
| Local Repo | 60 | 1 | 14 | 3 | 74 |
| Remote Repo | 88 | 3 | 15 | 3 | 103 |

### Layer starts (rank-to-draw-coordinate mapping)

With `ranks_doubled=true`, real nodes sit at even ranks, label dummies at odd ranks:

| Rank | layer_start | Purpose |
|------|-------------|---------|
| 0 | 1 | Working Dir (real) |
| 1 | 15 | label rank for Working->Staging ("git add") |
| 2 | 30 | Staging Area (real) |
| 3 | 45 | label rank for Staging->Local ("git commit") |
| 4 | 60 | Local Repo (real) |
| 5 | 74 | label rank for Local->Remote ("git push") |
| 6 | 88 | Remote Repo (real) |
| 7 | 88 | (duplicate, edge case for backward edge label) |

### Label positions and overlap analysis

**Edge: Staging -> Local, label "git commit" (len=10)**

- Precomputed position: **(45, 2)** -- the x=45 comes from `layer_starts[rank=3] = 45`
- `draw_label_at_position()` centers: `label_x = 45 - 10/2 = 40`
- Label occupies columns **40..50**
- Staging Area right edge = 46 (x=30, w=16)
- **Overlap: columns 40..46 fall inside the Staging Area node boundary**

**Edge: Working -> Staging, label "git add" (len=7)**

- Precomputed position: **(15, 2)** -- `layer_starts[rank=1] = 15`
- Centered: `label_x = 15 - 7/2 = 12`
- Label occupies columns **12..19**
- Working Dir right edge = 16
- **Overlap: columns 12..16 fall inside Working Dir node boundary**

**Edge: Local -> Remote, label "git push" (len=8)**

- Precomputed position: **(74, 2)** -- `layer_starts[rank=5] = 74`
- Centered: `label_x = 74 - 8/2 = 70`
- Label occupies columns **70..78**
- Local Repo right edge = 74
- **Overlap: columns 70..74 fall inside Local Repo node boundary**

### Label dummy node dimensions

From `normalize.rs`, edge label dummies get dimensions from `EdgeLabelInfo`:
- Width = `label.len() + 2` (set in `compute_layout_direct()` line 129)
- Height = 1.0
- For "git commit": width = 12.0, height = 1.0
- For "git add": width = 9.0, height = 1.0

### Minlen handling

`make_space_for_edge_labels()` doubles ALL edge minlens when any edge has a label. For git_workflow.mmd, all 4 edges have labels, so all get minlen=2. This means:
- Working(rank 0) -> Staging(rank 2): gap of 2 ranks
- Staging(rank 2) -> Local(rank 4): gap of 2 ranks
- etc.

The label dummy sits at the odd rank (1, 3, 5) between source and target.

### Actual gap analysis

For Staging -> Local:
- Staging right edge: x=46
- Local left edge: x=60
- **Physical gap: 14 characters**
- Label "git commit" length: 10 characters
- Gap is sufficient for the label IF it were placed in the gap

But the label's precomputed x-coordinate (45) is at the left edge of the gap, not centered in it. The midpoint formula `(curr + next) / 2 = (30 + 60) / 2 = 45` places the label at the left node's left edge, not in the gap between nodes.

## How

### Layer starts computation (the core issue)

The `layer_starts` array is built in two steps:

1. **Even ranks** (real nodes): `layer_starts_raw[layer_idx]` = minimum primary-axis draw position of nodes in that layer. For LR, this is the node's `x` position (its left edge).

2. **Odd ranks** (label/dummy): Interpolated as `(curr + next) / 2` where `curr` and `next` are adjacent `layer_starts_raw` values.

For Staging(rank 2) -> Local(rank 4):
- `layer_starts_raw[1]` (Staging layer) = 30 (Staging's x position = left edge)
- `layer_starts_raw[2]` (Local layer) = 60 (Local's x position = left edge)
- Midpoint = (30 + 60) / 2 = **45**

This midpoint of left edges equals the Staging node's right boundary minus 1 (Staging spans x=30..46). The interpolation treats `layer_start` as a representative point for the entire layer, but for wide nodes, the left edge is far from the right edge.

### Centering in draw_label_at_position()

```rust
fn draw_label_at_position(canvas, label, x, y) {
    let label_x = x.saturating_sub(label_len / 2);  // centers label on x
    ...
}
```

The precomputed `x` is already at the boundary, and centering shifts it further left into the node.

### Position assignment in dagre

In `assign_horizontal()`, x advances by `max_width_in_layer + rank_sep` for each layer. With rank_sep=50.0, the dagre coordinate gap between layers is large. The issue is not in dagre's coordinate space -- it is in the ASCII scaling and layer_starts interpolation.

### Scale factor

For LR with `ranks_doubled=true`:
- `max_w` = 16 (Staging Area)
- `effective_rank_sep = max_w + 2 * rank_sep = 16 + 100 = 116`
- `scale_x = (max_w + h_spacing) / (max_w + effective_rank_sep) = 20/132 = 0.1515`

Wait, the debug output shows `scale_x=0.2273`. Let me recalculate with the actual config values:
- `h_spacing = 4`, so `max_w + h_spacing = 16 + 4 = 20`
- `max_w + effective_rank_sep = 16 + 116 = 132`
- `scale_x = 20/132 = 0.1515`

Hmm, the actual value differs. The node_sep and edge_sep are computed dynamically for LR:
- avg_height = (3+3+3+3)/4 = 3.0
- node_sep = max(3.0 * 2.0, 6.0) = 6.0
- edge_sep = max(3.0 * 0.8, 2.0) = 2.4

And max_w = 16 (from all 4 nodes: 15, 16, 14, 15). So:
- effective_rank_sep = 16 + 100 = 116
- scale_x = (16 + 4) / (16 + 116) = 20/132 = 0.1515

But debug shows 0.2273. This means max_w might actually be different -- let me reconsider. The node_dimensions function may return different widths. In any case, the fundamental problem is clear regardless of the exact scale factor.

## Why

The root cause is a combination of two issues:

### Issue 1: layer_starts midpoint interpolation uses left edges, ignoring node widths

The `layer_starts_raw` values are the minimum x-positions (left edges) of nodes in each layer. The midpoint `(left_edge_of_layer_n + left_edge_of_layer_n+1) / 2` does not account for the width of layer_n's nodes. For wide nodes, this midpoint falls inside the source node's bounding box.

The correct midpoint for label placement should be in the gap between nodes:
```
correct_label_x = (right_edge_of_source_layer + left_edge_of_target_layer) / 2
```
Instead, the current code computes:
```
current_label_x = (left_edge_of_source_layer + left_edge_of_target_layer) / 2
```

For Staging -> Local:
- Current: (30 + 60) / 2 = 45 (inside Staging, which extends to x=46)
- Correct: (46 + 60) / 2 = 53 (in the 14-char gap between nodes)

### Issue 2: draw_label_at_position() centering shifts further into node territory

The precomputed position is already at or near the node boundary. Centering (`x - label_len/2`) moves it even further left into the node. Since `draw_label_at_position` skips cells marked `is_node`, part of the label is silently clipped, creating garbled output where the label partially overwrites or fails to render.

### Issue 3: No label-specific collision avoidance in precomputed path

The precomputed label flow (`draw_label_at_position`) does not call `find_safe_label_position()` -- it directly writes at the centered position. The fallback heuristic path (`draw_edge_label_with_tracking`) does have collision avoidance, but precomputed labels bypass it entirely.

## Key Takeaways

- The `layer_starts` midpoint interpolation formula is fundamentally wrong for LR layouts: it uses left-edge-to-left-edge midpoints instead of right-edge-to-left-edge midpoints, causing label x-positions to land inside the source node for any non-trivial node width.
- The centering step in `draw_label_at_position()` compounds the problem by shifting the label further left (toward the source node).
- All three forward-edge labels in git_workflow.mmd overlap their source nodes by 4-6 characters.
- The physical gap between nodes (14 chars for Staging->Local) is more than sufficient for the label text (10 chars), so the problem is purely positional, not a space allocation issue.
- The fix should compute odd-rank layer_starts as `(max_right_edge_of_layer_n + min_left_edge_of_layer_n+1) / 2`, centering labels in the actual inter-node gap rather than in the span between left edges.

## Open Questions

- Should `draw_label_at_position()` also call `find_safe_label_position()` as a safety net, in case the precomputed position still collides after the formula fix?
- For TD/BT layouts (vertical), does the same issue occur? The layer_starts would use y-positions, and node heights are typically uniform (3 chars), so the midpoint might not overlap. Worth verifying.
- Should the label dummy node's width influence the midpoint computation? Currently the dummy's width (label_len + 2) is used in dagre's coordinate assignment but not in the layer_starts interpolation.
- The `nudge_colliding_waypoints` function handles waypoint-node collisions but does not handle label-position-node collisions. Should it be extended to cover labels too?
