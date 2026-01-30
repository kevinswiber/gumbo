# Q3: Is the render layer correctly handling the new label positions and waypoints?

## Summary

The label-dummy branch's render layer correctly implements a new label position transformation that **overrides** the old heuristic with precomputed positions from dagre. However, there is a **fundamental algorithmic mismatch**: the label-dummy branch computes label positions at the **midpoint between node boundaries** in canvas space, while the main branch applies **uniform scaling directly** to dagre coordinates. This difference means labels may not land where the layout algorithm intended, particularly for edges with label dummies that have non-zero dimensions.

## Where

**Consulted sources:**
- `/Users/kevin/src/mmdflux-label-dummy/src/render/layout.rs` (lines 743-799): `transform_label_positions_direct()` in label-dummy (uses node bounds midpoint + primary axis snap)
- `/Users/kevin/src/mmdflux/src/render/layout.rs` (lines 734-751): `transform_label_positions_direct()` in main (uses uniform scaling only)
- `/Users/kevin/src/mmdflux-label-dummy/src/dagre/normalize.rs` (lines 359-388): `get_label_position()` returns `WaypointWithRank` with rank and point
- `/Users/kevin/src/mmdflux-label-dummy/src/render/edge.rs` (lines 650-701): `render_all_edges_with_labels()` consumes precomputed positions
- `/Users/kevin/src/mmdflux-label-dummy/src/render/layout.rs` (lines 404-434): Phase H orchestrates waypoint and label transformation

## What

### 1. Label Position Data Flow: What Gets Passed Where

**Label-Dummy Branch:**
- `dagre::layout_with_labels()` returns `LayoutResult` with `label_positions: HashMap<usize, WaypointWithRank>`
- Each `WaypointWithRank` carries:
  - `point: Point { x: f64, y: f64 }` — position in dagre coordinate space
  - `rank: i32` — the rank where the label dummy sits
- These come from `normalize::get_label_position()` (lines 364-388 of normalize.rs):
  ```rust
  pub fn get_label_position(graph: &LayoutGraph, edge_index: usize) -> Option<WaypointWithRank> {
      // Extract position of the label dummy
      let pos = graph.positions[idx];
      let dims = graph.dimensions[idx]; // (width, height) for label dummies
      return Some(WaypointWithRank {
          point: Point { x: pos.x + dims.0 / 2.0, y: pos.y + dims.1 / 2.0 },
          rank,
      })
  }
  ```
  This centers the label dummy's position in dagre space.

**Main Branch:**
- `dagre::layout_with_labels()` returns `label_positions: HashMap<usize, Point>` (just Point, no rank)
- Each Point is the center of the label dummy in dagre space

### 2. Transformation Pipeline: Where the Mismatch Occurs

**Label-Dummy Branch (`layout.rs:749-799`):**
```rust
fn transform_label_positions_direct(
    label_positions: &HashMap<usize, WaypointWithRank>,  // ← Has rank!
    edges: &[Edge],
    ctx: &TransformContext,
    node_bounds: &HashMap<String, NodeBounds>,  // ← Uses node bounds!
    is_vertical: bool,
    canvas_width: usize,
    canvas_height: usize,
) {
    for (edge_idx, wp) in label_positions {
        let (scaled_x, scaled_y) = ctx.to_ascii(wp.point.x, wp.point.y);  // Step 1: uniform scale

        // Step 2: Override primary axis with node bounds midpoint
        if is_vertical {
            let src_bottom = src.y + src.height;
            let tgt_top = tgt.y;
            let mid_y = (src_bottom + tgt_top) / 2;  // ← Replaces scaled_y!
            pos = (scaled_x, mid_y);  // Uses cross-axis scaling, but primary is node midpoint
        } else {
            let src_right = src.x + src.width;
            let tgt_left = tgt.x;
            let mid_x = (src_right + tgt_left) / 2;  // ← Replaces scaled_x!
            pos = (mid_x, scaled_y);
        }
    }
}
```

**Main Branch (`layout.rs:736-751`):**
```rust
fn transform_label_positions_direct(
    label_positions: &HashMap<usize, Point>,  // ← No rank
    edges: &[Edge],
    ctx: &TransformContext,
) {
    for (edge_idx, pos) in label_positions {
        // Direct uniform transformation — no node bounds, no rank override
        converted.insert(key, ctx.to_ascii(pos.x, pos.y));
    }
}
```

### 3. The Critical Difference

