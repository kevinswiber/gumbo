# Finding: dagre bounds overlap in y-dimension for stacked subgraphs

**Type:** plan-error
**Task:** 2.2
**Date:** 2026-01-29

## Details

The plan assumed "dagre already guarantees non-overlapping bounds through border nodes and nesting edges." This is **incorrect for vertically stacked subgraphs** (the primary Issue 0005 scenario).

For `subgraph_edges.mmd` (two TD subgraphs connected by A->C, B->D):
- sg1 dagre bounds: center=(235, 111.5), size=(50x103), y-span=(60, 163)
- sg2 dagre bounds: center=(85, 138), size=(50x156), y-span=(60, 216)

Both subgraphs share **y_top=60** because both `border_top` dummy nodes are ranked at the same level (both are children of the nesting root). The dagre compound layout guarantees non-overlap in the **x-dimension** (via left/right border node ordering) but NOT in the y-dimension for sibling subgraphs at different ranks.

The `to_ascii_rect()` transformation is mathematically correct, but the dagre bounds themselves overlap, so transforming them faithfully produces overlapping draw-space bounds.

## Impact

Tasks 2.2 and the entire "dagre bounds as primary source" strategy is invalid for the vertical overlap case. The fix needs a different approach:

**Correct approach:** Post-hoc collision detection on member-node-derived bounds. After computing all subgraph bounds independently, detect overlapping pairs and adjust borders to not overlap.

## Action Items
- [x] Revert the dagre bounds primary source change
- [ ] Implement post-hoc overlap resolution in `convert_subgraph_bounds()`
- [ ] Keep `to_ascii_rect()` for potential future use (e.g., x-axis bounds from dagre)
