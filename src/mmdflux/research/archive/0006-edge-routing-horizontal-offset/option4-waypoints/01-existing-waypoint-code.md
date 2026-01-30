# Existing Waypoint Infrastructure Analysis

## Overview

The mmdflux codebase has a sophisticated waypoint infrastructure for edge routing, built on top of the dagre hierarchical layout algorithm. This document analyzes what exists and what can be reused for Option 4 (waypoint-based routing for forward edges with large horizontal offset).

---

## 1. Layout Edge Waypoints Definition

**File:** `src/render/layout.rs`
**Lines:** 47-50

```rust
pub edge_waypoints: HashMap<(String, String), Vec<(usize, usize)>>,
```

### Purpose
- Maps edges `(from_id, to_id)` to a list of waypoint coordinates in ASCII draw space
- Coordinates are `(x, y)` tuples representing intermediate points the edge should pass through
- Used by the router to construct orthogonal paths through waypoints

### When Populated
- **Only** by `compute_layout_dagre()` function (lines 203-506)
- **Never** by the built-in `compute_layout()` function (returns empty HashMap)
- Populated for **long edges** that span multiple ranks in the dagre layout

### Current Usage Pattern
```rust
// In compute_layout_dagre() return value
Layout {
    edge_waypoints: edge_waypoints_converted,  // Populated from dagre
    // ...
}

// In compute_layout() return value
Layout {
    edge_waypoints: HashMap::new(),  // Always empty
    // ...
}
```

---

## 2. Route Edge with Waypoints

**File:** `src/render/router.rs`
**Lines:** 183-228

```rust
fn route_edge_with_waypoints(
    edge: &Edge,
    from_bounds: &NodeBounds,
    from_shape: Shape,
    to_bounds: &NodeBounds,
    to_shape: Shape,
    waypoints: &[(usize, usize)],
    direction: Direction,
) -> Option<RoutedEdge>
```

### Algorithm
1. **Calculate attachment points** using `calculate_attachment_points()` based on first/last waypoint positions
2. **Clamp** attachment points to node boundaries
3. **Offset** attachment points 1 cell outside node boundary
4. **Build orthogonal path** through waypoints using `build_orthogonal_path_with_waypoints()`
5. **Determine entry direction** from final segment orientation

### Key Feature
The function uses **dynamic intersection calculation** - the attachment point on the source node aims toward the first waypoint, not the target. Similarly, the target attachment aims toward the last waypoint.

### Call Site (route_edge, lines 155-168)
```rust
let edge_key = (edge.from.clone(), edge.to.clone());
let waypoints = layout.edge_waypoints.get(&edge_key);

if let Some(wps) = waypoints {
    if !wps.is_empty() {
        return route_edge_with_waypoints(
            edge, from_bounds, from_shape,
            to_bounds, to_shape, wps, diagram_direction
        );
    }
}
```

---

## 3. Dagre Integration for Waypoints

**File:** `src/render/layout.rs`
**Lines:** 412-482 (in `compute_layout_dagre()`)

### Waypoint Source: Dagre Normalization

Dagre's normalization process (in `src/dagre/normalize.rs`) inserts **dummy nodes** to break long edges (spanning 2+ ranks) into unit segments. The `denormalize()` function extracts these dummy node positions as waypoints.

**File:** `src/dagre/normalize.rs`
**Lines:** 319-352

```rust
pub(crate) fn denormalize(graph: &LayoutGraph) -> HashMap<usize, Vec<WaypointWithRank>> {
    let mut waypoints: HashMap<usize, Vec<WaypointWithRank>> = HashMap::new();

    for chain in &graph.dummy_chains {
        let mut points = Vec::new();

        for dummy_id in &chain.dummy_ids {
            if let Some(&dummy_idx) = graph.node_index.get(dummy_id) {
                let pos = graph.positions[dummy_idx];
                let dims = graph.dimensions[dummy_idx];
                let rank = graph.dummy_nodes.get(dummy_id)
                    .map(|d| d.rank)
                    .unwrap_or(graph.ranks[dummy_idx]);

                points.push(WaypointWithRank {
                    point: Point {
                        x: pos.x + dims.0 / 2.0,
                        y: pos.y + dims.1 / 2.0,
                    },
                    rank,
                });
            }
        }
        waypoints.insert(chain.edge_index, points);
    }
    waypoints
}
```

### Coordinate Transformation

Dagre waypoints are in dagre's coordinate system (floating point, different scale). The transformation in `compute_layout_dagre()` converts them to ASCII draw coordinates:

```rust
let converted: Vec<(usize, usize)> = waypoints
    .iter()
    .map(|wp| {
        let rank_idx = wp.rank as usize;

        if is_vertical {
            // For TD/BT: Y from layer_starts, X interpolated
            let y = layer_starts.get(rank_idx).copied().unwrap_or(0);
            let total_ranks = waypoints.len() + 1;
            let progress = (rank_idx as f64) / (total_ranks as f64);
            let x = src_center_x as f64
                + (tgt_center_x as f64 - src_center_x as f64) * progress;
            (x.round() as usize, y)
        } else {
            // For LR/RL: X from layer_starts, Y interpolated
            let x = layer_starts.get(rank_idx).copied().unwrap_or(0);
            let total_ranks = waypoints.len() + 1;
            let progress = (rank_idx as f64) / (total_ranks as f64);
            let y = src_center_y as f64
                + (tgt_center_y as f64 - src_center_y as f64) * progress;
            (x, y.round() as usize)
        }
    })
    .collect();
```

