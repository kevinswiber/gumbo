# 03: mmdflux Corridor-Based Backward Edge Routing

## Architecture Overview

The corridor system creates dedicated space on the canvas perimeter for backward edge routing. Instead of routing backward edges through the node layout area, they exit to the side and travel through a "corridor" zone.

## Layout Data Structures

**Layout struct** (`layout.rs:24-60`):
```rust
pub struct Layout {
    pub backward_corridors: usize,       // Number of corridors needed
    pub corridor_width: usize,           // Width per corridor (fixed: 3)
    pub backward_edge_lanes: HashMap<(String, String), usize>,  // Lane assignments
    pub edge_waypoints: HashMap<(String, String), Vec<(usize, usize)>>,
    pub edge_label_positions: HashMap<(String, String), (usize, usize)>,
    // ... node positions, dimensions, etc.
}
```

## How Corridors Work

### Canvas Expansion (layout.rs:115-168)

For TD/BT layouts, corridors expand the canvas **width** on the right side:
```
width += backward_corridors * corridor_width
```
- `corridor_width = 3` (hardcoded constant, line 117)
- Each backward edge gets one lane

For LR/RL layouts, corridors expand the canvas **height** at the bottom.

### Lane Assignment (layout.rs:512-555)

Backward edges are assigned lanes deterministically:
1. Collect all backward edges (compare grid positions against flow direction)
2. Sort by: source layer descending → target layer ascending → edge names
3. Assign lane = index in sorted order

### Corridor Position Calculation

For TD layout with lane `i`:
```
content_width = layout.width - (backward_corridors * corridor_width)
corridor_x = content_width + (lane * corridor_width) + corridor_width / 2
```

## Backward Edge Detection

**router.rs:102-121**:
```rust
pub fn is_backward_edge(
    from_bounds: &NodeBounds,
    to_bounds: &NodeBounds,
    direction: Direction,
) -> bool {
    match direction {
        Direction::TopDown => to_bounds.y < from_bounds.y,
        Direction::BottomTop => to_bounds.y > from_bounds.y,
        Direction::LeftRight => to_bounds.x < from_bounds.x,
        Direction::RightLeft => to_bounds.x > from_bounds.x,
    }
}
```

## Routing Path (3 Segments)

**For TD/BT layouts** (`router.rs:569-627`):

```
Segment 0 (Horizontal): Node right side → corridor X position
Segment 1 (Vertical):   Source Y → Target Y (up/down in corridor)
Segment 2 (Horizontal): Corridor X → Target right side
```

Visual:
```
┌──────┐
│Source │──────┐   ← Segment 0: horizontal to corridor
└──────┘      │
              │   ← Segment 1: vertical in corridor
┌──────┐      │
│Target │◄────┘   ← Segment 2: horizontal back to target
└──────┘
```

**For LR/RL layouts** (`router.rs:630-686`):
```
Segment 0 (Vertical):   Node bottom → corridor Y position
Segment 1 (Horizontal): Source X → Target X (in corridor)
Segment 2 (Vertical):   Corridor Y → Target bottom
```

## Entry Direction and Arrows

Backward edges enter from the **side** (not top/bottom), so arrows point LEFT or UP depending on layout:
- TD: `◄` (enters from right side)
- LR: `▲` (enters from bottom)

## Canvas Width Impact

Example with `complex.mmd` (2 backward edges):
- Base content width: ~40 chars
- Corridor overhead: 2 * 3 = 6 chars
- Total width: ~46 chars (15% wider)

## Interactions with Rest of Layout

- **Node positions**: Unaffected — corridors are outside the node area
- **Forward edge routing**: Completely independent — forward edges use waypoint-based routing
- **Canvas size**: Determined after corridor count is known
- **Label placement**: Special-cased for backward edges in `edge.rs:61-67`

## What Would Need to Change

To replace corridors with waypoint routing:

1. **Remove corridor expansion** from `layout.rs` (lines 115-168)
2. **Remove lane assignment** from `layout.rs` (lines 512-555)
3. **Replace `route_backward_edge()`** in `router.rs` (lines 546-687) with waypoint-based path
4. **Remove backward edge special-case** from label placement in `edge.rs`
5. **Update `is_backward_edge` usage** in `route_edge()` to route through waypoints instead of corridors
6. **Remove `backward_corridors`, `corridor_width`, `backward_edge_lanes`** from Layout struct
