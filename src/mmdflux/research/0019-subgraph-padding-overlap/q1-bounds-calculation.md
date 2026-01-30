# Q1: mmdflux subgraph bounds calculation

## Summary

mmdflux calculates subgraph bounds by computing the bounding box of member nodes in draw coordinates, then adding fixed padding constants (border_padding=2 cells, title_height=1 row) around them. The dagre layout algorithm is responsible for positioning the member nodes and border nodes, but the actual `_dagre_bounds` parameter from dagre's `remove_nodes()` is completely ignored—bounds are instead derived from draw position coordinates of member nodes, not from the border node positions computed by dagre. This creates a disconnect where dagre allocates layout space for border nodes, but the final bounds calculation uses a hardcoded padding value that may not match dagre's actual node separation constraints.

## Where

Sources consulted:
- `/Users/kevin/src/mmdflux-subgraphs/src/render/layout.rs` lines 692-749: `convert_subgraph_bounds()` function (the actual bounds calculation)
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/border.rs` lines 67-125: `remove_nodes()` function (border node extraction, returns Rect but is ignored)
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/mod.rs` lines 113-128: orchestration of border node lifecycle
- `/Users/kevin/src/mmdflux-subgraphs/src/render/layout.rs` lines 482-489: call to `convert_subgraph_bounds()`
- `/Users/kevin/src/mmdflux-subgraphs/src/render/subgraph.rs` lines 14-52: subgraph border rendering code

## What

**Exact padding values:**
- `border_padding: usize = 2` (line 705 in layout.rs): cells between member nodes and border rectangle
- `title_height: usize = 1` (line 706 in layout.rs): row above the border for title text

**Bounds calculation inputs (lines 715-723):**
The function scans all member nodes in draw coordinates to find:
- `min_x`: leftmost position of any member node
- `min_y`: topmost position of any member node
- `max_x`: rightmost edge (position + width) of any member node
- `max_y`: bottommost edge (position + height) of any member node

**Bounds calculation formula (lines 730-734):**
```
border_x = min_x - border_padding (saturating_sub to prevent underflow)
border_y = min_y - border_padding - title_height
border_right = max_x + border_padding
border_bottom = max_y + border_padding

width = border_right - border_x
height = border_bottom - border_y
```

