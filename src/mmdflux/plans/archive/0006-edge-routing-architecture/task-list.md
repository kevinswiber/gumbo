# Edge Routing Architecture Task List

## Status: ✅ COMPLETE

## Phase 1: Infrastructure
- [x] **1.1** Create `src/dagre/normalize.rs` with `DummyType`, `DummyNode`, `LabelPos` types
- [x] **1.2** Extend `LayoutGraph` with `dummy_nodes`, `dummy_chains`, `original_edge_count`, `is_dummy` fields
- [x] **1.3** Add `edge_waypoints` and `edge_label_positions` to `Layout` struct
- [x] **1.4** Extend `LayoutResult` with `edge_waypoints` and `label_positions`
- [x] **1.5** Unit tests for dummy node creation and tracking

## Phase 2: Normalization
- [x] **2.1** Implement `normalize::run()` to split long edges with dummy chains
- [x] **2.2** Implement `normalize::denormalize()` to convert dummy positions to waypoints
- [x] **2.3** Integrate normalization into `dagre::layout()` pipeline
- [x] **2.4** Update `compute_layout_dagre()` to calculate and pass edge label dimensions
- [x] **2.5** Unit tests for normalization (long edges, short edges, labeled edges)

## Phase 3: Intersection Calculation
- [x] **3.1** Create `src/render/intersect.rs` with `intersect_rect()` and `intersect_diamond()`
- [x] **3.2** Add `intersect_node()` shape-aware dispatch function
- [x] **3.3** Implement `build_orthogonal_path()` and `orthogonalize()` helpers in router
- [x] **3.4** Update `route_edge()` to use waypoints and intersection calculation
- [x] **3.5** Unit tests for intersection (top, right, diagonal approaches, diamond shape)

## Phase 4: Integration and Testing
- [x] **4.1** Update `render_edge()` to use pre-computed label positions
- [x] **4.2** ~~Add feature flag~~ (Skipped - not needed since everything works)
- [x] **4.3** Integration test: all fixtures render without panic
- [x] **4.4** Integration test: `complex.mmd` renders correctly
- [x] **4.5** Integration test: labeled edges have proper positions
- [x] **4.6** Fix arrow direction bug (arrows point correct direction for layout)
- [x] **4.7** Fix path shape bug (use Z-paths instead of L-paths for proper routing)
- [x] **4.8** Fix attachment point clamping (intersection calc gave points outside boundary)
- [x] **4.9** Fix BT/RL layout double-reverse (dagre already flips coords internally)

## Phase 5: Cleanup
- [x] **5.1** ~~Simplify backward edge routing~~ Kept corridor-based perimeter routing (dagre doesn't provide waypoints for cycles)
- [x] **5.2** Clean up unused functions: removed `determine_entry_direction`, `compute_path`, `compute_horizontal_first_path`; changed test-only functions to `#[cfg(test)]`
- [x] **5.3** ~~Remove collision detection~~ Kept as safety net for backward edges and edge cases
- [x] **5.4** ~~Remove unused functions~~ See 5.2; `clamp_to_boundary` is now actively used

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Infrastructure | Complete | Added normalize.rs, extended LayoutGraph and Layout with waypoint tracking |
| 2 - Normalization | Complete | Implemented run(), denormalize(), integrated into pipeline with edge labels |
| 3 - Intersection | Complete | Added intersect.rs, orthogonalize helpers, updated route_edge() to use dynamic attachment points |
| 4 - Integration | Complete | Fixed arrow direction, path shape, attachment clamping, BT/RL layout bugs |
| 5 - Cleanup | Complete | Removed unused functions, kept corridor routing and collision detection as safety nets |
