# Simplified Sugiyama Layout Module - Task List

## Status: ✅ COMPLETE (with caveats)

## Reference Material

**Code scaffolding:** `research/archive/0001-dagre-layout/module-design.md` contains full implementations to use as starting points for each module. Adapt as needed.

## Phase A: Foundation
- [x] **A.1** Add petgraph dependency to Cargo.toml (`petgraph = { version = "0.6", default-features = false }`)
- [x] **A.2** Create `src/dagre/mod.rs` with module structure and public exports → see §2.1 in module-design.md
- [x] **A.3** Implement `src/dagre/types.rs` → see §2.2 in module-design.md (NodeId, Direction, Point, Rect, LayoutConfig, LayoutResult, EdgeLayout)
- [x] **A.4** Implement `src/dagre/graph.rs` → see §2.3 and §2.8 in module-design.md (DiGraph public API + LayoutGraph internal)
- [x] **A.5** Add `pub mod dagre;` to `src/lib.rs`
- [x] **A.6** Write unit tests for graph operations (add_node, add_edge, successors, predecessors)

## Phase B: Core Algorithm
- [x] **B.1** Implement `src/dagre/acyclic.rs` → see §2.4 in module-design.md (uses petgraph's `greedy_feedback_arc_set`)
- [x] **B.2** Write unit tests for acyclic (cycles, DAGs, self-loops, disconnected components)
- [x] **B.3** Implement `src/dagre/rank.rs` → see §2.5 in module-design.md (longest-path with Kahn's algorithm)
- [x] **B.4** Write unit tests for rank (linear chain, diamond, disconnected, with cycles)
- [x] **B.5** Implement `src/dagre/order.rs` → see §2.6 in module-design.md (barycenter heuristic, sweep up/down)
- [x] **B.6** Write unit tests for order (verify crossing count decreases)

## Phase C: Coordinate Assignment
- [x] **C.1** Implement `src/dagre/position.rs` → see §2.7 in module-design.md (assign_vertical, layer centering)
- [x] **C.2** Implement horizontal layout support (LR/RL) → see assign_horizontal in §2.7
- [x] **C.3** Handle reversed directions (BT, RL) → see reverse_positions in §2.7
- [x] **C.4** Write unit tests for position (all four directions, variable node sizes)
- [x] **C.5** Implement `src/dagre/util.rs` → see §2.9 in module-design.md (create_edge_layouts helper) - *Inline in mod.rs*

## Phase D: Integration
- [x] **D.1** Create adapter in `src/render/layout.rs` → see §4 "Adapter Pattern" in module-design.md
- [x] **D.2** Update `src/render/mod.rs` imports if needed
- [x] **D.3** Run existing integration tests, fix regressions
- [x] **D.4** Verify http_request.mmd renders correctly (cycle handling works) - *Renders, but...*

## Phase E: Testing & Polish
- [x] **E.1** Add comprehensive unit tests for dagre module
- [x] **E.2** Test all fixture files render correctly
- [x] **E.3** Add rustdoc documentation to public API
- [x] **E.4** Run `cargo clippy` and fix warnings
- [x] **E.5** Verify WASM compatibility (no std-only features)

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| A - Foundation | ✅ Complete | 6 tests passing |
| B - Core Algorithm | ✅ Complete | 8 tests passing |
| C - Coordinate Assignment | ✅ Complete | 6 tests passing |
| D - Integration | ✅ Complete | Adapter created, edge routing issue found |
| E - Testing & Polish | ✅ Complete | 163 tests passing, WASM compatible |

## Test Summary

- **dagre module**: 27 unit tests
- **layout integration**: 17 tests (including 4 dagre adapter tests)
- **integration tests**: 26 tests
- **doc tests**: 3 tests
- **Total**: 163 tests passing

## Known Issues

### Edge Label Collision with Dagre Layout

When dagre is used as the default layout (`compute_layout_dagre`), diagrams with cycles can have edge labels overlap with nodes. This happens because:

1. Dagre uses greedy feedback arc set (FAS) to break cycles
2. This can reverse edges in ways that place nodes in different layers than expected
3. Edge labels placed at midpoints can collide with nodes in intermediate layers

**Example:** In `complex.mmd`, dagre reverses the A→B edge to break the cycle. This puts "Input" (A) in layer 3 instead of layer 0. The "no" edge label from E→F passes through layer 3 and overlaps with "Input".

**Workaround:** The old algorithm (`compute_layout`) is currently used as default. It breaks cycles alphabetically, which happens to keep nodes in a more expected order.

**Future Fix:** Improve edge routing to detect and avoid label-node collisions, or adjust label placement when collisions are detected.

## Files Created/Modified

### New Files (src/dagre/)
- `mod.rs` - Public API with `layout()` function
- `types.rs` - Core types (NodeId, Direction, Point, Rect, etc.)
- `graph.rs` - DiGraph and LayoutGraph
- `acyclic.rs` - Greedy FAS via petgraph
- `rank.rs` - Longest-path ranking
- `order.rs` - Barycenter crossing reduction
- `position.rs` - Coordinate assignment

### Modified Files
- `Cargo.toml` - Added petgraph dependency
- `src/lib.rs` - Added `pub mod dagre`
- `src/render/layout.rs` - Added `compute_layout_dagre()` adapter
- `src/render/mod.rs` - Exports `compute_layout_dagre`, keeps old algo as default
