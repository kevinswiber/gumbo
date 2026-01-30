# mmdflux Backward Edge Routing Analysis

## Current Implementation

### Backward Edge Detection
From `router.rs` lines 106-121:
```rust
pub fn is_backward_edge(
    from_bounds: &NodeBounds,
    to_bounds: &NodeBounds,
    direction: Direction,
) -> bool {
    match direction {
        // For TD, backward means target is above source
        Direction::TopDown => to_bounds.y < from_bounds.y,
        // ...
    }
}
```

### Backward Edge Routing (TD Layout)
From `router.rs` lines 551-624, `route_backward_edge_vertical()`:

**Exit Direction Logic (lines 559-563):**
```rust
let exit_dir = if diagram_direction == Direction::TopDown {
    AttachDirection::Top    // ← Exits from TOP
} else {
    AttachDirection::Bottom
};
let start = attachment_point(from_bounds, exit_dir);
```

**Entry Direction (line 566):**
```rust
let end = attachment_point(to_bounds, AttachDirection::Right);
```

**Segment Generation (lines 587-615):**
```rust
// Segment 0: Vertical connector from node border to attachment point (1 cell)
segments.push(Segment::Vertical {
    x: border_x,
    y_start: border_y,
    y_end: start.y,
});

// Segment 1: Horizontal from attachment point to corridor
segments.push(Segment::Horizontal {
    y: start.y,
    x_start: start.x,
    x_end: corridor_x,
});

// Segment 2: Vertical in corridor (main path)
segments.push(Segment::Vertical {
    x: corridor_x,
    y_start: start.y,
    y_end: end.y,
});

// Segment 3: Horizontal from corridor to target
segments.push(Segment::Horizontal {
    y: end.y,
    x_start: corridor_x,
    x_end: end.x,
});
```

## Why the Overlap Occurs

### For simple_cycle.mmd
```
graph TD
    A[Start] --> B[Process]
    B --> C[End]
    C --> A
```

**Forward Edge B→C:**
- Exits from BOTTOM of B: `(B.center_x, B.bottom + 1)`
- Enters from TOP of C: `(C.center_x, C.top - 1)`

**Backward Edge C→A:**
- Exits from TOP of C: `(C.center_x, C.top - 1)`  ← **SAME POSITION**
- Then goes RIGHT to corridor

Both edges use `(C.center_x, C.top - 1)` as an attachment point!

### Segment Overlap Visualization

```
y:  ...
    10: ─────────    Forward edge horizontal segment
    11: │       │    Forward edge vertical │, Backward edge vertical │
    12: │       │    Both edges share this column
    13: ├───────┘    ← Junction where backward branches right
    14: ┌─────┐      End node top
    15: │ End │
    16: └─────┘
```

The `├` character at y=13 is created when:
1. Forward edge draws a vertical segment at x=C.center_x going down
2. Backward edge draws a horizontal segment at y=13 going right
3. Canvas merges both into a T-junction `├`

## Junction Character Merging

From `canvas.rs` line 140-157:
```rust
pub fn set_with_connection(...) -> bool {
    if let Some(cell) = self.get_mut(x, y) {
        if cell.is_node {
            return false;  // Protected - cannot write
        }
        cell.connections.merge(connections);  // Merge connection info
        cell.ch = charset.junction(cell.connections);  // Select character
        true
    } else {
        false
    }
}
```

When the backward edge's horizontal segment is drawn through the forward edge's vertical path:
- Forward edge has: `connections = { up: true, down: true }`
- Backward edge adds: `connections = { left: true, right: true }`
- Merged: `{ up: true, down: true, left: true, right: false }` → `├`

## Arrow Loss Mechanism

From `edge.rs` lines 25-27:
```rust
if routed.edge.arrow != Arrow::None {
    draw_arrow_with_entry(canvas, &routed.end, routed.entry_direction, charset);
}
```

Arrows are drawn using `canvas.set()` which **does not** use connection merging:
```rust
pub fn set(&mut self, x: usize, y: usize, ch: char) {
    if let Some(cell) = self.get_mut(x, y) {
        cell.ch = ch;
    }
}
```

**Timeline:**
1. Forward edge B→C segments drawn, including arrow `▼` at C's top
2. Backward edge C→A segments drawn
3. When backward edge's horizontal passes through, `set_with_connection()` merges connections
4. Junction character `├` overwrites the `▼` arrow

## Render Order

From `edge.rs` lines 461-468:
```rust
// First pass: draw all segments and arrows
for routed in routed_edges {
    for segment in &routed.segments {
        draw_segment(canvas, segment, routed.edge.stroke, charset);
    }
    if routed.edge.arrow != Arrow::None {
        draw_arrow_with_entry(canvas, &routed.end, routed.entry_direction, charset);
    }
}
```

Edges are processed in order they appear in `diagram.edges`:
1. Start→Process (forward)
2. Process→End (forward) - arrow drawn
3. End→Start (backward) - segments overwrite previous arrow

## Summary

The overlap occurs because:
1. **Same attachment point**: Both forward entry and backward exit use node's top center
2. **Segment sharing**: Backward edge's horizontal segment passes through forward's vertical path
3. **Junction merging**: `set_with_connection()` combines connections into junction character
4. **Arrow overwrite**: Junction character replaces the arrow

**Fix required**: Change backward edge exit direction from TOP to RIGHT (or another solution that separates attachment points).
