# Implementation Deviations from Original Plan

This document tracks the decisions made during implementation that deviated from the original research plan in `IMPLEMENTATION-PLAN.md`. These deviations reflect lessons learned during implementation.

---

## Overview

The original plan proposed implementing three missing dagre mechanisms:
1. **Dummy nodes for long edges** (normalize/denormalize)
2. **Edge labels as layout entities** (label dummies)
3. **Dynamic intersection calculation** (intersectRect)

We implemented all three mechanisms, but the integration with the ASCII renderer required adaptations not anticipated in the original plan.

---

## Phase 1: Infrastructure ✅ Implemented as Planned

No significant deviations. Added:
- `src/dagre/normalize.rs` with `DummyType`, `DummyNode`, `LabelPos`, `DummyChain`
- Extended `LayoutGraph` with `dummy_nodes`, `dummy_chains`, `original_edge_count`
- Added `edge_waypoints` and `edge_label_positions` to `Layout`

---

## Phase 2: Normalization ✅ Implemented with Minor Adaptations

### Deviation: Edge Label Representation

**Original Plan:** Edge labels become dummy nodes with dimensions that participate in layout.

**What We Did:** Implemented as planned, but the label dimensions use character coordinates (label length + padding) rather than pixel dimensions. Labels are stored in `EdgeLabelInfo` with width/height in character units.

**Why:** ASCII rendering works in discrete character cells, not floating-point coordinates.

### Deviation: DummyChain Structure

**Original Plan:** Track dummy chains via `dummy_chains: Vec<usize>` pointing to first dummy index.

**What We Did:** Used `DummyChain` struct with `edge_index`, `dummy_ids`, `label_dummy_id`, `rank_range` for richer tracking.

**Why:** Needed to track which dummy is the label dummy and the full range of ranks for denormalization.

---

## Phase 3: Intersection Calculation ✅ Implemented with Critical Fix

### Deviation: Attachment Point Clamping

**Original Plan:** `intersect_rect()` returns intersection point directly.

**What We Did:** Added `clamp_to_boundary()` to ensure intersection points are on actual boundary cells.

**Why:** The floating-point intersection calculation (`center + width/2`) doesn't account for discrete cell boundaries. For a node with height=3 at y=1, the bottom boundary is at y=3, but `center_y + height/2 = 2.5 + 1.5 = 4.0` rounds to y=4, which is outside the node. This caused edges to be drawn through protected node cells, creating visual gaps.

**Code Location:** `router.rs:clamp_to_boundary()`, called in `route_edge_direct()` and `route_edge_with_waypoints()`

### Deviation: Kept `orthogonalize_segment()` as Active Helper

**Original Plan:** Use `orthogonalize()` for waypoint-based routing.

**What We Did:** `orthogonalize()` is test-only. Production code uses `orthogonalize_segment()` called by `build_orthogonal_path_with_waypoints()`.

**Why:** The waypoint-based approach needed direction-aware final segments (vertical for TD/BT, horizontal for LR/RL) to ensure arrows point correctly. `build_orthogonal_path_for_direction()` handles this.

---

## Phase 4: Integration ✅ Implemented with Bug Fixes

### Deviation: BT/RL Layout Double-Reverse Bug

**Original Plan:** Use `reverse` parameter in `grid_to_draw_vertical/horizontal` to flip node positions for BT/RL.

**What We Did:** Removed the reverse logic entirely.

**Why:** Dagre's `position.rs` already flips coordinates for BT/RL directions internally. The `grid_to_draw_*` reverse was double-reversing, putting nodes in the wrong positions. For BT layout, Foundation appeared at the top instead of the bottom.

**Code Location:** `layout.rs:grid_to_draw_vertical()` and `grid_to_draw_horizontal()` - `reverse` parameter is now ignored.

### Deviation: Connector Segments for Node Attachment

**Original Plan:** Edges connect at offset attachment points (1 cell outside node boundary).

**What We Did:** Added explicit connector segments from the node boundary to the offset point.

**Why:** Without connector segments, edges started 1 cell away from nodes with no visual connection. The connector segment draws the short line from the node boundary to where the main edge path begins.

**Code Location:** `router.rs:add_connector_segment()`

### Deviation: Entry Direction from Layout, Not Segments

**Original Plan:** `determine_entry_direction()` calculates entry direction from the last segment's direction.

