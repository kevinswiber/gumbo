# ASCII Adaptation Requirements

## Overview

dagre uses floating-point coordinates and renders to SVG with arbitrary precision. mmdflux renders to an ASCII grid with integer coordinates. This document analyzes the challenges and proposes solutions.

---

## Challenge 1: Integer Grid Rounding

### The Problem

dagre outputs like:
```
Node A: center (45.7, 12.3), width 8.0, height 3.0
Edge waypoint: (52.1, 18.8)
```

ASCII needs:
```
Node A: center (46, 12), width 8, height 3
Edge waypoint: (52, 19)
```

Rounding can cause:
1. **Waypoints inside nodes:** If `52.1` rounds to `52` and the node edge is at `51.5` → rounded to `52`
2. **Waypoint ties:** Two waypoints at `(10.3, 5.8)` and `(10.4, 5.2)` both round to `(10, 6)`
3. **Edge collisions:** Edges that were 0.5 apart become 0 apart after rounding

### Proposed Solution: Pre-Expand Layout

Multiply all dagre coordinates by a scale factor before rounding:

```rust
const SCALE_FACTOR: f64 = 2.0;  // Or higher if needed

fn scale_and_round(coord: f64) -> i32 {
    (coord * SCALE_FACTOR).round() as i32
}
```

**Effect:**
- Coordinates 0.5 apart become 1.0 apart after scaling
- Node spacing increases proportionally
- More room for edge routing

**Tradeoff:** Larger output diagrams. May need configuration option.

### Alternative: Round-Away-From-Nodes

When rounding waypoints, bias away from nearby node boundaries:

```rust
fn round_waypoint(wp: Point, nearby_nodes: &[Rect]) -> Point {
    let mut x = wp.x.round() as i32;
    let mut y = wp.y.round() as i32;

    // If inside any node, push to nearest boundary
    for node in nearby_nodes {
        if node.contains(x, y) {
            // Find nearest edge and offset by 1
            x = push_outside_x(x, node);
            y = push_outside_y(y, node);
        }
    }

    Point { x, y }
}
```

---

## Challenge 2: Minimum Spacing

### The Problem

In SVG, edges can be arbitrarily close. In ASCII, edges need at least 1 character of separation to be distinguishable:

```
Bad:                    Good:
│ │  ← Can't tell       │   │
│ │    which is which   │   │
```

### Proposed Solution: Enforce Minimum Dummy Spacing

During coordinate assignment, ensure dummy nodes on the same rank have minimum separation:

```rust
const MIN_DUMMY_SPACING: i32 = 2;  // Characters between dummy nodes

fn assign_x_coordinates(graph: &mut LayoutGraph) {
    for layer in layers.iter_mut() {
        let mut prev_x = 0;
        for node_idx in layer.iter() {
            let node = &mut graph.nodes[*node_idx];
            let min_x = prev_x + MIN_DUMMY_SPACING;
            node.x = node.x.max(min_x);
            prev_x = node.x + node.width / 2;
        }
    }
}
```

### ASCII Character Widths

Remember that ASCII characters have different visual widths:
- `│` is narrow
- `─` is wide
- Labels use proportional space

For routing, treat everything as 1 character = 1 unit.

---

## Challenge 3: Orthogonal Paths from Arbitrary Waypoints

### The Problem

dagre waypoints are not necessarily axis-aligned:

```
Source at (10, 5)
Waypoint at (15, 8)  ← diagonal!
Target at (20, 12)
```

ASCII can only draw horizontal/vertical segments:
```
─────┐
     │
     └─────
```

### Proposed Solution: Z-Path Conversion

Convert each diagonal waypoint-to-waypoint segment into an orthogonal Z-path:

