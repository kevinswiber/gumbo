# Finding: Title Rank Breaks Multi-Subgraph Layouts

**Type:** plan-error
**Task:** 4.1
**Date:** 2026-01-29

## Details
When `set_has_title()` is called for multiple subgraphs at different vertical positions, all title dummy nodes get assigned the same dagre rank (rank 1, one hop from root). This causes:

1. sg2's title rank lands in sg1's rank range (both at rank 1)
2. `assign_rank_minmax` sets sg2's `min_rank` to 1 (its title rank)
3. `add_segments` creates sg2's border_left/right nodes starting at rank 1
4. Ordering interleaves sg1 and sg2 border nodes at shared ranks
5. Rendered output is garbled: nodes overlap, borders are misplaced

The nesting chain `root → title → border_top → children → border_bottom` uses longest-path ranking, which only counts hops from root. It doesn't account for inter-subgraph edge dependencies (A→C, B→D). The title nodes rank at the minimum possible position rather than above their subgraph's actual content.

### Example
`subgraph_edges.mmd`: two subgraphs (Input, Output) with cross-subgraph edges.

Without title ranks:
- bt_sg1=1, A,B=2, bb_sg1=3
- bt_sg2=1, C,D=3, bb_sg2=4
(sg2's border_top is at rank 1 but its content is pushed to rank 3 by real edges)

With title ranks:
- tt_sg1=1, bt_sg1=2, A,B=3, bb_sg1=4
- tt_sg2=1, bt_sg2=2, C,D=4, bb_sg2=5
(tt_sg2 at rank 1 is inside sg1's rank range, causing garbled ordering)

## Impact
The structural title-rank approach (Phases 1-3 nesting changes) cannot be activated via Phase 4's `set_has_title()` without breaking multi-subgraph layouts. The approach works for single subgraphs but is fundamentally flawed for the multi-subgraph case.

### Alternative approaches
1. **Render-only fix**: Don't use dagre title ranks. Instead, add `title_extra` padding in `convert_subgraph_bounds()` and ensure edge rendering respects the extended bounds.
2. **Conditional activation**: Only add title ranks for subgraphs that have incoming cross-subgraph edges (the collision scenario), not all titled subgraphs.
3. **Different nesting topology**: Instead of `root → title → bt`, insert title between `bt → title → children` so the title node's rank is constrained relative to its own subgraph's content rather than root.

## Action Items
- [ ] Decide on alternative approach before proceeding with Phase 4
- [ ] The Phase 1-3 structural code is correct and tested but currently inert (no `set_has_title` calls)