**Key insight:** The transformation uses `layer_starts[rank]` for the primary axis (Y for vertical, X for horizontal) and **linear interpolation** for the secondary axis.

---

## 4. Build Orthogonal Path with Waypoints

**File:** `src/render/router.rs`
**Lines:** 506-540

```rust
fn build_orthogonal_path_with_waypoints(
    start: Point,
    waypoints: &[(usize, usize)],
    end: Point,
    direction: Direction,
) -> Vec<Segment> {
    let vertical_first = matches!(direction, Direction::TopDown | Direction::BottomTop);

    if waypoints.is_empty() {
        return build_orthogonal_path_for_direction(start, end, direction);
    }

    let mut segments = Vec::new();

    // Start → first waypoint
    let first_wp = Point::new(waypoints[0].0, waypoints[0].1);
    segments.extend(orthogonalize_segment(start, first_wp, !vertical_first));

    // Through all intermediate waypoints
    for window in waypoints.windows(2) {
        let from = Point::new(window[0].0, window[0].1);
        let to = Point::new(window[1].0, window[1].1);
        segments.extend(orthogonalize_segment(from, to, !vertical_first));
    }

    // Last waypoint → end: use direction-appropriate final segment
    let last_wp = Point::new(
        waypoints[waypoints.len() - 1].0,
        waypoints[waypoints.len() - 1].1,
    );
    segments.extend(build_orthogonal_path_for_direction(last_wp, end, direction));

    segments
}
```

### Key Behaviors
1. **Intermediate segments** use flexible routing (preference based on layout direction)
2. **Final segment** always uses direction-appropriate routing to ensure proper arrow orientation
3. Routes through each waypoint in sequence

### Helper: orthogonalize_segment() (Lines 753-799)

Converts diagonal waypoint connections to axis-aligned (orthogonal) paths:

```rust
fn orthogonalize_segment(from: Point, to: Point, vertical_first: bool) -> Vec<Segment> {
    if from.x == to.x {
        vec![Segment::Vertical { x: from.x, y_start: from.y, y_end: to.y }]
    } else if from.y == to.y {
        vec![Segment::Horizontal { y: from.y, x_start: from.x, x_end: to.x }]
    } else if vertical_first {
        // Z-path: vertical → horizontal
        vec![
            Segment::Vertical { x: from.x, y_start: from.y, y_end: to.y },
            Segment::Horizontal { y: to.y, x_start: from.x, x_end: to.x },
        ]
    } else {
        // Z-path: horizontal → vertical
        vec![
            Segment::Horizontal { y: from.y, x_start: from.x, x_end: to.x },
            Segment::Vertical { x: to.x, y_start: from.y, y_end: to.y },
        ]
    }
}
```

---

## 5. Dynamic Attachment Point Calculation

**File:** `src/render/intersect.rs`
**Lines:** 153-178

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

### Shape-Specific Intersection Functions
- `intersect_rect()` (lines 52-79): Line-rectangle boundary intersection
- `intersect_diamond()` (lines 93-116): Line-diamond boundary intersection

---

## 6. Usage Patterns Summary

### When `edge_waypoints` is Empty
- Short edges (span exactly 1 rank)
- All edges when using `compute_layout()` (non-dagre)
- Forward edges between adjacent ranks

### When `edge_waypoints` is Non-Empty
- Long edges spanning 2+ ranks in dagre layout
- Each waypoint corresponds to a dummy node position

---

## 7. What Can Be Reused for Option 4

### Directly Reusable (No Modification Needed)

| Component | Location | Purpose |
|-----------|----------|---------|
| `route_edge_with_waypoints()` | router.rs:183-228 | Full waypoint routing orchestration |
| `build_orthogonal_path_with_waypoints()` | router.rs:506-540 | Path segment generation through waypoints |
| `orthogonalize_segment()` | router.rs:753-799 | Diagonal to orthogonal conversion |
| `calculate_attachment_points()` | intersect.rs:153-178 | Dynamic attachment based on waypoint direction |
| `offset_from_boundary()` | router.rs:319-361 | Attachment point offsetting |
| `add_connector_segment()` | router.rs:366-384 | Connector segment creation |

### Needs to Be Built

| Component | Purpose |
|-----------|---------|
| **Waypoint generation logic** | Compute waypoints for forward edges with large horizontal offset |
| **Waypoint insertion point** | Where in the pipeline to generate/inject waypoints |
| **Threshold detection** | Identify which edges need custom waypoints |

---

## 8. Test Coverage

### Existing Waypoint Tests

**router.rs test:** `test_build_orthogonal_path_with_waypoints` (lines 1245-1285)
- Validates path construction through 2 waypoints
- Verifies segment type sequencing
- Confirms waypoint ordering preservation

**layout.rs tests:**
- `test_waypoint_transformation_vertical` (lines 1145-1204)
- `test_waypoint_transformation_horizontal` (lines 1207-1263)
- Validate coordinate transformation from dagre to ASCII space

---

## Summary

The waypoint infrastructure is **mature and well-tested**:

1. **Storage**: `Layout.edge_waypoints` - ready to accept additional waypoints
2. **Routing**: `route_edge_with_waypoints()` - fully functional, just needs waypoints
3. **Path Building**: `build_orthogonal_path_with_waypoints()` - handles any waypoint sequence
4. **Intersection**: `calculate_attachment_points()` - adapts to waypoint positions

**The primary gap is waypoint generation for non-normalized edges.** Currently only dagre-normalized long edges get waypoints. Option 4 would add waypoint generation for forward edges with large horizontal offset.
