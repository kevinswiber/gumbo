# Issue 2: "yes" Label Collision on Backward Edges

## Problem Statement

The "yes" label on the backward edge (More Data? -> Input) collides with other edges in the rendered output:

```
        ┌──────┘         ┌────yes┴──────────┐         │
        ├────────────────▼──────────────────▼─────────┘
```

The label "yes" appears on a horizontal line segment that also contains a junction character (`┴`), making it unclear which edge the label describes. This creates visual ambiguity.

---

## Mermaid.js Approach

### Label Positioning Strategy

Mermaid.js uses a **path-based midpoint calculation** for edge labels. The key logic is in `/packages/mermaid/src/utils.ts`:

```javascript
function traverseEdge(points) {
  let totalDistance = 0;
  points.forEach((point) => {
    totalDistance += distance(point, prevPoint);
    prevPoint = point;
  });

  // Label placed at exactly half the total path length
  const remainingDistance = totalDistance / 2;
  return calculatePoint(points, remainingDistance);
}
```

**Key insight:** Mermaid calculates the midpoint along the **actual rendered path**, not just the geometric midpoint between endpoints. This ensures the label appears on the edge itself.

### Edge Label Rendering (`/packages/mermaid/src/rendering-util/rendering-elements/edges.js`)

Labels are rendered in two passes:
1. **First pass:** Insert labels into the DOM and calculate their bounding boxes
2. **Layout pass:** Dagre runs, computing positions for all elements including edge label "dummy nodes"
3. **Position pass:** Labels are translated to their final positions based on the path

```javascript
export const positionEdgeLabel = (edge, paths) => {
  if (edge.label) {
    const pos = utils.calcLabelPosition(path);
    el.attr('transform', `translate(${pos.x}, ${pos.y})`);
  }
};
```

### Collision Avoidance

Mermaid relies on **SVG's natural layering** - labels render as separate DOM elements with z-index, so they appear "on top of" edge lines. In SVG, collision is purely visual overlap, not character overwriting.

For backward/reversed edges, the path is reversed (`reversePointsForReversedEdges`), but the label position is still calculated from the path midpoint.

---

## Dagre Approach

### Edge Labels as Dummy Nodes

Dagre treats edge labels as **first-class layout entities** by converting them to dummy nodes during the layout phase. From `/lib/normalize.js`:

```javascript
function normalizeEdge(g, e) {
  // Long edges are split into single-rank segments
  // Labels get their own dummy node at the appropriate rank
  if (vRank === labelRank) {
    attrs.width = edgeLabel.width;
    attrs.height = edgeLabel.height;
    attrs.dummy = "edge-label";
    attrs.labelpos = edgeLabel.labelpos;
  }
}
```

**Key insight:** By treating labels as nodes, Dagre's crossing reduction and coordinate assignment algorithms naturally avoid placing labels where they would collide with other elements.

### Label Rank Calculation

The label is placed at the "middle" rank between source and target:

```javascript
let label = { rank: (w.rank - v.rank) / 2 + v.rank, e: e };
util.addDummyNode(g, "edge-proxy", label, "_ep");
```

### Label Position Options

Dagre supports `labelpos` attribute with values:
- `"l"` - left of edge
- `"r"` - right of edge (default)
- `"c"` - center/on the edge

From `/lib/layout.js`:

```javascript
function fixupEdgeLabelCoords(g) {
  g.edges().forEach(e => {
    let edge = g.edge(e);
    switch (edge.labelpos) {
      case "l": edge.x -= edge.width / 2 + edge.labeloffset; break;
      case "r": edge.x += edge.width / 2 + edge.labeloffset; break;
    }
  });
}
```

### Reversed Edge Handling

When an edge is reversed (for cycle removal), Dagre marks it:

```javascript
label.reversed = true;
```

After layout, reversed edges have their points array reversed, but the label position is preserved because it was computed as a separate node.

---

## mmdflux Current Implementation

### Label Placement Logic (`/src/render/edge.rs`)

mmdflux places labels based on edge type:

