# Synthesis: Edge Routing for Forward Edges with Large Horizontal Offset

## Executive Summary

In complex.mmd, the edge from "More Data?" (E) to "Output" (F) labeled "no" takes a Z-shaped path that routes through the crowded middle of the diagram. The source node is on the right side, and the target is centered - routing through the right side (corridor area) would be visually cleaner.

The root cause is the **mid-y calculation** at line 464 of `router.rs`, which places the horizontal segment at `(start.y + end.y) / 2` without considering diagram density or node positions.

---

## WHAT: The Exact Problem

### Current Behavior

```
                              ┌────────────┐
                              < More Data? >  ← E is on RIGHT side (x ~= 50)
                              └────────────┘
            ┌────────────────────┘     (Z-path goes LEFT through middle)
            │
            │ ← Horizontal segment at mid_y crosses through crowded area
            │
            ▼
        ┌────────┐
        │ Output │  ← F is CENTERED (x ~= 25)
        └────────┘
```

### Ideal Behavior

```
                              ┌────────────┐
                              < More Data? >  ← E is on RIGHT side
                              └────────────┘
                                         │
                                         │  ← Stay on RIGHT, use corridor
                                         │
                                         └───────┐
                                                 │
                                         ┌───────┘
                                         ▼
                                     ┌────────┐
                                     │ Output │
                                     └────────┘
```

When the source is on the right side of the diagram, routing through the right corridor (where backward edges go) would avoid the crowded middle.

---

## WHERE: Code Locations

### Primary Decision Point

**File**: `src/render/router.rs`
**Function**: `build_orthogonal_path_for_direction()`
**Line**: 464

```rust
let mid_y = (start.y + end.y) / 2;  // <-- THE PROBLEM
```

### Full Call Chain

1. `route_edge()` (lines 124-177) - Entry point
2. `route_edge_direct()` (lines 234-291) - Handles edges without waypoints
3. `build_orthogonal_path_for_direction()` (lines 432-500) - Creates Z-path
4. Line 464: `mid_y = (start.y + end.y) / 2`

### Supporting Code

| Function | Lines | Purpose |
|----------|-------|---------|
| `is_backward_edge()` | 106-121 | Determines if edge goes against flow |
| `route_backward_edge_vertical()` | 569-628 | Routes backward edges through corridor |
| `attachment_point()` | 57-80 | Calculates attachment points on nodes |
| `offset_from_boundary()` | 319-361 | Offsets points outside node boundary |

---

## HOW: Current Algorithm

### Z-Path Construction for TD Layout

```rust
match direction {
    Direction::TopDown | Direction::BottomTop => {
        let mid_y = (start.y + end.y) / 2;  // Midpoint between source and target
        vec![
            Segment::Vertical { x: start.x, y_start: start.y, y_end: mid_y },
            Segment::Horizontal { y: mid_y, x_start: start.x, x_end: end.x },
            Segment::Vertical { x: end.x, y_start: mid_y, y_end: end.y },
        ]
    }
    // ...
}
```

**Algorithm**: Always places horizontal segment at vertical midpoint between source and target.

### What Dagre Does Differently

1. **Dummy nodes** break long edges into unit segments
2. **Crossing minimization** positions dummies to minimize conflicts
3. **Four alignments** (ul, ur, dl, dr) computed in parallel
4. **Smallest width** alignment selected
5. **Side emerges** from the optimization, not explicit choice

### What Mermaid Does

1. Relies on Dagre for waypoints
2. Post-processes with corner smoothing
3. No explicit side preference
4. Uses SVG curves (not applicable to ASCII)

---

## WHY: Original Design Constraints

The current implementation prioritizes:

1. **Simplicity** - Single formula for all edges
2. **Vertical entry** - Guarantees arrows match layout direction (▼ for TD)
3. **Symmetry** - Bend point centered between source and target
4. **Predictability** - Deterministic output for same input

It does NOT account for:

1. **Edge congestion** in the middle region
2. **Node distribution** at intermediate layers
3. **Source position** relative to diagram center
4. **Multiple edges** competing for space

---

## SOLUTION OPTIONS

### Option 1: Side-Preference Heuristic

**Description**: Choose routing side based on source position relative to diagram center.

```rust
fn build_orthogonal_path_for_direction(
    start: Point,
    end: Point,
    direction: Direction,
    layout: &Layout,  // NEW: pass layout for context
) -> Vec<Segment> {
    // Calculate diagram center
    let diagram_center_x = layout.width / 2;

    // If source is on right side and has large horizontal offset
    let horizontal_offset = start.x.saturating_sub(end.x);
    let on_right_side = start.x > diagram_center_x;

    if on_right_side && horizontal_offset > THRESHOLD {
        // Route via right side (similar to backward edge corridor)
        return build_right_side_path(start, end, layout);
    }

    // Otherwise, use standard mid-y approach
    let mid_y = (start.y + end.y) / 2;
    // ... existing logic
}
```