```rust
fn orthogonalize_path(waypoints: &[Point]) -> Vec<Segment> {
    let mut segments = Vec::new();

    for window in waypoints.windows(2) {
        let from = window[0];
        let to = window[1];

        if from.x == to.x {
            // Vertical segment
            segments.push(Segment::Vertical { x: from.x, y1: from.y, y2: to.y });
        } else if from.y == to.y {
            // Horizontal segment
            segments.push(Segment::Horizontal { y: from.y, x1: from.x, x2: to.x });
        } else {
            // Diagonal: create Z-path
            // Option A: horizontal first, then vertical
            // Option B: vertical first, then horizontal
            // Choose based on which creates fewer crossings

            let mid_y = (from.y + to.y) / 2;
            segments.push(Segment::Vertical { x: from.x, y1: from.y, y2: mid_y });
            segments.push(Segment::Horizontal { y: mid_y, x1: from.x, x2: to.x });
            segments.push(Segment::Vertical { x: to.x, y1: mid_y, y2: to.y });
        }
    }

    segments
}
```

### Z-Path Direction Heuristic

When converting diagonal to Z-path, choose direction to minimize visual issues:

```rust
fn choose_z_direction(from: Point, to: Point, layout: &Layout) -> ZDirection {
    // Count obstructions for each option
    let h_first_obstructions = count_obstructions_h_first(from, to, layout);
    let v_first_obstructions = count_obstructions_v_first(from, to, layout);

    if h_first_obstructions <= v_first_obstructions {
        ZDirection::HorizontalFirst
    } else {
        ZDirection::VerticalFirst
    }
}
```

---

## Challenge 4: Label Placement

### The Problem

dagre places labels at exact (x, y) coordinates. In ASCII:
- Labels are horizontal text strings
- Cannot rotate labels
- Labels need clear space around them

### Proposed Solution: Label as Horizontal Text Block

When denormalizing edge-label dummies:

```rust
struct EdgeLabel {
    text: String,
    x: i32,      // Left edge of label
    y: i32,      // Center y
    width: i32,  // text.len()
}

fn place_label(dummy: &DummyNode, label_text: &str) -> EdgeLabel {
    EdgeLabel {
        text: label_text.to_string(),
        x: dummy.x - (label_text.len() as i32 / 2),  // Center on dummy
        y: dummy.y,
        width: label_text.len() as i32,
    }
}
```

### Labels on Vertical Segments

When an edge-label dummy is on a vertical edge segment:
- Place label to the left or right of the segment
- Use `labelpos` ("l", "r", "c") to determine side

```
    │
    │ label     ← labelpos: "r"
    │

    │
label │         ← labelpos: "l"
    │
```

### Labels on Horizontal Segments

Place label above or below the segment:

```
    label
  ─────────     ← Above (default for TD)

  ─────────
    label       ← Below (alternative)
```

---

## Challenge 5: Intersection Point Rounding

### The Problem

`intersectRect` returns floating coordinates:
```
Source boundary intersection: (45.3, 12.0)
```

After rounding to `(45, 12)`, the point may be:
- Inside the node (if node boundary is at 45.5)
- Off the node edge (missing the visual boundary)

### Proposed Solution: Shape-Aware Rounding

Round intersection points to the nearest point that is:
1. On or outside the node boundary
2. Visually on the node's drawn edge

```rust
fn round_intersection(point: Point, node: &NodeRect, shape: Shape) -> Point {
    let (x, y) = (point.x.round() as i32, point.y.round() as i32);

    // Ensure we're on the boundary, not inside
    let boundary = get_boundary_cell(node, shape, x, y);

    boundary
}

fn get_boundary_cell(node: &NodeRect, shape: Shape, x: i32, y: i32) -> Point {
    match shape {
        Shape::Rectangle => {
            // Clamp to the rectangle's drawn edges
            let left = node.x;
            let right = node.x + node.width - 1;
            let top = node.y;
            let bottom = node.y + node.height - 1;

            Point {
                x: x.clamp(left, right),
                y: y.clamp(top, bottom),
            }
        }
        Shape::Diamond => {
            // For diamonds, find nearest edge cell
            snap_to_diamond_edge(node, x, y)
        }
        _ => Point { x, y }
    }
}
```

---

