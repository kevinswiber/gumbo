# Research Synthesis: LR Forward Edge Label Overlap with Adjacent Nodes

## Summary

Forward edge labels in LR layouts overlap with adjacent node boxes because the `layer_starts` midpoint interpolation formula computes odd-rank positions using the **left edges** of adjacent layers instead of the **right edge of the source layer and left edge of the target layer**. For git_workflow.mmd, this places label coordinates inside the source node's bounding box (e.g., x=45 for "git commit" when the Staging Area node extends to x=46). The centering adjustment in `draw_label_at_position()` (`x - label_len/2`) compounds the problem by shifting labels further into node territory. The same bad coordinate also causes the stray `─┴─────┘` segment: the label dummy waypoint at (45, 2) collides with the Staging node boundary, triggering `nudge_colliding_waypoints()` to push it to y=5, creating a U-shaped routing detour.

## Key Findings

### Finding 1: The `layer_starts` midpoint formula is the root cause

The odd-rank (label dummy) positions in `layer_starts` are computed as:

```
label_x = (left_edge_of_source_layer + left_edge_of_target_layer) / 2
```

This should be:

```
label_x = (right_edge_of_source_layer + left_edge_of_target_layer) / 2
```

For the Staging → Local "git commit" label:
- **Current**: (30 + 60) / 2 = 45 — inside Staging Area (extends to x=46)
- **Correct**: (46 + 60) / 2 = 53 — centered in the 14-char gap between nodes

All three forward-edge labels in git_workflow.mmd overlap their source nodes:

| Edge | Label | Overlap chars | Current x | Correct x |
|------|-------|--------------|-----------|-----------|
| Working → Staging | "git add" | 4 | 15 | ~16 |
| Staging → Local | "git commit" | 6 | 45 | 53 |
| Local → Remote | "git push" | 4 | 74 | ~77 |

### Finding 2: The stray segment shares the same root cause

The `─┴─────┘` artifact is a direct consequence of the bad `layer_starts` formula:

1. Label dummy waypoint transforms to (45, 2) — on the Staging node boundary
2. `nudge_colliding_waypoints()` detects the collision (inclusive boundary check)
3. Waypoint pushed to (45, 5) — below the node
4. Router faithfully routes through displaced waypoint, creating a 6-segment U-shaped detour

Fixing the `layer_starts` formula to produce x=53 instead of x=45 would eliminate both the label overlap AND the stray segment, since the waypoint would no longer collide with the Staging node.

### Finding 3: Precomputed labels intentionally skip collision avoidance

The design follows a layered correctness principle:
- **Dagre layer**: Structural correctness via label dummy nodes
- **Transform layer**: Coordinate mapping via rank snapping + uniform scaling
- **Render layer**: Trust upstream, draw at given positions

`draw_label_at_position()` has only per-cell `is_node` protection. It lacks node bounding-box avoidance, edge cell protection, label-label deconfliction, and position shifting — all of which `draw_edge_label_with_tracking()` provides. This was a deliberate choice (evidenced by commit `719ff00` adding collision avoidance only for backward edges), based on the assumption that precomputed positions are correct by construction.

### Finding 4: The centering adjustment compounds the overlap

`draw_label_at_position()` centers labels via `x.saturating_sub(label_len / 2)`. If the precomputed position is already at or near a node boundary, centering shifts the label further into the node. For "git commit" (len=10): position 45 becomes draw range [40..50], overlapping 6 characters with the Staging node at [30..46].

## Recommendations

1. **Fix the `layer_starts` midpoint formula** — Use right edge of source layer instead of left edge when interpolating odd-rank positions. This is the primary fix and addresses both the label overlap and the stray segment. The formula in `compute_layout_direct()` (layout.rs, layer_starts computation around lines 416-434) should compute odd ranks as `(max_right_edge_of_layer_n + min_left_edge_of_layer_n+1) / 2`.

2. **Add `find_safe_label_position()` as a defensive safety net for precomputed labels** — This is low-risk (no-op when positions are correct) and catches edge cases where the formula fix doesn't fully resolve overlap (e.g., rounding errors in uniform scaling). It preserves the layered correctness principle while adding robustness.

3. **Consider filtering label dummy waypoints for short forward edges** — In LR layout, label dummy waypoints serve no routing purpose for forward edges (the label is placed by the precomputed system). Removing them from the waypoint list would eliminate the nudge/detour issue entirely, regardless of coordinate values.

4. **Consider using exclusive boundary checks in `nudge_colliding_waypoints()`** — The current inclusive check (`contains()`) triggers nudging when a waypoint is at the exact boundary cell. Using exclusive right/bottom boundaries would avoid nudging for boundary-touching waypoints, reducing unnecessary detours.

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | `layer_starts` computation in `compute_layout_direct()` (layout.rs ~line 416-434), `draw_label_at_position()` (edge.rs ~line 760), `nudge_colliding_waypoints()` (layout.rs ~line 736) |
| **What** | Odd-rank `layer_starts` midpoint uses left-edge-to-left-edge instead of right-edge-to-left-edge; label centering compounds overlap; waypoint nudging creates routing artifacts |
| **How** | Pipeline: dagre dummy → rank-snapped layer_start → centered draw position. Midpoint formula produces x=45 (inside node) instead of x=53 (in gap). Waypoint at same x triggers nudge to y=5, causing U-detour. |
| **Why** | The `layer_starts` interpolation was designed for coordinate snapping but doesn't account for node widths when computing midpoints. The precomputed path trusts upstream correctness, so render-layer collision avoidance was intentionally omitted. |

## Open Questions

- Does the same `layer_starts` midpoint issue affect TD/BT layouts? Node heights are typically uniform (3 chars), so the midpoint may fall correctly between nodes. Worth verifying.
- Should the label dummy node's width influence the midpoint computation? Currently the dummy's dagre dimensions don't feed into `layer_starts`.
- Is there a double-centering issue? If `transform_label_positions_direct()` returns a center point, and `draw_label_at_position()` also centers, the label shifts twice.
- Should `placed_labels` tracking be symmetric? Currently precomputed labels are tracked for heuristic labels to avoid, but precomputed labels don't check against each other.

## Next Steps

- [ ] Fix the `layer_starts` odd-rank interpolation formula to use right edge of source layer
- [ ] Add `find_safe_label_position()` call in the precomputed label path as a safety net
- [ ] Verify the fix resolves both the label overlap and stray segment in git_workflow.mmd
- [ ] Test that TD/BT layouts are unaffected by the formula change
- [ ] Consider whether label dummy waypoints should be excluded from forward edge routing

## Source Files

| File | Question |
|------|----------|
| `q1-label-position-trace.md` | Q1: Trace the precomputed label position pipeline |
| `q2-node-boundary-analysis.md` | Q2: Why does the label position land inside node boundaries? |
| `q3-collision-avoidance-analysis.md` | Q3: Should precomputed labels use collision avoidance? |
| `q4-stray-segment-investigation.md` | Q4: What causes the stray segment? |
