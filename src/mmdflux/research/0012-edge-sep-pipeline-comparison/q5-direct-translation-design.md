# Q5: What would a direct dagre-to-ASCII coordinate translation look like?

## Summary

A direct translation approach would replace mmdflux's current 6-step pipeline (dagre output -> layer grouping -> sort by cross-axis -> grid position assignment -> stagger mapping -> draw coordinates) with a 3-step pipeline: take dagre's float coordinates, apply an ASCII-aware scaling function, and round to integer character cells. This is feasible and would preserve edge_sep effects naturally, but requires careful handling of the ~2:1 character aspect ratio, minimum spacing enforcement, and integer rounding collisions. The key insight is that dagre already produces coordinates that respect node_sep and edge_sep -- the current pipeline defeats this by discarding the cross-axis positions and re-assigning them through a grid.

## Where

Sources consulted:

- `/Users/kevin/src/mmdflux/src/render/layout.rs` -- current mmdflux pipeline (lines 177-581): `compute_layout_dagre()`, `compute_stagger_positions()`, `grid_to_draw_vertical()`, `grid_to_draw_horizontal()`, `map_cross_axis()`
- `/Users/kevin/src/mmdflux/src/dagre/position.rs` -- dagre's coordinate assignment (assigns float coords using BK algorithm)
- `/Users/kevin/src/mmdflux/src/dagre/bk.rs` -- Brandes-Kopf implementation, especially `horizontal_compaction()` (lines 640-692) where `edge_sep` vs `node_sep` is applied per-node
- `/Users/kevin/src/dagre/lib/position/index.js` -- dagre.js's direct approach: `positionY()` for rank axis, `positionX()` for cross axis, then done
- `/Users/kevin/src/dagre/lib/position/bk.js` -- dagre.js's `sep()` function (lines 389-425) showing how edge_sep/node_sep affects spacing
- `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/layout-algorithms/dagre/index.js` -- Mermaid's approach: calls `dagreLayout(graph)` and directly uses node.x/node.y as pixel positions for SVG
- `/Users/kevin/src/mmdflux/tests/fixtures/fan_in_lr.mmd` -- test case

## What

### Current Pipeline (6 steps)

The current `compute_layout_dagre()` in layout.rs does this:

1. **Run dagre**: Gets float coordinates with edge_sep/node_sep respected
2. **Group by primary coord**: Sorts nodes by y (TD/BT) or x (LR/RL), groups into layers by proximity (>25.0 gap = new layer)
3. **Sort within layer**: Orders by cross-axis dagre coordinate (x for TD, y for LR)
4. **Assign grid positions**: `compute_grid_positions()` -- gives each node a (layer, pos) integer pair, effectively discarding dagre's cross-axis float values
5. **Compute stagger**: `compute_stagger_positions()` -- tries to recover cross-axis differentiation by scaling dagre cross positions to ASCII space with a heuristic formula
6. **Grid to draw**: `grid_to_draw_vertical()`/`grid_to_draw_horizontal()` -- converts grid positions to pixel-like character coordinates

Steps 2-4 are where edge_sep information is lost. Dagre computes that dummy nodes should be edge_sep apart and real nodes node_sep apart, but the grid assignment (step 4) treats all nodes as equally spaced within a layer, and the stagger recovery (step 5) only partially restores the relative spacing.

### Proposed Direct Translation Pipeline (3 steps)

```
dagre float coords --> aspect-ratio-aware scaling --> integer rounding with collision repair
```

**Step 1: Raw dagre output** (unchanged)
- dagre produces `Rect { x, y, width, height }` for each node in float coordinates
- These already respect edge_sep between dummy nodes and node_sep between real nodes
- For LR/RL layouts, dagre uses BK to optimize the y-axis (cross-axis), placing nodes with proper separation

**Step 2: ASCII-aware scaling**
- Convert from dagre's abstract float coordinate space to character cells
- Account for the ~2:1 aspect ratio of terminal characters (each char is ~1 unit wide, ~2 units tall visually)
- Apply per-axis scale factors

**Step 3: Integer rounding with collision repair**
- Round all positions to integer character cells
- Post-process to enforce minimum spacing (no overlapping nodes)
- Clamp to canvas bounds

### dagre.js and Mermaid comparison

