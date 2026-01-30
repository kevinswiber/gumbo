# Edge Routing Deep Dive: Synthesis

## Executive Summary

After analyzing all 4 edge routing issues and comparing mmdflux with Mermaid.js and Dagre implementations, a clear pattern emerges: **mmdflux is fundamentally sound in approach, but lacks several key mechanisms that SVG renderers use for clean edge visualization.**

The core gaps are:

1. **Render Order** - Arrows get overwritten by later edge segments
2. **Label Segment Selection** - Labels placed on congested segments instead of isolated ones
3. **Fixed Attachment Points** - Single center point per node side vs. dynamic distribution
4. **No Node Collision Detection** - Router doesn't check if paths cross nodes

---

## Issue Summary Table

| Issue                | Root Cause                                                                         | mmdflux Code Location                            | Recommended Fix                                                  | Effort |
| -------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------ | ---------------------------------------------------------------- | ------ |
| 1. Missing Arrow     | Arrows drawn before all segments; later segments overwrite                         | `edge.rs:render_all_edges()`                     | Draw arrows in separate pass after ALL segments                  | Low    |
| 2. Label Collision   | Label placed on `segments[1]` (congested row) vs `segments[2]` (isolated corridor) | `edge.rs:draw_edge_label_with_tracking()`        | Change to `segments[2]` for backward edges with 4+ segments      | Low    |
| 3. Overlapping Edges | Fixed center attachment points; all edges to same side collide                     | `shape.rs:top()`, `router.rs:attachment_point()` | Port-based attachment or use right side for backward edges       | Medium |
| 4. Edge Through Node | No dummy nodes in layout; no collision detection in router                         | `layout.rs`, `router.rs:compute_path()`          | Add collision detection; consider dagre layout for complex cases | Medium |

---

## How Mermaid.js/Dagre Differ from mmdflux

### Rendering Model

| Aspect              | SVG (Mermaid)         | ASCII (mmdflux)       |
| ------------------- | --------------------- | --------------------- |
| Coordinate system   | Floating-point        | Integer grid          |
| Edge representation | Vector paths          | Character cells       |
| Layering            | Z-index support       | One char per cell     |
| Curves              | Bezier curves         | Orthogonal only       |
| Arrow rendering     | SVG markers (overlay) | Character replacement |

### Key Mechanisms mmdflux Lacks

1. **Arrow Markers as Overlays**
   - Mermaid: SVG `marker-end` attributes render arrows on top of paths
   - mmdflux: Arrow characters can be overwritten by later segments

2. **Dynamic Intersection Calculation**
   - Dagre: `intersectRect()` computes unique attachment point per edge based on approach angle
   - mmdflux: `top()` returns same center point for all edges

3. **Dummy Nodes for Long Edges**
   - Dagre: Creates placeholder nodes in intermediate ranks for edges spanning multiple layers
   - mmdflux: No equivalent mechanism

4. **Labels as Layout Entities**
   - Dagre: Edge labels become dummy nodes that participate in crossing reduction
   - mmdflux: Labels placed opportunistically after layout

---

## Recommended Implementation Order

### Phase 1: Quick Wins (Low Effort, High Impact)

**Fix Issue 1 (Missing Arrow):**
```rust
// In render_all_edges():
// Current: for edge { draw_segments; draw_arrow; }
// Fixed:   for edge { draw_segments; } for edge { draw_arrow; }

pub fn render_all_edges(...) {
    // Pass 1: All segments
    for routed in routed_edges {
        for segment in &routed.segments {
            draw_segment(canvas, segment, ...);
        }
    }

    // Pass 2: All arrows (after all segments, so arrows win)
    for routed in routed_edges {
        if routed.edge.arrow != Arrow::None {
            draw_arrow_with_entry(canvas, &routed.end, ...);
        }
    }

    // Pass 3: All labels
    for routed in routed_edges {
        if let Some(label) = &routed.edge.label {
            draw_edge_label_with_tracking(...);
        }
    }
}
```

