# Waypoint Generation Strategies

## Overview

This document explores approaches for computing waypoints for forward edges with large horizontal offset. The goal is to route these edges through cleaner paths (like the right corridor area) instead of the crowded diagram middle.

---

## Problem Statement

In `complex.mmd`, the edge E→F ("More Data?" → "Output") with label "no":
- Source E is on the **right side** of the diagram
- Target F is **centered**
- Current routing goes **left through the middle** (crowded area)
- Ideal routing would go **down on the right, then left** below the congestion

```
Current (mid-y routing):          Ideal (waypoint-based):
    E{More Data?}                     E{More Data?}
        │                                  │
        └───────┐                          │
                │ ← crosses middle         │ ← stays right
        ┌───────┘                          └────────┐
        │                                           │
        ▼                                    ┌──────┘
    [Output]                                 ▼
                                         [Output]
```

---

## Strategy 1: Simple Heuristic Waypoint

### Description
Insert a single waypoint that forces the edge to travel vertically first, then horizontally at a better y-position.

### Algorithm

```rust
fn generate_heuristic_waypoint(
    source_bounds: &NodeBounds,
    target_bounds: &NodeBounds,
    layout: &Layout,
    direction: Direction,
) -> Option<Vec<(usize, usize)>> {
    let horizontal_offset = source_bounds.center_x().abs_diff(target_bounds.center_x());
    let diagram_center_x = layout.width / 2;

    // Only apply for large horizontal offsets
    const THRESHOLD: usize = 20;
    if horizontal_offset < THRESHOLD {
        return None;
    }

    // Determine if source is on right or left side
    let source_on_right = source_bounds.center_x() > diagram_center_x;

    match direction {
        Direction::TopDown => {
            // Waypoint: keep source X, move Y close to target
            // This forces vertical travel first, then horizontal at bottom
            let waypoint_x = source_bounds.center_x();
            let waypoint_y = target_bounds.y.saturating_sub(2); // Just above target

            Some(vec![(waypoint_x, waypoint_y)])
        }
        Direction::BottomTop => {
            let waypoint_x = source_bounds.center_x();
            let waypoint_y = target_bounds.y + target_bounds.height + 2;

            Some(vec![(waypoint_x, waypoint_y)])
        }
        // Similar for LR/RL...
        _ => None,
    }
}
```

### Pros
- Simple to implement (~30 lines)
- Deterministic behavior
- No pathfinding overhead
- Works for the common case (source on side, target in middle)

### Cons
- Single waypoint may not avoid all obstacles
- Doesn't consider intermediate node positions
- Fixed threshold may not work for all diagram sizes

### Complexity: Low

---

## Strategy 2: Corridor-Based Waypoint

### Description
Route through the backward edge corridor area (right side for TD layouts) using two waypoints to create an "around the corner" path.

### Algorithm

```rust
fn generate_corridor_waypoints(
    source_bounds: &NodeBounds,
    target_bounds: &NodeBounds,
    layout: &Layout,
    direction: Direction,
) -> Option<Vec<(usize, usize)>> {
    let horizontal_offset = source_bounds.center_x().abs_diff(target_bounds.center_x());
    let diagram_center_x = layout.width / 2;

    const THRESHOLD: usize = 20;
    if horizontal_offset < THRESHOLD {
        return None;
    }

    let source_on_right = source_bounds.center_x() > diagram_center_x;

    if !source_on_right {
        return None; // Only handle right-side sources for now
    }

    match direction {
        Direction::TopDown => {
            // Use the corridor on the right side
            let corridor_x = layout.width.saturating_sub(layout.corridor_width / 2);

            // Two waypoints:
            // 1. Move right to corridor at source Y
            // 2. Stay in corridor, drop to target Y level
            let wp1 = (corridor_x, source_bounds.center_y());
            let wp2 = (corridor_x, target_bounds.y.saturating_sub(2));

            Some(vec![wp1, wp2])
        }
        _ => None,
    }
}
```

### Pros
- Uses existing corridor infrastructure
- Creates clean "around the corner" paths
- Avoids middle diagram entirely
- Consistent with backward edge visual style

### Cons
- May conflict with backward edges using same corridor
- Only works when source is on correct side
- Two waypoints = more segments

### Complexity: Low-Medium

---

## Strategy 3: Node-Avoiding Pathfinding (A*)

### Description
Use A* or similar pathfinding to find a path that avoids all node bounding boxes.

### Algorithm

