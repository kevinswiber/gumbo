# mmdflux Edge Attachment Point Analysis

## 1. Complete Data Flow: Layout to Rendered Edge

The pipeline has five distinct stages:

### Stage 1: Layout (`compute_layout_dagre()` in `src/render/layout.rs`)

The dagre-based layout produces:
- `node_bounds: HashMap<String, NodeBounds>` -- bounding box for each node
- `edge_waypoints: HashMap<(String, String), Vec<(usize, usize)>>` -- waypoints for long edges (spanning 2+ ranks)
- `node_shapes: HashMap<String, Shape>` -- shape of each node (for intersection dispatch)
- `edge_label_positions` -- pre-computed label centers

Waypoints come from dagre's normalization phase. Long edges (spanning 2+ ranks) get dummy nodes inserted at intermediate ranks. After coordinate assignment, these dummy node positions are transformed from dagre's internal coordinate space (node_sep=50, rank_sep=50) to ASCII draw coordinates using `map_cross_axis()` (layout.rs:863) with per-rank anchor interpolation.

Short edges (spanning 1 rank) get **no waypoints** -- the `edge_waypoints` map has no entry for them.

### Stage 2: Routing (`route_all_edges()` in `src/render/router.rs`)

```rust
// router.rs:712-721
pub fn route_all_edges(
    edges: &[Edge],
    layout: &Layout,
    diagram_direction: Direction,
) -> Vec<RoutedEdge> {
    edges
        .iter()
        .filter_map(|edge| route_edge(edge, layout, diagram_direction))
        .collect()
}
```

Each edge is routed **independently** via `route_edge()`. The router has **no knowledge of other edges**.

### Stage 3: Attachment Point Calculation (`route_edge()` -> `calculate_attachment_points()`)

`route_edge()` (router.rs:97-153) dispatches to one of two paths:

**Path A: With waypoints** (`route_edge_with_waypoints`, router.rs:159-204):
```
1. calculate_attachment_points(from_bounds, from_shape, to_bounds, to_shape, &waypoints)
2. clamp_to_boundary(src_attach_raw, from_bounds)
3. clamp_to_boundary(tgt_attach_raw, to_bounds)
4. offset_from_boundary(src_attach, from_bounds)  -- push 1 cell outside node
5. offset_from_boundary(tgt_attach, to_bounds)    -- push 1 cell outside node
6. Build segments: connector + orthogonal path through waypoints
```

**Path B: Direct (no waypoints)** (`route_edge_direct`, router.rs:210-267):
```
1. calculate_attachment_points(from_bounds, from_shape, to_bounds, to_shape, &[])
2. clamp_to_boundary(src_attach_raw, from_bounds)
3. clamp_to_boundary(tgt_attach_raw, to_bounds)
4. offset_from_boundary(src_attach, from_bounds)
5. offset_from_boundary(tgt_attach, to_bounds)
6. Build segments: connector + direction-appropriate path
```

### Stage 4: Intersection Calculation (`calculate_attachment_points()` in `src/render/intersect.rs:153-178`)

```rust
pub fn calculate_attachment_points(
    source_bounds: &NodeBounds,
    source_shape: Shape,
    target_bounds: &NodeBounds,
    target_shape: Shape,
    waypoints: &[(usize, usize)],
) -> ((usize, usize), (usize, usize)) {
    let source_center = (source_bounds.center_x(), source_bounds.center_y());
    let target_center = (target_bounds.center_x(), target_bounds.center_y());

    // Source attachment: intersect towards first waypoint or target center
    let source_attach = if let Some(&first_wp) = waypoints.first() {
        intersect_node(source_bounds, first_wp, source_shape)
    } else {
        intersect_node(source_bounds, target_center, source_shape)
    };

    // Target attachment: intersect towards last waypoint or source center
    let target_attach = if let Some(&last_wp) = waypoints.last() {
        intersect_node(target_bounds, last_wp, target_shape)
    } else {
        intersect_node(target_bounds, source_center, target_shape)
    };

    (source_attach, target_attach)
}
```