The label-dummy branch **rejects the precomputed rank information** and **replaces it with a heuristic computed in canvas space**:

| Aspect | Label-Dummy | Main |
|--------|------------|------|
| **Primary axis** | `(src_bound + tgt_bound) / 2` (computed from final node positions) | `scaled_y/scaled_x` (from dagre's label dummy center, scaled uniformly) |
| **Cross axis** | `scaled_x/scaled_y` (uniform scale of dagre point) | `scaled_x/scaled_y` (same) |
| **Rank used** | Ignored entirely — the rank from `WaypointWithRank` is discarded | N/A in main branch |
| **Fallback** | None — always uses node bounds if both nodes found | None — always applies uniform scale |

### 4. When This Breaks Down

**For short edges with label dummies (label_dummy branch only):**
- An edge A→B with a label might have minlen=2, placing the label dummy at rank 1 (midpoint)
- After position phase, label dummy sits at dagre coords `(150.0, 75.0)` with rank 1
- `get_label_position()` returns `WaypointWithRank { point: (150.0, 75.0), rank: 1 }`
- `transform_label_positions_direct()` computes `(src.y + src.height + tgt.y) / 2` which is independent of the label dummy's actual Y coordinate

**This causes a desync:**
- Layout intends: label at the label dummy's center, which participates in crossing reduction
- Render receives: label at the gap midpoint, ignoring where the dummy actually sits

**For long edges with waypoints:**
- Edge A→C with midpoint label dummy at rank 2, position (100.0, 110.0)
- The waypoints also use `layer_starts` snap (line 729 of layout.rs)
- But labels use node bounds midpoint
- If node B (at rank 1) moves during collision repair, the label midpoint shifts but waypoints do not

### 5. Waypoint Handling: Correct

The waypoint transformation (lines 706-741 of layout.rs, both branches) **is correct and consistent**:
```rust
fn transform_waypoints_direct(...) {
    let rank_idx = wp.rank as usize;
    let layer_pos = layer_starts.get(rank_idx).copied().unwrap_or(0);  // Snap to rank
    let (scaled_x, scaled_y) = ctx.to_ascii(wp.point.x, wp.point.y);    // Uniform scale

    if is_vertical {
        (scaled_x.min(...), layer_pos)  // ← Cross-axis scaled, primary axis snapped
    }
}
```
This **correctly uses rank** to snap waypoints to layer boundaries.

### 6. Edge Rendering: Accepts Precomputed Positions

In `render/edge.rs:650-701` (both branches), labels are rendered with precomputed positions:
```rust
pub fn render_all_edges_with_labels(
    canvas: &mut Canvas,
    routed_edges: &[RoutedEdge],
    charset: &CharSet,
    diagram_direction: Direction,
    label_positions: &HashMap<(String, String), (usize, usize)>,  // ← Precomputed!
) {
    for routed in routed_edges {
        if let Some(label) = &routed.edge.label {
            let edge_key = (routed.edge.from.clone(), routed.edge.to.clone());
            let precomputed = label_positions.get(&edge_key).filter(|&&(px, py)| {
                // Bounds check
                px < canvas.width() && py < canvas.height()
                    && px.saturating_add(label_len) <= canvas.width()
            });

            if let Some(&(pre_x, pre_y)) = precomputed {
                draw_label_at_position(canvas, label, pre_x, pre_y);  // Use precomputed
            } else {
                draw_edge_label_with_tracking(canvas, routed, label, ...);  // Fallback to heuristic
            }
        }
    }
}
```
The fallback heuristic (lines 43-132 of edge.rs) uses the routed edge's segment geometry, not the label dummy positions.

## How

### The Label Positioning Algorithm (Label-Dummy Branch)

**Phase 1: Normalize**
1. Identify edges spanning > 1 rank
2. For each edge with a label, insert an `EdgeLabel` dummy at the midpoint rank
3. The dummy has dimensions (label_width, label_height)
4. Store `DummyNode { dummy_type: EdgeLabel, rank: mid_rank, width, height }`

**Phase 2: Layout**
1. Run Sugiyama: acyclic → rank → normalize → order → position
2. Position phase assigns x,y coordinates to every node (including label dummies)
3. Label dummies participate in crossing reduction via their rank and width

**Phase 3: Extract Label Positions**
1. `normalize::get_label_position(graph, edge_index)` extracts the label dummy's center in dagre space
2. Returns `WaypointWithRank { point: (center_x, center_y), rank: label_dummy.rank }`
3. Stored in `LayoutResult.label_positions`

**Phase 4: Transform to Canvas Space**
1. `transform_label_positions_direct()` receives `label_positions` with rank
2. Applies uniform scaling to the cross-axis coordinate: `(center_x - min_x) * scale_x`
3. **But then overrides the primary axis** with `(src_bottom + tgt_top) / 2`
4. This **discards the rank and the label dummy's actual position**

### Why This Mismatch Exists

The label-dummy code appears to have been partially refactored:
- Dagre correctly computes label positions via label dummies
- `denormalize()` correctly extracts them
- But `transform_label_positions_direct()` was written to override them with a heuristic

This suggests the developer may have:
1. Decided the rank-based label dummy wasn't needed after position phase
2. Reverted to the original "gap midpoint" heuristic for safety
3. But kept the waypoint rank-snapping logic (which is correct)

The result: **waypoints use ranks, labels don't** — a fundamental inconsistency.

## Why

### Design Rationale: Two Competing Approaches

**Approach A: Label Dummy Integration (Intended)**
- Rationale: Labels are structural elements that participate in layout
- Labels shape crossing reduction and node ordering
- Their final positions are determined by the layout algorithm
- Render layer should trust dagre's output

**Approach B: Post-Layout Label Positioning (Current)**
- Rationale: Labels are annotations, not structural
- After layout completes, place them in the gap between nodes
- Simpler, more predictable, less likely to cause layout artifacts
- Render layer applies a deterministic heuristic

The label-dummy branch **implements Approach A in dagre but Approach B in the render layer**, creating a contradiction.

### Constraints and Tradeoffs

1. **Coordinate Space Translation**: Dagre coordinates (floats, 50.0 rank_sep) must map to ASCII (usize, 3 char units). The scale factors account for this, but they're uniform — if label placement depends on rank snapping, it must use `layer_starts`, not precomputed scale factors.

2. **Collision Repair**: After scaling, collision repair (lines 313-335 of layout.rs) shifts nodes to enforce spacing. This invalidates any precomputed positions that depended on node locations. The midpoint heuristic recalculates based on final node positions (lines 769-784), making it robust to post-scale node movements.

3. **Waypoint Consistency**: Waypoints snap to `layer_starts` (line 729), not to precomputed dagre positions. If labels didn't also snap, edge paths and labels would diverge, especially visible in long edges with many waypoints.

## Key Takeaways

1. **Precomputed positions are available but rejected**: The label-dummy branch computes label positions correctly in dagre space (via label dummy centers) but then discards them in favor of a heuristic.

2. **Inconsistency with waypoints**: Waypoints correctly use rank-based snapping to `layer_starts`, but labels override the precomputed rank with a gap-midpoint heuristic. This means edge paths and labels are computed using different coordinate systems.

3. **Label dummies are inactive in rendering**: The label dummy nodes (with width/height) affect layout but their final coordinates are ignored. Only the gap midpoint is used, meaning the label dummy's crossing reduction benefit may not be realized if the gap is a different position.

4. **Collision repair invalidates precomputation**: Node shifting during collision repair (rank_gap_repair, lines 582-633) changes node positions after the precomputed label positions were calculated. The current heuristic recalculates based on final positions, which is correct but defeats the purpose of precomputation.

5. **The fallback heuristic is comprehensive**: If precomputed positions fail bounds checks or are absent, the code falls back to `draw_edge_label_with_tracking()`, which uses segment geometry heuristics. This fallback works well for simple cases but may not reflect the intent of label dummies in complex layouts.

## Open Questions

1. **Why was the rank discarded?** — Was there a discovered bug in rank-based positioning that prompted reverting to the midpoint heuristic?

2. **Should collision repair include label positions?** — Currently, node collision repair doesn't adjust label positions. Should a post-repair step recompute label midpoints, or should labels be fixed before repair?

3. **Are label dummy dimensions unused?** — The normalize phase assigns width/height to label dummies to affect crossing reduction. But render-layer label positioning ignores these dimensions and uses the gap midpoint instead. Is this intentional?

4. **Why not simplify to direct-scaling?** — The label-dummy branch computes precomputed positions via a WaypointWithRank with rank, then converts it back to a gap midpoint, losing the rank. Why not use main branch's simpler approach of returning just Point from dagre?

5. **Integration with waypoint routing**: When an edge has many waypoints (long edge with label dummy), how should the label position relate to the waypoints? Currently they use different position calculations — should they align?