```rust
fn generate_pathfinding_waypoints(
    source_bounds: &NodeBounds,
    target_bounds: &NodeBounds,
    layout: &Layout,
    direction: Direction,
) -> Option<Vec<(usize, usize)>> {
    // Create grid representation of diagram
    let mut grid = Grid::new(layout.width, layout.height);

    // Mark all node bounds as obstacles
    for (_, bounds) in &layout.node_bounds {
        grid.mark_obstacle(bounds);
    }

    // Start and end points (offset from nodes)
    let start = offset_from_boundary(source_bounds.center(), source_bounds);
    let end = offset_from_boundary(target_bounds.center(), target_bounds);

    // Run A* with orthogonal movement only
    let path = astar_orthogonal(&grid, start, end)?;

    // Convert path to waypoints (simplify to corner points)
    let waypoints = simplify_to_corners(path);

    Some(waypoints)
}

fn astar_orthogonal(grid: &Grid, start: Point, end: Point) -> Option<Vec<Point>> {
    let mut open_set = BinaryHeap::new();
    let mut came_from: HashMap<Point, Point> = HashMap::new();
    let mut g_score: HashMap<Point, usize> = HashMap::new();

    g_score.insert(start, 0);
    open_set.push(AStarNode { point: start, f_score: heuristic(start, end) });

    while let Some(current) = open_set.pop() {
        if current.point == end {
            return Some(reconstruct_path(&came_from, current.point));
        }

        // Only orthogonal neighbors (up, down, left, right)
        for neighbor in orthogonal_neighbors(current.point, grid) {
            if grid.is_obstacle(neighbor) {
                continue;
            }

            let tentative_g = g_score[&current.point] + 1;

            if tentative_g < *g_score.get(&neighbor).unwrap_or(&usize::MAX) {
                came_from.insert(neighbor, current.point);
                g_score.insert(neighbor, tentative_g);

                let f = tentative_g + heuristic(neighbor, end);
                open_set.push(AStarNode { point: neighbor, f_score: f });
            }
        }
    }

    None // No path found
}

fn simplify_to_corners(path: Vec<Point>) -> Vec<(usize, usize)> {
    // Extract only the corner points where direction changes
    let mut corners = Vec::new();

    for i in 1..path.len() - 1 {
        let prev_dir = direction(path[i - 1], path[i]);
        let next_dir = direction(path[i], path[i + 1]);

        if prev_dir != next_dir {
            corners.push((path[i].x, path[i].y));
        }
    }

    corners
}
```

### Pros
- Guaranteed to find path if one exists
- Automatically avoids all obstacles
- Produces optimal or near-optimal paths
- Handles complex node arrangements

### Cons
- Significantly more complex implementation (~100-150 lines)
- Performance overhead (grid creation, pathfinding)
- May produce many waypoints (noisy paths)
- Overkill for simple cases

### Complexity: High

---

## Strategy 4: Leveraging Dagre Dummy Node Positions

### Description
When using dagre layout, the algorithm already computes optimal edge routing. For edges that don't have waypoints (same rank or adjacent ranks), we could ask dagre to compute what the routing *would be* if it were a long edge.

### Algorithm

```rust
fn generate_dagre_synthetic_waypoints(
    edge: &Edge,
    source_rank: usize,
    target_rank: usize,
    layout: &Layout,
    dagre_result: &DagreResult,
) -> Option<Vec<(usize, usize)>> {
    // Check if this edge already has waypoints
    let key = (edge.from.clone(), edge.to.clone());
    if layout.edge_waypoints.contains_key(&key) {
        return None; // Already has waypoints
    }

    // For short edges (rank diff ≤ 1), dagre doesn't create waypoints
    // We could insert a synthetic "dummy" at the optimal position
    // by querying dagre's crossing minimization state

    // However, dagre's API doesn't easily expose this...
    // This would require modifying the dagre integration

    // Alternative: compute synthetic waypoint at the layer_starts position
    // between source and target
    let horizontal_offset = abs_diff(source_center_x, target_center_x);

    if horizontal_offset < THRESHOLD {
        return None;
    }

    // Compute intermediate ranks
    let rank_diff = target_rank.saturating_sub(source_rank);
    if rank_diff <= 1 {
        // Single waypoint at the layer boundary
        let intermediate_rank = source_rank + 1;
        let layer_y = layout.layer_starts.get(intermediate_rank)?;

        // X position: use source X to force vertical-first routing
        let waypoint_x = source_center_x;

        return Some(vec![(waypoint_x, *layer_y)]);
    }

    None
}
```

### Pros
- Consistent with dagre's layout philosophy
- Uses existing infrastructure
- Waypoints align with layer boundaries

### Cons
- Requires access to rank information not currently exposed
- Dagre API doesn't support "synthetic" waypoint queries
- Only works with dagre layout

### Complexity: Medium (requires dagre modifications)

---

## Strategy 5: Hybrid Approach

### Description
Combine simple heuristics with collision checking: use heuristic waypoints, then verify they don't cause collisions.

### Algorithm

