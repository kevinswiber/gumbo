# Issue 03: labeled_edges.mmd Backward Edge Label Far From Edge

**Severity:** Medium
**Category:** Backward edge label cross-axis positioning
**Status:** Fixed
**Fixed by:** Plan 0027 (path-midpoint backward edge label placement)
**Affected fixtures:** `labeled_edges.mmd`
**Source finding:** Plan 0025 regression sweep

## Description

The "retry" label on the backward edge (Handle Error → Setup) rendered far to the left of the vertical segment, looking free-floating and disconnected from its edge. The edge routed correctly (compact backward routing to the right of the nodes), but the label x-position was too far left — using the dagre-computed x-coordinate instead of the actual backward edge route's x-coordinate.

## Resolution

Plan 0027 implemented a path-midpoint algorithm (`calc_label_position()`) that computes backward edge label positions from the actual routed segments instead of dagre's precomputed coordinates. The label now renders centered on the backward edge's vertical segment at the 50% mark of the total path length.

## Cross-References

- **Fix:** Plan 0027 (`plans/0027-backward-edge-label-midpoint/`)
- **Plan 0025:** Phase 2 (rank-based label snapping), Phase 3 (backward edge waypoint stripping)
- **Research 0020:** Backward edge label placement (`research/0020-backward-edge-label-placement/`)