## Challenge 6: Corridor Width for Backward Edges

### The Problem

mmdflux currently routes backward edges through corridors (columns of space). With dummy nodes, backward edges will have waypoints from the layout. But corridors may still be needed for:
- Edges that loop back multiple ranks
- Clear visual separation from forward edges

### Proposed Solution: Hybrid Approach

1. **Short backward edges:** Use dummy node positions as waypoints
2. **Long backward edges:** Allocate dedicated corridor columns

```rust
fn route_backward_edge(edge: &Edge, layout: &Layout) -> RoutedEdge {
    let rank_span = layout.rank_of(&edge.to) - layout.rank_of(&edge.from);

    if rank_span.abs() <= 2 {
        // Short backward edge: use waypoints from dummies
        route_with_waypoints(edge, layout)
    } else {
        // Long backward edge: use corridor
        route_via_corridor(edge, layout)
    }
}
```

### Corridor Allocation

When using corridors:
- Place corridors at `max_x + corridor_spacing` (rightmost position + buffer)
- Each long backward edge gets its own column
- Corridors are outside the main node layout area

---

## Implementation Recommendations

### Phase 1: Basic Integer Adaptation

1. Add `SCALE_FACTOR` constant (default 1.0, adjustable)
2. Implement `scale_and_round()` for all coordinate conversions
3. Implement basic `intersect_rect()` with integer output
4. Test with existing fixtures

### Phase 2: Orthogonal Path Conversion

1. Implement `orthogonalize_path()` for diagonal waypoints
2. Add Z-path direction heuristic
3. Test with multi-rank edges

### Phase 3: Label Placement

1. Pre-calculate label dimensions in characters
2. Implement `place_label()` with position offsets
3. Handle vertical vs horizontal segment labels
4. Test with labeled edge fixtures

### Phase 4: Edge Case Handling

1. Add waypoint-inside-node detection and correction
2. Add minimum spacing enforcement
3. Add corridor fallback for complex backward edges
4. Add tie-breaking for multiple edges to same cell

---

## Open Questions Answered

### Q: What happens when continuous coordinates are rounded to integer grid?

**A:** Multiple challenges:
- Waypoints may land inside nodes → need push-outside logic
- Multiple waypoints may merge → accept ties or add spacing
- Edges may collide → enforce minimum dummy spacing

Mitigation: Use scale factor to spread coordinates before rounding.

### Q: How do we handle ties (multiple edges rounding to same cell)?

**A:** Three strategies (in order of recommendation):
1. Accept ties for now (visual may be fine)
2. Add index-based spreading for tied edges
3. Implement port system for high-density cases

Start with option 1; add complexity only if needed.

### Q: What minimum spacing prevents collisions?

**A:** Depends on element type:
- **Nodes:** Already spaced by dagre's coordinate assignment
- **Dummy nodes (edge waypoints):** 2 characters minimum
- **Labels:** Label width + 1 character buffer
- **Corridors:** 2 characters between corridor columns

These can be configuration options:
```rust
pub struct AsciiConfig {
    pub min_dummy_spacing: i32,      // default: 2
    pub label_buffer: i32,            // default: 1
    pub corridor_spacing: i32,        // default: 2
    pub scale_factor: f64,            // default: 1.0
}
```

---

## Summary

ASCII adaptation requires careful handling of:

| Challenge | Solution |
|-----------|----------|
| Integer rounding | Scale factor + round-away-from-nodes |
| Minimum spacing | Enforce during coordinate assignment |
| Diagonal waypoints | Z-path orthogonalization |
| Label placement | Horizontal text with position offsets |
| Intersection rounding | Shape-aware boundary snapping |
| Backward edge corridors | Hybrid: waypoints for short, corridors for long |

The key insight is that most issues can be solved by:
1. Scaling up coordinates before rounding (more room for everything)
2. Treating rounding as a post-processing step with correction logic
3. Falling back to simpler routing for edge cases

This allows us to use dagre's algorithms with minimal modification while producing clean ASCII output.
