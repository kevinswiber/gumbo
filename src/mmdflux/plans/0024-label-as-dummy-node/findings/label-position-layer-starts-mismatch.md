# Finding: Label Position layer_starts Mismatch

**Phase:** 7 (Integration Testing)
**Severity:** Bug (blocking)
**Status:** Fixed

## Problem

`transform_label_positions_direct()` in `src/render/layout.rs` used `ctx.to_ascii()` (uniform scaling) for label positions, but waypoints used `layer_starts` snapping. The session 1 notes identified this as the bug and proposed using `layer_starts` for labels too.

However, `layer_starts` is computed from `result.nodes` which only contains **real** nodes, not dummy nodes. When `make_space_for_edge_labels` inserts a label dummy at rank R between source (rank R-1) and target (rank R+1), there may be no real node at rank R. The `layers` array therefore has no entry for rank R, and `layer_starts[R]` maps to the **target node's row** instead of the gap between nodes.

This caused labels to render on node rows where `is_node: true` cells prevented any characters from being written.

## Root Cause

The dagre rank of the label dummy doesn't correspond to a layer index in the render layer's `layers` array. The `layers` array is built from real nodes only, so ranks that contain only dummy nodes have no corresponding `layer_starts` entry.

## Fix

Changed `transform_label_positions_direct()` to compute the primary axis position as the **midpoint between the source node's bottom edge and the target node's top edge** (for TD; analogously for LR). This uses `node_bounds` instead of `layer_starts`, ensuring labels always land in the gap between nodes.

Also changed `get_label_position()` in `normalize.rs` to return `WaypointWithRank` instead of `Point`, and updated `LayoutResult.label_positions` to `HashMap<usize, WaypointWithRank>` for consistency with waypoints (the rank info may be useful for future refinements).

## Files Changed

- `src/dagre/normalize.rs` - `get_label_position()` returns `WaypointWithRank`
- `src/dagre/types.rs` - `LayoutResult.label_positions` type changed
- `src/dagre/mod.rs` - Updated test assertions for `.point.x`/`.point.y`
- `src/render/layout.rs` - `transform_label_positions_direct()` uses `node_bounds` midpoint