**dagre.js** (position/index.js) does direct translation in just 2 functions:
- `positionY()`: Assigns Y by walking layers top-to-bottom, accumulating `maxHeight + rankSep`
- `positionX()`: Uses BK to assign X coordinates with node_sep/edge_sep
- No intermediate grid. No stagger mapping. Coordinates are used directly.

**Mermaid** uses dagre's output directly for SVG rendering:
- Calls `dagreLayout(graph)` (line 165)
- Reads `node.x`, `node.y` from dagre's output
- Calls `positionNode(node)` which sets SVG element position directly
- No re-interpretation of coordinates at all

Both approaches work because they render to a continuous coordinate system (SVG/canvas pixels), not a discrete character grid.

## How

### Algorithm Design

```
fn compute_layout_direct(diagram: &Diagram, config: &LayoutConfig) -> Layout {
    // 1. Run dagre (same as today)
    let result = dagre::layout_with_labels(&dgraph, &dagre_config, ...);

    // 2. Compute scale factors for ASCII
    let (scale_x, scale_y) = compute_ascii_scales(&result, &node_dims, config);

    // 3. Transform each node's position
    let mut positions: HashMap<String, (usize, usize)> = HashMap::new();
    for (id, rect) in &result.nodes {
        let ascii_x = (rect.x * scale_x).round() as usize;
        let ascii_y = (rect.y * scale_y).round() as usize;
        positions.insert(id.clone(), (ascii_x, ascii_y));
    }

    // 4. Enforce minimum spacing (collision repair)
    enforce_min_spacing(&mut positions, &node_dims, config);

    // 5. Transform waypoints identically
    let waypoints = transform_waypoints(&result.edge_waypoints, scale_x, scale_y);

    // 6. Compute canvas size from actual positions
    let (width, height) = compute_canvas_bounds(&positions, &node_dims, config);

    Layout { ... }
}
```

### Scale Factor Computation

The critical question: what scale factors convert dagre's float space to ASCII character cells?

**dagre's coordinate space:**
- node_sep = 50.0 (default) between real node centers
- edge_sep = 20.0 (default) between dummy node centers
- rank_sep = 50.0 between layer centers
- Node dimensions are passed in character units (e.g., width=9, height=3 for `[Src A]`)

**ASCII character space:**
- Horizontal: 1 character = 1 unit
- Vertical: 1 character = 1 unit (but visually ~2x taller than wide)
- Minimum spacing: h_spacing=4 chars horizontal, v_spacing=3 chars vertical

**Scale factor derivation for TD/BT:**
- Primary axis (Y): `scale_y = (max_node_height + v_spacing) / (max_node_height + rank_sep)`
  - We want layers spaced by `max_height + v_spacing` chars
  - dagre spaces them by `max_height + rank_sep` abstract units
  - For typical values: `(3 + 3) / (3 + 50) = 6/53 ~ 0.113`
- Cross axis (X): `scale_x = (avg_node_width + h_spacing) / (avg_node_width + node_sep)`
  - We want nodes spaced by `width + h_spacing` chars
  - dagre spaces real nodes by `width + node_sep`
  - For typical values: `(9 + 4) / (9 + 50) = 13/59 ~ 0.22`

**Scale factor derivation for LR/RL:**
- Primary axis (X): `scale_x = (max_node_width + h_spacing) / (max_node_width + rank_sep)`
  - `(9 + 4) / (9 + 50) = 13/59 ~ 0.22`
- Cross axis (Y): `scale_y = (avg_node_height + v_spacing) / (avg_node_height + node_sep)`
  - For LR/RL with direction-aware spacing (node_sep ~ 6.0): `(3 + 3) / (3 + 6) = 6/9 ~ 0.67`
  - For default spacing (node_sep = 50.0): `(3 + 3) / (3 + 50) = 6/53 ~ 0.113` (too compressed!)

The direction-aware spacing in the current code (lines 240-258 of layout.rs) addresses this: for LR/RL, it sets `node_sep = avg_height * 2` and `edge_sep = avg_height * 0.8`. This makes the dagre coordinate space closer to ASCII space, reducing the scaling distortion.

### Worked Example: fan_in_lr.mmd

```
graph LR
    A[Src A] --> D[Target]
    B[Src B] --> D
    C[Src C] --> D
```

