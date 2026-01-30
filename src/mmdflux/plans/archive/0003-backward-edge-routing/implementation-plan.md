# Backward Edge Routing Implementation Plan

## Status: 🚧 IN PROGRESS

## Overview

Implement proper routing of backward edges (edges going against the layout direction, such as cycles) in the mmdflux ASCII renderer. Currently, backward edges render incorrectly - they either create stubs, pass invisibly through nodes, or end abruptly.

## Current State Analysis

### What We Have

1. **Layout System** (`src/render/layout.rs`):
   - Topological layer assignment that already handles cycles by breaking back-edges
   - `GridPos` tracks each node's layer and position within layer
   - Layout direction support for TD/BT/LR/RL

2. **Router** (`src/render/router.rs`):
   - `attachment_directions()` function determines exit/entry sides based on diagram direction
   - For TD: edges exit from bottom, enter from top
   - `compute_vertical_first_path()` and `compute_horizontal_first_path()` create Z-shaped paths
   - **Problem**: No concept of backward vs forward edges - all edges use the same routing logic

3. **Edge Rendering** (`src/render/edge.rs`):
   - Already has backward edge detection in `draw_edge_label()` (lines 43-48)
   - Edges with `end.y < start.y` for TD layout are detected as backward
   - Labels are offset for backward edges to avoid collision
   - **Problem**: Path segments still route "through" nodes

4. **Canvas** (`src/render/canvas.rs`):
   - Cells can be protected (`is_node = true`) to prevent edge overwrite
   - `set_with_connection()` returns false for protected cells but doesn't reroute
   - **Result**: Backward edge segments that hit nodes are simply dropped, creating gaps

### Test Fixtures with Cycles

1. **decision.mmd**: `D --> A` (backward from layer 3 to layer 0)
2. **git_workflow.mmd**: `Remote --> Working` (backward in LR layout)
3. **http_request.mmd**: `Response --> Client` (backward from bottom back to top)

### Root Cause

The router assumes all edges flow in the layout direction. For a TD layout:
- Forward edge: source is above target (source.y < target.y)
- Backward edge: source is below target (source.y > target.y)

When routing a backward edge, the current logic creates a path that passes through intermediate nodes.

### Required Solution

Backward edges need to be routed AROUND the diagram, not through it:

```
Standard (wrong):           Correct:
     ┌─────┐                     ┌─────┐
     │  A  │                     │  A  │◄──┐
     └──┬──┘                     └──┬──┘   │
        │                           │      │
        ▼                           ▼      │
     ┌─────┐                     ┌─────┐   │
     │  B  │                     │  B  │   │
     └──┬──┘                     └──┬──┘   │
        │                           │      │
        ▼                           ▼      │
     ┌─────┐                     ┌─────┐   │
     │  D  │                     │  D  │───┘
     └─────┘                     └─────┘
        │ (dangles)
```

## Implementation Approach

### Phase 1: Backward Edge Detection

Add function to detect backward edges in `router.rs`:

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

### Phase 2: Backward Edge Routing Strategy

For backward edges, route around the side of the diagram:

1. **Choose routing side**: Right side for TD (or left if right is closer to target)
2. **Create corridor path**:
   - Exit source node from the appropriate side
   - Go to the routing corridor (right edge + margin)
   - Travel vertically/horizontally in the corridor
   - Turn back toward the target
   - Enter target from the appropriate side

### Phase 3: Canvas Size Expansion

The layout needs to reserve space for backward edge corridors:

1. **Detect backward edges** during layout
2. **Track required corridors**: How many backward edges need routing
3. **Expand canvas dimensions**: Add padding on the routing side

### Phase 4: Corridor Allocation for Multiple Backward Edges

When multiple backward edges exist, they need separate lanes:

1. **Sort backward edges** by their vertical span (for TD) or horizontal span (for LR)
2. **Assign corridor lanes**: Longer spans get outer lanes, shorter spans get inner lanes
3. **Track lane assignments** in the routing result

### Phase 5: Correct Arrow Direction

The arrow needs to point in the direction the edge is traveling:
- For backward edges in TD entering from RIGHT, arrow points LEFT
- Track entry direction in `RoutedEdge` struct

### Phase 6: Integration and Testing

1. Update `route_edge()` to dispatch to forward vs backward routing
2. Update `render_edge()` to use correct arrow direction
3. Add unit tests for backward edge detection
4. Add integration tests using existing fixtures

## Files to Modify/Create

### Modify

| File | Changes |
|------|---------|
| `src/render/router.rs` | Add `is_backward_edge()`, `route_backward_edge()`, entry direction tracking |
| `src/render/layout.rs` | Add backward edge detection, corridor width calculation, canvas expansion |
| `src/render/edge.rs` | Fix arrow direction to use entry direction |
| `src/render/mod.rs` | Update render pipeline integration |

### Create

| File | Purpose |
|------|---------|
| `tests/fixtures/simple_cycle.mmd` | Basic backward edge test case |
| `tests/fixtures/multiple_cycles.mmd` | Multiple backward edges test |

## Testing Strategy

### Unit Tests

- `test_is_backward_edge_td()` - TD layout backward detection
- `test_is_backward_edge_lr()` - LR layout backward detection
- `test_route_backward_edge_single()` - Single backward edge routing
- `test_route_backward_edge_multiple()` - Multiple lanes allocation

### Integration Tests

1. **decision.mmd**: Verify D --> A renders with visible path around right side
2. **git_workflow.mmd**: Verify Remote --> Working creates proper loop
3. **http_request.mmd**: Verify Response --> Client creates visible cycle

## Expected Output

**decision.mmd** after implementation:
```
     ┌───────┐
     │ Start │◄───────┐
     └───┬───┘        │
         │            │
         ▼            │
┌────────────────┐    │
< Is it working? >    │
└───────┬────────┘    │
        │             │
   Yes──┴──No         │
   │       │          │
   ▼       ▼          │
┌────────┐ ┌───────┐  │
│ Great! │ │ Debug │──┘
└────────┘ └───────┘
```

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Canvas expansion makes output too wide | Make corridor width configurable; use minimal spacing |
| Multiple backward edges overlap | Lane assignment algorithm with proper spacing |
| Arrow direction confusion | Comprehensive unit tests for all direction combinations |
