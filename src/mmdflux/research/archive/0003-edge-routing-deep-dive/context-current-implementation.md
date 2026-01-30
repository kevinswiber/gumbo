# Current Implementation Context

## Recent Changes

We recently changed backward edge routing for TD (top-down) layouts:

**Before:** Backward edges exited from the RIGHT side of the source node
**After:** Backward edges exit from the TOP of the source node

This was done to fix visual ambiguity when the source node has siblings on the same row. The old approach made horizontal lines pass through sibling nodes.

## Key Code Locations

### Router (`src/render/router.rs`)

The `route_backward_edge_vertical()` function handles backward edges in TD/BT layouts:

```rust
fn route_backward_edge_vertical(
    edge: &Edge,
    from_bounds: &NodeBounds,
    to_bounds: &NodeBounds,
    layout: &Layout,
    diagram_direction: Direction,
) -> Option<RoutedEdge> {
    // Exit direction: TD exits from top, BT exits from bottom
    let exit_dir = if diagram_direction == Direction::TopDown {
        AttachDirection::Top
    } else {
        AttachDirection::Bottom
    };
    let start = attachment_point(from_bounds, exit_dir);
    let end = attachment_point(to_bounds, AttachDirection::Right);

    // 4 segments:
    // 1. Vertical: connect node border to attachment point
    // 2. Horizontal: attachment point → corridor
    // 3. Vertical: in corridor
    // 4. Horizontal: corridor → target right
}
```

### Layout (`src/render/layout.rs`)

The layout algorithm uses topological sorting to assign nodes to layers (rows), then positions nodes within each layer.

Key concepts:
- `backward_corridors`: Number of lanes reserved for backward edges
- `backward_edge_lanes`: Maps each backward edge to its assigned lane
- Nodes in the same layer are positioned horizontally

### Edge Rendering (`src/render/edge.rs`)

The `render_edge()` function draws edge segments and handles:
- Line characters (─, │)
- Corners and junctions (┌, ┐, └, ┘, ├, ┤, ┬, ┴, ┼)
- Arrows (▲, ▼, ◄, ►)
- Labels (placed at segment midpoints)

## Attachment Points

Nodes have 4 attachment points (top, bottom, left, right), each offset 1 cell outside the node boundary:

```rust
fn attachment_point(bounds: &NodeBounds, direction: AttachDirection) -> Point {
    match direction {
        AttachDirection::Top => Point::new(bounds.center_x(), bounds.y.saturating_sub(1)),
        AttachDirection::Bottom => Point::new(bounds.center_x(), bounds.y + bounds.height),
        // ...
    }
}
```

## Forward vs Backward Edge Routing

**Forward edges (flow direction):**
- Exit from bottom (TD) or right (LR)
- Enter from top (TD) or left (LR)
- Route through intermediate space

**Backward edges (against flow):**
- Exit from top (TD) - recently changed from right
- Route through dedicated corridor on right side of diagram
- Enter target from right side

## Known Limitations

1. **Fixed attachment points:** Each edge uses the center of a node side
2. **No edge bundling:** Multiple edges don't share paths
3. **Grid-based routing:** All paths follow grid lines
4. **Limited junction characters:** ASCII has finite box-drawing options
