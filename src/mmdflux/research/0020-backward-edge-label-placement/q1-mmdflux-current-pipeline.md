# Q1: How does mmdflux compute backward edge label positions today?

## Summary

mmdflux computes backward edge label positions through a two-stage coordinate transformation pipeline: (1) dagre creates a label dummy node at the label's rank during normalization and assigns it coordinates during the layout phase, and (2) the render layer transforms these dagre coordinates to ASCII draw coordinates using `transform_label_positions_direct()`, which applies uniform scaling and rank-based snapping for the primary axis. However, for backward edges, the label's cross-axis position diverges from the actually routed edge because the label position is computed from the label dummy's coordinate (static dagre position), while backward edge routing is computed synthetically via `generate_backward_waypoints()` that positions the edge at a different cross-axis location entirely.

## Where

**Sources consulted:**
- `src/dagre/normalize.rs` (lines 136-388): EdgeLabelInfo, DummyNode, label dummy creation and position extraction
- `src/render/layout.rs` (lines 100-514): compute_layout_direct(), transform_label_positions_direct() (lines 814-848)
- `src/render/edge.rs` (lines 30-222): render_edge() and label rendering logic
- `src/render/router.rs` (lines 115-154): generate_backward_waypoints() and is_backward_edge()
- `src/dagre/mod.rs` (lines 54-158): layout_with_labels() orchestration and label position extraction

## What

### 1. Label Dummy Creation During Normalization (dagre/normalize.rs)

**Lines 225-270**: When normalizing long edges (edges spanning multiple ranks), normalize.rs:
- Calculates `label_rank = (from_rank + to_rank) / 2` for edges with labels (line 226-230)
- Creates a `DummyNode::edge_label()` at the midpoint rank with the label's width/height dimensions (lines 242-257)
- Inserts this label dummy into the graph's node arrays, giving it unique coordinates during layout (lines 259-266)
- Tracks the label dummy's index in `chain.label_dummy_index` for later retrieval (line 269)

The `DummyNode` structure (lines 51-103) stores:
- `dummy_type: DummyType::EdgeLabel` — marks this as a label carrier
- `edge_index: usize` — original edge index (e.g., edge 0)
- `rank: i32` — the layer the label occupies (e.g., rank 1 for edges spanning ranks 0-2)
- `width, height: f64` — label dimensions in layout units
- `label_pos: LabelPos` — position hint (Center, Left, Right)

### 2. Label Position Extraction (dagre/normalize.rs & mod.rs)

**Lines 359-388 (normalize.rs)** - `get_label_position()`:
- Iterates through dummy_chains to find the label dummy for an edge
- Extracts its `position` and `dimensions` from the LayoutGraph (line 374-375)
- Computes the **center** of the label dummy: `(pos.x + dims.0 / 2.0, pos.y + dims.1 / 2.0)` (lines 378-380)
- Returns a `WaypointWithRank` containing the **dagre coordinate** and the **rank** it occupies

**Lines 127-133 (dagre/mod.rs)** - Main layout orchestration:
```rust
let mut label_positions = HashMap::new();
for chain in &lg.dummy_chains {
    if let Some(pos) = normalize::get_label_position(&lg, chain.edge_index) {
        label_positions.insert(chain.edge_index, pos);
    }
}
```
Collects all label positions from dummy chains into a HashMap indexed by original edge index.

### 3. Coordinate Transformation to ASCII (render/layout.rs)

**Lines 814-848** - `transform_label_positions_direct()`:
```rust
fn transform_label_positions_direct(
    label_positions: &HashMap<usize, WaypointWithRank>,
    edges: &[Edge],
    ctx: &TransformContext,
    layer_starts: &[usize],
    is_vertical: bool,
    canvas_width: usize,
    canvas_height: usize,
) -> HashMap<(String, String), (usize, usize)>
```

For each label position:
1. **Primary axis (Y for TD/BT, X for LR/RL)**: Uses **rank-based snapping** via `layer_starts[rank]` (lines 828-829)
   - The rank indicates which layer (0, 1, 2, ...) or fractional rank (1.5 for label between layers)
   - Snaps to the precomputed draw coordinate for that rank

2. **Cross axis (X for TD/BT, Y for LR/RL)**: Uses **uniform scaling** (lines 830)
   - Applies `ctx.to_ascii(wp.point.x, wp.point.y)` which scales dagre coordinates uniformly
   - Formula: `((dagre_x - dagre_min_x) * scale_x).round() as usize + offsets`

3. **Result**: Produces a draw coordinate `(x, y)` stored in `edge_label_positions` HashMap by edge key `(from_id, to_id)`

### 4. Label Rendering (render/edge.rs)

**Lines 678-707** - `render_all_edges_with_labels()`:
- Checks if a precomputed label position exists in `edge_label_positions` (line 685)
- If found and within canvas bounds, calls `draw_label_at_position()` (line 692)
- If not found, falls back to heuristic `draw_edge_label_with_tracking()` (lines 694-700)

**Lines 711-734** - `draw_label_at_position()`:
- Takes the precomputed position `(x, y)`
- Centers the label: `label_x = x.saturating_sub(label_len / 2)` (line 719)
- Writes label characters to the canvas, avoiding node cells (lines 722-727)

### 5. Backward Edge Waypoint Generation (render/router.rs)

**Lines 115-154** - `generate_backward_waypoints()`:
- For backward edges (detected by comparing source/target node positions), generates **synthetic waypoints** at a completely different location
- For TD/BT: Routes to the right: `route_x = right_edge + BACKWARD_ROUTE_GAP` (line 135)
- For LR/RL: Routes below: `route_y = bottom_edge + BACKWARD_ROUTE_GAP` (line 146)
- Returns waypoints: `[(route_x, src_center_y), (route_x, tgt_center_y)]` for TD/BT