**What We Did:** Removed `determine_entry_direction()`. Use `entry_direction_for_layout()` which returns the canonical entry direction for the layout direction (TD→Top, BT→Bottom, LR→Left, RL→Right).

**Why:** The segment-based calculation was complex and error-prone. For forward edges, the entry direction is always determined by the layout direction. Backward edges have special handling.

---

## Phase 5: Cleanup 🚧 Partially Completed

### Deviation: 5.1 - Backward Edge Routing NOT Simplified

**Original Plan:** Simplify backward edge routing to use waypoints.

**What We Did:** Kept the corridor-based perimeter routing (`route_backward_edge_vertical`, `route_backward_edge_horizontal`).

**Why:** Dagre doesn't provide waypoints for backward edges (cycles). The perimeter routing creates the distinctive "wrap around" visual that clearly shows the cycle. Integrating waypoints would require significant changes for unclear benefit.

### Deviation: 5.2 - Fixed Attachment Points Partially Deprecated

**Original Plan:** Deprecate `shape.rs` functions like `top()`, `bottom()` in favor of `intersect_node()`.

**What We Did:**
- Forward edges use `intersect_node()` via `calculate_attachment_points()`
- Backward edges still use `attachment_point()` with `AttachDirection`
- Removed unused routing functions, changed test-only functions to `#[cfg(test)]`

**Why:** Backward edge routing needs predictable exit/entry points (right side for TD, bottom for LR) rather than dynamic intersection. The hybrid approach works well.

**Removed Functions:**
- `determine_entry_direction` - replaced by `entry_direction_for_layout`
- `compute_path` - replaced by `build_orthogonal_path_for_direction`
- `compute_horizontal_first_path` - only used by `compute_path`

**Changed to `#[cfg(test)]`:**
- `attachment_directions` - useful for testing direction logic
- `compute_vertical_first_path` - tests exercise this path computation
- `orthogonalize` - tests verify waypoint orthogonalization
- `build_orthogonal_path` - tests verify full path construction

### Deviation: 5.3 - Collision Detection Kept as Safety Net

**Original Plan:** Remove redundant post-hoc label collision detection.

**What We Did:** Kept `find_safe_label_position()` and `label_has_collision()` in `edge.rs`.

**Why:**
1. Backward edge labels don't get dagre-computed positions
2. Acts as safety net for edge cases
3. Low cost to keep, high cost if removed and causes regressions

---

## Summary of Key Decisions

| Decision | Rationale |
|----------|-----------|
| Clamp intersection points to boundary | Float math gives points outside discrete cell boundaries |
| Remove BT/RL reverse | Dagre already flips coordinates internally |
| Add connector segments | Visual connection from node to edge path |
| Use layout-based entry direction | Simpler and more reliable than segment analysis |
| Keep backward edge corridor routing | Dagre doesn't provide waypoints for cycles |
| Keep label collision detection | Safety net for backward edges and edge cases |
| `#[cfg(test)]` for unused-but-tested functions | Keeps test coverage without dead code warnings |

---

## Lessons Learned

1. **ASCII vs. SVG:** Many dagre concepts need adaptation for discrete cell grids. Floating-point calculations that work for SVG need clamping/rounding for ASCII.

2. **Coordinate Systems:** Different parts of the system use different coordinate origins. Dagre's internal y-axis direction, screen coordinates, and ASCII rendering all need careful alignment.

3. **Test-Driven Validation:** The extensive test suite caught the BT/RL double-reverse bug that would have been hard to diagnose otherwise.

4. **Incremental Integration:** Adding debug output at key points (attachment calculation, segment generation) was essential for diagnosing rendering issues.

5. **Keep Working Code:** The backward edge perimeter routing "just works" for cycles. Refactoring it to use waypoints would add complexity without clear benefit.

---

## Files Changed from Original Plan

| Planned File | Actual File | Notes |
|--------------|-------------|-------|
| `src/dagre/normalize.rs` | Same | As planned |
| `src/dagre/graph.rs` | Same | As planned + `DummyChain` struct |
| `src/dagre/mod.rs` | Same | As planned |
| `src/render/intersect.rs` | Same | As planned |
| `src/render/router.rs` | Same | Significant additions: `clamp_to_boundary`, `add_connector_segment`, removed/changed functions |
| `src/render/layout.rs` | Same | Removed BT/RL reverse logic |
| `src/render/edge.rs` | Same | Kept collision detection |
