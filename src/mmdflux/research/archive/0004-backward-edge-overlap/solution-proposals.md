# Backward Edge Overlap: Solution Proposals

## Problem Statement

In `simple_cycle.mmd`, the backward edge (End→Start) shares the same vertical path as the forward edge (Process→End), causing:
1. Lost arrow information (overwritten by junction character)
2. Visual ambiguity (unclear where backward edge originates)

## Solution 1: Side-Differentiation

**Concept**: Change backward edges to exit from a different side than forward edges.

### Code Changes

File: `src/render/router.rs`, function `route_backward_edge_vertical()`

**Before (lines 559-563):**
```rust
let exit_dir = if diagram_direction == Direction::TopDown {
    AttachDirection::Top
} else {
    AttachDirection::Bottom
};
```

**After:**
```rust
let exit_dir = AttachDirection::Right;  // Always exit from right side
```

### Visual Result

```
Current:                        Fixed:
  ┌───────┐                      ┌───────┐
  │ Start │◄──┐                  │ Start │◄──┐
  └───────┘   │                  └───────┘   │
      │       │                      │       │
      ▼       │                      ▼       │
 ┌─────────┐  │                 ┌─────────┐  │
 │ Process │  │                 │ Process │  │
 └─────────┘  │                 └─────────┘  │
      │       │                      │       │
      ├───────┘  ← Arrow lost        ▼       │
   ┌─────┐                        ┌─────┐    │
   │ End │                        │ End │────┘  ← Exits right
   └─────┘                        └─────┘
```

### Trade-offs

| Aspect | Rating | Notes |
|--------|--------|-------|
| Complexity | ★☆☆☆☆ | ~5 lines changed |
| Handles multiple edges | ◐ | Only backward edges |
| Visual clarity | ★★★★☆ | Clear distinction |
| Width impact | None | |
| Direction compatibility | ✓ | All 4 directions |

---

## Solution 2: Port-Based Attachment

**Concept**: Pre-allocate multiple attachment positions ("ports") on each node side and distribute edges across them.

### Code Changes

**New method in `shape.rs`:**
```rust
impl NodeBounds {
    pub fn top_port(&self, port: usize, total_ports: usize) -> (usize, usize) {
        let usable_width = self.width.saturating_sub(2);  // Exclude corners
        let spacing = usable_width / (total_ports + 1);
        let x = self.x + 1 + spacing * (port + 1);
        (x, self.y)
    }

    // Similar for bottom_port, left_port, right_port
}
```

**New tracking in `layout.rs`:**
```rust
pub struct Layout {
    // ... existing fields
    pub edge_connections: HashMap<(String, AttachDirection), Vec<String>>,
}
```

**Updated routing in `router.rs`:**
```rust
fn route_edge(...) {
    let port_index = layout.get_port_index(&edge, &target, direction);
    let total_ports = layout.count_ports(&target, direction);
    let start = bounds.top_port(port_index, total_ports);
}
```

### Visual Result

```
With 2 edges to top of Process:

     │ │
     │ │
+----┴-┴----+
│  Process  │
+-----------+
Port 1  Port 2
```

### Trade-offs

| Aspect | Rating | Notes |
|--------|--------|-------|
| Complexity | ★★★★☆ | ~80 lines changed |
| Handles multiple edges | ✓ | Full support |
| Visual clarity | ★★★★★ | Best distribution |
| Width impact | May increase | Wider nodes needed |
| Direction compatibility | ✓ | All 4 directions |

---

## Solution 3: Intersection-Based Attachment

**Concept**: Calculate attachment points based on edge approach angle, like Dagre does.

### Code Changes

**New function in `intersect.rs`:**
```rust
pub fn intersect_rect(bounds: &NodeBounds, approach: Point) -> Point {
    let cx = bounds.center_x() as f64;
    let cy = bounds.center_y() as f64;
    let dx = approach.x as f64 - cx;
    let dy = approach.y as f64 - cy;
    let w = bounds.width as f64 / 2.0;
    let h = bounds.height as f64 / 2.0;

    let (sx, sy) = if dy.abs() * w > dx.abs() * h {
        let sign_h = if dy < 0.0 { -h } else { h };
        (sign_h * dx / dy, sign_h)
    } else {
        let sign_w = if dx < 0.0 { -w } else { w };
        (sign_w, sign_w * dy / dx)
    };

    Point::new(
        (cx + sx).round() as usize,
        (cy + sy).round() as usize,
    )
}
```