These synthetic waypoints are used in `route_edge()` (lines 223-235) to create the routed path segments, which are completely independent of the dagre label dummy's coordinates.

## How

### Pipeline for Backward Edge Labels (End-to-End)

**Stage 1: Dagre Layout (src/dagre/)**
1. Input: Diagram with backward edge, label width/height provided
2. Normalization runs: Creates label dummy at midpoint rank (if edge spans multiple ranks) with the specified dimensions
3. Layout assigns coordinates to the label dummy based on its rank and crossing reduction constraints
4. Result: Label dummy positioned at dagre coordinates, e.g., `(x_label=150.0, y_label=90.0, rank=1)`

**Stage 2: Coordinate Transformation (src/render/layout.rs)**
1. Input: dagre label dummy position `(150.0, 90.0, rank=1)`
2. `transform_label_positions_direct()` converts to draw coordinates:
   - Primary axis (Y): `layer_starts[rank]` → e.g., `y_draw = 8` (snaps to rank 1's draw position)
   - Cross axis (X): `((150.0 - min_x) * scale_x).round()` → e.g., `x_draw = 45` (uniformly scaled)
3. Result: Label position `(45, 8)` stored in `edge_label_positions`

**Stage 3: Backward Edge Routing (src/render/router.rs)**
1. Input: Same backward edge (source at top, target at bottom)
2. `route_edge()` detects it's backward, has no dagre waypoints (stripped in phase I), calls `generate_backward_waypoints()`
3. Synthetic waypoints generated: `[(right_edge + gap, src_y), (right_edge + gap, tgt_y)]` → e.g., `[(80, 3), (80, 15)]`
4. Segments created through these waypoints using `build_orthogonal_path_with_waypoints()`
5. Result: Edge routed vertically at x=80, far from label at x=45

### Point of Divergence

The **cross-axis coordinate diverges** because:
- **Label position**: Computed from dagre label dummy's position → X-coordinate determined by dagre's layout constraints
- **Routed edge**: Computed synthetically → X-coordinate determined by `right_edge + BACKWARD_ROUTE_GAP` constant

For a TD/BT backward edge with a label:
- Label may be positioned at `x=45` (scaled from dagre dummy at `x=150.0`)
- Edge routes at `x=80` (right side of nodes + gap)
- Result: Label appears 35 units away from the routed edge

### Rank-Based Snapping (why primary axis matches)

The primary axis works correctly because:
1. Dagre assigns the label dummy to a specific rank (e.g., rank 1)
2. `layer_starts` array maps each rank to its draw coordinate based on actual node positions
3. Both label position and edge waypoints snap to the same `layer_starts[rank]`, so they align on the primary axis
4. This was the fix implemented in plan 0025, phase 2

## Why

The design rationale behind the divergence:

1. **Label Dummy Purpose**: The label dummy node in dagre serves crossing-reduction and layout purposes — it must participate in the full Sugiyama algorithm to get pushed aside by other nodes and to affect layer spacing. It produces a reasonable dagre coordinate for the label's primary-axis position.

2. **Backward Edge Synthetic Routing**: Backward edges without dagre waypoints are routed via `generate_backward_waypoints()` to avoid overlaps with forward edges. This uses a **perimeter-based strategy** (route to the right/bottom side) rather than the label dummy's embedded position. This is necessary because long backward edges with waypoints are stripped (phase I.5 in layout.rs lines 474-483) to use compact synthetic routing instead.

3. **Coordinate Transformation Gap**: The `transform_label_positions_direct()` function was designed to handle **forward edges and long backward edges with waypoints** (where dagre provides explicit waypoints). For backward edges relying on synthetic routing, the label dummy's dagre coordinate is irrelevant because the routed edge takes a completely different path. The current approach assumes the label's dagre position is always the right answer, which fails for this case.

4. **Mermaid's Solution**: Mermaid (as noted in research plan) recomputes label positions from the actual **rendered edge path** using `calcLabelPosition()` — a geometric midpoint traversal that finds the label's ideal location along the routed segments. mmdflux currently skips this step for precomputed positions, trusting the dagre coordinates unconditionally.

## Key Takeaways

- **Label dummies are created at dagre's computed midpoint rank** with dimensions, providing the primary-axis rank correctly
- **Cross-axis coordinate is scaled uniformly from dagre's layout**, which is appropriate for forward edges but misses the mark for backward edges
- **Backward edges route synthetically** around the nodes using `generate_backward_waypoints()`, which selects a perimeter-based location independent of the label dummy's position
- **The divergence occurs because two independent systems produce cross-axis coordinates**: dagre's label dummy layout vs. router's synthetic waypoint generation
- **Primary-axis alignment works** because both systems snap to `layer_starts[rank]`, but this masks the cross-axis issue
- **The root cause**: Precomputed label positions from dagre are treated as gospel, but for backward edges without dagre waypoints, the label position should be derived from the actual routed path, not from the label dummy's coordinate

## Open Questions

- In `compute_layout_direct()`, Phase I.5 (lines 468-483) explicitly strips dagre waypoints for backward edges when ranks are doubled. Why not also strip or recompute label positions at this stage?
- Does the label position need to be exact at the midpoint of the routed edge path, or is approximate proximity sufficient for ASCII rendering?
- How do we determine which backward edges have "real" dagre waypoints (long edges) vs. those using purely synthetic routing?
