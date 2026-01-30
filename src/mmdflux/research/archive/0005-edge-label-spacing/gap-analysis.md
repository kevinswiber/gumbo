# Gap Analysis: Edge Label Spacing

## Overview

This document compares Mermaid.js/Dagre's label positioning approach with mmdflux's current implementation to identify gaps causing the label overlap issues.

## Feature Comparison

| Feature | Mermaid/Dagre | mmdflux | Gap |
|---------|---------------|---------|-----|
| Position calculation | Geometric midpoint of path | Midpoint of start/end coords | ✓ Equivalent |
| Label centering | Transform-based SVG centering | Character-level centering | ✓ Equivalent |
| Perpendicular offset | 10-25px for terminal labels only | None | **Gap** |
| Collision detection | None (relies on spacing) | Node + label collision only | **Gap** |
| Edge character protection | N/A (SVG layers) | Not implemented | **Gap** |
| Label dimensions in layout | Dagre reserves space via dummy nodes | Not integrated with layout | **Gap** |
| Labelpos (left/center/right) | Full support | Not implemented | **Gap** |
| Labeloffset property | Configurable (default 10px) | Hard-coded 1 char | **Gap** |
| Space reservation | Halves ranksep for labels | None | **Gap** |

## Critical Gaps

### Gap 1: No Perpendicular Offset

**What:** Mermaid's terminal labels are offset 10+ pixels perpendicular to the edge. mmdflux places labels directly adjacent to edge paths.

**When:** All edges with labels.

**Impact:** Labels touch or overlap edge path characters, especially at corners.

**Evidence:**
```
Mermaid (SVG):
    A ─── label ─── B    (label floats above/beside line)

mmdflux (ASCII):
    A ───label─── B      (label overwrites line characters)
```

### Gap 2: Edge Characters Not Protected

**What:** mmdflux marks node characters with `is_node = true` but doesn't mark edge characters. Label collision detection only checks `is_node`.

**When:** Writing label characters to canvas.

**Impact:** Labels overwrite edge path characters (─, │, └, ┐, etc.).

**Code location:** `src/render/edge.rs:134-136`
```rust
// Current: only skips node cells
if canvas.get(x, label_y).is_some_and(|cell| !cell.is_node) {
    canvas.set(x, label_y, ch);  // Overwrites edge characters
}
```

### Gap 3: No Space Reservation for Labels

**What:** Dagre halves `ranksep` and doubles edge `minlen` when labels exist, creating vertical space. mmdflux uses fixed spacing regardless of labels.

**When:** Layout computation.

**Impact:** Labels compete for the same vertical space as edges, leading to crowding.

**Dagre approach:**
```javascript
// From dagre layout.js:158-172
graph.ranksep /= 2;  // Create room for labels
edge.minlen *= 2;    // Ensure vertical space
```

**mmdflux:** Fixed `row_spacing` in config, not adjusted for labels.

### Gap 4: Hard-Coded Offsets vs Configurable

**What:** Dagre has `labeloffset` property (default 10px). mmdflux uses hard-coded 1-character offsets.

**When:** Positioning labels relative to edge segments.

**Impact:** Insufficient spacing in ASCII where characters are discrete cells.

**mmdflux code:** `src/render/edge.rs:160, 171`
```rust
// Vertical segment: 1 character offset
x.saturating_sub(label_len + 1)

// Horizontal segment: 1 row offset
y.saturating_sub(1)
```

### Gap 5: No Corner Awareness

**What:** When edges have corners (└, ┐, ┘, ┌), the corner character occupies space. Neither Mermaid nor mmdflux explicitly handle this, but SVG rendering naturally accommodates it while ASCII doesn't.

**When:** Labels near edge junctions.

**Impact:** Labels collide with corner characters.

**Example:**
```
Expected:
    valid
     │
     └──┐
        ▼

Actual:
   valid└──┐
        ▼
```

### Gap 6: Collision Detection Incomplete

**What:** mmdflux checks collision against nodes and previously-placed labels, but not against edge path characters already on canvas.

**When:** `label_has_collision()` called during placement.

**Impact:** Labels placed on top of edge paths pass collision check.

**Code location:** `src/render/edge.rs:249-267`

## Why SVG Works But ASCII Doesn't

| Aspect | SVG (Mermaid) | ASCII (mmdflux) |
|--------|---------------|-----------------|
| Coordinate precision | Sub-pixel floats | Discrete integers |
| Overlap tolerance | Layers can overlap readably | Characters overwrite |
| Spacing granularity | Continuous | 1 character minimum |
| Line rendering | Vectors with thickness | Single characters |
| Corner representation | Smooth curves or sharp angles | Box-drawing characters |

## Root Cause Analysis

The fundamental mismatch:

1. **Mermaid/Dagre assume continuous space** where labels can be positioned at any coordinate and "float" near edges without physically intersecting them.

2. **ASCII art is discrete** where labels must occupy character cells, and those cells either contain the label OR the edge, not both.

3. **Current mmdflux approach** positions labels similarly to Mermaid but then **overwrites edge characters** because the canvas model doesn't distinguish between "empty space near edge" and "edge character".

## Recommended Fixes

### Short-term (Quick Wins)

1. **Add edge character collision check** in `label_has_collision()`
   - Check if canvas cells contain non-space, non-node characters
   - Prevents labels from overwriting edge paths

2. **Increase minimum offset** from 1 to 2 characters
   - Provides buffer for corner characters
   - Change in `find_label_position_on_segment()`

### Medium-term (Proper Fix)

3. **Mark edge cells on canvas** with new flag `is_edge`
   - Modify `Canvas` struct to track edge cells
   - Update collision detection to check `is_edge`

4. **Adjust layout spacing for labels**
   - When edge has label, increase `row_spacing` for that edge
   - Similar to Dagre's ranksep halving approach

### Long-term (Full Feature)

5. **Implement labelpos support** (left/center/right)
   - Give users control over label placement
   - Particularly useful for dense diagrams

6. **Add configurable labeloffset**
   - Allow tuning spacing per-diagram or per-edge
   - Default to 2 characters for ASCII
