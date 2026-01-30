# ASCII Art Constraints for Edge Rendering

## Fundamental Limitations

### 1. Single Character Per Cell

Each cell in the ASCII grid can hold exactly one character. There is no layering, transparency, or overlap.

```rust
// From canvas.rs
pub struct Cell {
    pub ch: char,           // One character only
    pub is_node: bool,      // Protected from edge overwrites
    pub connections: Connections,  // Metadata for junction selection
}
```

### 2. Integer Coordinate Grid

All positions are whole numbers:
```rust
pub struct Point {
    pub x: usize,
    pub y: usize,
}
```

No sub-pixel positioning. If two edges need to be at x=5.4 and x=5.6, both round to x=5 or x=6.

### 3. Orthogonal Only

Edges can only be vertical or horizontal segments:
```rust
pub enum Segment {
    Vertical { x: usize, y_start: usize, y_end: usize },
    Horizontal { y: usize, x_start: usize, x_end: usize },
}
```

No diagonal lines, no curves, no beziers.

## Available Characters

### From `chars.rs`

**Box Drawing (Unicode):**
```
Corners: ┌ ┐ └ ┘ (square), ╭ ╮ ╰ ╯ (rounded)
Lines:   │ ─ (solid), ┆ ┄ (dotted)
Junctions: ┼ (cross), ├ ┤ ┬ ┴ (T-junctions)
```

**ASCII Fallback:**
```
Corners: + (all)
Lines:   | - (solid), : - (dotted)
Junctions: + (all)
```

**Arrows:**
```
Unicode: ▲ ▼ ◄ ►
ASCII:   ^ v < >
```

### Junction Selection Logic

From `chars.rs` `junction()`:
```rust
pub fn junction(&self, conn: Connections) -> char {
    match (conn.up, conn.down, conn.left, conn.right) {
        (true, true, true, true) => self.cross,      // ┼
        (true, true, true, false) => self.tee_left,  // ┤
        (true, true, false, true) => self.tee_right, // ├
        (true, false, true, true) => self.tee_up,    // ┴
        (false, true, true, true) => self.tee_down,  // ┬
        // ... more combinations
    }
}
```

## Representing Edge Scenarios

### Two Edges Crossing (Perpendicular)

**Possible**: `┼` represents both edges
```
    │
────┼────
    │
```

### Two Edges Parallel (Same Cell)

**Not distinguishable**: Only one `│` or `─` shown
```
Cannot show:  ││  or  ══
Only shows:   │   or  ─
```

### Edge Entering Node While Another Passes

**Possible**: T-junction shows connection
```
    │
    ├────  (edge continues right, edge enters down)
┌───┴───┐
│ Node  │
```

### Two Edges to Same Node Side

**Not distinguishable at same x**: Both become single `│` or `▼`
```
Cannot show:  ▼ ▼  (two arrows at x=5)
Only shows:   ▼    (one arrow visible)
```

## Minimum Spacing Requirements

### Between Parallel Edges

Minimum 1 cell to be visually distinct:
```
│ │   (2 edges, 1 space between)
```

For N parallel edges: minimum width = 2N - 1

### Between Edge and Node

Always 1 cell (enforced by `attachment_point()`):
```rust
AttachDirection::Top => Point::new(x, y.saturating_sub(1))
//                                    ↑ one cell above node
```

### For Multiple Edges on One Side

Need distinct x (or y) coordinates:
```
Node width 7:  +-----+
               ↑  ↑  ↑
               x=1 x=3 x=5  (3 distinct positions for 3 edges)
```

Formula: For N edges on top, need width ≥ 2N + 2 (borders + positions)

## What IS Possible

### 1. Offset Attachment Points

If node is wide enough, edges can attach at different x positions:
```
    │ │
    │ │
+---┴-┴---+
|  Node   |
+---------+
```

### 2. Different Sides for Different Edge Types

Forward edges use top/bottom, backward edges use left/right:
```
          │
          ▼
+--------→│ Node ├←--------+
          │                |
          ▼                |
                           |
+----------- corridor -----+
```

### 3. Junction Characters for Merging

Show edges coming together with T-junctions:
```
    ┬
    │     (two edges merge at ┬, continue as one │)
    ▼
```

### 4. Separate Corridors

Route backward edges through dedicated columns:
```
Content    │ Corridor
   │       │
   ▼       │
+----+     │
|Node|─────┤
+----+     │
           │
```

## What IS NOT Possible

### 1. Two Distinct Paths in One Cell

Cannot show:
```
│║   ──═   These require 2+ characters per cell
```

### 2. Curved Paths

Cannot show:
```
╭─╮   (requires sub-character precision)
│ │
╰─╯
```

### 3. Transparent Layering

Cannot show edge "behind" another:
```
A ─────── B
    │        (edge C→D should pass "under" but overlaps)
    C
```

### 4. Sub-Character Positioning

If two edges need x=5.3 and x=5.7, both map to x=5:
```
Target:  │ │   (x=5 and x=6)
Actual:  │     (both at x=5)
```

## Implications for Backward Edge Problem

The overlap in `simple_cycle.mmd` cannot be solved by:
- Showing both edges in the same cell (impossible)
- Using transparency (doesn't exist)
- Curves around obstacles (orthogonal only)

It CAN be solved by:
- Offsetting attachment points (requires node width)
- Using different node sides (changes visual style)
- Separate routing corridors (increases diagram width)
- Accepting junction characters (loses arrow direction)

## Recommended Approach

Given ASCII constraints, the most practical solutions are:

1. **Side differentiation**: Backward edges exit from right side
   - No width increase needed
   - Clear visual distinction
   - Works with any node width

2. **Port-based attachment**: Distribute edges along node side
   - Requires wider nodes (may need layout adjustment)
   - Most faithful to Dagre approach
   - Scales to any number of edges

3. **Multi-lane corridors**: Each backward edge gets own column
   - Width increases with backward edge count
   - Guaranteed no collisions
   - Already partially implemented
