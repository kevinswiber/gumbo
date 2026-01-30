# Q3: What is mmdflux's stagger mapping doing that dagre.js/Mermaid don't?

## Summary

mmdflux implements a **three-phase coordinate transformation pipeline** that dagre.js/Mermaid does not use: (1) dagre layout produces continuous floating-point coordinates in internal space; (2) stagger mapping groups nodes into layers, extracts cross-axis positions, and scales them proportionally to ASCII grid space; (3) layer-based positioning converts these stagger positions back to character grid coordinates with integer rounding. This indirection exists primarily to **bridge ASCII grid constraints (integer coordinates, discrete spacing) with dagre's continuous optimization**, but the stagger mapping also enables **preservation of relative cross-axis positioning** that would otherwise be lost to uniform layer centering.

## Where

**Files Consulted:**
- `/Users/kevin/src/mmdflux/src/render/layout.rs` — main pipeline orchestration
- `/Users/kevin/src/mmdflux/src/dagre/mod.rs` — dagre layout entry point
- `/Users/kevin/src/mmdflux/src/dagre/bk.rs` — Brandes-Köpf coordinate assignment
- `/Users/kevin/src/mmdflux/src/dagre/position.rs` — dagre's coordinate output

## What

**The Complete Pipeline from Dagre Output to Final Draw Coordinates:**

```
1. Diagram Input (mmdflux graph)
   ↓
2. dagre::layout_with_labels()
   → Returns: floating-point (x, y) in internal space
   → Brandes-Köpf produces x-coords optimized for continuous space
   → Layer assignment produces y-coords based on rank + spacing
   ↓
3. Layer Grouping & Cross-Axis Extraction
   → Group nodes by primary coordinate (y for TD/BT, x for LR/RL)
   → Extract dagre_cross_positions: HashMap of (node_id → dagre center)
   → Establish layer boundaries with 25.0 unit tolerance
   ↓
4. Stagger Position Computation (compute_stagger_positions)
   → Find global dagre cross-axis range [min, max]
   → Detect if stagger exists (range > 1.0)
   → Calculate target stagger in ASCII space:
       target_stagger = (dagre_range / nodesep * (spacing + 2.0))
   → Compute scale factor: scale = target_stagger / dagre_range
   → For each node: cross_center = canvas_center + (dagre_val - dagre_center) * scale
   → Enforce minimum spacing between adjacent nodes
   ↓
5. Grid Position Assignment (grid_to_draw_vertical/horizontal)
   → If stagger_positions NOT empty:
       Use stagger-derived centers, place nodes around them
       Recalculate canvas dimensions from actual positions
   → If stagger_positions empty:
       Use original logic: center all nodes in layer
   ↓
6. Layer Start Extraction
   → For each layer: record layer_y_starts[i] or layer_x_starts[i]
   → These become anchor points for waypoint transformation
   ↓
7. Rank-Based Anchor Construction (rank_cross_anchors)
   → For each rank/layer, build (dagre_center, draw_center) pairs
   → Create per-rank piecewise linear mapping function
   ↓
8. Waypoint Transformation (map_cross_axis)
   → For each waypoint: look up its rank, get anchors at that rank
   → Interpolate/extrapolate dagre position → draw position
   → Use global_scale as fallback for single-anchor ranks
   ↓
9. Final Output: Layout struct
   → draw_positions: integer (usize, usize) coordinates
   → edge_waypoints: transformed waypoints
   → node_bounds: discrete bounds for rendering
```

## How

**Step-by-Step Breakdown of the Stagger Mapping Pipeline:**

### Phase 1: Dagre Layout Execution (compute_layout_dagre, lines 177-275)
- Creates internal dagre graph with node dimensions
- Configures node_sep and edge_sep based on direction (adaptive for LR/RL)
- Calls `dagre::layout_with_labels()` which returns continuous coordinates
- Example: Node A at dagre position (245.5, 50.0), Node B at (380.2, 50.0)

### Phase 2: Layer Grouping by Primary Coordinate (lines 277-328)
- For TD/BT: group by y-coordinate (primary axis = vertical)
- For LR/RL: group by x-coordinate (primary axis = horizontal)
- Sort within groups by secondary coordinate (x for TD/BT, y for LR/RL)
- Tolerance: nodes within 25.0 units grouped into same layer
- Result: `layers: Vec<Vec<String>>` with nodes sorted by crossing-reduced order from dagre

