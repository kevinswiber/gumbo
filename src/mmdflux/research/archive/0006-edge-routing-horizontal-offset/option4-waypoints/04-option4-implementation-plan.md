# Option 4 Implementation Plan: Waypoint-Based Routing for Large Horizontal Offset

## Executive Summary

Based on the research findings, this plan proposes implementing waypoint-based routing for forward edges with large horizontal offset by generating waypoints during the routing phase. The implementation reuses existing waypoint infrastructure and adds ~100-150 lines of code.

---

## Recommended Approach

### Strategy: Corridor-Based Single Waypoint (Strategy 2 from waypoint generation research)

**Why this strategy:**
1. Directly addresses the `complex.mmd` issue (E→F "no" edge)
2. Simple heuristic with predictable behavior
3. Reuses existing `route_edge_with_waypoints()` infrastructure
4. Low risk - fallback to default routing if waypoint not generated

### Integration Point: Routing Phase (Option B)

**Why this integration point:**
1. Minimal architectural change (single file modification)
2. Natural fit - routing decisions belong in router
3. All required context (bounds, shapes, layout) already available
4. Follows existing pattern (similar to backward edge detection)

---

## Implementation Phases

### Phase 1: Core Waypoint Generation

**Goal:** Generate single waypoint for right-side source edges in TD layout

**File:** `src/render/router.rs`

**New Function:**
```rust
/// Generate waypoints for forward edges with large horizontal offset.
/// Returns Some(waypoints) if special routing is needed, None for default routing.
fn generate_offset_waypoints(
    from_bounds: &NodeBounds,
    to_bounds: &NodeBounds,
    layout: &Layout,
    direction: Direction,
) -> Option<Vec<(usize, usize)>> {
    const LARGE_OFFSET_THRESHOLD: usize = 20;

    // Only for vertical layouts initially
    if !matches!(direction, Direction::TopDown | Direction::BottomTop) {
        return None;
    }

    let horizontal_offset = from_bounds.center_x().abs_diff(to_bounds.center_x());
    if horizontal_offset < LARGE_OFFSET_THRESHOLD {
        return None; // Small offset, use default routing
    }

    let diagram_center_x = layout.width / 2;
    let source_on_right = from_bounds.center_x() > diagram_center_x;

    // Only handle right-side sources initially
    if !source_on_right {
        return None;
    }

    // Check if target is to the left of source
    if to_bounds.center_x() >= from_bounds.center_x() {
        return None; // Target is not to the left, use default
    }

    match direction {
        Direction::TopDown => {
            // Single waypoint: stay at source X, drop to near target Y
            // This forces vertical-first routing on the right side
            let waypoint_x = from_bounds.center_x();
            let waypoint_y = to_bounds.y.saturating_sub(3); // Just above target

            Some(vec![(waypoint_x, waypoint_y)])
        }
        Direction::BottomTop => {
            // Inverted: stay at source X, rise to near target Y
            let waypoint_x = from_bounds.center_x();
            let waypoint_y = to_bounds.y + to_bounds.height + 3;

            Some(vec![(waypoint_x, waypoint_y)])
        }
        _ => None,
    }
}
```

**Integration in `route_edge()`:**
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

    // ===== NEW CODE START =====
    // Check if this forward edge needs generated waypoints due to large horizontal offset
    let from_shape = layout.node_shapes.get(&edge.from).copied().unwrap_or(Shape::Rectangle);
    let to_shape = layout.node_shapes.get(&edge.to).copied().unwrap_or(Shape::Rectangle);

    if let Some(generated_wps) = generate_offset_waypoints(
        from_bounds, to_bounds, layout, diagram_direction
    ) {
        return route_edge_with_waypoints(
            edge,
            from_bounds,
            from_shape,
            to_bounds,
            to_shape,
            &generated_wps,
            diagram_direction,
        );
    }
    // ===== NEW CODE END =====

    // Fall back to direct routing
    route_edge_direct(...)
}
```

**Estimated Lines:** ~50 new lines

---

### Phase 2: Testing and Validation

**Goal:** Verify the fix works and doesn't break existing diagrams

**Tasks:**

1. **Unit tests for `generate_offset_waypoints()`:**
   ```rust
   #[test]
   fn test_generate_offset_waypoints_right_source_large_offset() {
       // Source at x=60 (right side), target at x=25 (center)
       // Should generate waypoint at (60, near_target_y)
   }

   #[test]
   fn test_generate_offset_waypoints_small_offset_returns_none() {
       // Source and target close together
       // Should return None
   }

   #[test]
   fn test_generate_offset_waypoints_left_source_returns_none() {
       // Source on left side (not handled in Phase 1)
       // Should return None
   }
   ```

2. **Integration test update for `complex.mmd`:**
   - Run `cargo run -- ./tests/fixtures/complex.mmd`
   - Verify E→F "no" edge routes via right side
   - Update expected output in integration tests

3. **Regression tests:**
   - Run all fixtures: `cargo test --test integration`
   - Visual inspection of outputs
   - Verify simple/chain diagrams unchanged

**Estimated Lines:** ~80 test lines

---

### Phase 3: Left-Side Source Support

**Goal:** Handle edges with source on left side of diagram

**Add to `generate_offset_waypoints()`:**
```rust
let source_on_left = from_bounds.center_x() < diagram_center_x.saturating_sub(LARGE_OFFSET_THRESHOLD / 2);