**What's ignored:**
The `_dagre_bounds` parameter (HashMap<String, Rect> from dagre's `remove_nodes()`) is prefixed with underscore but is neither used nor read. The `remove_nodes()` function in border.rs (lines 89-121) computes bounds from positioned border node coordinates:
- `x_min` from left border nodes' x positions
- `x_max` from right border nodes' x positions
- `y_min` and `y_max` from border top/bottom or left/right node y positions
- Returns these as dagre::Rect in a HashMap

But this information is discarded in `convert_subgraph_bounds()`.

## How

**Step-by-step execution path:**

1. **Dagre border node creation** (border.rs, `add_segments()`):
   - For each subgraph, left and right border nodes are created for each rank in the subgraph's span (lines 34-54)
   - Border nodes are linked vertically: `lg.add_nesting_edge(left_nodes[i], left_nodes[i+1], 1.0)`
   - These edges force dagre's layout to allocate vertical separation (edge constraints)

2. **Dagre layout phases** (mod.rs):
   - Border nodes participate in ordering (phase 3, line 118) and positioning (phase 4, line 121)
   - They are subject to `node_sep` and `rank_sep` constraints like regular nodes
   - After positioning, they occupy actual float coordinates in `lg.positions[]`

3. **Border bounds extraction** (border.rs, `remove_nodes()`):
   - Extracts positions from positioned border nodes (lines 90-107)
   - Computes x_min/x_max from left/right nodes' x values
   - Computes y_min/y_max from top/bottom (or left/right) nodes' y values
   - Returns Rect with center point and dimensions (lines 109-121)
   - This returned HashMap is stored in `LayoutResult.subgraph_bounds`

4. **Translation to draw coordinates** (layout.rs, `compute_layout_direct()`):
   - Scales all dagre positions (including border nodes) via `TransformContext` (lines 440-449)
   - Calls `convert_subgraph_bounds()` with:
     - `result.subgraph_bounds`: the ignored Rect HashMap from dagre
     - `draw_positions`: HashMap of actual member node positions in draw coordinates
     - `node_dims`: HashMap of member node dimensions

5. **Draw-coordinate bounds calculation** (layout.rs, `convert_subgraph_bounds()`):
   - Loops through member nodes only (line 715: `for node_id in &sg.nodes`)
   - Finds min/max positions from draw_positions HashMap
   - Adds hardcoded padding: 2 cells on left/right, 1+2 cells on top/bottom
   - Returns SubgraphBounds with these computed bounds

6. **Canvas expansion** (layout.rs, lines 491-497):
   - After subgraph bounds are computed, canvas width/height are expanded to fit borders:
   ```rust
   for sb in subgraph_bounds.values() {
       width = width.max(sb.x + sb.width + config.padding);
       height = height.max(sb.y + sb.height + config.padding);
   }
   ```

7. **Rendering** (subgraph.rs, `render_subgraph_borders()`):
   - Draws border rectangle at (bounds.x, bounds.y) with dimensions (bounds.width, bounds.height)
   - Title text placed at (x + i, y - 1) for each character

## Why

**Design rationale:**

The hardcoded padding approach is pragmatic for rendering but creates a mismatch with dagre's layout constraints:

1. **Dagre's border nodes serve ordering and containment**, not sizing:
   - They constrain node ordering (via barycenter heuristic in order phase)
   - They create vertical linkage that enforces rank participation
   - But they don't directly control the final padding amount

2. **The 2-cell + title height padding is a heuristic**:
   - 2 cells provides space to see member nodes inside the border
   - 1 row title + 1 row padding = 2 rows above (saturating_sub prevents clipping)
   - This is independent of dagre's node_sep and rank_sep settings

3. **Why the dagre bounds are ignored**:
   - Dagre's border Rect is in dagre coordinate space (floats, before scaling)
   - The rendering layer works in draw coordinates (integers, after scaling)
   - A direct scale-and-translate of dagre bounds would require the TransformContext
   - Instead, the code takes the simpler path: use member node positions in draw space + hardcoded padding

**Constraint interaction:**

- dagre's `node_sep` (default 50.0 floats) controls spacing between nodes horizontally
- dagre's `rank_sep` (default 50.0 floats) controls spacing between ranks vertically
- These are scaled by `scale_x` and `scale_y` (computed at line 263-270)
- After collision repair and rank_gap_repair, minimum gaps are enforced (config.h_spacing and config.v_spacing)
- But border padding is applied *after all this*, with fixed values (2 cells)

This can cause overlaps if:
- Member nodes are tightly packed (collision repair shrinks them closer)
- Padding is larger than the gap between final member positions and desired border boundary
- The formula assumes member positions already have proper clearance

## Key Takeaways

- **Bounds are computed from member node positions in draw coordinates, not from dagre's border node positions**. The `_dagre_bounds` parameter is generated by dagre but completely discarded.
- **Padding is fixed (2 cells left/right, 1 row title + 2 cells top/bottom)**, not derived from layout algorithm spacing parameters. This decouples subgraph containment from node separation constraints.
- **Border nodes do participate in the layout** (they affect ordering and ranking), but their final positioned coordinates are not used to compute bounds—they are only used to constrain the layout process itself.
- **Canvas expansion happens after bounds calculation**, so subgraph borders can extend beyond the base node extent without explicit collision detection.
- **The rendering coordinates assume bounds.x/y are ready to use as border top-left corners**, with title rendered one row above at (x + char_offset, y - 1).

## Open Questions

- What is the actual purpose of computing `_dagre_bounds` in `remove_nodes()` if it's never used? Could it have been intended as a future improvement to derive padding from layout constraints?
- Does the fixed padding of 2 cells cause visible overlaps or awkward spacing in practice? The code has no overlap detection between subgraph borders and member nodes.
- Why does `convert_subgraph_bounds()` use `saturating_sub()` for `border_padding` but then adds `border_right = max_x + border_padding` without saturation? This suggests asymmetric handling of left vs. right padding.
- How does the hardcoded padding interact with the diagram's overall `config.padding` parameter? The diagram padding (line 488, default 1) is applied separately during canvas sizing (line 495).