**Pros**:
- Minimal code change (~30 lines)
- Clear decision logic
- Reuses existing corridor infrastructure

**Cons**:
- Still a heuristic, may not work for all cases
- Needs threshold tuning
- Left-side sources with large offsets not addressed

**Complexity**: Low
**Files Changed**: `router.rs`
**Risk**: Low - fallback to existing behavior

---

### Option 2: Collision-Aware Routing

**Description**: Check if horizontal segment would pass through or near existing nodes, and reroute if so.

```rust
fn build_orthogonal_path_for_direction(
    start: Point,
    end: Point,
    direction: Direction,
    layout: &Layout,
) -> Vec<Segment> {
    let mid_y = (start.y + end.y) / 2;
    let candidate_horizontal = Segment::Horizontal {
        y: mid_y,
        x_start: start.x.min(end.x),
        x_end: start.x.max(end.x),
    };

    // Check for node collisions
    if segment_collides_with_nodes(&candidate_horizontal, layout) {
        // Try alternative routes
        if let Some(path) = try_right_side_routing(start, end, layout) {
            return path;
        }
        if let Some(path) = try_left_side_routing(start, end, layout) {
            return path;
        }
    }

    // Use original mid-y path
    // ...
}

fn segment_collides_with_nodes(segment: &Segment, layout: &Layout) -> bool {
    for (_, bounds) in &layout.node_bounds {
        if segment_intersects_bounds(segment, bounds) {
            return true;
        }
    }
    false
}
```

**Pros**:
- Handles any configuration, not just right-side sources
- Collision detection useful for other issues too
- More robust solution

**Cons**:
- More complex implementation (~60-80 lines)
- Performance overhead from collision checks
- Need to define "collision" threshold (near vs through)

**Complexity**: Medium
**Files Changed**: `router.rs`
**Risk**: Medium - new logic path, needs thorough testing

---

### Option 3: Corridor Reservation for Forward Edges

**Description**: Extend the backward edge corridor system to optionally include forward edges with large horizontal offsets.

```rust
// In layout.rs
pub struct Layout {
    // Existing
    pub backward_corridors: usize,
    pub backward_edge_lanes: HashMap<(String, String), usize>,

    // NEW
    pub forward_corridor_edges: HashSet<(String, String)>,
}

// In layout computation
fn assign_corridor_edges(diagram: &Diagram, grid_positions: &HashMap<String, GridPos>) {
    let mut forward_corridor = HashSet::new();

    for edge in &diagram.edges {
        let from_pos = grid_positions.get(&edge.from);
        let to_pos = grid_positions.get(&edge.to);

        // Check if this forward edge should use corridor
        if should_use_corridor(from_pos, to_pos, diagram) {
            forward_corridor.insert((edge.from.clone(), edge.to.clone()));
        }
    }

    forward_corridor
}

// In router.rs
pub fn route_edge(...) -> Option<RoutedEdge> {
    // Check if forward edge should use corridor
    if layout.forward_corridor_edges.contains(&(edge.from.clone(), edge.to.clone())) {
        return route_forward_via_corridor(edge, from_bounds, to_bounds, layout, direction);
    }

    // ... existing logic
}
```

**Pros**:
- Clean integration with existing corridor system
- Layout-time decision (consistent routing)
- Can coordinate multiple edges using same corridor

**Cons**:
- Significant architectural change
- Requires layout algorithm modification
- May widen diagrams unnecessarily

**Complexity**: High
**Files Changed**: `layout.rs`, `router.rs`
**Risk**: Medium-High - architectural change

---

### Option 4: Waypoint-Based Routing

**Description**: Use dagre's waypoint output (from `edge_waypoints`) for complex edges.

Currently, `edge_waypoints` is populated by the dagre integration but only used when non-empty. For most edges, it's empty and direct routing is used.

```rust
// In layout.rs - compute_layout_dagre()
// Currently: waypoints only from dummy nodes
// Change: Compute waypoints for ALL edges with large offsets

fn compute_waypoints_for_edge(
    edge: &Edge,
    from_bounds: &NodeBounds,
    to_bounds: &NodeBounds,
    layout_context: &LayoutContext,
) -> Vec<(usize, usize)> {
    let horizontal_offset = abs_diff(from_bounds.center_x(), to_bounds.center_x());

    if horizontal_offset < WAYPOINT_THRESHOLD {
        return vec![];  // Use direct routing
    }

    // Compute intelligent waypoints
    // Could use A* pathfinding, or simple heuristics
    compute_avoiding_waypoints(from_bounds, to_bounds, layout_context)
}
```

