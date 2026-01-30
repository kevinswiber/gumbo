# Finding: Heuristic label placement fails for waypoint edges

**Type:** discovery
**Task:** 2.2
**Date:** 2026-01-29

## Details

When `make_space_for_edge_labels` is wired into the pipeline, labeled short edges (e.g., A->B with label "Yes") now span 2 ranks and get a dummy node with waypoints. This changes the routing from a direct vertical path to a Z-shaped waypoint path with 6 segments.

The heuristic label placement in `draw_edge_label_with_tracking` treats 6+ segment paths as "long paths" (backward edges) and attempts to place the label beside the longest vertical segment. For the test case, this placed the label at x=12 (right of the edge at x=10), but the canvas was only ~11 characters wide, causing the label to be silently clipped.

## Impact

The `test_render_edge_with_label` test was updated to use the full rendering pipeline (`crate::render::render`) instead of the isolated `render_edge` function. The full pipeline handles this correctly because the canvas is sized for the entire diagram.

This confirms the plan's premise: heuristic label placement doesn't work well for edges that now have waypoints from label dummies. Phase 6 (precomputed label positions) will address this properly.

## Action Items
- [ ] Phase 6 should ensure precomputed label positions are preferred over heuristic placement
- [ ] Consider whether `is_long_path` threshold (6 segments) is still appropriate with label dummies
