# Q3: What is the best fix strategy for mmdflux?

## Summary

**Best approach: Implement a mermaid-style path-midpoint algorithm for backward edge labels.** For backward edges, skip the precomputed dagre label position and instead compute the geometric midpoint of the routed path using Manhattan distance over orthogonal segments. This mirrors mermaid's `calcLabelPosition()` strategy, adapted for the ASCII grid, and is direction-agnostic without relying on the brittle segment-count heuristics in the existing code.

## Where

**Key files:**
- `src/render/edge.rs` (lines 43-222): `draw_edge_label_with_tracking()`, existing segment heuristics (`select_label_segment()`, etc.)
- `src/render/edge.rs` (lines 657-708): `render_all_edges_with_labels()` — where precomputed positions are consumed
- `src/render/layout.rs` (lines 814-843): `transform_label_positions_direct()` computes precomputed positions from dagre
- `src/render/layout.rs` (lines 474-483): Backward edge waypoint stripping
- `src/render/router.rs` (lines 39-69): `Segment` enum and `RoutedEdge` struct — the data available at rendering time
- `src/render/router.rs` (lines 121-154): `generate_backward_waypoints()` — synthetic routing
- `~/src/mermaid/packages/mermaid/src/utils.ts` (lines 305-366): `traverseEdge()`, `calculatePoint()`, `calcLabelPosition()` — mermaid's reference implementation
- `issues/0004-label-placement-backward-edges/`: Three issues showing label placement failures
- `plans/0025-label-dummy-regression-fix/findings/`: Rank-to-layer mapping and ranksep halving discoveries

## What

### Three Approaches Analyzed

#### (a) Path-Midpoint Algorithm (Mermaid-Style) ← RECOMMENDED

**Concept:** Walk the routed orthogonal segments, sum Manhattan distances to get total path length, walk forward to the 50% mark, return the grid cell at that point.

**How mermaid does it** (`utils.ts:305-366`):
1. `traverseEdge()` sums Euclidean distances between consecutive points to get total path length
2. Divides by 2 to get the midpoint distance
3. `calculatePoint()` walks segments from start, accumulating distance
4. When it reaches the segment containing the midpoint, linearly interpolates within that segment

**Adaptation for ASCII grid:** Since all routed edges are orthogonal (`Segment::Vertical` and `Segment::Horizontal`), the algorithm simplifies:
- Each segment's length is `abs_diff(start, end)` (Manhattan distance = Euclidean for axis-aligned segments)
- The midpoint always falls on a segment (not between segments)
- Interpolation within a segment produces an exact integer grid cell — no floating-point rounding needed

**Pros:**
- Direction-agnostic: works identically for TD/BT/LR/RL without branching
- Length-agnostic: works for short and long backward edges
- Visually balanced: label appears at the true center of the edge path
- Simple algorithm: ~20 lines of Rust, pure function on `&[Segment]`
- Mirrors mermaid's proven approach
- No heuristic thresholds (no 6-segment magic number)

**Cons:**
- New code (but small and well-defined with clear test cases)
- Must handle edge case of zero-length path (degenerate) and single-segment path

**Example (TD backward edge routed right):**
```
Segments: H(y=3, x=20→25), V(x=25, y=3→15), H(y=15, x=25→20)
Lengths:  5 + 12 + 5 = 22
Midpoint: distance 11, falls in V segment at offset 6: y=3+6=9
Label placed at: (25±1, 9) — offset by 1 cell so label sits beside the edge line
```

#### (b) Reuse Existing Segment-Based Heuristics ← NOT RECOMMENDED

**Concept:** Skip precomputed positions for backward edges and fall through to `draw_edge_label_with_tracking()`.

**Why this is unsuitable:**
- The heuristics were written before the label-as-dummy-node work on this branch
- Uses a **6-segment threshold** to guess backward edges by segment count — brittle
- Places labels *beside the longest inner segment*, not at the path midpoint — different goal
- Has separate TD/BT vs LR/RL code paths (`select_label_segment()` vs `select_label_segment_horizontal()`) — more surface area
- Would need significant updates to work correctly for this use case, negating the "reuse proven code" advantage

#### (c) Fix in Coordinate Transform Layer

**Concept:** Detect backward edges in `transform_label_positions_direct()` and recompute.

**Why this is unsuitable:**
- `transform_label_positions_direct()` runs before routing — it doesn't have access to the routed segments
- Would require duplicating backward edge routing logic in layout.rs
- Risk of divergence between transform-computed route and actual rendered route

## How

### Recommended Implementation: Path-Midpoint in Rendering Layer

**1. Add `calc_label_position()` function in `edge.rs`:**