The critical detail: **the "approach point" that determines where the edge attaches is either:**
- The first/last waypoint (for long edges), or
- The other node's center (for direct edges with no waypoints)

### Stage 5: Rendering (`render_all_edges_with_labels()` in `src/render/edge.rs`)

Two passes:
1. Draw all segments and arrows for every edge
2. Draw all labels (with collision avoidance against nodes and other labels)

---

## 2. Exact Code Path Causing Overlapping Attachment Points

### Concrete Example: `multiple_cycles.mmd`

```
graph TD
    A[Top] --> B[Middle]
    B --> C[Bottom]
    C --> A        (backward, spans 2 ranks)
    C --> B        (backward, spans 1 rank)
```

Current output:
```
  +-------+
  | Top   |
  +-------+
     | ^
     +<+---+      <-- Two edges leave/enter at same column
      v    |
 +--------+|
 | Middle ||
 +--------+|
      ^    |
      |    |
      |+---+
 +--------+
 | Bottom |
 +--------+
```

### Tracing the overlap for edges leaving node C (Bottom)

Node C ("Bottom") has two backward edges: C->A and C->B.

**Edge C->A** (backward, spans 2 ranks):
1. `route_edge()` finds waypoints in `layout.edge_waypoints` for key ("C", "A")
2. Since `is_backward_edge()` returns true (A.y < C.y in TD), waypoints are reversed
3. `calculate_attachment_points()` is called with these reversed waypoints
4. Source attach (C): `intersect_node(C_bounds, first_reversed_waypoint, Rectangle)`
5. Target attach (A): `intersect_node(A_bounds, last_reversed_waypoint, Rectangle)`

**Edge C->B** (backward, spans 1 rank):
1. `route_edge()` finds **no waypoints** (short edge, only spans 1 rank)
2. Falls through to `route_edge_direct()`
3. `calculate_attachment_points()` called with empty waypoints
4. Source attach (C): `intersect_node(C_bounds, B_center, Rectangle)`
5. Target attach (B): `intersect_node(B_bounds, C_center, Rectangle)`

### Why they overlap

Both backward edges C->A and C->B compute their **source attachment on node C independently**. Each one fires a ray from C's center toward its respective approach point:

- C->A: ray toward the first waypoint (which is near C, at the rank between B and C)
- C->B: ray toward B's center (directly above C)

If these two approach points are at similar angles relative to C's center, `intersect_rect()` will return the **same boundary point** on C. Since nodes are typically centered vertically, both approach points are roughly directly above C's center, yielding the same attachment at `(center_x, top_y)`.

The same problem occurs on the target side. Both edges arriving at node A compute:
- C->A: ray from the last waypoint into A
- A<-B (forward): ray from B's center into A

When B is directly below A, both rays approach A from below at the same angle, producing the same bottom-center attachment point on A.

### The root cause in `intersect_rect()` (intersect.rs:52-79)

```rust
pub fn intersect_rect(bounds: &NodeBounds, point: FloatPoint) -> FloatPoint {
    let x = bounds.center_x() as f64;
    let y = bounds.center_y() as f64;
    let dx = point.x - x;
    let dy = point.y - y;
    let w = bounds.width as f64 / 2.0;
    let h = bounds.height as f64 / 2.0;

    if dy.abs() * w > dx.abs() * h {
        // Steeper than diagonal -> top or bottom edge
        let h = if dy < 0.0 { -h } else { h };
        (h * dx / dy, h)
    } else {
        // Shallower -> left or right edge
        let w = if dx < 0.0 { -w } else { w };
        (w, w * dy / dx)
    }
}
```

When two approach points are at similar angles (e.g., both nearly directly above), the computed intersection points will be nearly identical after rounding to integer coordinates. The function has **no concept of "port" allocation or spreading** -- it purely computes a geometric intersection.

