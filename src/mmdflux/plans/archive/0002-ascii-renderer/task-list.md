# ASCII Renderer Task List

## Status: ✅ COMPLETE

## Phase 1: Foundation (Canvas + Characters)
- [x] **1.1** Create `src/render/mod.rs` with public `render()` function signature
- [x] **1.2** Implement `Canvas` struct in `canvas.rs` with `new()`, `get()`, `set()`, `to_string()`
- [x] **1.3** Add `Cell` struct with char, connections metadata, and is_node flag
- [x] **1.4** Implement `Connections` struct for tracking up/down/left/right
- [x] **1.5** Implement `CharSet` in `chars.rs` with Unicode box-drawing characters
- [x] **1.6** Implement `CharSet::ascii()` for ASCII-only fallback
- [x] **1.7** Add `--ascii` flag to CLI in `main.rs`
- [x] **1.8** Unit tests for canvas operations

## Phase 2: Node Rendering
- [x] **2.1** Create `shape.rs` with `render_node()` function
- [x] **2.2** Implement Rectangle shape rendering (box with label)
- [x] **2.3** Implement Round shape rendering (rounded corners)
- [x] **2.4** Implement Diamond shape rendering (`/\` and `\/` approximation)
- [x] **2.5** Handle label centering within shapes
- [x] **2.6** Mark node cells as protected (is_node = true)
- [x] **2.7** Unit tests for node rendering

## Phase 3: Simple Layout (TD)
- [x] **3.1** Create `layout.rs` with `compute_layout()` function
- [x] **3.2** Implement `GridPos` and `Layout` structs
- [x] **3.3** Implement topological sort for layer (row) assignment
- [x] **3.4** Order nodes within layers (simple left-to-right by ID)
- [x] **3.5** Calculate column widths based on node label lengths
- [x] **3.6** Implement `grid_to_draw()` coordinate conversion
- [x] **3.7** Implement `node_bounds()` for getting node bounding boxes
- [x] **3.8** Unit tests for layout algorithms

## Phase 4: Edge Routing
- [x] **4.1** Create `router.rs` with `route_edge()` function
- [x] **4.2** Calculate attachment points on node boundaries
- [x] **4.3** Implement straight vertical edge routing
- [x] **4.4** Implement L-shaped edge routing (one bend)
- [x] **4.5** Implement Z-shaped edge routing (two bends)
- [x] **4.6** Avoid routing through node boundaries
- [x] **4.7** Unit tests for edge routing

## Phase 5: Edge Rendering
- [x] **5.1** Create `edge.rs` with `render_edge()` function
- [x] **5.2** Draw vertical lines (`│`) along paths
- [x] **5.3** Draw horizontal lines (`─`) along paths
- [x] **5.4** Draw corners at bends (`┌ ┐ └ ┘`)
- [x] **5.5** Draw arrows at endpoints (`▲ ▼ ◄ ►`)
- [x] **5.6** Handle dotted stroke style (`┈ ┊`)
- [x] **5.7** Handle Arrow::None (no arrowhead)
- [x] **5.8** Integration test: complete TD flowchart rendering

## Phase 6: Edge Labels
- [x] **6.1** Find label placement position (midpoint of longest segment)
- [x] **6.2** Clear space for label text on canvas
- [x] **6.3** Render label text centered on edge
- [x] **6.4** Integration test: flowchart with labeled edges

## Phase 7: LR Layout
- [x] **7.1** Implement horizontal layout in `compute_layout()`
- [x] **7.2** Swap row/column concepts for LR direction
- [x] **7.3** Adjust edge routing for horizontal primary direction
- [x] **7.4** Update arrow orientations for LR
- [x] **7.5** Integration test: LR flowchart rendering

## Phase 8: Junction Merging
- [x] **8.1** Implement `set_with_connection()` on Canvas
- [x] **8.2** Implement `CharSet::junction()` for connection-based character selection
- [x] **8.3** Update edge rendering to track connections per cell
- [x] **8.4** Handle T-junctions (`┬ ┴ ├ ┤`)
- [x] **8.5** Handle 4-way cross (`┼`)
- [x] **8.6** Integration test: flowchart with crossing/merging edges

## Phase 9: Polish and Edge Cases
- [x] **9.1** Implement BT (bottom-top) layout
- [x] **9.2** Implement RL (right-left) layout
- [x] **9.3** Handle cycles (detect and break back-edges)
- [ ] **9.4** Add basic crossing minimization (barycenter heuristic) [DEFERRED]
- [ ] **9.5** Handle very long labels (truncation) [DEFERRED]
- [x] **9.6** Update lib.rs to export render module
- [x] **9.7** Final integration tests with fixture files
- [x] **9.8** Update README with rendering examples

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Foundation | ✅ Complete | |
| 2 - Node Rendering | ✅ Complete | |
| 3 - Simple Layout | ✅ Complete | |
| 4 - Edge Routing | ✅ Complete | |
| 5 - Edge Rendering | ✅ Complete | |
| 6 - Edge Labels | ✅ Complete | |
| 7 - LR Layout | ✅ Complete | |
| 8 - Junction Merging | ✅ Complete | |
| 9 - Polish | ✅ Complete | Tasks 9.4-9.5 deferred as enhancements |
