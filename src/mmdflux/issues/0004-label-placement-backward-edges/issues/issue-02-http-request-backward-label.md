# Issue 02: http_request.mmd Backward Edge Label Misplaced

**Severity:** Medium
**Category:** Backward edge label cross-axis positioning
**Status:** Fixed
**Fixed by:** Plan 0027 (path-midpoint backward edge label placement)
**Affected fixtures:** `http_request.mmd`
**Source finding:** Plan 0025 regression sweep

## Description

The "HTTP Response" label on the backward edge (Send Response → Client) rendered 2 spaces to the left of its vertical segment, colliding with the "Authenticated?" diamond node. The label should be adjacent to the backward edge's vertical routing column (which routes to the right of the diagram), not offset into node territory.

## Resolution

Plan 0027 implemented a path-midpoint algorithm (`calc_label_position()`) that computes backward edge label positions from the actual routed segments instead of dagre's precomputed coordinates. The label now renders centered on the backward edge's vertical segment at the 50% mark of the total path length.

## Cross-References

- **Fix:** Plan 0027 (`plans/0027-backward-edge-label-midpoint/`)
- **Plan 0025:** Phase 2 (rank-based label snapping), Phase 3 (backward edge waypoint stripping)
- **Research 0020:** Backward edge label placement (`research/0020-backward-edge-label-placement/`)