**Pros**:
- Leverages existing waypoint infrastructure
- Can use sophisticated pathfinding
- Works with dagre integration

**Cons**:
- Waypoints are in dagre coordinates (transformation needed)
- May require pathfinding algorithm
- Complex integration

**Complexity**: High
**Files Changed**: `layout.rs`, `router.rs`
**Risk**: High - significant new functionality

---

## Recommendation

### Immediate Fix: Option 1 (Side-Preference Heuristic)

**Rationale**:
- Directly addresses the complex.mmd issue
- Minimal code change
- Low risk
- Can be implemented and tested quickly

**Implementation Sketch**:
```rust
// In router.rs, modify build_orthogonal_path_for_direction()

const LARGE_OFFSET_THRESHOLD: usize = 15;  // Tune based on testing

fn should_route_via_side(start: Point, end: Point, layout: &Layout) -> Option<Side> {
    let diagram_center_x = layout.width / 2;
    let horizontal_offset = start.x.abs_diff(end.x);

    if horizontal_offset < LARGE_OFFSET_THRESHOLD {
        return None;  // Use standard routing
    }

    if start.x > diagram_center_x + LARGE_OFFSET_THRESHOLD / 2 {
        Some(Side::Right)
    } else if start.x < diagram_center_x - LARGE_OFFSET_THRESHOLD / 2 {
        Some(Side::Left)
    } else {
        None
    }
}
```

### Future Enhancement: Option 2 (Collision-Aware Routing)

**Rationale**:
- Handles edge cases Option 1 misses
- Useful foundation for other improvements
- Can be layered on top of Option 1

---

## Test Cases

After implementation, verify with:

1. **`tests/fixtures/complex.mmd`** - Original problem case
   - E→F ("no") should route via right side
   - All other edges should remain unchanged

2. **New test: `tests/fixtures/horizontal_offset.mmd`**
   ```
   graph TD
       A[Left] --> C[Center]
       B[Right] --> C
       A --> D[Bottom Left]
       B --> E[Bottom Right]
   ```
   - B→C should consider right-side routing
   - A→C should use standard routing

3. **Regression: `tests/fixtures/simple.mmd`, `chain.mmd`, etc.**
   - No changes expected for simple cases

---

## Implementation Attempts

### Option 4B: Synthetic Waypoints (FAILED)

**Date:** 2026-01-26
**Result:** Reverted after testing

An implementation of waypoint-based routing was attempted that generated synthetic waypoints for edges with large horizontal offset where the source was on the left or right side of the diagram.

**Why it failed:** The synthetic waypoints caused edges to stay on one side and then cross back over to reach the target, which created **more** visual confusion than the default mid-Y routing. The default approach handles edge convergence better by crossing at the midpoint.

**Key learning:** Edge routing is a global optimization problem. You can't optimize individual edges in isolation - the routing of one edge affects how others look. Simple heuristics that optimize individual edges can make the overall diagram worse.

See `06-option4b-implementation-results.md` for full details.

### Option 4A: Brandes-Kopf (IMPLEMENTED but INSUFFICIENT)

**Date:** 2026-01-26
**Result:** Implemented successfully, but didn't fully solve the problem

The Brandes-Kopf coordinate assignment algorithm was implemented in Plan 0011. The implementation is correct and produces optimal coordinates **within the given node ordering**.

**Why it's insufficient:** BK optimizes positions within the assigned order. If node A has order=0 and node B has order=1, BK places A left of B. It can't change which side nodes appear on.

The actual problem is in the **ordering algorithm** (`order.rs`), which determines which nodes go left vs. right within each layer. Dagre's ordering uses:
1. Bias parameter alternating left/right
2. Multiple ordering attempts keeping best
3. Edge weights for crossing counts

See `07-ordering-algorithm-gap.md` for detailed analysis and proposed fixes.

---

## References

- `01-current-mmdflux-behavior.md` - Current implementation details
- `02-dagre-edge-routing.md` - Dagre's approach
- `03-mermaid-dagre-integration.md` - Mermaid's post-processing
- `06-option4b-implementation-results.md` - Failed implementation attempt and learnings
- `07-ordering-algorithm-gap.md` - **Post-BK analysis: ordering is the real gap**
- `research/edge-routing-deep-dive/issue-4-edge-through-node.md` - Related collision issue
- `research/edge-routing-deep-dive/SYNTHESIS.md` - Overall edge routing analysis