**Updated routing:**
```rust
fn route_backward_edge(...) {
    let corridor_point = Point::new(corridor_x, corridor_y);
    let start = intersect_rect(from_bounds, corridor_point);
    let end = intersect_rect(to_bounds, start);
}
```

### Visual Result

Edges naturally spread based on approach angle:
```
      ↙ ↘
     ╱   ╲
+----+   +----+
|Node|   |Node|
+----+   +----+
```

### Trade-offs

| Aspect | Rating | Notes |
|--------|--------|-------|
| Complexity | ★★★★☆ | ~50 lines + math |
| Handles multiple edges | ✓ | Natural distribution |
| Visual clarity | ★★★★★ | Most principled |
| Width impact | None | |
| Rounding issues | ⚠️ | May still collide |

---

## Solution 4: Multi-Lane Corridors

**Concept**: Enhance existing lane system to ensure backward edges never share paths.

### Code Changes

**Enhanced lane assignment in `layout.rs`:**
```rust
fn assign_backward_lanes(&mut self, diagram: &Diagram) {
    let mut lane_assignments = HashMap::new();
    let mut next_lane = 0;

    for edge in &diagram.edges {
        if is_backward_edge(...) {
            // Check for conflicts with existing lanes
            let conflicts_with = self.find_conflicting_lanes(&edge);
            let lane = conflicts_with.iter().max().map(|l| l + 1).unwrap_or(next_lane);
            lane_assignments.insert((edge.from.clone(), edge.to.clone()), lane);
            next_lane = next_lane.max(lane + 1);
        }
    }

    self.backward_edge_lanes = lane_assignments;
    self.backward_corridors = next_lane;
}
```

### Visual Result

```
Content   │ Lane 0 │ Lane 1
          │        │
   │      │        │
   ▼      │        │
+----+────┤        │
|Node|    │        │
+----+────┼────────┤
          │        │
   │      │        │
   ▼      │        │
+----+────┘        │
|Node|─────────────┘
+----+
```

### Trade-offs

| Aspect | Rating | Notes |
|--------|--------|-------|
| Complexity | ★★★☆☆ | ~30 lines changed |
| Handles multiple edges | ✓ | All backward edges |
| Visual clarity | ★★★★☆ | Clear separation |
| Width impact | ★★★☆☆ | +2 per backward edge |
| Direction compatibility | ✓ | All 4 directions |

---

## Comparison Summary

| Solution | Quick Fix | Scalable | Width Neutral | Effort |
|----------|-----------|----------|---------------|--------|
| 1. Side-Differentiation | ✓ | ◐ | ✓ | 1-2h |
| 2. Port-Based | | ✓ | ◐ | 4-6h |
| 3. Intersection-Based | | ✓ | ✓ | 6-8h |
| 4. Multi-Lane | | ✓ | | 3-4h |

---

## Recommendation

### Immediate: Solution 1

Implement side-differentiation to fix the reported issue quickly:
- Change backward edges to exit from RIGHT side
- Takes 1-2 hours
- Addresses `simple_cycle.mmd` immediately

### Short-term: Solution 2 or 4

Choose based on priority:
- **Solution 2** if: You need to handle multiple forward edges colliding
- **Solution 4** if: Only backward edge collisions are the concern

### Long-term: Solution 3

Consider intersection-based attachment for:
- Mathematical precision
- Matching Mermaid.js/Dagre behavior
- Most principled solution

---

## Direction Mapping

For all solutions, ensure symmetry across directions:

### Solution 1 Side Mapping

| Layout | Forward Flow | Backward Exit (Fixed) |
|--------|--------------|----------------------|
| TD | Top→Bottom | Right |
| BT | Bottom→Top | Left |
| LR | Left→Right | Bottom |
| RL | Right→Left | Top |

### Solutions 2-4

These work identically for all directions by design (port distribution, intersection math, and lane assignment are direction-agnostic).