if source_on_left && to_bounds.center_x() > from_bounds.center_x() {
    match direction {
        Direction::TopDown => {
            let waypoint_x = from_bounds.center_x();
            let waypoint_y = to_bounds.y.saturating_sub(3);
            return Some(vec![(waypoint_x, waypoint_y)]);
        }
        Direction::BottomTop => {
            let waypoint_x = from_bounds.center_x();
            let waypoint_y = to_bounds.y + to_bounds.height + 3;
            return Some(vec![(waypoint_x, waypoint_y)]);
        }
        _ => {}
    }
}
```

**Estimated Lines:** ~15 additional lines

---

### Phase 4: Horizontal Layout Support (LR/RL)

**Goal:** Extend to left-right and right-left layouts

**Add to `generate_offset_waypoints()`:**
```rust
Direction::LeftRight => {
    // Large vertical offset with source at top or bottom
    let vertical_offset = from_bounds.center_y().abs_diff(to_bounds.center_y());
    if vertical_offset < LARGE_OFFSET_THRESHOLD {
        return None;
    }

    let diagram_center_y = layout.height / 2;
    let source_at_top = from_bounds.center_y() < diagram_center_y;

    if source_at_top && to_bounds.center_y() > from_bounds.center_y() {
        let waypoint_x = to_bounds.x.saturating_sub(3);
        let waypoint_y = from_bounds.center_y();
        return Some(vec![(waypoint_x, waypoint_y)]);
    }
    // Similar for source_at_bottom...
}

Direction::RightLeft => {
    // Mirror of LeftRight
}
```

**Estimated Lines:** ~30 additional lines

---

## Existing Code to Reuse

| Component | Location | Usage |
|-----------|----------|-------|
| `route_edge_with_waypoints()` | router.rs:183-228 | Routes edge through provided waypoints |
| `build_orthogonal_path_with_waypoints()` | router.rs:506-540 | Builds path segments through waypoints |
| `calculate_attachment_points()` | intersect.rs:153-178 | Computes dynamic attachment based on waypoints |
| `NodeBounds::center_x()`, `center_y()` | layout.rs | Get node center coordinates |
| Layout width/height | layout.rs | Diagram dimensions for center calculation |

---

## New Code Summary

| Function | Lines | Purpose |
|----------|-------|---------|
| `generate_offset_waypoints()` | ~50 | Core waypoint generation logic |
| Integration in `route_edge()` | ~10 | Call waypoint generation |
| Unit tests | ~50 | Test waypoint generation |
| Integration test updates | ~30 | Verify complex.mmd fix |
| **Total** | **~140** | |

---

## Test Strategy

### Unit Tests

1. **Waypoint generation conditions:**
   - Large offset → generates waypoint
   - Small offset → returns None
   - Right-side source → generates waypoint
   - Left-side source (Phase 1) → returns None
   - Backward edge → not called (handled earlier)

2. **Waypoint position correctness:**
   - X coordinate matches source center
   - Y coordinate is above target (for TD)
   - Y coordinate is below target (for BT)

### Integration Tests

1. **`complex.mmd`:**
   - E→F "no" edge routes via right side
   - All other edges unchanged

2. **`simple.mmd`, `chain.mmd`, etc.:**
   - No visual changes (no large offsets)

3. **New fixture `horizontal_offset.mmd`:**
   ```
   graph TD
       A[Left Node] --> B[Center]
       C[Right Node] --> B
       C --> D[Bottom Left]
   ```
   - A→B: default routing (left side, moves right)
   - C→B: generated waypoint (right side, large offset left)
   - C→D: generated waypoint (right side, large offset left)

### Visual Validation

Run and visually inspect:
```bash
cargo run -- ./tests/fixtures/complex.mmd
cargo run -- ./tests/fixtures/horizontal_offset.mmd
```

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Threshold too aggressive | Start with 20, adjust based on testing |
| Generated waypoint causes collision | Waypoint stays at source X, unlikely to collide |
| Breaks existing diagrams | Threshold ensures only large-offset edges affected |
| Performance impact | O(1) per edge, negligible |

---

## Success Criteria

1. **Primary:** E→F "no" edge in `complex.mmd` routes via right side, not through middle
2. **Secondary:** All existing tests pass
3. **Tertiary:** No visual regressions in other fixtures

---

## Estimated Complexity

- **Implementation:** ~100-150 lines of code
- **Files changed:** 1 (router.rs)
- **New files:** 0
- **Test files changed:** 1 (integration.rs)
- **New fixtures:** 1 (horizontal_offset.mmd)

---

## Timeline Recommendation

1. **Phase 1 (Core):** First implementation session
2. **Phase 2 (Testing):** Same session, validate immediately
3. **Phase 3 (Left-side):** Follow-up if needed
4. **Phase 4 (Horizontal):** Future enhancement

The core fix (Phases 1-2) can be implemented in a single focused session.