**Node dimensions** (character cells):
- A: width=9 ("Src A" + box), height=3
- B: width=9, height=3
- C: width=9, height=3
- D: width=10 ("Target" + box), height=3

**dagre configuration (direction-aware):**
- direction: LR
- node_sep = max(avg_height * 2, 6) = max(3*2, 6) = 6.0
- edge_sep = max(avg_height * 0.8, 2) = max(2.4, 2) = 2.4
- rank_sep = 50.0
- margin = 10.0

**Expected dagre output** (approximate float coordinates for LR):
- Layer 0 (rank 0): A, B, C -- arranged vertically by BK
- Layer 1 (rank 1): D -- single node

With node_sep=6 and BK centering:
- A: x=10, y=10 (margin)
- B: x=10, y=10+3+6=19
- C: x=10, y=19+3+6=28
- D: x=10+9+50=69, y=19 (centered among A,B,C)

**Scale factors:**
- scale_x (primary for LR) = (max_width + h_spacing) / (max_width + rank_sep) = (10+4)/(10+50) = 14/60 ~ 0.233
- scale_y (cross for LR) = (avg_height + v_spacing) / (avg_height + node_sep) = (3+3)/(3+6) = 6/9 ~ 0.667

**Scaled positions:**
- A: x = 10 * 0.233 = 2, y = 10 * 0.667 = 7
- B: x = 10 * 0.233 = 2, y = 19 * 0.667 = 13
- C: x = 10 * 0.233 = 2, y = 28 * 0.667 = 19
- D: x = 69 * 0.233 = 16, y = 19 * 0.667 = 13

**After padding adjustment (padding=1):**
- A: (1, 1), B: (1, 7), C: (1, 13), D: (15, 7)

**Spacing between A, B, C:** 7-1-3 = 3 chars (= v_spacing). Correct!

**Current mmdflux output** for comparison:
```
+-------+
| Src A |--+
+-------+  |
           |  +--------+
           +->| Target |
+-------+  |  +--------+
| Src B |--+
+-------+  |
           |
           |
+-------+  |
| Src C |--+
+-------+
```

Note: The current output has B,C,D staggered with uneven spacing (bigger gap between B and C than between A and B). A direct translation would produce uniform spacing because dagre places A, B, C with equal node_sep gaps.

### Handling edge_sep specifically

For a diagram with long edges producing dummy nodes:
```
graph TD
    A --> B
    A --> D
    B --> C
    C --> D
```

Layer 1 would contain B and a dummy node for the A->D long edge. With direct translation:
- B gets node_sep/2 on each side
- Dummy gets edge_sep/2 on each side
- The gap between dummy and B is `(node_sep + edge_sep) / 2 = (50 + 20) / 2 = 35`

After scaling, this becomes `35 * scale_x`. The dummy-to-real gap is visibly tighter than the real-to-real gap (35 vs 50 in dagre space). This is exactly the edge_sep effect that the current pipeline loses.

### Collision Repair

After rounding to integers, adjacent nodes might overlap. The repair algorithm:

```
fn enforce_min_spacing(positions, node_dims, config) {
    // For each layer (group by primary axis position):
    //   Sort nodes by cross-axis position
    //   Walk left to right (or top to bottom)
    //   If gap between adjacent nodes < min_spacing:
    //     Push the right node further right
    // Then center the layer to maintain balance
}
```

This is simpler than the current stagger computation because:
1. The initial positions are already good (from dagre)
2. We only need to fix rounding collisions, not reconstruct spacing from scratch
3. Most cases won't need any adjustment (dagre's spacing >> 1 character)

## Why

### Why this preserves edge_sep

The current pipeline loses edge_sep because it:
1. Groups nodes into layers (fine)
2. Assigns grid positions 0, 1, 2... within each layer (loses relative spacing)
3. Tries to recover via `compute_stagger_positions()` (partial recovery)

The stagger recovery uses this formula (layout.rs line 1103):
```rust
let target_stagger = (dagre_range / nodesep * (spacing as f64 + 2.0))
    .round().max(2.0).min(max_layer_content as f64 / 2.0);
```

This maps the full dagre cross-axis range to a target ASCII range, but it's a single linear scale applied uniformly. It doesn't distinguish between dummy gaps (edge_sep) and real gaps (node_sep). The stagger just preserves relative ordering and approximate proportions.