```rust
fn generate_hybrid_waypoints(
    edge: &Edge,
    source_bounds: &NodeBounds,
    target_bounds: &NodeBounds,
    layout: &Layout,
    direction: Direction,
) -> Option<Vec<(usize, usize)>> {
    // Step 1: Check if edge needs special routing
    let horizontal_offset = source_bounds.center_x().abs_diff(target_bounds.center_x());
    if horizontal_offset < LARGE_OFFSET_THRESHOLD {
        return None;
    }

    // Step 2: Generate candidate waypoints using heuristic
    let candidate = generate_heuristic_waypoint(source_bounds, target_bounds, layout, direction)?;

    // Step 3: Build candidate path and check for collisions
    let start = offset_from_boundary(source_bounds.center(), source_bounds);
    let end = offset_from_boundary(target_bounds.center(), target_bounds);
    let candidate_segments = build_orthogonal_path_with_waypoints(start, &candidate, end, direction);

    // Step 4: Check if candidate path collides with any nodes
    if !path_collides_with_nodes(&candidate_segments, layout) {
        return Some(candidate);
    }

    // Step 5: Try alternative strategies
    if let Some(corridor_wps) = generate_corridor_waypoints(source_bounds, target_bounds, layout, direction) {
        let corridor_segments = build_orthogonal_path_with_waypoints(start, &corridor_wps, end, direction);
        if !path_collides_with_nodes(&corridor_segments, layout) {
            return Some(corridor_wps);
        }
    }

    // Step 6: Fall back to no waypoints (use default routing)
    None
}

fn path_collides_with_nodes(segments: &[Segment], layout: &Layout) -> bool {
    for segment in segments {
        for (node_id, bounds) in &layout.node_bounds {
            if segment_intersects_bounds(segment, bounds) {
                return true;
            }
        }
    }
    false
}
```

### Pros
- Best of both worlds: simple heuristics + collision verification
- Falls back gracefully when heuristics fail
- Can try multiple strategies in order of preference

### Cons
- More complex than pure heuristics
- Needs collision detection infrastructure
- Multiple candidate evaluation = more computation

### Complexity: Medium

---

## Comparison Summary

| Strategy | Complexity | Quality | Performance | Handles All Cases |
|----------|------------|---------|-------------|-------------------|
| 1. Simple Heuristic | Low | Medium | Fast | No |
| 2. Corridor-Based | Low-Medium | Good | Fast | No (right-side only) |
| 3. A* Pathfinding | High | Excellent | Slow | Yes |
| 4. Dagre Synthetic | Medium | Good | Medium | No (dagre only) |
| 5. Hybrid | Medium | Good | Medium | Mostly |

---

## Recommendation

### For Initial Implementation: Strategy 2 (Corridor-Based)

**Rationale:**
1. Directly addresses the `complex.mmd` issue (E→F is right-side source)
2. Leverages existing corridor infrastructure
3. Low implementation complexity
4. Predictable behavior

### For Future Enhancement: Strategy 5 (Hybrid)

**Rationale:**
1. Handles both left and right side sources
2. Collision verification prevents new problems
3. Multiple fallback strategies
4. Can be extended with more heuristics

---

## Pseudocode: Recommended Implementation

```rust
/// Generate waypoints for forward edges with large horizontal offset
pub fn generate_offset_waypoints(
    edge: &Edge,
    from_bounds: &NodeBounds,
    to_bounds: &NodeBounds,
    layout: &Layout,
    direction: Direction,
) -> Option<Vec<(usize, usize)>> {
    const LARGE_OFFSET_THRESHOLD: usize = 20;

    let horizontal_offset = from_bounds.center_x().abs_diff(to_bounds.center_x());
    if horizontal_offset < LARGE_OFFSET_THRESHOLD {
        return None; // Use default routing
    }

    let diagram_center_x = layout.width / 2;
    let source_on_right = from_bounds.center_x() > diagram_center_x;
    let source_on_left = from_bounds.center_x() < diagram_center_x - LARGE_OFFSET_THRESHOLD / 2;

    match direction {
        Direction::TopDown => {
            if source_on_right && to_bounds.center_x() < from_bounds.center_x() {
                // Source on right, target to the left → route via right side
                // Waypoint 1: below source, at source X
                // Waypoint 2: at target Y level, still on right
                let wp1_x = from_bounds.center_x();
                let wp1_y = to_bounds.y.saturating_sub(3);

                return Some(vec![(wp1_x, wp1_y)]);
            }
            if source_on_left && to_bounds.center_x() > from_bounds.center_x() {
                // Source on left, target to the right → route via left side
                let wp1_x = from_bounds.center_x();
                let wp1_y = to_bounds.y.saturating_sub(3);

                return Some(vec![(wp1_x, wp1_y)]);
            }
        }
        Direction::BottomTop => {
            // Similar logic, inverted Y
        }
        Direction::LeftRight | Direction::RightLeft => {
            // Similar logic, X and Y swapped
        }
    }

    None
}
```