```rust
/// Compute the geometric midpoint of an orthogonal path, mimicking
/// mermaid's `calcLabelPosition()`. Returns the (x, y) grid cell at
/// the 50% mark of the total path length (Manhattan distance).
fn calc_label_position(segments: &[Segment]) -> Option<(usize, usize)> {
    if segments.is_empty() {
        return None;
    }

    // Sum total path length
    let total_length: usize = segments.iter().map(|s| s.length()).sum();
    if total_length == 0 {
        return None;
    }

    // Walk to the midpoint
    let mut remaining = total_length / 2;
    for seg in segments {
        let len = seg.length();
        if len >= remaining {
            // Midpoint falls within this segment — interpolate
            return Some(seg.point_at_offset(remaining));
        }
        remaining -= len;
    }

    // Fallback: endpoint of last segment
    segments.last().map(|s| s.endpoint())
}
```

This requires adding `length()`, `point_at_offset(offset)`, and `endpoint()` methods to `Segment`, which are trivial:
- `Vertical { x, y_start, y_end }` → length = `y_start.abs_diff(y_end)`, point_at_offset = `(x, min(y_start,y_end) + offset)`
- `Horizontal { y, x_start, x_end }` → length = `x_start.abs_diff(x_end)`, point_at_offset = `(min(x_start,x_end) + offset, y)`

**2. In `render_all_edges_with_labels()`, use path-midpoint for backward edges:**

```rust
// For backward edges, compute label position from the routed path
// rather than using dagre's precomputed position (which doesn't account
// for synthetic backward routing).
let label_pos = if is_backward {
    calc_label_position(&routed.segments)
} else {
    label_positions.get(&edge_key).map(|&(x, y)| (x, y))
};
```

**3. Offset label so it sits beside the edge, not on it:**

The midpoint will be *on* the edge line. For readable ASCII output, offset by 1 cell:
- If midpoint falls on a vertical segment → place label 1 cell to the left or right
- If midpoint falls on a horizontal segment → place label 1 cell above or below

This offset logic can be determined from which segment type the midpoint falls on, returned alongside the coordinates from `calc_label_position()`.

**4. Detect backward edges:**

Either use `is_backward_edge()` from router.rs, or (cleaner) store a `is_backward: bool` flag on `RoutedEdge` during routing, since the router already computes this.

### Implementation steps (TDD):

1. **Red:** Test that `calc_label_position()` returns the correct midpoint for known segment lists (vertical-only, horizontal-only, mixed orthogonal)
2. **Green:** Implement `calc_label_position()` and the `Segment` helper methods
3. **Red:** Integration test that a backward edge label in `labeled_edges.mmd` renders adjacent to the edge path
4. **Green:** Wire up the backward-edge check in `render_all_edges_with_labels()`
5. **Refactor:** Verify no regressions on forward edge labels across all four directions

## Why

1. **Mirrors mermaid's proven strategy**: mermaid's `calcLabelPosition()` works universally because it derives position from the concrete rendered path. This is the same principle, adapted for orthogonal ASCII segments.
2. **Direction-agnostic**: One code path handles TD/BT/LR/RL — no branching by direction. The segments encode the direction implicitly.
3. **No magic thresholds**: Unlike the existing 6-segment heuristic, this works for any number of segments.
4. **Small, testable, pure function**: `calc_label_position(&[Segment]) -> Option<(usize, usize)>` is easy to unit test with constructed segment lists.
5. **Self-correcting**: If backward edge routing changes, the midpoint automatically adjusts because it's computed from the actual routed segments.
6. **Existing heuristics are stale**: The segment-based heuristics in `draw_edge_label_with_tracking()` were designed before the label-as-dummy-node branch and would need significant rework to handle this case — negating the "reuse" advantage.

## Key Takeaways

- **Root cause confirmed**: Precomputed label positions from dagre don't match synthetic backward edge routing
- **Mermaid's approach is the right model**: Compute label position from the actual rendered path, not from abstract layout coordinates
- **ASCII adaptation is straightforward**: Orthogonal segments simplify mermaid's Euclidean algorithm to Manhattan distance with exact integer grid cells
- **Existing heuristics are unsuitable**: The 6-segment threshold, longest-inner-segment selection, and direction-specific branching are artifacts of pre-dummy-node code and would need rework
- **Recommended fix**: Add `calc_label_position()` (~20 lines), wire it up for backward edges in `render_all_edges_with_labels()`, offset label by 1 cell from the edge line

## Open Questions

- **Label offset direction**: When the midpoint falls on a vertical segment, should the label go left or right? Should it prefer the side facing the graph interior (away from the perimeter)? Or always the same side?
- **Forward edges**: Could this approach also improve forward edge label placement, replacing `transform_label_positions_direct()` entirely? (Future consideration — out of scope for the backward edge fix.)
- **Collision avoidance**: What if the midpoint position overlaps a node or another label? The existing `find_safe_label_position()` logic may need to be applied after midpoint calculation.
- **Store `is_backward` on RoutedEdge**: Cleaner than recalculating in the rendering layer. Should this be done as part of this fix or separately?