Direct translation preserves edge_sep because:
- dagre's BK algorithm computes `sep = (left_sep + node_sep) / 2` for real-real pairs and `sep = (edge_sep + edge_sep) / 2 = edge_sep` for dummy-dummy pairs (bk.rs lines 743-754)
- These separations are baked into the float coordinates
- Applying a uniform scale factor preserves the ratio between edge_sep and node_sep gaps
- Dummy nodes appear closer together than real nodes, which is the desired visual effect

### ASCII constraints that require attention

1. **Integer coordinates**: All positions must be whole numbers (character cells). Rounding can cause collisions when dagre's gap scales to <1 character.

2. **Aspect ratio**: Terminal characters are ~2x taller than wide. For LR/RL layouts, this means dagre's abstract coordinate space must be scaled differently on X vs Y. The current direction-aware `node_sep` computation (layout.rs lines 240-258) partially addresses this, but direct translation needs explicit aspect ratio in the scale factors.

3. **Minimum node spacing**: Nodes need at least 1 character of clearance for edge routing. If dagre places two nodes very close (edge_sep=2.4 with small dummy nodes), the scaled gap might be 0 or 1 characters.

4. **Canvas size constraints**: Unlike SVG, the canvas has a practical upper bound. A diagram with 50+ nodes shouldn't produce a 500-line output.

## Key Takeaways

- **The current pipeline is a workaround for not trusting dagre's cross-axis positions.** It re-derives positions from scratch using grid assignment, then tries to recover dagre's relative spacing through the stagger mechanism. This is fundamentally lossy.

- **dagre.js and Mermaid both use direct coordinate translation.** dagre.js assigns Y by layer accumulation and X by BK, then done. Mermaid reads node.x/node.y directly. Neither has an intermediate grid step.

- **Direct translation is simpler (3 steps vs 6) and preserves edge_sep natively.** The core algorithm is: scale, round, repair collisions. The stagger computation, grid position assignment, layer dimension calculation, and cross-axis mapping functions (~400 lines) could be replaced by ~100 lines of scale+round+repair.

- **The main risk is rounding collisions at small scales.** When dagre's abstract spacing (50 units for node_sep) scales down to 3-4 character cells, the difference between node_sep and edge_sep (50 vs 20 -> 3 vs 1.2 chars) might round to the same integer, eliminating the visual distinction.

- **The direction-aware spacing computation is still needed.** Without it, LR/RL layouts produce huge vertical gaps. Direct translation doesn't remove this need -- it just means the scaled dagre coordinates map more naturally to ASCII.

- **Waypoint transformation becomes trivial.** Currently, waypoints require per-rank anchor interpolation (the `map_cross_axis()` function and `rank_cross_anchors` mechanism, ~100 lines). With direct translation, waypoints use the same scale factors as nodes: `(wp.x * scale_x, wp.y * scale_y)`.

## Open Questions

- **What scale factors work across all diagram types?** The worked example uses a simple ratio, but diagrams with mixed node sizes (e.g., diamonds vs rectangles) may need per-layer or per-node scaling adjustments.

- **How should the collision repair handle cascading pushes?** If pushing node B right to avoid collision with A causes B to collide with C, the repair needs to cascade. This is essentially a constraint solver -- how far can it diverge from dagre's intended positions before the layout looks wrong?

- **Should dagre's config parameters be adjusted for ASCII?** Instead of scaling dagre's output, an alternative is to configure dagre with ASCII-appropriate values directly (e.g., `node_sep=4.0`, `edge_sep=2.0`, `rank_sep=6.0`). This would make the scale factors close to 1.0, reducing rounding issues. But it would mean dagre's internal BK algorithm operates with very small numbers, potentially causing precision issues.

- **Can the aspect ratio be handled inside dagre instead of outside?** If dagre's node dimensions were pre-scaled (multiply heights by 2 before passing to dagre), the output coordinates would already account for aspect ratio. This might simplify the external scaling.

- **How does this interact with edge label placement?** Labels have their own dummy nodes. If edge_sep affects label dummy spacing, direct translation would automatically space labels correctly. But labels also need to be readable (minimum width), which might conflict with tight edge_sep scaling.
