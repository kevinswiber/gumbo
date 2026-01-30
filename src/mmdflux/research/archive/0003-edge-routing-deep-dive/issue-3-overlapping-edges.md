# Issue 3: Overlapping Edges at Node Top

**Problem:** When multiple edges connect to the same side of a node, they all attach at the same center point, creating visual confusion. Example: On "More Data?", both the outgoing backward edge (going up to corridor) and the incoming forward edge (from Process) connect at the top of the node.

---

## Mermaid.js Approach

### Edge Path Generation

Mermaid.js delegates edge routing to dagre, then performs post-processing via the `intersection` function in `packages/mermaid/src/rendering-util/rendering-elements/edges.js`.

**Key insight from edges.js lines 303-366:**

```javascript
export const intersection = (node, outsidePoint, insidePoint) => {
  // Uses ray-casting to find where edge intersects node boundary
  // Each edge gets its own intersection point based on its angle of approach
  const dx = Math.abs(x - insidePoint.x);
  // ... calculates unique intersection point per edge
}
```

The critical difference from mmdflux: **Mermaid calculates intersection points dynamically based on the angle of approach** rather than using fixed center attachment points. When multiple edges connect to the same node side, they spread out naturally because:

1. Each edge has a different approach angle (determined by dagre's routing)
2. The intersection calculation finds where that specific angle crosses the node boundary
3. This produces offset attachment points along the node edge

### Dagre Layout Integration

From `packages/mermaid/src/rendering-util/layout-algorithms/dagre/index.js` lines 530-544:

```javascript
if (head.intersect && tail.intersect && !skipIntersect) {
  points = points.slice(1, edge.points.length - 1);
  points.unshift(tail.intersect(points[0]));
  points.push(head.intersect(points[points.length - 1]));
}
```

**Mermaid's approach:**
1. Dagre provides intermediate waypoints for edge paths
2. Node shapes expose an `intersect(point)` method
3. Edge endpoints are recalculated by finding intersection of edge direction with node boundary
4. This means edges naturally spread along the node boundary based on their routing

---

## Dagre Approach

### The `assignNodeIntersects` Function

From `$HOME/src/dagre/lib/layout.js` lines 266-283:

```javascript
function assignNodeIntersects(g) {
  g.edges().forEach(e => {
    let edge = g.edge(e);
    let nodeV = g.node(e.v);
    let nodeW = g.node(e.w);
    let p1, p2;
    if (!edge.points) {
      edge.points = [];
      p1 = nodeW;
      p2 = nodeV;
    } else {
      p1 = edge.points[0];
      p2 = edge.points[edge.points.length - 1];
    }
    edge.points.unshift(util.intersectRect(nodeV, p1));
    edge.points.push(util.intersectRect(nodeW, p2));
  });
}
```

### The `intersectRect` Utility

From `$HOME/src/dagre/lib/util.js` lines 101-134:

```javascript
function intersectRect(rect, point) {
  let x = rect.x;
  let y = rect.y;
  let dx = point.x - x;
  let dy = point.y - y;
  let w = rect.width / 2;
  let h = rect.height / 2;

  let sx, sy;
  if (Math.abs(dy) * w > Math.abs(dx) * h) {
    // Intersection is top or bottom of rect
    if (dy < 0) { h = -h; }
    sx = h * dx / dy;
    sy = h;
  } else {
    // Intersection is left or right of rect
    if (dx < 0) { w = -w; }
    sx = w;
    sy = w * dy / dx;
  }
  return { x: x + sx, y: y + sy };
}
```

**Key insight:** Dagre computes continuous-coordinate intersection points. Even when two edges connect to the top of a node, if they have different x-coordinates in their waypoints, they'll have different x-values at the intersection point.

### Edge Normalization

From `$HOME/src/dagre/lib/normalize.js` - long edges spanning multiple ranks are split into segments with "dummy nodes" at each intermediate rank. This creates distinct waypoints, which leads to different approach angles even for edges going to the same node.

---

## mmdflux Current Implementation

### Fixed Center Attachment Points

From `$HOME/src/mmdflux/src/render/shape.rs` lines 28-45:

```rust
impl NodeBounds {
    pub fn top(&self) -> (usize, usize) {
        (self.center_x(), self.y)  // Always returns center!
    }
    pub fn bottom(&self) -> (usize, usize) {
        (self.center_x(), self.y + self.height - 1)
    }
    // ... same for left/right
}
```

**Problem:** All edges connecting to a given side use the exact same x (or y) coordinate - the center of that side.

### Attachment Point Usage in Router

From `$HOME/src/mmdflux/src/render/router.rs` lines 54-79:

```rust
fn attachment_point(bounds: &NodeBounds, direction: AttachDirection) -> Point {
    match direction {
        AttachDirection::Top => {
            let (x, y) = bounds.top();  // Gets center of top edge
            Point::new(x, y.saturating_sub(1))
        }
        // ...
    }
}
```

### Backward Edge Routing

From `$HOME/src/mmdflux/src/render/router.rs` lines 181-254:

```rust
fn route_backward_edge_vertical(...) -> Option<RoutedEdge> {
    let exit_dir = if diagram_direction == Direction::TopDown {
        AttachDirection::Top
    } else {
        AttachDirection::Bottom
    };
    let start = attachment_point(from_bounds, exit_dir);  // Center of top
    let end = attachment_point(to_bounds, AttachDirection::Right);
    // ...
}
```

For a backward edge in TD layout:
- **Exit:** Uses `AttachDirection::Top` - center of top edge
- **Entry:** Uses `AttachDirection::Right` - center of right edge

### Forward Edge Routing

For a forward edge in TD layout:
- **Exit:** Uses `AttachDirection::Bottom` - center of bottom edge
- **Entry:** Uses `AttachDirection::Top` - center of top edge

**The collision occurs when:**
A node has both an incoming forward edge AND an outgoing backward edge. Both use the center of the top edge, causing visual overlap.

---

## Root Cause Analysis

The fundamental issue is that mmdflux uses **discrete, fixed attachment points** while dagre/mermaid use **continuous intersection calculations**.

### Why This Works for SVG (Mermaid)

1. **Floating-point coordinates:** SVG uses real numbers, so two edges at the top can be at x=50.2 and x=50.8
2. **Smooth curves:** D3 curve functions create smooth bends that visually separate near-parallel edges
3. **Dynamic intersection:** Each edge calculates its own boundary intersection point

### Why This Fails for ASCII (mmdflux)

1. **Integer grid:** ASCII coordinates must be whole numbers
2. **Fixed attachment points:** `top()` always returns `(center_x, y)`
3. **No intersection calculation:** Doesn't consider edge approach direction
4. **Single-character cells:** Two edge lines at the same position will overwrite

### Specific Scenario

For a diagram like:
```
graph TD
    A[Process] --> B{More Data?}
    B --> A
```

Node B has:
- Forward edge from A entering at top (center)
- Backward edge to A exiting from top (center) and routing right

Both edges converge at the same top-center point, creating visual ambiguity.

---

## ASCII Constraints for Multiple Connections

### Character Grid Limitations

In ASCII art, each character cell can only hold one character. When two edges need to connect to the same node side, we have limited options:

1. **Offset the attachment points** along the node edge (requires enough width)
2. **Use corner characters** to show edges merging before reaching the node
3. **Use different sides** of the node for different edge types
4. **Accept overlap** with a special "junction" character

### Minimum Node Width Requirements

For a node to support N edges on one side with distinct attachment points:
- Need at least N attachment positions
- With 1-character spacing, minimum width = 2*N + 1 (borders + positions)

For example, to support 2 edges on the top:
```
+-------+     Position 1 at x=2, Position 2 at x=4
|  Node |     (for a node from x=0 to x=6)
+-------+
```

---

## Recommended Solutions (with tradeoffs)

### Solution 1: Port-Based Attachment Points

**Concept:** Pre-allocate multiple "ports" on each side of a node and assign edges to specific ports.

```rust
struct NodeBounds {
    // ... existing fields
}

impl NodeBounds {
    /// Get attachment point for port N on the top edge
    /// Ports are numbered 0..n, distributed evenly across the edge
    pub fn top_port(&self, port: usize, total_ports: usize) -> (usize, usize) {
        let usable_width = self.width.saturating_sub(2);  // Exclude corners
        let spacing = usable_width / (total_ports + 1);
        let x = self.x + 1 + spacing * (port + 1);
        (x, self.y)
    }
}
```

**Tradeoffs:**
- (+) Clear separation of edges
- (+) Predictable positioning
- (-) Requires knowing total edge count per side upfront
- (-) May look odd with narrow nodes
- (-) Requires layout pass to count edges per node-side

### Solution 2: Differentiate Edge Types by Side

**Concept:** Use different attachment points for forward vs backward edges.

Current TD backward edges exit from top. Change to:
- Forward edges: bottom-exit, top-entry (unchanged)
- Backward edges: **right-exit**, right-entry (all on right side)

```rust
fn route_backward_edge_vertical(...) -> Option<RoutedEdge> {
    // Exit from RIGHT side of source (not top)
    let start = attachment_point(from_bounds, AttachDirection::Right);
    // Enter at RIGHT side of target
    let end = attachment_point(to_bounds, AttachDirection::Right);
    // Route: right exit -> down in corridor -> up to target level -> left to target
}
```

**Tradeoffs:**
- (+) Simple to implement
- (+) Clear visual distinction between forward/backward edges
- (+) No edge counting needed
- (-) Backward edges may look less intuitive (exiting sideways)
- (-) Doesn't solve the problem for multiple backward edges to same node

### Solution 3: Intersection-Based Attachment (Full Dagre Style)

**Concept:** Calculate actual intersection points based on edge approach angle.

```rust
fn intersect_rect(bounds: &NodeBounds, point: Point) -> Point {
    let cx = bounds.center_x() as f64;
    let cy = bounds.center_y() as f64;
    let dx = point.x as f64 - cx;
    let dy = point.y as f64 - cy;
    let w = bounds.width as f64 / 2.0;
    let h = bounds.height as f64 / 2.0;

    let (sx, sy) = if dy.abs() * w > dx.abs() * h {
        // Top or bottom intersection
        let sign_h = if dy < 0.0 { -h } else { h };
        (sign_h * dx / dy, sign_h)
    } else {
        // Left or right intersection
        let sign_w = if dx < 0.0 { -w } else { w };
        (sign_w, sign_w * dy / dx)
    };

    Point::new(
        (cx + sx).round() as usize,
        (cy + sy).round() as usize
    )
}
```

**Tradeoffs:**
- (+) Most faithful to dagre's approach
- (+) Natural distribution based on edge geometry
- (-) Requires waypoints for each edge (mmdflux currently doesn't store these)
- (-) Rounding to integer grid may still cause collisions
- (-) More complex implementation

### Solution 4: Connection Ordering with Offset

**Concept:** Count edges per side, assign sequential positions.

```rust
struct EdgeConnectionInfo {
    node_id: String,
    side: AttachDirection,
    edge_index: usize,  // Which edge is this (0, 1, 2...)
    total_edges: usize, // How many edges on this side
}

fn get_attachment_point(bounds: &NodeBounds, conn: &EdgeConnectionInfo) -> Point {
    let offset = calculate_offset(conn.edge_index, conn.total_edges, bounds);
    match conn.side {
        AttachDirection::Top => Point::new(bounds.x + offset, bounds.y.saturating_sub(1)),
        // ...
    }
}
```

**Tradeoffs:**
- (+) Guarantees no overlap when node is wide enough
- (+) Deterministic layout
- (-) Requires pre-pass to count connections
- (-) May cause ugly spreading on narrow nodes
- (-) Need to define edge ordering heuristics

### Solution 5: Smart Merging with Junction Characters

**Concept:** When edges must share a point, use special junction characters.

```
      |
      v      (two edges merging into top)
  +-------+
  | Node  |
  +-------+
```

Use characters like `┬` (split down) or custom symbols to show multiple edges merging.

**Tradeoffs:**
- (+) Works with any node width
- (+) No layout changes needed
- (-) May be visually confusing
- (-) Arrow characters become ambiguous
- (-) Need new character set entries

---

## Recommended Approach

**Short-term fix (Solution 2):** Change backward edges to exit/enter from the right side consistently. This eliminates the specific case of forward+backward edge collision at top.

**Medium-term enhancement (Solution 1 or 4):** Implement port-based attachment with a pre-pass to count edges. This handles the general case of multiple edges on any side.

**Implementation steps:**

1. Add `Layout.edge_connections: HashMap<(NodeId, Side), Vec<EdgeId>>` to track connections per node-side
2. In layout phase, populate this map by scanning all edges
3. Modify `attachment_point()` to accept port index and total count
4. Distribute ports evenly along the node side, respecting corners

This gives mmdflux the ability to handle arbitrarily complex edge scenarios while keeping the ASCII rendering clean and unambiguous.
