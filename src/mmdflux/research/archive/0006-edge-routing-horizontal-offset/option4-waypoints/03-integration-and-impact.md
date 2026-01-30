# Integration Points and Impact Analysis

## Overview

This document analyzes where waypoint generation for large-offset forward edges would integrate into the mmdflux pipeline, what changes are needed, and the potential risks.

---

## Integration Option A: In Layout Phase

### Where: `compute_layout()` and `compute_layout_dagre()`

**File:** `src/render/layout.rs`

### Approach

Generate waypoints during layout computation, after node positions are known but before the Layout struct is returned.

```rust
pub fn compute_layout(diagram: &Diagram, config: &RenderConfig) -> Layout {
    // ... existing layout computation ...

    // NEW: Generate waypoints for large-offset forward edges
    let edge_waypoints = generate_offset_waypoints_for_edges(
        &diagram.edges,
        &draw_positions,
        &node_bounds,
        diagram.direction,
    );

    Layout {
        // ... existing fields ...
        edge_waypoints,  // Now populated for both dagre and non-dagre
    }
}
```

### Pros
- Single point of waypoint generation
- Layout struct already has all needed information
- Works for both `compute_layout()` and `compute_layout_dagre()`

### Cons
- Mixes layout computation with routing decisions
- Layout phase doesn't have segment/collision info yet

### Changes Required

1. **New function in layout.rs:**
   ```rust
   fn generate_offset_waypoints_for_edges(
       edges: &[Edge],
       draw_positions: &HashMap<String, (usize, usize)>,
       node_bounds: &HashMap<String, NodeBounds>,
       direction: Direction,
   ) -> HashMap<(String, String), Vec<(usize, usize)>>
   ```

2. **Modify `compute_layout()`** to call new function and populate `edge_waypoints`

3. **Modify `compute_layout_dagre()`** to merge dagre waypoints with offset waypoints

---

## Integration Option B: In Routing Phase

### Where: `route_edge()` function

**File:** `src/render/router.rs`

### Approach

Generate waypoints on-demand during edge routing, for edges that need special handling.

```rust
pub fn route_edge(
    edge: &Edge,
    layout: &Layout,
    diagram_direction: Direction,
) -> Option<RoutedEdge> {
    let from_bounds = layout.get_bounds(&edge.from)?;
    let to_bounds = layout.get_bounds(&edge.to)?;

    // Check if backward edge
    if is_backward_edge(from_bounds, to_bounds, diagram_direction) {
        return route_backward_edge(...);
    }

    // Check for existing waypoints (from dagre normalization)
    let edge_key = (edge.from.clone(), edge.to.clone());
    if let Some(wps) = layout.edge_waypoints.get(&edge_key) {
        if !wps.is_empty() {
            return route_edge_with_waypoints(...);
        }
    }

    // NEW: Check if this edge needs generated waypoints
    if let Some(generated_wps) = generate_offset_waypoints(
        edge, from_bounds, to_bounds, layout, diagram_direction
    ) {
        return route_edge_with_waypoints(
            edge, from_bounds, from_shape,
            to_bounds, to_shape, &generated_wps, diagram_direction
        );
    }

    // Fall back to direct routing
    route_edge_direct(...)
}
```

### Pros
- Localized change in router.rs
- Routing decisions stay in routing code
- Can use full routing context (bounds, shapes)

### Cons
- Waypoint generation happens during routing (every render)
- Can't coordinate multiple edges (each routed independently)

### Changes Required

1. **New function in router.rs:**
   ```rust
   fn generate_offset_waypoints(
       edge: &Edge,
       from_bounds: &NodeBounds,
       to_bounds: &NodeBounds,
       layout: &Layout,
       direction: Direction,
   ) -> Option<Vec<(usize, usize)>>
   ```

2. **Modify `route_edge()`** to call waypoint generation before direct routing

---

## Integration Option C: New Pre-Routing Analysis Phase

### Where: New module `src/render/waypoints.rs`

### Approach

Create a separate phase that analyzes all edges and generates waypoints before any routing occurs.

```rust
// New file: src/render/waypoints.rs

pub fn analyze_and_generate_waypoints(
    diagram: &Diagram,
    layout: &Layout,
) -> HashMap<(String, String), Vec<(usize, usize)>> {
    let mut waypoints = layout.edge_waypoints.clone(); // Start with dagre waypoints

    for edge in &diagram.edges {
        let key = (edge.from.clone(), edge.to.clone());

        // Skip if already has waypoints
        if waypoints.contains_key(&key) {
            continue;
        }

        // Check if edge needs generated waypoints
        if let Some(wps) = generate_offset_waypoints(edge, layout, diagram.direction) {
            waypoints.insert(key, wps);
        }
    }

    waypoints
}

// Called from render.rs
pub fn render(diagram: &Diagram, options: &RenderOptions) -> Canvas {
    let layout = compute_layout(diagram, &options.config);

    // NEW: Pre-routing waypoint analysis
    let enhanced_layout = Layout {
        edge_waypoints: analyze_and_generate_waypoints(diagram, &layout),
        ..layout
    };

    let routed_edges = route_all_edges(&diagram.edges, &enhanced_layout, diagram.direction);
    // ...
}
```

### Pros
- Clean separation of concerns
- Can coordinate multiple edges
- Easy to test independently

### Cons
- New module to maintain
- Additional pass over edges

### Changes Required

