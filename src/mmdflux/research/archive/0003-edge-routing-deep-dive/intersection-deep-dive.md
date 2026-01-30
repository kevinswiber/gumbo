# Deep Dive: dagre's lib/util.js intersectRect

## Overview

The `intersectRect` function calculates where a line from an external point to a rectangle's center would intersect the rectangle's boundary. This enables dynamic edge attachment points that vary based on the edge's approach angle.

**Source:** https://github.com/dagrejs/dagre/blob/master/lib/util.js

---

## The Algorithm

### Complete Implementation

```javascript
function intersectRect(rect, point) {
  let x = rect.x;           // Rectangle center x
  let y = rect.y;           // Rectangle center y
  let dx = point.x - x;     // Horizontal distance from center to point
  let dy = point.y - y;     // Vertical distance from center to point
  let w = rect.width / 2;   // Half-width (distance from center to edge)
  let h = rect.height / 2;  // Half-height

  // Edge case: point is exactly at center
  if (!dx && !dy) {
    throw new Error("Not possible to find intersection inside of the rectangle");
  }

  let sx, sy;
  // Determine which edge the line intersects
  if (Math.abs(dy) * w > Math.abs(dx) * h) {
    // Line is steeper than the rectangle's diagonal
    // → Intersection is on TOP or BOTTOM edge
    if (dy < 0) {
      h = -h;  // Point is above center → top edge
    }
    sx = h * dx / dy;  // Calculate x offset
    sy = h;            // y offset is exactly half-height
  } else {
    // Line is shallower than the rectangle's diagonal
    // → Intersection is on LEFT or RIGHT edge
    if (dx < 0) {
      w = -w;  // Point is left of center → left edge
    }
    sx = w;            // x offset is exactly half-width
    sy = w * dy / dx;  // Calculate y offset
  }

  return { x: x + sx, y: y + sy };
}
```

---

## Mathematical Explanation

### The Core Insight

The line from rectangle center `(x, y)` to external point `(point.x, point.y)` has a slope. The intersection point depends on whether this slope is "steeper" or "shallower" than the rectangle's corner diagonal.

```
             point (steep approach - hits top)
              ↘
        ┌─────────────┐
        │      ╲      │
        │       ╲     │  point (shallow approach - hits right)
        │    ●───╲────┼──→
        │     center  │
        └─────────────┘
```

### The Comparison: `Math.abs(dy) * w > Math.abs(dx) * h`

This compares the line's slope against the rectangle's aspect ratio:

- **Steep line:** `|dy/dx| > h/w` → hits top or bottom
- **Shallow line:** `|dy/dx| < h/w` → hits left or right

Rearranging to avoid division: `|dy| * w > |dx| * h`

### Calculating the Intersection

**For vertical edges (top/bottom):**
- We know the y-offset is `±h` (half-height)
- Solve for x using similar triangles: `sx/h = dx/dy` → `sx = h * dx / dy`

**For horizontal edges (left/right):**
- We know the x-offset is `±w` (half-width)
- Solve for y using similar triangles: `sy/w = dy/dx` → `sy = w * dy / dx`

---

## Usage in Edge Routing

### How dagre Uses intersectRect

After layout, each edge has:
1. A source node position (center)
2. Waypoints from dummy nodes (if any)
3. A target node position (center)

The endpoints are computed by:

```javascript
// Source endpoint: where line from first waypoint hits source boundary
let sourcePoint = intersectRect(sourceNode, waypoints[0] || targetNode);

// Target endpoint: where line from last waypoint hits target boundary
let targetPoint = intersectRect(targetNode, waypoints[waypoints.length - 1] || sourceNode);
```

### The Result

Each edge gets unique attachment points based on its actual path:

```
       ┌─────────┐
       │    A    │
       └───┬─┬───┘
           │ │
    edge1 ─┘ └─ edge2
```

Instead of all edges attaching at the center bottom:

```
       ┌─────────┐
       │    A    │
       └────┬────┘
            ├───── edge1
            └───── edge2 (overlaps!)
```

---

## Adapting for ASCII Grids

### Challenge: Integer Coordinates

dagre's `intersectRect` returns floating-point coordinates. In ASCII, we need integer character positions.

**Example:**
- Rectangle at (10, 5) with width=8, height=3
- Point at (20, 8)
- `intersectRect` returns (14.0, 6.5)
- Rounded: (14, 7) or (14, 6)?

### Proposed Adaptation

```rust
fn intersect_rect_ascii(rect: &Rect, point: Point) -> Point {
    let x = rect.center_x();
    let y = rect.center_y();
    let dx = point.x - x;
    let dy = point.y - y;
    let w = rect.width as f64 / 2.0;
    let h = rect.height as f64 / 2.0;

    let (sx, sy) = if dy.abs() * w > dx.abs() * h {
        // Top or bottom edge
        let h = if dy < 0.0 { -h } else { h };
        (h * dx / dy, h)
    } else {
        // Left or right edge
        let w = if dx < 0.0 { -w } else { w };
        (w, w * dy / dx)
    };

    // Round to nearest integer
    Point {
        x: (x + sx).round() as i32,
        y: (y + sy).round() as i32,
    }
}
```

### Handling Ties (Multiple Edges to Same Cell)

When rounding, multiple edges may land on the same cell. Options:

1. **Accept ties:** Let edges share attachment points (may be fine for ASCII)
2. **Offset by index:** If 3 edges hit bottom, place at -1, 0, +1 from calculated point
3. **Port system:** Divide each edge into discrete ports and assign edges to ports

