# mmdflux Current Edge Label Behavior

## Summary

mmdflux handles edge label positioning through a **two-phase placement system** in `src/render/edge.rs`:

1. **Label position calculation** - determines where a label should appear based on edge type (forward vs backward), direction, and available space
2. **Collision avoidance** - attempts to shift labels if they collide with nodes or other labels

**Core Issue:** Labels are positioned relative to edge paths without considering segment-level spacing, and collision detection only checks against nodes and previously-placed labels, not against the edge path itself (including corner characters like `└──┐`).

## Current Label Positioning Logic

### Entry Point: render_edge()

**File:** `src/render/edge.rs:11-33`

```rust
pub fn render_edge(
    edge: &Edge,
    canvas: &mut Canvas,
    segments: &[Segment],
    arrow_pos: (usize, usize),
    charset: &CharSet,
    layout: &Layout,
    placed_labels: &mut Vec<LabelRect>,
) {
    // Draw segments
    // Draw arrow at endpoint
    // If label exists, call draw_edge_label_with_tracking()
}
```

### Label Position Calculation

**File:** `src/render/edge.rs:43-144` (`draw_edge_label_with_tracking()`)

#### Forward Edges (lines 69-117)

For edges flowing in layout direction:

```rust
// Calculate midpoint
let mid_y = (start.y + end.y) / 2;
let mid_x = (start.x + end.x) / 2;

// Center label horizontally
let label_x = mid_x.saturating_sub(label_len / 2);
let label_y = mid_y;
```

For TD/BT layouts, labels placed at Y-midpoint with X-centering.
For LR/RL layouts, additional boundary constraints keep labels between source and arrow.

#### Backward Edges (lines 52-67)

For edges routing around perimeter (cycles):

```rust
if is_backward && segments.len() >= 4 {
    // Use segment[2] for 4-segment paths
    find_label_position_on_segment(&segments[2], label_len)
} else if is_backward && segments.len() == 3 {
    // Use segment[1] for 3-segment paths
    find_label_position_on_segment(&segments[1], label_len)
}
```

### Segment-Based Label Placement

**File:** `src/render/edge.rs:146-181` (`find_label_position_on_segment()`)

For backward edges, labels are positioned on corridor segments:

```rust
match segment {
    Segment::Vertical { x, y_start, y_end } => {
        let mid_y = (*y_start + *y_end) / 2;
        // Place label to LEFT of vertical line
        (x.saturating_sub(label_len + 1), mid_y)
    }
    Segment::Horizontal { y, x_start, x_end } => {
        let mid_x = (*x_start + *x_end) / 2;
        let label_x = mid_x.saturating_sub(label_len / 2);
        // Place label ABOVE the horizontal line
        (label_x, y.saturating_sub(1))
    }
}
```

**Problem:** Hard-coded offsets (`label_len + 1` for vertical, `1` for horizontal) don't account for corner character width.

### Safe Position Finding

**File:** `src/render/edge.rs:183-246` (`find_safe_label_position()`)

```rust
fn find_safe_label_position(
    base_x: usize,
    base_y: usize,
    label_len: usize,
    canvas: &Canvas,
    nodes: &HashMap<String, NodeRect>,
    placed_labels: &[LabelRect],
    direction: Direction,
) -> (usize, usize) {
    // Check if base position collides
    if !label_has_collision(base_x, base_y, label_len, canvas, nodes, placed_labels) {
        return (base_x, base_y);
    }

    // Try shift offsets in direction-specific order
    let shifts = match direction {
        Direction::TopDown | Direction::BottomTop => {
            // Try Y-shifts first, then X-shifts
            vec![(0, -1), (0, 1), (0, -2), (0, 2), (-1, 0), (1, 0)]
        }
        Direction::LeftRight | Direction::RightLeft => {
            // Try Y-shifts first, then limited X-shifts
            vec![(0, -1), (0, 1), (-1, 0), (1, 0)]
        }
    };

    // Apply shifts and return first non-colliding position
    // ...
}
```

### Collision Detection

**File:** `src/render/edge.rs:248-272`

#### label_has_collision() (lines 249-267)

```rust
fn label_has_collision(
    x: usize,
    y: usize,
    len: usize,
    canvas: &Canvas,
    nodes: &HashMap<String, NodeRect>,
    placed_labels: &[LabelRect],
) -> bool {
    // Check node collision
    if label_collides_with_node(x, y, len, canvas) {
        return true;
    }

    // Check other label collision
    for label in placed_labels {
        if rectangles_overlap(x, y, len, 1, label.x, label.y, label.width, label.height) {
            return true;
        }
    }

    false
}
```