```rust
fn draw_edge_label_with_tracking(
    canvas: &mut Canvas,
    routed: &RoutedEdge,
    label: &str,
    direction: Direction,
    placed_labels: &[PlacedLabel],
) -> Option<PlacedLabel> {
    // Detect backward edge
    let is_backward = match direction {
        Direction::TopDown => routed.end.y < routed.start.y,
        // ...
    };

    // Calculate base position
    let (base_x, base_y) = if is_backward && routed.segments.len() >= 3 {
        // For backward edges: place on corridor segment (segment[1])
        find_label_position_on_segment(&routed.segments[1], label_len, direction)
    } else {
        // For forward edges: midpoint between start and end
        let mid_x = (routed.start.x + routed.end.x) / 2;
        let mid_y = (routed.start.y + routed.end.y) / 2;
        (mid_x.saturating_sub(label_len / 2), mid_y)
    };
}
```

### Backward Edge Segment Structure

For TD layouts, backward edges have 4 segments:
1. **Vertical:** Node border to attachment point (1 cell)
2. **Horizontal:** Attachment point to corridor - **THIS IS `segments[1]`**
3. **Vertical:** In corridor (going up)
4. **Horizontal:** Corridor to target

The current code places the label on `segments[1]`, which is the **horizontal segment going TO the corridor** - not the corridor itself or the path to the target.

### The Bug

The problem is that `segments[1]` is the **wrong segment** for backward edge labels in TD layouts:

```rust
find_label_position_on_segment(&routed.segments[1], label_len, direction)
```

For a backward edge from "More Data?" to "Input":
- `segments[0]`: Short vertical (node top to attachment point)
- `segments[1]`: Horizontal from node to corridor (on the same row as other edges!)
- `segments[2]`: Vertical in corridor (isolated)
- `segments[3]`: Horizontal from corridor to target

The label is being placed on `segments[1]`, which shares its Y-coordinate with forward edges on that row, causing the collision.

### Collision Detection

mmdflux does have collision detection:

```rust
fn find_safe_label_position(
    canvas: &Canvas,
    base_x: usize,
    base_y: usize,
    label_len: usize,
    direction: Direction,
    placed_labels: &[PlacedLabel],
) -> (usize, usize) {
    if !label_has_collision(canvas, base_x, base_y, label_len, placed_labels) {
        return (base_x, base_y);
    }
    // Try shifts...
}
```

However, the collision check only considers:
1. Node cells (`cell.is_node`)
2. Previously placed labels

It does **not** consider edge line characters that are already drawn, because labels are drawn in a separate pass after edges.

---

## Root Cause Analysis

### Primary Cause: Wrong Segment Selection

