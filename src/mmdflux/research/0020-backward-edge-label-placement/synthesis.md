# Research Synthesis: Backward Edge Label Placement

## Summary

Backward edge labels in mmdflux render at wrong cross-axis positions because label positions are computed from dagre's abstract layout-space coordinates, while backward edges are routed synthetically via `generate_backward_waypoints()` at completely different cross-axis positions. Dagre provides no backward-edge-specific label handling. Mermaid solves this by recomputing label positions from the actual rendered path (`calcLabelPosition()`). The recommended fix is to implement a mermaid-style path-midpoint algorithm — computing the geometric midpoint of the routed orthogonal segments using Manhattan distance — rather than reusing the existing segment-based heuristics, which are stale pre-branch code with brittle magic thresholds.

## Key Findings

### 1. Two Independent Coordinate Systems Cause the Mismatch

The label position comes from dagre's label dummy node (placed by the Sugiyama algorithm in abstract layout space), while the backward edge path comes from `generate_backward_waypoints()` (which routes around the node perimeter). These two systems produce different cross-axis coordinates. The primary axis aligns correctly because both snap to rank-based `layer_starts[]` positions, but the cross-axis diverges because dagre's layout constraints and the router's perimeter strategy are independent.

### 2. Mermaid's Path-Aware Approach Is the Right Strategy

Mermaid ignores dagre's label coordinates and recomputes from the actual rendered SVG path using `calcLabelPosition()` — a geometric midpoint traversal. This works universally for forward and backward edges because it depends on the concrete rendered path, not abstract layout coordinates. mmdflux needs an equivalent approach.

### 3. Existing Heuristics Are Unsuitable; Path-Midpoint Is the Right Fix

The existing segment-based heuristics (`select_label_segment()`, `draw_edge_label_with_tracking()`) were written before the label-as-dummy-node work on this branch. They use a brittle 6-segment threshold to guess backward edges, pick the "longest inner segment" rather than the true path midpoint, and have separate TD/BT vs LR/RL code paths. A mermaid-style path-midpoint algorithm — walking the orthogonal segments by Manhattan distance to find the 50% mark — is simpler (~20 lines), direction-agnostic, and mirrors mermaid's proven `calcLabelPosition()` approach. For ASCII's orthogonal segments, the midpoint always falls on an exact grid cell with no floating-point rounding.

## Recommendations

1. **Implement a path-midpoint algorithm for backward edge labels** — Add `calc_label_position(&[Segment]) -> Option<(usize, usize)>` that walks orthogonal segments by Manhattan distance to find the 50% mark. This mirrors mermaid's `calcLabelPosition()` adapted for the ASCII grid. ~20 lines, pure function, easy to unit test.

2. **Skip precomputed dagre positions for backward edges** — In `render_all_edges_with_labels()`, detect backward edges and use the path-midpoint result instead of the dagre-derived `edge_label_positions` entry.

3. **Offset label from the edge line** — The midpoint falls *on* the edge. Offset by 1 cell (left/right for vertical segments, above/below for horizontal) so the label text sits beside the edge, not on it.

4. **Store `is_backward` flag on `RoutedEdge`** — The router already computes this. Caching it avoids recalculation in the rendering layer and makes the backward-edge check explicit rather than heuristic.

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | Label positions: `transform_label_positions_direct()` in layout.rs. Backward routing: `generate_backward_waypoints()` in router.rs. Label rendering: `render_all_edges_with_labels()` in edge.rs. Segment heuristics: `select_label_segment()` / `select_label_segment_horizontal()` in edge.rs. |
| **What** | Cross-axis coordinate diverges between dagre label dummy position and synthetic backward edge route. Primary axis aligns via rank-based snapping. Dagre has no backward-edge label handling. Mermaid recomputes from rendered path. |
| **How** | Add `calc_label_position()` — a path-midpoint function that walks orthogonal segments by Manhattan distance to the 50% mark. For backward edges, use this instead of dagre's precomputed position. Offset by 1 cell so the label sits beside the edge line. |
| **Why** | Dagre is a layout engine that assumes rendering follows its abstract coordinates. mmdflux's synthetic backward routing violates this assumption. Mermaid compensates with `calcLabelPosition()` (path-midpoint traversal). The existing segment-based heuristics are pre-branch code with brittle magic thresholds and are unsuitable. A path-midpoint algorithm is simpler, direction-agnostic, and mirrors mermaid's proven strategy. |

## Open Questions

- **Label offset direction**: When the midpoint falls on a vertical segment, should the label go left or right of the edge? Prefer the side facing the graph interior, or always the same side?
- **Collision avoidance**: What if the midpoint position overlaps a node or another label? May need to apply existing `find_safe_label_position()` logic after midpoint calculation.
- **Forward edge applicability**: Could the path-midpoint approach also improve forward edge labels in the future, replacing `transform_label_positions_direct()` entirely? (Out of scope for the backward edge fix.)
- **`is_backward` on RoutedEdge**: Should this flag be added as part of this fix or as a separate preparatory change?

## Next Steps

- [ ] Create implementation plan for path-midpoint backward edge label placement
- [ ] Add `Segment::length()`, `Segment::point_at_offset()`, `Segment::endpoint()` helper methods
- [ ] Implement `calc_label_position(&[Segment])` with unit tests for known segment lists
- [ ] Wire up backward-edge detection and path-midpoint in `render_all_edges_with_labels()`
- [ ] Add integration tests for backward edge labels in all four directions (TD, BT, LR, RL)
- [ ] Test with existing fixtures: `labeled_edges.mmd`, `git_workflow.mmd`, `http_request.mmd`

## Source Files

| File | Question |
|------|----------|
| `q1-mmdflux-current-pipeline.md` | Q1: How does mmdflux compute backward edge label positions today? |
| `q2-dagre-mermaid-comparison.md` | Q2: How do dagre and mermaid handle edge label positioning for backward edges? |
| `q3-fix-strategy.md` | Q3: What is the best fix strategy for mmdflux? |