### Fan-in also demonstrates overlap (verified in output)

`fan_in.mmd` output shows three edges arriving at "Target":
```
           |           |           |
           +-------+   |   +-------+
                   v   v   v
                  +--------+
                  | Target |
                  +--------+
```

Here, edges from Source A, B, C all converge on Target's top edge. The three downward arrows at `v   v   v` show that dagre's waypoint-based approach angle calculation **does** spread them somewhat (they arrive at different x positions). But for edges approaching from the same direction without waypoints, they would overlap.

---

## 3. Information Available at Each Stage

| Stage | Knows about other edges? | Knows about edge ports? | Knows about approach angles? |
|-------|--------------------------|------------------------|------------------------------|
| Layout (`compute_layout_dagre`) | Yes (dagre processes all edges for ordering) | No explicit port model | Implicitly via waypoint x-positions |
| Routing (`route_edge`) | **No** -- processes each edge independently | No | Only for current edge |
| Intersection (`calculate_attachment_points`) | **No** | No | Current edge's waypoint/target only |
| Rendering (`render_all_edges`) | Has all routed edges | No | No (just draws segments) |

**Key gap**: `route_all_edges()` (router.rs:712-721) is a simple `.filter_map()` over edges. There is no aggregation step that groups edges by source/target node to spread attachment points.

---

## 4. Backward vs Forward Edge Routing

### Detection (router.rs:79-94)

```rust
pub fn is_backward_edge(
    from_bounds: &NodeBounds,
    to_bounds: &NodeBounds,
    direction: Direction,
) -> bool {
    match direction {
        Direction::TopDown => to_bounds.y < from_bounds.y,
        Direction::BottomTop => to_bounds.y > from_bounds.y,
        Direction::LeftRight => to_bounds.x < from_bounds.x,
        Direction::RightLeft => to_bounds.x > from_bounds.x,
    }
}
```

### Routing differences

**Forward edges** can be:
- **Short (1 rank)**: Direct routing, no waypoints. Uses `route_edge_direct()`.
- **Long (2+ ranks)**: Has waypoints from dagre normalization. Uses `route_edge_with_waypoints()`.

**Backward edges** can be:
- **Short (1 rank, e.g., B->A when adjacent)**: Direct routing, no waypoints. Uses `route_edge_direct()`.
- **Long (2+ ranks)**: Has waypoints. Uses `route_edge_with_waypoints()` with **reversed waypoints** (since dagre stores them in forward/effective order).

The waypoint reversal for backward edges happens at router.rs:127-131:
```rust
let waypoints: Vec<(usize, usize)> = if is_backward {
    wps.iter().rev().copied().collect()
} else {
    wps.to_vec()
};
```

Both forward and backward edges go through the **same** intersection and segment-building logic. The only difference is the waypoint order reversal for backward edges.

---

## 5. The Waypoint System

### How dagre assigns waypoints

1. **Normalization** (in dagre crate): Long edges spanning 2+ ranks get dummy nodes inserted at each intermediate rank. For an edge A->D spanning ranks 0-3, dummies are created at ranks 1 and 2.

2. **Ordering** (in dagre crate): Dummy nodes participate in the barycenter crossing-reduction heuristic alongside real nodes. This determines their cross-axis positions within each rank.

3. **Coordinate assignment** (in dagre crate): Each dummy node gets (x, y) coordinates in dagre's internal space (node_sep=50, rank_sep=50).

4. **Transformation** (layout.rs:401-436): Dagre waypoints are converted to ASCII draw coordinates using:
   - **Primary axis** (rank direction): Mapped to `layer_starts[rank_idx]` -- the y-position (TD) or x-position (LR) where that rank starts.
   - **Cross axis**: Mapped using `map_cross_axis()` with piecewise linear interpolation between real node anchor positions at that rank.

### How waypoints feed into attachment points