**Missing:** No check against edge path characters.

#### label_collides_with_node() (lines 270-272)

```rust
fn label_collides_with_node(x: usize, y: usize, label_len: usize, canvas: &Canvas) -> bool {
    (0..label_len).any(|i| canvas.get(x + i, y).is_some_and(|cell| cell.is_node))
}
```

Only returns true if cell is marked `is_node`. Edge characters (└, ─, ┘) are NOT marked as nodes.

### Label Writing

**File:** `src/render/edge.rs:124-137`

```rust
for (i, ch) in label.chars().enumerate() {
    let x = label_x + i;

    // Skip arrow position
    if x == arrow_pos.0 && label_y == arrow_pos.1 {
        continue;
    }

    // Overwrite non-node cells
    if canvas.get(x, label_y).is_some_and(|cell| !cell.is_node) {
        canvas.set(x, label_y, ch);
    }
}
```

**Critical Issue:** Labels overwrite edge characters because they're not in the `is_node` set.

## Code Walkthrough with References

| Location | Function | Purpose |
|----------|----------|---------|
| `edge.rs:11-33` | `render_edge()` | Entry point for edge rendering |
| `edge.rs:43-144` | `draw_edge_label_with_tracking()` | Main label placement logic |
| `edge.rs:52-67` | (within above) | Backward edge detection and handling |
| `edge.rs:69-117` | (within above) | Forward edge midpoint calculation |
| `edge.rs:124-137` | (within above) | Label character writing |
| `edge.rs:146-181` | `find_label_position_on_segment()` | Segment-based positioning for backward edges |
| `edge.rs:183-246` | `find_safe_label_position()` | Collision avoidance with shifting |
| `edge.rs:249-267` | `label_has_collision()` | Collision detection |
| `edge.rs:270-272` | `label_collides_with_node()` | Node collision check |

## Identified Issues

### Issue 1: Edge Path Characters Not Protected

**Root cause:** `src/render/edge.rs:134-136`

Edge path characters are drawn to canvas but not marked with `is_node = true`. During label writing, non-node cells are overwritten.

Example from reproduction:
```
     ┌───┐
     │ A │
     └───┘
      invalid
   valid└──┐    ← Corner "└──┐" gets overwritten by "valid"
    ▼      ▼
```

### Issue 2: Collision Detection Ignores Edge Characters

**Root cause:** `src/render/edge.rs:249-267`

`label_has_collision()` doesn't check if label would overlap edge segment characters. It only checks:
1. Is it on a node cell?
2. Does it overlap with a placed label?

Should also check: Are there edge path characters at this location?

### Issue 3: Insufficient Offset for Corners

**Root cause:** `src/render/edge.rs:160, 171`

For horizontal segments, offset is just `y.saturating_sub(1)` (one row above). When segment connects to vertical segment (creating a corner), the corner occupies space not considered.

### Issue 4: No Minimum Distance From Path

**Root cause:** `src/render/edge.rs:69-117, 156-181`

Label positioning places text adjacent to path:
- Forward edge: label at midpoint Y
- Backward edge: label 1 cell away from horizontal segment

No buffer for segment characters or junction width.

## Limitations

### Current Approach Advantages

1. **Fast:** Single-pass calculation
2. **Simple:** Predictable offsets
3. **Direction-aware:** Different logic for TD/BT/LR/RL

### Current Approach Limitations

1. **No geometry awareness:** Doesn't know segment corner shapes
2. **Reactive collision avoidance:** Only shifts after collision detected
3. **Overwrite behavior:** Labels overwrite edge paths
4. **Limited shifting:** Only tries ±1, ±2, ±3 offsets

### Layout Direction Constraints

- **TD/BT:** Labels above/below or left/right of midpoint
- **LR/RL:** Labels in corridor, constrained by corridor width
- **Backward edges:** Routing around perimeter limits label space

## Why Overlap Occurs

When placing a label:

1. Calculate position (midpoint or segment-based)
2. Check collision against NODE cells only
3. If no collision, write label to canvas
4. **Label overwrites edge path characters (not marked `is_node`)**

Result: Label visually overlaps edge path.

## Potential Fix Approaches

### Option A: Mark Edge Characters
Add metadata to edge cells in canvas. Requires canvas redesign.

### Option B: Check Canvas Content
Before placing labels, check if canvas cells contain edge characters.

### Option C: Increase Spacing
Larger offsets between paths and label placement areas. Trades space for clarity.
