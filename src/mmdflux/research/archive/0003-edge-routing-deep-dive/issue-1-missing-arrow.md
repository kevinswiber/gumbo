# Issue 1: Missing Arrow on Process to More Data? Edge

## Problem Statement

In the complex.mmd diagram, the edge from "Process" to "More Data?" has no arrow at the entry point. The edge terminates at a junction character (`├`) without indicating direction. This makes it unclear where the flow is going.

**Observed output (excerpt):**
```
          ┌─────────┐    ╭───────────────╮
          │ Process │    │ Error Handler │
          └─────────┘    ╰───────────────╯
               │                 │
        ┌──────┘         ┌────yes┴──────────┐
        ├────────────────▼──────────────────▼─────────┘
 ┌────────────┐    ┌───────────┐    ┌──────────────┐
 < More Data? >    │ Log Error │    │ Notify Admin │
```

**Expected:** An arrow (▼) should appear where the edge from "Process" enters "More Data?".

---

## Mermaid.js Approach

### Arrow Rendering via SVG Markers

Mermaid.js uses SVG marker definitions for arrows. Key insights from `/packages/mermaid/src/rendering-util/rendering-elements/edgeMarker.ts`:

1. **Marker-based approach**: Arrows are defined as SVG markers and attached to path endpoints using `marker-start` and `marker-end` attributes.

2. **No junction collision**: Because SVG paths are vector graphics with Z-ordering, arrows are always rendered as separate overlay elements. They don't get "overwritten" by other edge segments.

3. **Marker types**: Supports multiple arrow types (point, circle, cross, barb) via a type map:
   ```typescript
   const arrowTypesMap = {
     arrow_point: { type: 'point', fill: true },
     arrow_circle: { type: 'circle', fill: false },
     // ...
   };
   ```

