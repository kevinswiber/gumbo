# Current mmdflux Edge Routing Behavior for Large Horizontal Offsets in TD Layouts

## Overview

This document analyzes how forward edges with large horizontal offsets are routed in TopDown (TD) layouts in mmdflux. The routing logic creates Z-shaped orthogonal paths that ensure arrows visually connect to the expected sides of target nodes.

## Key Entry Points

### 1. `route_edge()` - Main Routing Dispatcher (Lines 124-177)

```rust
pub fn route_edge(
    edge: &Edge,
    layout: &Layout,
    diagram_direction: Direction,
) -> Option<RoutedEdge> {
    let from_bounds = layout.get_bounds(&edge.from)?;
    let to_bounds = layout.get_bounds(&edge.to)?;

    // Check if this is a backward edge
    if is_backward_edge(from_bounds, to_bounds, diagram_direction) {
        return route_backward_edge(edge, from_bounds, to_bounds, layout, diagram_direction);
    }

    // Check if we have waypoints for this edge (from normalization)
    let edge_key = (edge.from.clone(), edge.to.clone());
    let waypoints = layout.edge_waypoints.get(&edge_key);

    // ... [shape info retrieval] ...

    if let Some(wps) = waypoints {
        if !wps.is_empty() {
            // Use waypoints with dynamic intersection calculation
            return route_edge_with_waypoints(/* ... */);
        }
    }

    // No waypoints: use intersection calculation for direct path
    route_edge_direct(/* ... */)
}
```

**Critical Decision Point**: Forward edges with large horizontal offsets follow the direct routing path (line 169-176) when there are no waypoints from normalization.

### 2. `route_edge_direct()` - Direct Edge Routing (Lines 234-291)

This function handles edges with no intermediate waypoints:

```rust
fn route_edge_direct(
    edge: &Edge,
    from_bounds: &NodeBounds,
    from_shape: Shape,
    to_bounds: &NodeBounds,
    to_shape: Shape,
    direction: Direction,
) -> Option<RoutedEdge> {
    // Step 1: Calculate attachment points based on node centers
    let empty_waypoints: &[(usize, usize)] = &[];
    let (src_attach_raw, tgt_attach_raw) = calculate_attachment_points(
        from_bounds, from_shape, to_bounds, to_shape, empty_waypoints,
    );

    // Step 2: Clamp to node boundaries
    let src_attach_point = clamp_to_boundary(src_attach_raw, from_bounds);
    let tgt_attach_point = clamp_to_boundary(tgt_attach_raw, to_bounds);

    // Step 3: Offset by 1 cell outside node boundaries
    let start = offset_from_boundary(src_attach, from_bounds);
    let end = offset_from_boundary(tgt_attach, to_bounds);

    // Step 4: Build orthogonal path using direction-specific routing
    segments.extend(build_orthogonal_path_for_direction(start, end, direction));

    // Step 5: Determine entry direction from final segment
    let entry_direction = entry_direction_from_segments(&segments, end);

    Some(RoutedEdge { edge, start, end, segments, entry_direction })
}
```

### 3. `build_orthogonal_path_for_direction()` - Z-Path Construction (Lines 432-500)

This is the **critical function** that creates Z-shaped paths for TD layouts:

```rust
fn build_orthogonal_path_for_direction(
    start: Point,
    end: Point,
    direction: Direction,
) -> Vec<Segment> {
    // If aligned on same x-axis, straight vertical path
    if start.x == end.x {
        return vec![Segment::Vertical { x: start.x, y_start: start.y, y_end: end.y }];
    }
    // If aligned on same y-axis, straight horizontal path
    if start.y == end.y {
        return vec![Segment::Horizontal { y: start.y, x_start: start.x, x_end: end.x }];
    }

    // For non-aligned paths in TD/BT, construct Z-shaped path (V-H-V)
    match direction {
        Direction::TopDown | Direction::BottomTop => {
            // Z-SHAPE: Vertical -> Horizontal -> Vertical
            let mid_y = (start.y + end.y) / 2;  // <-- CRITICAL LINE 464
            vec![
                Segment::Vertical { x: start.x, y_start: start.y, y_end: mid_y },
                Segment::Horizontal { y: mid_y, x_start: start.x, x_end: end.x },
                Segment::Vertical { x: end.x, y_start: mid_y, y_end: end.y },
            ]
        }
        Direction::LeftRight | Direction::RightLeft => {
            // L-SHAPE: Horizontal -> Vertical
            vec![
                Segment::Horizontal { y: start.y, x_start: start.x, x_end: end.x },
                Segment::Vertical { x: end.x, y_start: start.y, y_end: end.y },
            ]
        }
    }
}
```