The label is placed on `segments[1]` (horizontal segment at the source node's row), which is congested with other edges. This is the wrong segment for two reasons:

1. **Congestion:** Multiple edges pass through this row (forward edges from Process to More Data?, etc.)
2. **Ambiguity:** The label appears near a junction (`┴`), making it unclear which edge it belongs to

### Secondary Cause: Inadequate Collision Detection

The collision detection doesn't see edge characters because:
1. Edges are drawn first, labels second
2. Edge characters are not marked as "protected" like node characters
3. The `label_has_collision` function only checks `cell.is_node`

### Tertiary Cause: No Dedicated Label Space

Unlike Dagre, mmdflux doesn't reserve space for labels during layout. Labels are placed opportunistically after the fact.

---

## ASCII Constraints for Labels

### Character Grid Limitations

In ASCII art, labels must:
1. Be placed on a single horizontal line (no vertical text)
2. Not overlap with edge characters (would overwrite them)
3. Not overlap with node boundaries
4. Be close enough to their edge to be clearly associated

### Box-Drawing Character Interactions

When a label is placed on an edge segment, it **replaces** the edge characters:
- `───yes───` is clear
- `─yes┴───` is confusing (junction breaks the label)

### Optimal Label Positions for Backward Edges

Given the 4-segment structure of backward edges in TD layouts:

```
     ┌───────────────────────────────────┐
     │                                   │
     │  segments[2] (vertical corridor)  │
     │                                   │
─────┴───segments[1]───┐ segments[3]─────►
     ^                 │
     │                 ▼
  SOURCE            TARGET
```

The best positions for labels are:
1. **segments[2]** (vertical corridor): Isolated, no other edges
2. **segments[3]** (horizontal to target): Clear path to destination
3. **Avoid segments[1]**: Shares row with source node and other edges

---

## Recommended Solutions

### Solution 1: Place Label on Corridor Segment (segments[2])

**Change:** Modify `find_label_position_on_segment` to use `segments[2]` for vertical layouts.

**Implementation:**
```rust
let (base_x, base_y) = if is_backward && routed.segments.len() >= 4 {
    // For backward edges in TD: place on vertical corridor segment
    // segments[2] is the isolated vertical segment in the corridor
    find_label_position_on_segment(&routed.segments[2], label_len, direction)
} else if is_backward && routed.segments.len() >= 3 {
    find_label_position_on_segment(&routed.segments[1], label_len, direction)
} else {
    // Forward edge midpoint
};
```

**Pros:**
- Labels appear on isolated corridor segment
- No collision with other edges
- Clear association with the backward edge

**Cons:**
- Vertical segment labels must be placed horizontally (to the left or right of the line)
- May need special handling for short corridors

**Visual Result:**
```
                      ┌───────┐
                      │ Input │◄────────────────────┐
                      └───────┘                     │
                          │                        yes
                          │                         │
                          ▼                         │
```

### Solution 2: Place Label Near Target Entry (segments[3])

**Change:** Place the label on the final horizontal segment entering the target.

**Implementation:**
```rust
let (base_x, base_y) = if is_backward && routed.segments.len() >= 4 {
    // Place on horizontal segment entering target
    find_label_position_on_segment(&routed.segments[3], label_len, direction)
};
```

**Pros:**
- Label is near the arrow, clearly indicating the edge
- Horizontal segment is natural for text labels

**Cons:**
- May collide with target node's other incoming edges
- Limited space if corridor is close to target

**Visual Result:**
```
                      ┌───────┐
                      │ Input │◄───yes──────────────┐
                      └───────┘                     │
```

### Solution 3: Offset Labels Above/Below Edge Lines

**Change:** Place labels one row above or below the edge segment.

**Implementation:**
```rust
fn find_label_position_on_segment(segment, label_len, direction) -> (usize, usize) {
    match segment {
        Segment::Horizontal { y, x_start, x_end } => {
            let mid_x = (*x_start + *x_end) / 2;
            // Place one row ABOVE the horizontal line
            (mid_x.saturating_sub(label_len / 2), y.saturating_sub(1))
        }
        // ...
    }
}
```

**Pros:**
- Works for any segment
- Labels don't interfere with edge characters

**Cons:**
- May collide with nodes above/below
- Takes more vertical space
- Label association is less clear

### Solution 4: Reserve Label Space in Layout

**Change:** During layout, calculate label positions and reserve space.

**Implementation:**
1. Before finalizing layout, identify which edges have labels
2. For backward edges, expand corridor height to accommodate labels
3. Mark label cells during layout, not just during rendering

**Pros:**
- Prevents collisions by design
- Most robust solution

**Cons:**
- Significant architecture change
- Increases diagram size
- Complex implementation

---

## Recommended Approach

**Primary recommendation: Solution 1** (Label on corridor segment)

This provides the best balance of:
- Simplicity (small code change)
- Effectiveness (labels in isolated area)
- Visual clarity (clear edge-label association)

**Implementation steps:**
1. Change backward edge label placement to use `segments[2]` for TD/BT layouts
2. For horizontal label on vertical segment, place to the left of the line
3. Add special case for when corridor segment is very short (fall back to segments[3])

**Secondary recommendation: Enhance collision detection**

Even with better segment selection, improve the collision check:
1. After drawing edges, scan canvas for non-space characters
2. Use this scan when checking label positions
3. Fall back to shifting labels if collision detected

---

## Test Cases

To verify the fix, test with:
1. `tests/fixtures/simple_cycle.mmd` - Basic cycle
2. `tests/fixtures/multiple_cycles.mmd` - Multiple backward edges
3. `tests/fixtures/complex.mmd` - The original problem case

Expected outcomes:
- Labels on backward edges should not share cells with other edges
- Labels should be clearly associated with their edge
- No visual ambiguity about which edge a label describes