In `calculate_attachment_points()` (intersect.rs:153-178):
- **Source attachment**: Ray from node center toward `waypoints[0]` (first waypoint)
- **Target attachment**: Ray from node center toward `waypoints[last]` (last waypoint)

For direct edges (no waypoints):
- **Source attachment**: Ray from node center toward target node center
- **Target attachment**: Ray from node center toward source node center

### Collision nudging (layout.rs:441-464)

After waypoint transformation, there's a post-processing step that nudges waypoints colliding with node bounding boxes:
```rust
for waypoints in edge_waypoints_converted.values_mut() {
    for wp in waypoints.iter_mut() {
        for bounds in node_bounds.values() {
            if collides { wp.0 = bounds.x + bounds.width + 1; }
        }
    }
}
```

This only addresses waypoint-node collision, not waypoint-waypoint or attachment-attachment collision.

---

## 6. Existing Spreading/Offset Logic

### What exists

1. **Intersection-based angle variation** (intersect.rs): When edges approach from different angles, `intersect_rect()`/`intersect_diamond()` naturally produce different attachment points. This works well for fan-out/fan-in patterns where targets are at different cross-axis positions.

2. **Waypoint cross-axis mapping** (layout.rs `map_cross_axis()`): Dagre's ordering phase places dummy nodes at different cross-axis positions, which creates natural spread for long edges that share endpoints.

3. **Offset from boundary** (router.rs:295-337 `offset_from_boundary()`): Pushes the start/end point 1 cell outside the node boundary. This is a fixed 1-cell offset, not a spreading mechanism.

4. **Label collision avoidance** (edge.rs:219-278 `find_safe_label_position()`): Shifts labels to avoid overlap with nodes and other labels. This only applies to labels, not to edge attachment points.

### What is missing

1. **No per-node port allocation**: There is no mechanism that collects all edges incident on a node and distributes their attachment points along the node's boundary. Each edge independently computes its attachment via ray-intersection.

2. **No edge-edge collision detection in routing**: `route_all_edges()` processes edges independently with no awareness of other edges' paths. Two edges can produce identical segments that visually overlap.

3. **No attachment point deduplication**: When two edges compute the same attachment point on a shared node (e.g., both attaching at `(center_x, top_y)`), there's nothing to detect or correct this.

4. **No cross-axis spreading for short backward edges**: Short backward edges (1 rank span) have no waypoints, so both the forward and backward edge between two adjacent nodes compute attachment points using each other's center, often landing on the same boundary point.

---

## 7. Summary of Where Overlaps Occur

### Case 1: Multiple short edges between adjacent nodes (same rank span)
- Example: A->B (forward) and B->A (backward, 1 rank)
- Both compute attachment on A toward B's center and vice versa
- Result: overlapping vertical segments on same column

### Case 2: Multiple backward edges from same source
- Example: C->A and C->B from `multiple_cycles.mmd`
- Both compute source attachment on C by intersecting toward upward approach points
- Approach points are at similar angles -> same boundary cell on C

### Case 3: Multiple edges arriving at same target from similar directions
- Example: Fan-in where all sources are in the same rank directly above target
- All intersections yield nearby points on top edge
- Dagre waypoints help when they exist, but short edges with no waypoints converge

### Case 4: Direct edges with aligned nodes
- When source and target share the same center_x (common in TD layouts)
- All edges between them attach at exact center of top/bottom edges
- No mechanism to offset horizontally

### Architectural fix needed

The key missing component is a **port allocation pass** between routing and intersection calculation. This would:
1. Group all edges by their shared endpoint nodes
2. For each node, compute how many edges attach on each face (top/bottom/left/right)
3. Distribute attachment points evenly along each face
4. Feed these pre-allocated ports into the routing stage instead of computing intersections independently

This is what dagre-d3 and ELK do with their "port" models. The current `intersect_node()` approach is geometrically correct for single edges but breaks down with multiple co-incident edges.