## The Mid-Y Calculation Problem

### Where the Problem Occurs

**Line 464**: `let mid_y = (start.y + end.y) / 2;`

This single line determines where the horizontal segment is placed in the Z-shaped path.

### Example: E->F Edge from complex.mmd

Given the diagram:
```
graph TD
    ...
    E{More Data?}      % Diamond node on right side of diagram
    F[Output]          % Rectangle at center of diagram
```

**After layout computation** (approximate positions):
- E node: bounds at (x=50, y=20, width=15, height=3) - right side
- F node: bounds at (x=25, y=40, width=13, height=3) - center

**Step-by-step execution of route_edge_direct() for E->F**:

1. **Attachment calculation**: Based on node centers
2. **Clamping**: Points adjusted to node boundaries
3. **Offsetting**: Points moved 1 cell outside nodes
4. **Z-path construction** (Line 464):
   ```rust
   mid_y = (21 + 40) / 2 = 30  // <-- CRITICAL CALCULATION

   Segments created:
   [
     Vertical { x: 66, y_start: 21, y_end: 30 },    // Down from E
     Horizontal { y: 30, x_start: 66, x_end: 31 },  // Leftward THROUGH MIDDLE
     Vertical { x: 31, y_start: 30, y_end: 40 },    // Down to F
   ]
   ```

### Why This Creates the "Crowded Middle" Problem

The Z-path's horizontal segment is placed at **y = 30**, which:
- Falls in the middle vertical space of the diagram
- May cross through areas where other nodes (like "Cleanup") exist
- Doesn't consider node density or other edges at that y-level

**Visual result** (schematic):
```
E{More Data?}
    |
    | (down to mid_y)
    └────────────────────┐  <-- Horizontal segment at mid_y
                         |       passes through crowded middle
                         |
                     [Output]
```

### The Algorithm's Design Rationale

The mid-y calculation `(start.y + end.y) / 2` attempts to:
1. **Create symmetric paths** - The bend point is centered between source and target
2. **Ensure vertical entry** - The final segment is vertical, guaranteeing entry from top/bottom
3. **Work for most cases** - For pairs of nodes with similar positions, paths don't interfere

But it **fails for large offsets** because:
- It doesn't consider **other edges and nodes** in the middle region
- It doesn't account for **node density** at intermediate layers
- All edges with similar start/end y-ranges converge to the **same mid_y value**

## Key Code Locations

| Function | File | Lines | Purpose |
|----------|------|-------|---------|
| `route_edge()` | router.rs | 124-177 | Entry point, dispatches to direct or waypoint routing |
| `route_edge_direct()` | router.rs | 234-291 | Handles edges without waypoints |
| `build_orthogonal_path_for_direction()` | router.rs | 432-500 | Creates Z-path segments |
| `offset_from_boundary()` | router.rs | 319-361 | Determines attachment direction |
| `clamp_to_boundary()` | router.rs | 298-313 | Ensures points are on node edges |

## Z-Path Structure

A Z-path for TD layout is always three segments (unless start/end align):
1. **First Vertical**: `Segment::Vertical { x: start.x, y_start: start.y, y_end: mid_y }`
2. **Horizontal**: `Segment::Horizontal { y: mid_y, x_start: start.x, x_end: end.x }`
   - This is where **large offsets cause congestion**
3. **Second Vertical**: `Segment::Vertical { x: end.x, y_start: mid_y, y_end: end.y }`

## Current Behavior Summary

1. **Forward edges are routed directly** (no waypoints) when source and target don't have waypoints
2. **Z-paths (V-H-V) are created for TD layouts** to ensure vertical entry arrows
3. **The horizontal bend is placed at `(start.y + end.y) / 2`** regardless of other diagram elements
4. **Large horizontal offsets** cause the horizontal segment to pass through crowded middle areas
5. **No collision avoidance** is applied to the horizontal segment
6. **No consideration** of routing through the right corridor (where backward edges go) even when source is on the right side