1. **New file:** `src/render/waypoints.rs`
2. **Modify `src/render/mod.rs`:** Call waypoint analysis phase
3. **Update Layout:** May need to make `edge_waypoints` mutable or create enhanced layout

---

## Recommended Integration: Option B (Routing Phase)

### Rationale

1. **Minimal architectural change** - No new modules, no new phases
2. **Natural fit** - Waypoint generation is a routing decision
3. **Access to bounds** - Already have from_bounds and to_bounds available
4. **Existing pattern** - Follows similar pattern to backward edge detection

### Implementation Location

**File:** `src/render/router.rs`
**Function:** `route_edge()` (lines 124-177)
**Insert at:** Line 155 (after waypoint lookup, before direct routing)

---

## Changes to Layout Struct

### Current Structure

```rust
pub struct Layout {
    pub grid_positions: HashMap<String, GridPos>,
    pub draw_positions: HashMap<String, (usize, usize)>,
    pub node_bounds: HashMap<String, NodeBounds>,
    pub width: usize,
    pub height: usize,
    pub h_spacing: usize,
    pub v_spacing: usize,
    pub backward_corridors: usize,
    pub corridor_width: usize,
    pub backward_edge_lanes: HashMap<(String, String), usize>,
    pub edge_waypoints: HashMap<(String, String), Vec<(usize, usize)>>,
    pub edge_label_positions: HashMap<(String, String), (usize, usize)>,
    pub node_shapes: HashMap<String, Shape>,
}
```

### No Changes Needed

For Option B (routing phase integration), the Layout struct doesn't need modification. The waypoint generation function will compute waypoints on-demand using existing Layout fields.

If we later want to cache generated waypoints, we could add:

```rust
// Optional future enhancement
pub generated_waypoints: HashMap<(String, String), Vec<(usize, usize)>>,
```

---

## Impact on Existing Tests

### Affected Test Categories

1. **Integration tests** (`tests/integration.rs`)
   - `complex.mmd` rendering will change (expected/desired)
   - Other fixtures should be unaffected

2. **Router unit tests** (`src/render/router.rs`)
   - `test_route_edge_simple` - Should pass (no large offset)
   - `test_route_edge_diagonal` - May need update if offset exceeds threshold
   - `test_build_orthogonal_path_*` - Unaffected (lower-level)

3. **Layout tests** (`src/render/layout.rs`)
   - `test_compute_layout_*` - Unaffected (waypoint generation in router)

### New Tests Needed

```rust
#[test]
fn test_generate_offset_waypoints_large_offset() {
    // Edge with source on right, target in center
    // Should generate waypoint(s)
}

#[test]
fn test_generate_offset_waypoints_small_offset() {
    // Edge with small horizontal offset
    // Should return None (use default routing)
}

#[test]
fn test_generate_offset_waypoints_left_side() {
    // Edge with source on left, target to right
    // Should generate appropriate waypoint(s)
}

#[test]
fn test_route_edge_with_generated_waypoints() {
    // Full routing test with generated waypoints
}
```

### Fixture Updates

1. **`tests/fixtures/complex.mmd`** - Expected output will change
2. **New fixture:** `tests/fixtures/horizontal_offset.mmd` - Specific test case

---

## Risk Assessment

### Low Risk

| Risk | Mitigation |
|------|------------|
| Breaking existing simple diagrams | Threshold ensures only large-offset edges affected |
| Performance regression | Waypoint generation is O(1) per edge |
| Waypoints conflict with nodes | Use heuristic that maintains source X position |

### Medium Risk

| Risk | Mitigation |
|------|------------|
| Visual regression in complex diagrams | Snapshot testing with multiple fixtures |
| Waypoints conflict with backward edges | Check corridor bounds before generating waypoints |
| Threshold too aggressive/conservative | Make threshold configurable, test with multiple values |

### High Risk

| Risk | Mitigation |
|------|------------|
| Algorithm creates worse paths than default | Fallback to default if generated path has issues |

---

## Rollout Strategy

### Phase 1: Basic Implementation
1. Implement `generate_offset_waypoints()` in router.rs
2. Integrate into `route_edge()` flow
3. Test with `complex.mmd`

### Phase 2: Validation
1. Run all existing tests
2. Visual inspection of all fixtures
3. Add new test cases for edge cases

### Phase 3: Refinement
1. Tune threshold value based on testing
2. Add left-side source handling
3. Consider collision checking (Strategy 5 from waypoint strategies)

---

## Files Changed Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `src/render/router.rs` | Modified | Add `generate_offset_waypoints()` function |
| `src/render/router.rs` | Modified | Update `route_edge()` to call waypoint generation |
| `tests/integration.rs` | Updated | Update expected output for `complex.mmd` |
| New fixture | Added | `tests/fixtures/horizontal_offset.mmd` |

### Lines of Code Estimate

- New function: ~40-60 lines
- Integration code: ~10 lines
- Tests: ~50-80 lines
- **Total:** ~100-150 lines

---

## Conclusion

**Option B (Routing Phase Integration)** is the recommended approach because:

1. **Minimal change** - Single file modification
2. **Natural fit** - Routing decisions belong in router
3. **Low risk** - Threshold ensures minimal impact on existing diagrams
4. **Easy testing** - Unit tests in existing test suite

The implementation can be done incrementally, starting with the common case (right-side source in TD layout) and expanding to handle other cases as needed.
