# Edge Routing Architecture Implementation Plan

## Status: ✅ COMPLETE

**Completed:** 2026-01-26

## Overview

Implement three key dagre mechanisms missing from mmdflux's edge routing:

1. **Dummy nodes for long edges** - Split edges spanning multiple ranks into chains of single-rank edges
2. **Edge labels as layout entities** - Give labels their own space during crossing reduction
3. **Dynamic intersection calculation** - Compute attachment points based on approach angle rather than fixed center points

**Estimated scope:** ~800-1000 lines of new/modified code across 5 phases.

## Current State

The mmdflux codebase has a well-defined pipeline:

```
src/dagre/
├── mod.rs      - Main layout() entry point
├── acyclic.rs  - Phase 1: Cycle removal (greedy feedback arc set)
├── rank.rs     - Phase 2: Rank assignment (longest path)
├── order.rs    - Phase 3: Crossing reduction (barycenter heuristic)
├── position.rs - Phase 4: Coordinate assignment
├── graph.rs    - LayoutGraph internal representation
└── types.rs    - Public types (LayoutResult, EdgeLayout, etc.)

src/render/
├── layout.rs   - compute_layout_dagre() bridges dagre to render
├── router.rs   - Edge routing (route_edge, route_backward_edge)
├── edge.rs     - Edge rendering (render_edge, render_all_edges)
├── shape.rs    - Node rendering and NodeBounds
└── canvas.rs   - Character grid operations
```

### Gap Analysis

The current implementation is missing:

1. **No normalization step** - Long edges are not split into chains
2. **No edge waypoints** - `LayoutResult.edges` only has center-to-center points
3. **Fixed attachment points** - `NodeBounds.top()` always returns center of top edge
4. **No label-aware layout** - Labels are placed post-hoc, not during crossing reduction

## Implementation Approach

### Phase 1: Infrastructure (Low Risk)

Add data structures without changing existing behavior.

**Tasks:**
- 1.1 Create `src/dagre/normalize.rs` with `DummyType`, `DummyNode`, `LabelPos` types
- 1.2 Extend `LayoutGraph` in `src/dagre/graph.rs` with dummy tracking fields
- 1.3 Add `edge_waypoints` and `edge_label_positions` to `Layout` in `src/render/layout.rs`
- 1.4 Extend `LayoutResult` in `src/dagre/types.rs` with waypoint data
- 1.5 Unit tests for new data structures

### Phase 2: Normalization (Medium Risk)

Implement edge normalization that inserts dummy nodes.

**Tasks:**
- 2.1 Implement `normalize::run()` - Split long edges into chains of single-rank edges
- 2.2 Implement `normalize::denormalize()` - Convert dummy positions to waypoints
- 2.3 Integrate into layout pipeline in `src/dagre/mod.rs`
- 2.4 Update `compute_layout_dagre()` to pass edge label dimensions
- 2.5 Unit tests for normalization

### Phase 3: Intersection Calculation (Medium Risk)

Implement dynamic edge attachment points.

**Tasks:**
- 3.1 Create `src/render/intersect.rs` with `intersect_rect()`, `intersect_diamond()`, `intersect_node()`
- 3.2 Update router to use waypoints and intersection calculation
- 3.3 Implement `build_orthogonal_path()` and `orthogonalize()` helpers
- 3.4 Unit tests for intersection calculation

### Phase 4: Integration and Testing (Higher Risk)

Wire everything together and verify with real diagrams.

**Tasks:**
- 4.1 Update edge rendering to use pre-computed label positions
- 4.2 Integration tests for complex diagrams
- 4.3 Add feature flag for rollback capability

### Phase 5: Cleanup (Low Risk)

Remove workarounds and simplify code after stabilization.

**Tasks:**
- 5.1 Simplify backward edge routing (keep as fallback)
- 5.2 Deprecate fixed attachment point methods
- 5.3 Clean up redundant label collision detection

## Files to Modify/Create

| File | Change Type | Description |
|------|-------------|-------------|
| `src/dagre/normalize.rs` | New | Dummy node normalization |
| `src/dagre/graph.rs` | Modified | Dummy node tracking |
| `src/dagre/mod.rs` | Modified | Pipeline integration |
| `src/dagre/types.rs` | Modified | Result types for waypoints |
| `src/render/intersect.rs` | New | Intersection calculation |
| `src/render/router.rs` | Modified | Waypoint-based routing |
| `src/render/layout.rs` | Modified | Waypoint/label storage |
| `src/render/edge.rs` | Modified | Label rendering |
| `tests/integration.rs` | Modified | New test cases |

## Testing Strategy

### Unit Tests
- Dummy node creation and tracking
- Normalization of long edges (2+ rank span)
- Short edges preserved unchanged
- Label dummy has proper dimensions
- Intersection calculation for rectangles and diamonds
- Orthogonalization of diagonal paths

### Integration Tests
- All existing fixtures render without panic
- `complex.mmd` renders without edge-through-node issues
- Labeled edges have label positions
- Multiple edges to same node use different attachment points

### Visual Verification
- Compare output for key fixtures before/after
- Verify no visual regressions

## Success Criteria

1. All existing tests pass
2. `complex.mmd` renders without:
   - Edge routing through intermediate nodes
   - Overlapping edges at same attachment point
   - Label collisions
3. Edge labels are placed on isolated segments
4. Multiple edges to same node use different attachment points
5. All fixtures in `tests/fixtures/*.mmd` render correctly
6. No performance regression (render time within 2x of current)

## Risk Mitigation

### Feature Flag
Add `use_normalize: bool` config option (default: false initially) to enable rolling back if issues are discovered.

### Incremental Rollout
1. Phase 1: Infrastructure only (no behavior change)
2. Phase 2: Normalization behind feature flag
3. Phase 3: Intersection calculation (can coexist with old routing)
4. Phase 4: Full integration with extensive testing
5. Phase 5: Cleanup after stabilization

## Reference Documents

- `research/archive/0003-edge-routing-deep-dive/IMPLEMENTATION-PLAN.md` - Detailed algorithm descriptions
- `research/archive/0003-edge-routing-deep-dive/normalize-deep-dive.md` - dagre normalization algorithm
- `research/archive/0003-edge-routing-deep-dive/intersection-deep-dive.md` - intersectRect algorithm
- `research/archive/0003-edge-routing-deep-dive/ascii-adaptation.md` - ASCII-specific adaptations