**Recommendation:** Start with option 1 (accept ties), add option 2 if visual quality suffers.

---

## Different Node Shapes

### Rectangles
The standard `intersectRect` handles these perfectly.

### Diamonds (Decision Nodes)

```
      ╱╲
     ╱  ╲
    ╱    ╲
    ╲    ╱
     ╲  ╱
      ╲╱
```

For diamonds, the intersection calculation changes:

```rust
fn intersect_diamond(diamond: &Rect, point: Point) -> Point {
    let x = diamond.center_x();
    let y = diamond.center_y();
    let dx = point.x - x;
    let dy = point.y - y;

    // Diamond has half-diagonals of w and h
    let w = diamond.width as f64 / 2.0;
    let h = diamond.height as f64 / 2.0;

    // Diamond boundary: |dx|/w + |dy|/h = 1
    // Intersection at t where: |t*dx|/w + |t*dy|/h = 1
    // Solving: t = 1 / (|dx|/w + |dy|/h)

    let t = 1.0 / (dx.abs() / w + dy.abs() / h);

    Point {
        x: (x + t * dx).round() as i32,
        y: (y + t * dy).round() as i32,
    }
}
```

### Rounded Rectangles (Stadium Shape)

For rounded corners, we can approximate with the rectangle formula since ASCII doesn't really have curves anyway.

### Circles/Ellipses

If needed:

```rust
fn intersect_ellipse(ellipse: &Rect, point: Point) -> Point {
    let x = ellipse.center_x();
    let y = ellipse.center_y();
    let dx = point.x - x;
    let dy = point.y - y;
    let a = ellipse.width as f64 / 2.0;  // Semi-major axis
    let b = ellipse.height as f64 / 2.0; // Semi-minor axis

    // Parametric: intersection at (a*cos(θ), b*sin(θ))
    // where tan(θ) = (b*dy)/(a*dx)
    let angle = (b * dy).atan2(a * dx);

    Point {
        x: (x + a * angle.cos()).round() as i32,
        y: (y + b * angle.sin()).round() as i32,
    }
}
```

---

## Implementation Strategy for mmdflux

### Phase 1: Basic Rectangle Intersection

```rust
// In src/render/router.rs or new src/render/intersect.rs

pub fn intersect_rect(rect: &NodeRect, point: Point) -> Point {
    // Direct port of dagre's algorithm
    // Return integer coordinates
}
```

### Phase 2: Shape-Aware Intersection

```rust
pub fn intersect_node(node: &NodeRect, point: Point, shape: Shape) -> Point {
    match shape {
        Shape::Rectangle => intersect_rect(node, point),
        Shape::Diamond => intersect_diamond(node, point),
        Shape::Round => intersect_rect(node, point), // Approximate
        Shape::Circle => intersect_ellipse(node, point),
    }
}
```

### Phase 3: Integration with Router

```rust
pub fn route_edge(edge: &Edge, layout: &Layout) -> RoutedEdge {
    let source = layout.get_node(&edge.from);
    let target = layout.get_node(&edge.to);
    let waypoints = layout.get_waypoints(&edge);

    // Calculate attachment points
    let source_attach = if let Some(first_wp) = waypoints.first() {
        intersect_node(&source.rect, *first_wp, source.shape)
    } else {
        intersect_node(&source.rect, target.center(), source.shape)
    };

    let target_attach = if let Some(last_wp) = waypoints.last() {
        intersect_node(&target.rect, *last_wp, target.shape)
    } else {
        intersect_node(&target.rect, source.center(), target.shape)
    };

    // Build path: source_attach → waypoints → target_attach
    build_orthogonal_path(source_attach, &waypoints, target_attach)
}
```

---

## Open Questions Answered

### Q: How do we handle ties when rounding to integer grid?

**A:** Options in order of complexity:
1. **Accept ties:** Multiple edges can share a cell (simplest)
2. **Index-based offset:** Spread tied edges across adjacent cells
3. **Port assignment:** Pre-allocate discrete attachment ports

Recommend starting with option 1; the visual result may be acceptable.

### Q: Should we implement port-based fallback for high edge density?

**A:** Not initially. The combination of:
- Dynamic intersection from approach angle
- Dummy nodes spreading edges apart
- Integer grid rounding

...should provide sufficient separation for most diagrams. Add ports if testing reveals problems.

### Q: How does intersection interact with diamond/rounded node shapes?

**A:** Each shape needs its own intersection formula:
- **Rectangle:** Standard `intersectRect` (slope comparison)
- **Diamond:** Line intersection with rhombus edges
- **Rounded:** Can approximate with rectangle (ASCII limitation)
- **Circle/Ellipse:** Parametric circle intersection

The shape is known from the node, so `intersect_node()` can dispatch to the right formula.

---

## Summary

The `intersectRect` function is simple but crucial:

1. **Input:** Rectangle bounds + external point
2. **Algorithm:** Compare line slope to rectangle diagonal
3. **Output:** Point on rectangle boundary where line crosses

For mmdflux:
- Port the algorithm with integer rounding
- Add shape-aware variants for diamonds
- Integrate with waypoint-based routing
- Accept ties initially; add spreading logic if needed

The key insight is that dynamic intersection calculation naturally spreads edges apart when combined with dummy node waypoints, eliminating the need for fixed center attachment points that cause collisions.