### Phase 3: Extract Dagre Cross-Positions (lines 343-355)
```rust
let dagre_cross_positions: HashMap<String, f64> = result
    .nodes
    .iter()
    .map(|(id, rect)| {
        let cross = if is_vertical {
            rect.x + rect.width / 2.0  // center_x for TD/BT
        } else {
            rect.y + rect.height / 2.0 // center_y for LR/RL
        };
        (id.0.clone(), cross)
    })
    .collect();
```
- Preserves dagre's continuous cross-axis positioning
- Maps to centers (not corners) for compatibility with Brandes-Köpf output

### Phase 4: Compute Stagger Positions (lines 1042-1157)

**Detailed algorithm:**

Step 1: Find global dagre cross-axis range
```
all_dagre_vals = [collect all cross-axis values]
dagre_min = minimum value
dagre_max = maximum value
dagre_range = dagre_max - dagre_min
```

Step 2: Return empty if no variation
```
if dagre_range < 1.0:
    return empty HashMap (no stagger needed)
```

Step 3: Compute required ASCII layer content
```
max_layer_content = max(
    for each layer:
        sum(node widths) + (num_nodes - 1) * spacing
)
```

Step 4: Calculate target stagger in ASCII space
```
max_half_cross = max(node_width / 2 for all nodes)
target_stagger = (dagre_range / nodesep * (spacing + 2.0))
                 .round()
                 .max(2.0)
                 .min(max_layer_content / 2.0)
```
- **Key insight:** Scale dagre's coordinate variation proportionally to ASCII spacing
- Nodesep is dagre's separation (e.g., 50.0 for TD/BT, 6.0-15.0 for LR/RL)

Step 5: Compute scale factor
```
scale = target_stagger / dagre_range
        (if dagre_range > epsilon, else 0.0)
```

Step 6: For each node, compute draw cross-center
```
canvas_center = (canvas_content_start + total_content_width / 2)
dagre_center = (dagre_min + dagre_max) / 2.0

for each node:
    offset = (dagre_val - dagre_center) * scale
    cross_center = canvas_center + offset
    cross_center = max(cross_center, content_start + dimension/2)
```

Step 7: Enforce minimum spacing between nodes in same layer
```
for each layer with 2+ nodes:
    sort nodes by cross_center
    for each pair (i, i+1):
        if nodes overlap:
            push node[i+1] right by (spacing)
```

**Result:** `HashMap<node_id, cross_axis_center_draw_position>`
- Each node's cross-axis center in ASCII character grid
- Only populated if dagre produced varied positioning
- Empty HashMap triggers fallback to centered positioning

### Phase 5: Layer-Aware Grid Positioning (grid_to_draw_vertical/horizontal, lines 717-1032)

Two code paths based on `has_stagger`:

**WITH STAGGER** (lines 778-806 for vertical):
```
for each node in layer:
    y = layer_y_starts[layer_idx]  // primary axis from layers
    x = stagger_centers[node_id]   // cross-axis from stagger map
    x = x - width/2                // convert center to top-left corner
    draw_positions[node_id] = (x, y)
```

**WITHOUT STAGGER** (lines 808-841 for vertical):
```
for each layer:
    center_layer_width = sum(node widths) + spacing
    layer_start_x = canvas_center - center_layer_width/2  // centered
    for each node:
        x = layer_start_x + cumulative_offset
        y = layer_y_starts[layer_idx]
```

### Phase 6: Rank-Based Anchor Construction (lines 426-453)
```rust
let rank_cross_anchors: Vec<Vec<(f64, f64)>> = layers
    .iter()
    .map(|layer| {
        let anchors: Vec<(f64, f64)> = layer
            .iter()
            .filter_map(|node_id| {
                let dagre_center = dagre_node.x + dagre_node.width/2;
                let draw_center = (draw_x + w/2) as f64;
                Some((dagre_center, draw_center))
            })
            .collect();
        anchors.sort_by(|a, b| a.0.cmp(&b.0));
        anchors
    })
    .collect();
```
- Creates per-rank mapping: (dagre_position → draw_position)
- Enables waypoint transformation with per-rank accuracy
- Accounts for potential stagger-based reordering

