# Q3: What is mmdflux doing today and where does it break?

## Summary

mmdflux-subgraphs computes subgraph borders using a fallback approach: it scans member nodes' draw positions, computes a bounding box with fixed 2-cell padding, and renders borders and titles directly to canvas without protection from overwrite. This causes two main classes of failures: (1) borders of adjacent subgraphs overlap on the same row because inter-subgraph spacing is ignored, and (2) backward edges within subgraphs escape their bounds because the border expansion for backward edges uses hardcoded padding that doesn't account for waypoint routing distances.

## Where

**Files read with line references:**

- `/Users/kevin/src/mmdflux-subgraphs/src/render/layout.rs` lines 700-812: `convert_subgraph_bounds()` function
- `/Users/kevin/src/mmdflux-subgraphs/src/render/subgraph.rs` lines 14-67: `render_subgraph_borders()` function
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/border.rs` lines 67-125: `remove_nodes()` function and Rect computation
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/nesting.rs` lines 1-94: Border top/bottom node creation and min_rank/max_rank assignment
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/mod.rs` lines 74-128: Layout orchestration with border node lifecycle
- `/Users/kevin/src/mmdflux-subgraphs/src/render/canvas.rs` lines 151-175: `set_with_connection()` protection logic (does NOT protect subgraph borders)
- `/Users/kevin/src/mmdflux-subgraphs/src/render/router.rs` line 113: BACKWARD_ROUTE_GAP = 2

**Related findings:**
- `/Users/kevin/src/mmdflux/plans/0026-subgraph-padding-overlap/findings/dagre-to-draw-coordinate-mismatch.md`: Phase 1 revert reason

## What

### Border Node Lifecycle

**Creation (nesting.rs:18-77, border.rs:17-65):**

1. `nesting::run()` creates border_top and border_bottom dummy nodes for each compound node, with high-weight nesting edges to constrain children's rank span. These define the vertical extent.
2. After ranking, `nesting::assign_rank_minmax()` extracts min_rank and max_rank from border_top/bottom node ranks.
3. `border::add_segments()` creates left/right border nodes at each rank within min_rank..=max_rank, linking them vertically. These define the horizontal extent.

**Removal (border.rs:71-125):**

The `remove_nodes()` function computes a dagre-space Rect from border node positions:
- `x_min`: minimum x from all left border nodes
- `x_max`: maximum x from all right border nodes
- `y_min`: y from top border node (or minimum y from left nodes if no top node)
- `y_max`: y from bottom border node (or maximum y from left nodes if no bottom node)
- `width`: x_max - x_min
- `height`: y_max - y_min
- **Center computed as:** `(x: (x_min + x_max) / 2.0, y: (y_min + y_max) / 2.0)`

Result: `HashMap<String, Rect>` in **dagre float space** passed as `result.subgraph_bounds`.

### Coordinate Space Mismatch (The Core Problem)

**`convert_subgraph_bounds()` ignores dagre bounds entirely (layout.rs:700-812):**

The function receives `_dagre_bounds` (underscore prefix = unused) and `_ctx` but doesn't use either. Instead, it iterates over subgraph member nodes and computes bounds from draw positions:

```rust
// Lines 726-734: Scan member node positions
for node_id in &sg.nodes {
    if let (Some(&(x, y)), Some(&(w, h))) = (...) {
        min_x = min_x.min(x);
        min_y = min_y.min(y);
        max_x = max_x.max(x + w);
        max_y = max_y.max(y + h);
    }
}

// Lines 741-747: Apply fixed padding
let border_padding: usize = 2;
let border_x = min_x.saturating_sub(border_padding);
let border_y = min_y.saturating_sub(border_padding);
let border_right = max_x + border_padding;
let border_bottom = max_y + border_padding;
```

**Why the revert happened (per dagre-to-draw-coordinate-mismatch.md):**

Phase 1 attempted to transform dagre bounds via `TransformContext::to_ascii()`, but:
- Node draw formula: `cx = (rect.x + rect.width/2.0 - dagre_min_x) * scale_x` (treating rect.x as center)
- `to_ascii()` formula: `x = (dagre_x - dagre_min_x) * scale_x + overhang + padding` (treating input as raw point)
- Result: 15+ cell offset between subgraph borders and member nodes

The revert accepted that member-node draw positions are already in correct coordinate frame, but discarded dagre's inter-subgraph spacing guarantees.

### Title Rendering (subgraph.rs:14-67)

Titles embedded in top border (not above):
- Corners placed at (x, y) and (x+w-1, y)
- Title text placed as: "─ Title ─" format between corners
- Remaining space filled with horizontal lines

**Critical protection gap:**
- `set_subgraph_border()` marks cells as `is_subgraph_border`
- Edges CAN overwrite via `set_with_connection()` which **does NOT check** `is_subgraph_border` (canvas.rs:159)
- Only `is_node` prevents overwrite

### Backward Edge Expansion (layout.rs:761-797)

For subgraphs with backward edges (from_y > to_y in TD):
```rust
let has_backward = edges.iter().any(|e| {
    from_in && to_in && from_y > to_y  // Backward in TD
});

