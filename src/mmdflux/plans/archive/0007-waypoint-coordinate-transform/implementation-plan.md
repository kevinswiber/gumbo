# Waypoint Coordinate Transformation Implementation Plan

## Status: ✅ COMPLETE

**Completed:** 2026-01-26

## Overview

Fix the bug where waypoints from dagre's normalization are in dagre's internal coordinate system but are being used directly in the ASCII draw coordinate system without transformation. This causes edges spanning multiple ranks (like E→F in complex.mmd) to render incorrectly with segments going off-screen.

## Problem Analysis

**Evidence:**
- Node E ("More Data?") draw position: (38, 19) in ASCII coordinates
- Waypoint from dagre: (112, 223) in dagre coordinates
- These are completely different scales (dagre uses `node_sep=50.0`, `rank_sep=50.0`)

**Current buggy code in `layout.rs:379-389`:**
```rust
for (edge_idx, waypoints) in &result.edge_waypoints {
    if let Some(edge) = diagram.edges.get(*edge_idx) {
        let key = (edge.from.clone(), edge.to.clone());
        let converted: Vec<(usize, usize)> = waypoints
            .iter()
            .map(|p| (p.x.round() as usize, p.y.round() as usize))  // BUG: Just rounding!
            .collect();
        edge_waypoints_converted.insert(key, converted);
    }
}
```

**Root Cause:**
- Real nodes go through `grid_to_draw_vertical/horizontal()` transformation
- Dummy nodes (waypoints) skip this transformation entirely
- Router receives waypoints in wrong coordinate space

## Current State

The codebase has:
- Dagre module that assigns positions to dummy nodes during position assignment
- `denormalize()` function that extracts waypoints from dummy node positions
- `compute_layout_dagre()` that receives waypoints but doesn't transform them
- `grid_to_draw_*` functions that transform node positions correctly

Key insight: Dummy nodes have ranks assigned during normalization. We can use this rank information to determine which layer each waypoint belongs to, then compute proper draw coordinates.

## Implementation Approach

**Strategy:** Transform waypoints in `compute_layout_dagre()` after computing draw positions for real nodes.

1. Extend `denormalize()` to return rank information with each waypoint
2. Create transformation functions that use layer positions and rank info
3. Apply transformation in `compute_layout_dagre()` before storing waypoints

### Coordinate Transformation Algorithm

For TD/BT layouts:
- **Y coordinate:** Use the layer's y-start position from `layer_y_starts[rank]`
- **X coordinate:** Interpolate between source and target node x-positions based on rank progress

For LR/RL layouts:
- **X coordinate:** Use the layer's x-start position from `layer_x_starts[rank]`
- **Y coordinate:** Interpolate between source and target node y-positions

## Files to Modify

| File | Changes |
|------|---------|
| `src/dagre/normalize.rs` | Extend `denormalize()` to include rank info with waypoints |
| `src/dagre/types.rs` | Add `WaypointWithRank` type or modify existing types |
| `src/render/layout.rs` | Add transformation functions, update `compute_layout_dagre()` |

## Testing Strategy

1. **Unit tests:** Test waypoint transformation for simple long edges
2. **Integration test:** Verify complex.mmd renders correctly
3. **Visual verification:** All fixtures render without off-screen segments
4. **Direction coverage:** Test TD, BT, LR, RL layouts

## Risk Assessment

**Low risk:** Changes are isolated to the waypoint handling path. Direct edge routing (edges without waypoints) is unaffected.

**Rollback:** If issues arise, can temporarily disable waypoint usage by returning empty waypoints, falling back to `route_edge_direct()`.