**Fix Issue 2 (Label Collision):**
```rust
// In draw_edge_label_with_tracking():
let (base_x, base_y) = if is_backward && routed.segments.len() >= 4 {
    // Use segments[2] (isolated corridor) instead of segments[1]
    find_label_position_on_segment(&routed.segments[2], label_len, direction)
} else if is_backward && routed.segments.len() >= 3 {
    find_label_position_on_segment(&routed.segments[1], label_len, direction)
} else {
    // Forward edge: midpoint
    (mid_x, mid_y)
};
```

### Phase 2: Medium Effort Improvements

**Fix Issue 3 (Overlapping Edges):**

Option A (Simple): Use right side for backward edges
```rust
fn route_backward_edge_vertical(...) {
    // Exit from RIGHT side instead of TOP
    let start = attachment_point(from_bounds, AttachDirection::Right);
}
```

Option B (Robust): Port-based attachment
```rust
impl NodeBounds {
    pub fn top_port(&self, port: usize, total_ports: usize) -> (usize, usize) {
        let usable_width = self.width.saturating_sub(2);
        let spacing = usable_width / (total_ports + 1);
        let x = self.x + 1 + spacing * (port + 1);
        (x, self.y)
    }
}
```

**Fix Issue 4 (Edge Through Node):**
```rust
fn compute_path_with_avoidance(
    start: Point,
    end: Point,
    layout: &Layout,
    direction: Direction
) -> Vec<Segment> {
    let basic_path = compute_path(start, end, direction);

    // Check each segment for node collisions
    for segment in &basic_path {
        for (node_id, bounds) in &layout.node_bounds {
            if segment_intersects_bounds(segment, bounds) {
                // Reroute around this node
                return compute_avoidance_path(...);
            }
        }
    }

    basic_path
}
```

### Phase 3: Long-Term Architecture

- Implement dummy nodes for long edges in the built-in layout algorithm
- Add edge labels as layout entities that participate in crossing reduction
- Consider full dagre-style intersection calculation (with rounding)

---

## ASCII-Specific Tradeoffs

### What We Can Do

1. **Render order** - Draw arrows last so they're always visible
2. **Segment selection** - Choose isolated segments for labels
3. **Port-based attachment** - Distribute edges along node sides when width allows
4. **Collision detection** - Check and reroute around nodes

### What We Cannot Do

1. **True overlapping** - One character per cell, period
2. **Smooth curves** - Only orthogonal segments
3. **Sub-character positioning** - Integer grid only
4. **Infinite resolution** - Limited by terminal width

### Acceptable Compromises

1. **Arrows overwrite junction info** - Arrows are more important for direction
2. **Labels beside vertical segments** - Horizontal text next to vertical line
3. **Extra bends for avoidance** - Clarity over compactness
4. **Wider diagrams for port distribution** - Node width must accommodate edge count

---

## Testing Strategy

After implementing fixes, verify with these test cases:

1. **`tests/fixtures/simple_cycle.mmd`** - Basic backward edge
2. **`tests/fixtures/multiple_cycles.mmd`** - Multiple backward edges
3. **`tests/fixtures/complex.mmd`** - Original problem case (all 4 issues)
4. **`tests/fixtures/labeled_edges.mmd`** - Label placement verification

Expected outcomes per fix:

| Fix                 | Test        | Expected Change                              |
| ------------------- | ----------- | -------------------------------------------- |
| Arrow render order  | complex.mmd | `├` at More Data? entry becomes `▼`          |
| Label segment       | complex.mmd | "yes" moves to corridor, away from junctions |
| Attachment points   | complex.mmd | Backward edge exits right side of More Data? |
| Collision detection | complex.mmd | "no" edge routes around Cleanup node         |

---

## Conclusion

The 4 issues stem from fundamental differences between SVG and ASCII rendering, but all are fixable without major architectural changes:

1. **Issue 1** - 5-line code change (restructure loop)
2. **Issue 2** - 3-line code change (different segment index)
3. **Issue 3** - 10-20 line change (right-side routing or port system)
4. **Issue 4** - 30-50 line change (collision detection function)

Recommend implementing in order: 1, 2, 3, 4. Each fix is independent and can be tested separately.
