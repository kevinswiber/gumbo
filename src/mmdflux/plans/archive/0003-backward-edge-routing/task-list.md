# Backward Edge Routing Task List

## Status: ✅ COMPLETE

## Phase 1: Backward Edge Detection
- [x] **1.1** Add `is_backward_edge()` function in `router.rs` to detect edges going against layout direction
- [x] **1.2** Add unit tests for backward edge detection (TD, BT, LR, RL layouts)

## Phase 2: Backward Edge Routing
- [x] **2.1** Create `route_backward_edge()` function for routing around diagram perimeter
- [x] **2.2** Add `entry_direction` field to `RoutedEdge` to track how edge enters target
- [x] **2.3** Update `route_edge()` to dispatch to backward routing when appropriate
- [x] **2.4** Add unit tests for backward edge path generation

## Phase 3: Canvas Size Expansion
- [x] **3.1** Add backward edge detection during layout computation in `layout.rs`
- [x] **3.2** Add `backward_corridors` and `corridor_width` fields to `Layout` struct
- [x] **3.3** Expand canvas dimensions in `grid_to_draw_*` functions to accommodate corridors

## Phase 4: Multiple Backward Edge Handling
- [x] **4.1** Implement lane assignment algorithm for multiple backward edges
- [x] **4.2** Add `backward_edge_lanes` field to Layout to track lane assignments
- [x] **4.3** Add tests for multiple backward edges using separate lanes

## Phase 5: Arrow Direction Fix
- [x] **5.1** Update `draw_arrow()` in `edge.rs` to use entry direction
- [x] **5.2** Pass entry direction through render pipeline
- [x] **5.3** Add tests for arrow direction in all orientations

## Phase 6: Integration and Testing
- [x] **6.1** Create `simple_cycle.mmd` test fixture
- [x] **6.2** Create `multiple_cycles.mmd` test fixture
- [x] **6.3** Update integration tests to verify backward edge rendering
- [x] **6.4** Verify existing fixtures (decision.mmd, git_workflow.mmd, http_request.mmd)

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Backward Edge Detection | ✅ Complete | |
| 2 - Backward Edge Routing | ✅ Complete | |
| 3 - Canvas Size Expansion | ✅ Complete | |
| 4 - Multiple Backward Edges | ✅ Complete | Lane assignment implemented |
| 5 - Arrow Direction Fix | ✅ Complete | |
| 6 - Integration and Testing | ✅ Complete | |