### Phase 7: Waypoint Cross-Axis Transformation (map_cross_axis, lines 1167-1245)

Uses anchors to map waypoint coordinates:

**No anchors:** Return canvas center
**1 anchor:** Offset from anchor using global scale
**2+ anchors:** Piecewise linear interpolation
```
if waypoint.dagre_pos < anchors[0]:
    ratio = (waypoint - anchors[0]) / (anchors[1] - anchors[0])
    result = anchors_draw[0] + ratio * (anchors_draw[1] - anchors_draw[0])
```

**Global scale:** Computed from first/last anchors across all ranks as fallback

## Why

### NECESSARY for ASCII Constraints:

1. **Integer Coordinate Grid**
   - Dagre produces continuous floats (e.g., 245.5, 380.2)
   - ASCII rendering requires character cell positions (integers: 240, 380)
   - Direct rounding loses proportional information
   - **Stagger mapping preserves proportions before rounding**

2. **Discrete Layer Spacing**
   - Dagre uses `rank_sep: 50.0` (continuous spacing in internal units)
   - ASCII uses `v_spacing: 3` (discrete rows between layers)
   - Stagger scaling maps continuous separation to ASCII integer grid
   - Without it: all cross-axis variation lost to layer centering

3. **Character Cell Alignment**
   - Long edges need waypoints at specific character positions
   - Without per-rank anchors, waypoints would be linearly interpolated
   - **Anchor mapping uses actual node positions, not linear extrapolation**
   - More accurate routing, fewer collisions

### ARTIFACT of Grid-Based Design (could be simplified):

1. **Layer Grouping Overhead**
   - `compute_layout_dagre` re-implements layer grouping (lines 291-328)
   - Dagre already computed ranks internally
   - Could extract rank info directly instead of re-grouping by coordinate
   - **This is redundant but non-harmful**

2. **Two-Pass Grid Positioning**
   - Stagger mapping computes positions in abstract space
   - Grid functions then convert to draw coordinates
   - Could be combined into single pass
   - **This adds complexity but enables flexible positioning schemes**

3. **Scale Factor Heuristics**
   - Target stagger formula includes magic: `dagre_range / nodesep * (spacing + 2.0)`
   - Attempts to preserve dagre's intent but is empirical
   - No formal derivation from Sugiyama or Brandes-Köpf theory
   - **Necessary for practical ASCII output, but could be more principled**

## Key Takeaways

- **The stagger mapping is a coordinate-space bridge, not a substitute algorithm.** Dagre still does layout optimization (ranking, crossing reduction, Brandes-Köpf). mmdflux adds a post-processing layer for ASCII rendering constraints. It preserves dagre's relative positioning while adapting to character grid.

- **Three distinct transformations in sequence:** Dagre space (continuous, optimized) → ASCII stagger space (scaled but continuous) → Draw grid (integer, discrete). Each transformation has a specific purpose and cannot be eliminated without loss.

- **The layer grouping is essential for waypoint accuracy.** Per-rank anchors enable precise waypoint placement. Linear interpolation would produce different routing.

- **Stagger detection is performance-smart.** Empty map return when dagre produces uniform positioning. Falls back to efficient centered layout. Most simple diagrams take the fast path (no stagger computation).

- **ASCII constraints mandate the indirection.** Integer coordinate grid is fundamentally different from continuous layout. Proportional scaling preserves intent better than rounding/snapping. These are necessary features, not optional optimizations.

## Open Questions

- What happens when dagre places nodes outside expected ranges? Is the clamping in `compute_stagger_positions` (lines 1131-1132) always safe, or can it produce overlaps?

- The `map_cross_axis` function uses piecewise linear interpolation for waypoints. Does this ever diverge significantly from what the Brandes-Köpf algorithm intended, especially in wide/tall diagrams?

- Could the layer grouping tolerance (25.0 units at line 302) be data-driven instead of hardcoded? What if diagrams have unusual spacing?

- The target stagger formula (line 1103) includes `spacing + 2.0`. Is the `2.0` empirically determined? What principle guides this?
