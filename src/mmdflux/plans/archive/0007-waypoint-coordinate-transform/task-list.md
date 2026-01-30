# Waypoint Coordinate Transformation Task List

## Status: ✅ COMPLETE

## Phase 1: Infrastructure
- [x] **1.1** Extend `denormalize()` to return rank information with each waypoint
- [x] **1.2** Update `LayoutResult.edge_waypoints` type to include rank data (or add parallel field)
- [x] **1.3** Update dagre `layout()` to propagate rank information to the result

## Phase 2: Core Transformation
- [x] **2.1** Create `transform_waypoints_vertical()` for TD/BT layouts
- [x] **2.2** Create `transform_waypoints_horizontal()` for LR/RL layouts
- [x] **2.3** Update `compute_layout_dagre()` to call transformation instead of simple rounding
- [x] **2.4** Pass necessary context (layer_y_starts, node positions, ranks) to transformation

## Phase 3: Testing and Validation
- [x] **3.1** Add unit tests for `transform_waypoints_vertical()`
- [x] **3.2** Add unit tests for `transform_waypoints_horizontal()`
- [x] **3.3** Add integration test verifying complex.mmd E→F edge renders correctly
- [x] **3.4** Visual verification: run all fixtures and check for rendering issues
- [x] **3.5** Test all four directions (TD, BT, LR, RL) with long edges

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Infrastructure | Complete | Added WaypointWithRank type, updated denormalize() |
| 2 - Core Transformation | Complete | Inline transformation in compute_layout_dagre() |
| 3 - Testing | Complete | Added unit tests for vertical and horizontal transformation |

## Implementation Summary

### Changes Made

1. **`src/dagre/normalize.rs`**:
   - Added `WaypointWithRank` struct with `point: Point` and `rank: i32`
   - Modified `denormalize()` to return `HashMap<usize, Vec<WaypointWithRank>>`

2. **`src/dagre/types.rs`**:
   - Updated `LayoutResult.edge_waypoints` to use `Vec<WaypointWithRank>`

3. **`src/dagre/mod.rs`**:
   - Updated to extract just points when building `EdgeLayout`

4. **`src/render/layout.rs`**:
   - Added `VerticalLayoutResult` and `HorizontalLayoutResult` structs
   - Modified `grid_to_draw_vertical()` and `grid_to_draw_horizontal()` to return layer positions
   - Implemented waypoint coordinate transformation using:
     - `layer_starts[rank]` for primary axis (Y for vertical, X for horizontal)
     - Linear interpolation between source and target node centers for secondary axis
   - Added unit tests for both vertical and horizontal transformation