if has_backward {
    let route_margin = BACKWARD_ROUTE_GAP + 2;  // = 4
    final_width += route_margin;
}
```

But router computes (router.rs:135):
```rust
let route_x = right_edge + BACKWARD_ROUTE_GAP;  // 2, not 4
```

**The mismatch:** Expansion adds 4 but router uses only 2.

## How

### Data Flow Trace: subgraph_edges.mmd fixture

Input fixture:
```
graph TD
subgraph sg1[Input]
  A[Data]
  B[Config]
end
subgraph sg2[Output]
  C[Result]
  D[Log]
end
A --> C
B --> D
```

**Phase 1: Graph Building**
- Nodes: A, B (parent=sg1), C, D (parent=sg2)
- Edges: A→C, B→D (cross-subgraph)
- Subgraphs: sg1={nodes:[A,B], title:"Input"}, sg2={nodes:[C,D], title:"Output"}

**Phase 2: Dagre Layout**

1. `LayoutGraph::from_digraph()`: Create compound nodes sg1, sg2
2. `nesting::run()`: Create border nodes with nesting edges
3. `rank::run()`: Assign ranks (TD: A,B → rank 0; C,D → rank 1)
4. `nesting::assign_rank_minmax()`: sg1.min/max_rank=0; sg2.min/max_rank=1
5. `border::add_segments()`: Create left/right border nodes per rank
6. `order::run()` + `position::run()`: Position all nodes in dagre float space
7. `border::remove_nodes()`: Compute bounds in dagre space (both have same x-range; dagre spacing normally prevents overlap but we discard it)

**Phase 3: Layout Conversion**

1. Node draw positions computed via node formula (scaling + overhang + padding)
2. `convert_subgraph_bounds()` ignores dagre bounds, scans member positions:
   - sg1: bounding box from A, B positions + 2-cell padding
   - sg2: bounding box from C, D positions + 2-cell padding

### Why Adjacent Subgraphs Overlap

When two subgraphs have members close vertically:
1. Each computes independent bounding box from its member nodes
2. Fixed 2-cell padding applied symmetrically
3. No consideration of spacing between subgraph pairs

Example: If sg1 has y ∈ [5,15] and sg2 has y ∈ [15,25]:
- sg1 borders: y=3, h=17 → rows [3,20]
- sg2 borders: y=13, h=17 → rows [13,30]
- Overlap at rows [13,20]

The member-node approach has no way to express "sg2 should be 2 cells below sg1" because it doesn't know the relationship between subgraph pairs.

## Why

### Pragmatic Tradeoff in Planning

The member-node approach was accepted as a pragmatic tradeoff:
- **dagre bounds are theoretically correct** — Border nodes positioned by dagre algorithm with inter-subgraph spacing
- **But translation is complex** — Node formula (right-edge offset + overhang) doesn't match `to_ascii()`
- **Member-node approach is simple** — Always correct in draw space, no translation, but loses dagre spacing

This tradeoff is documented in the Phase 1 revert: "use member-node bounds and accept loss of inter-subgraph spacing guarantees."

### Hardcoded Padding Symmetry

The 2-cell padding is symmetric (`saturating_sub(2)` on min, `add(2)` on max). Works for isolated subgraphs but doesn't account for:
- Inter-subgraph gaps (should be additive between pair, not per-subgraph)
- Directionality (space between sg1.right and sg2.left is different from space around a single subgraph)

### Border Cells are Unprotected

Design choice: `is_subgraph_border` cells can be overwritten by edges via `set_with_connection()` (canvas.rs:162-167). This allows edge-border merging but means borders aren't preserved as visual boundaries.

## Key Takeaways

- **dagre bounds are computed correctly but discarded** — The `_dagre_bounds` parameter is evidence of incomplete implementation. The fix should properly transform dagre Rects, not ignore them.
- **Member-node bounding boxes lose inter-subgraph spacing** — Fallback approach has no way to express spacing between adjacent subgraph pairs, causing overlaps.
- **Title rendering assumes exclusive row ownership** — Titles embedded in top border row, but layout doesn't reserve space. Content at same y causes collision.
- **Backward edge containment is brittle** — Fixed 4-cell expansion doesn't scale to multiple backward edges. No coordination between bounds computation and routing.
- **Border cells not protected from edge overwrite** — By design, `is_subgraph_border` cells can be overwritten. Allows merging but borders aren't preserved as visual boundaries.

## Open Questions

- Should subgraph bounds be computed from dagre Rects with proper coordinate translation that mirrors the node formula?
- Should layout explicitly allocate space between adjacent subgraphs (compound margin)?
- Should backward edge routing be constrained to max distance, or should bounds expand dynamically based on actual waypoints?
- Should border cells be protected from edge overwrite, or should edge-border crossings be intentional "gates"?