4. **Position attachment**: Arrows are attached via SVG's built-in marker positioning:
   ```typescript
   svgPath.attr(`marker-end`, `url(${url}#${markerId})`);
   ```

### Edge Path Computation

From `/packages/mermaid/src/rendering-util/rendering-elements/edges.js`:

1. **Intersection calculation**: The edge path is trimmed to the node boundary using intersection calculations:
   ```javascript
   points.unshift(tail.intersect(points[0]));
   points.push(head.intersect(points[points.length - 1]));
   ```

2. **Separate edge rendering**: Each edge is drawn as its own independent SVG path. There's no shared canvas where edges overwrite each other.

3. **Multi-pass rendering**: Labels and markers are added after the main path is drawn, ensuring they appear on top.

---

## Dagre Approach

### Edge Point Assignment

From `/lib/layout.js`:

1. **Edge points as array**: Dagre computes edge waypoints as an array of `{x, y}` coordinates:
   ```javascript
   inputLabel.points = layoutLabel.points;
   ```

2. **Node intersection for endpoints**: The `assignNodeIntersects` function calculates where edges touch node boundaries:
   ```javascript
   function assignNodeIntersects(g) {
     g.edges().forEach(e => {
       let edge = g.edge(e);
       let nodeV = g.node(e.v);
       let nodeW = g.node(e.w);
       // ...
       edge.points.unshift(util.intersectRect(nodeV, p1));
       edge.points.push(util.intersectRect(nodeW, p2));
     });
   }
   ```

3. **Intersection algorithm** (from `/lib/util.js`):
   ```javascript
   function intersectRect(rect, point) {
     // Calculates the exact point where a line from rect center
     // to external point crosses the rect boundary
     // Returns precise {x, y} coordinates
   }
   ```

### Key insight: Dagre provides endpoints, rendering is separate

Dagre only computes the geometry. Arrow rendering is delegated to the rendering layer (like Mermaid.js's SVG renderer). This separation means arrows are never subject to overwriting.

---

## mmdflux Current Implementation

### Edge Routing (`/src/render/router.rs`)

1. **Attachment points**: Edges connect to nodes at specific attachment points:
   ```rust
   fn attachment_point(bounds: &NodeBounds, direction: AttachDirection) -> Point {
       match direction {
           AttachDirection::Top => Point::new(x, y.saturating_sub(1)),
           // ... one cell outside node boundary
       }
   }
   ```

2. **RoutedEdge structure**: Contains entry direction for arrow drawing:
   ```rust
   pub struct RoutedEdge {
       pub end: Point,           // Attachment point on target
       pub entry_direction: AttachDirection,  // For arrow direction
       pub segments: Vec<Segment>,
   }
   ```

3. **Forward edge routing**: Uses midpoint Z-shaped paths:
   ```rust
   fn compute_vertical_first_path(start: Point, end: Point) -> Vec<Segment> {
       // Vertical -> Horizontal -> Vertical segments
   }
   ```

### Edge Rendering (`/src/render/edge.rs`)

1. **Segment drawing**: Each segment draws line characters with connection tracking:
   ```rust
   fn draw_segment(canvas: &mut Canvas, segment: &Segment, ...) {
       for y in y_min..=y_max {
           let connections = Connections { up: y > y_min, down: y < y_max, ... };
           canvas.set_with_connection(x, y, connections, charset);
       }
   }
   ```

2. **Arrow drawing**: After all segments, arrow is placed at endpoint:
   ```rust
   if routed.edge.arrow != Arrow::None {
       draw_arrow_with_entry(canvas, &routed.end, routed.entry_direction, charset);
   }
   ```

3. **Render order in `render_all_edges`**:
   ```rust
   // First pass: draw all segments and arrows
   for routed in routed_edges {
       for segment in &routed.segments { draw_segment(...); }
       if routed.edge.arrow != Arrow::None {
           draw_arrow_with_entry(canvas, &routed.end, ...);
       }
   }
   // Second pass: draw all labels
   ```

### Canvas and Junction Resolution (`/src/render/canvas.rs`, `/src/render/chars.rs`)

1. **Connection-based character selection**: When edges cross, connections are merged:
   ```rust
   pub fn set_with_connection(&mut self, x, y, connections, charset) {
       cell.connections.merge(connections);
       cell.ch = charset.junction(cell.connections);  // ├, ┼, etc.
   }
   ```

2. **Junction characters replace arrows**: The `junction()` function returns box-drawing characters based on connections, NOT arrows. A cell with 3 connections gets `├`, not `▼`.

---

## Code Location of the Bug

The bug is in `/src/render/edge.rs` in the `render_all_edges` function (lines 375-407):

```rust
pub fn render_all_edges(
    canvas: &mut Canvas,
    routed_edges: &[RoutedEdge],
    charset: &CharSet,
    diagram_direction: Direction,
) {
    // First pass: draw all segments and arrows
    for routed in routed_edges {
        for segment in &routed.segments {
            draw_segment(canvas, segment, routed.edge.stroke, charset);
        }
        if routed.edge.arrow != Arrow::None {
            draw_arrow_with_entry(canvas, &routed.end, routed.entry_direction, charset);
        }
    }
    // ...
}
```

**The bug**: Segments and arrows are drawn together for each edge. When Edge A draws its arrow, then Edge B's segment passes through that cell, Edge B's `draw_segment` -> `set_with_connection` overwrites the arrow with a junction character.

---

## Root Cause Analysis

### The Problem: Junction Characters Overwrite Arrows

The issue occurs because of the rendering order and canvas cell semantics:

1. **Multiple edges share the same endpoint**: In the complex diagram, multiple edges converge at the same horizontal line. The "Process" to "More Data?" edge and other edges share cells.

2. **Segment drawing uses `set_with_connection`**: When drawing segments, the code tracks connections and calls `charset.junction()` to get the appropriate box-drawing character.

3. **Junction() returns line characters, not arrows**: The `junction()` function only knows about `├`, `┼`, `┬` etc. It has no concept of arrows.

4. **Arrow drawing uses `canvas.set()`**: The arrow is drawn with a simple `set()` call:
   ```rust
   canvas.set(point.x, point.y, arrow_char);  // ▼
   ```

5. **Later edges overwrite the arrow**: If another edge segment passes through the same cell after the arrow is drawn, `set_with_connection()` replaces the `▼` with `├` or similar.

### Specific Scenario

In the complex diagram:
1. Edge from "Process" to "More Data?" is rendered, placing `▼` at the entry point
2. Another edge (backward edge or shared corridor line) passes through the same cell
3. `set_with_connection()` merges connections and calls `junction()`, replacing `▼` with `├`

---

## ASCII Constraints

Unlike SVG where elements can overlap with Z-ordering, ASCII art has fundamental constraints:

1. **One character per cell**: Each (x, y) position can hold exactly one character
2. **No layering**: Cannot draw an arrow "on top of" a junction
3. **Edge merging**: Multiple edges sharing a cell must be represented by a single junction character
4. **Character semantics**: Box-drawing characters imply connectivity but not direction

---

## Recommended Solutions

### Solution 1: Arrow Priority (Simple)

**Approach**: Mark arrow cells as "protected" so junction resolution doesn't overwrite them.

**Implementation**:
```rust
// In draw_arrow_with_entry:
fn draw_arrow_with_entry(canvas: &mut Canvas, point: &Point, ...) {
    canvas.set(point.x, point.y, arrow_char);
    canvas.mark_as_protected(point.x, point.y);  // New: prevent overwrite
}

// In set_with_connection:
if cell.is_protected {
    return false;  // Don't overwrite
}
```

**Tradeoffs**:
- (+) Simple implementation, few code changes
- (+) Preserves arrows at entry points
- (-) Could cause visual artifacts if protected cell should merge with other connections
- (-) Only one arrow can be at a junction (first wins)

### Solution 2: Arrow-Aware Junction Characters (Medium)

**Approach**: Create special characters or character combinations that show both junction and arrow.

**Implementation**:
```rust
// Extend junction() to handle arrow overlay
pub fn junction_with_arrow(&self, conn: Connections, arrow_dir: Option<AttachDirection>) -> char {
    match (arrow_dir, conn) {
        (Some(AttachDirection::Top), _) => self.arrow_down,  // Arrow takes priority
        (Some(AttachDirection::Right), _) => self.arrow_left,
        // ...
        (None, _) => self.junction(conn),
    }
}
```

**Tradeoffs**:
- (+) Arrows always visible at entry points
- (+) Logically consistent: arrow direction matters
- (-) Junction information is lost visually
- (-) Multiple arrows at same point still a problem

### Solution 3: Offset Arrow Placement (Medium-High)

**Approach**: Place the arrow one cell before the actual entry point, leaving the entry point free for junction.

**Implementation**:
```rust
fn draw_arrow_with_entry(canvas: &mut Canvas, routed: &RoutedEdge, ...) {
    // Place arrow at the penultimate point of the path, not the endpoint
    let arrow_pos = calculate_arrow_position_before_entry(&routed.segments, routed.end);
    canvas.set(arrow_pos.x, arrow_pos.y, arrow_char);
}
```

**Tradeoffs**:
- (+) Arrow and junction can coexist
- (+) Visually clear entry direction
- (-) Requires modifying path analysis
- (-) Arrows appear slightly before the node, may look off
- (-) Complex edges may not have suitable "before entry" position

### Solution 4: Two-Character Arrow with Junction (High Complexity)

**Approach**: Use the cell before the junction as the arrow, with the junction cell showing the merge.

Example:
```
     ▼
     ├─────
```

Instead of:
```
     ├─────  (arrow missing)
```

**Implementation**:
- Ensure every edge path has at least one "runway" cell before entering a potential junction
- Place arrow on runway, let junction resolve normally

**Tradeoffs**:
- (+) Both arrow and junction visible
- (+) Clear visual hierarchy
- (-) Requires more space/padding in layout
- (-) May not work well with tight node spacing
- (-) Significant changes to routing algorithm

### Solution 5: Render Order Adjustment (Simplest) - RECOMMENDED FIRST FIX

**Approach**: Draw arrows AFTER all segments are drawn, as a final pass.

The current code structure is:
```rust
// Current (buggy) implementation:
for routed in routed_edges {
    for segment in &routed.segments { draw_segment(...); }  // Edge A segments
    draw_arrow_with_entry(...);                             // Edge A arrow at (x, y)
}
// Next iteration:
// Edge B segment passes through (x, y), calls set_with_connection() -> overwrites arrow!
```

**Fixed Implementation**:
```rust
pub fn render_all_edges(...) {
    // First pass: draw all segments ONLY
    for routed in routed_edges {
        for segment in &routed.segments {
            draw_segment(...);
        }
    }

    // Second pass: draw all arrows (overwrites junctions at entry points)
    for routed in routed_edges {
        if routed.edge.arrow != Arrow::None {
            draw_arrow_with_entry(...);
        }
    }

    // Third pass: draw all labels
    // ...
}
```

**Tradeoffs**:
- (+) Minimal code change (just restructure the existing loop)
- (+) Arrows always visible at entry points
- (+) Matches the stated intent in the comment ("Draws all segments and arrows first")
- (-) Arrows overwrite junction info (but arrows ARE more important than junctions at entry points)
- (-) Multiple arrows at same cell: last one wins (rare edge case)

---

## Recommendation

**Start with Solution 5 (Render Order)** as it requires minimal changes and fixes the most common case. If visual regression occurs on junction-heavy diagrams, then escalate to **Solution 1 (Arrow Priority)** with selective protection.

For a more robust long-term fix, **Solution 3 (Offset Arrow Placement)** provides the best balance of clarity and correctness, but requires more significant refactoring.

### Next Steps

1. Verify the root cause by adding debug output showing which cells are being overwritten
2. Implement Solution 5 first and test on existing fixtures
3. If issues remain, implement arrow cell protection (Solution 1)
4. Consider Solution 3 for v2 if edge density continues to cause problems
