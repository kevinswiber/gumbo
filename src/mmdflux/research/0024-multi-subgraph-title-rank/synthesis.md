# Research Synthesis: Multi-Subgraph Title Rank Collision

## Summary

All four investigations converge on the same conclusion: the current structural approach (title dummy nodes in the nesting chain) is architecturally superior to render-only fixes, but the specific nesting topology used (`root → title → border_top → children`) causes all title nodes to rank at 1 regardless of subgraph position. Neither an alternative nesting topology (Q3) nor post-rank reassignment (Q2) solves this, because the fundamental issue is that longest-path ranking determines title rank by nesting chain distance from root, not by actual content position. A render-only approach (Q1) is not viable because waypoints and subgraph bounds are decoupled systems. The reference implementations (dagre-js/mermaid.js, Q4) handle titles purely at render time and suffer persistent collision bugs as a result — validating that a layout-level solution is the right direction.

**Q5 (post-rank title node insertion)** resolves the impasse from Q1-Q4. Instead of inserting title nodes into the nesting chain before ranking (which causes the collision) or reassigning their ranks afterward (fragile cascading), the approach removes title nodes from the nesting chain entirely and creates them after ranking at `border_top_rank - 1`. This means the ranking of all other nodes is identical to the working no-title case — the title is simply an extra node at a known-correct position. No renormalization, no cascading updates, no fragility.

## Key Findings

### Finding 1: No Nesting Topology Can Solve Title Rank Collision

Both the current topology (`root → title → border_top → children`) and the alternative (`root → border_top → title → children`) produce title nodes at rank 1 for all subgraphs. The root cause is that longest-path ranking counts hops from the DAG root via nesting edges, and all title nodes are equidistant from root regardless of their subgraph's vertical position in the real graph. This is a fundamental limitation of using nesting chain distance for title positioning. (Q2, Q3)

### Finding 2: Render-Only Approach Is Not Viable

Waypoints are computed from dagre's rank system and transformed to draw coordinates via `layer_starts`, which derives from node positions — not subgraph bounds. Adding padding to `convert_subgraph_bounds()` only affects the visual border extent, not waypoint positions. The title is embedded directly in the top border row (`bounds.y`), with no separate structural space. A collision avoidance system for titles would require new waypoint nudging logic that doesn't exist and would be fragile. (Q1)

### Finding 3: Reference Implementations Validate Layout-Level Approach

Dagre-js has zero concept of compound node titles — border nodes are purely structural with zero dimensions. Mermaid.js handles titles entirely at render time with `subGraphTitleTopMargin` offset, but this causes persistent edge-title collision bugs (5+ open issues spanning 4+ years). A recent fix (PR #7268) adjusts edge intersection calculations post-hoc, but it's reactive and fragile. An unmerged dagre PR (#242) attempted asymmetric cluster padding at the layout level but was never merged. Our title-node approach is architecturally superior because the layout algorithm naturally routes edges around the title area. (Q4)

### Finding 4: Post-Rank Reassignment Is Safe but Fragile

Normalize, order, and position phases use ranks only for layer partitioning — they never re-validate rank constraints or edge monotonicity. However, reassigning existing title nodes requires cascading updates to min_rank, border_top rank, and border segments. Q2 correctly identified this as "treating the symptom." (Q2)

### Finding 5: Post-Rank Insertion Solves the Problem Cleanly

By removing title nodes from the nesting chain entirely and inserting them after ranking at `border_top_rank - 1`, the ranking of all other nodes remains identical to the working no-title case. Traced through the two-subgraph example: the result is the no-title layout plus one extra rank at the top with both title nodes. Ordering handles this identically to how it handles overlapping border_top nodes. No renormalization needed (title rank ≥ 0 guaranteed). Net code change: ~5 lines. (Q5)

## Recommendations

1. **Use post-rank title node insertion** — Remove title nodes from the nesting chain in `nesting::run()`. After `rank::normalize()` and `nesting::cleanup()`, insert title nodes at `border_top_rank - 1` via a new `insert_title_nodes()` function. This avoids the rank collision by construction.

2. **Keep Phase 1 and Phase 3 infrastructure** — Storage fields (`border_title`, `compound_titles`) and ordering fixes are still needed. Phase 2's nesting insertion code needs modification: remove title creation and title nesting edges from `run()`, add `insert_title_nodes()`.

3. **Revise Phase 4 task files** — Phase 4 should wire `set_has_title()` in the render layer to activate compound_titles. The dagre-side change (moving title insertion to post-rank) replaces Phase 2's approach.

4. **Do not pursue render-only fixes** — Mermaid.js's experience shows this leads to an ongoing whack-a-mole of collision bugs. The layout-level approach is the right architecture.

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | `src/dagre/nesting.rs` (title node insertion), `src/dagre/rank.rs` (Kahn's ranking), `src/dagre/mod.rs` (pipeline), `src/render/layout.rs` (waypoints/bounds) |
| **What** | All title nodes rank at 1 regardless of subgraph position; waypoints and bounds are decoupled; dagre-js has no title concept; mermaid handles titles at render time with persistent bugs |
| **How** | Post-rank insertion: remove title from nesting chain, create title nodes after ranking at `border_top_rank - 1`. Deterministic, no cascading. |
| **Why** | Longest-path ranking uses nesting chain distance from root, which is the same for all titles. No topology change fixes this. Render-only approaches are fragile. Layout-level title space is architecturally superior. |

## Open Questions

- Should the post-rank reassignment happen before or after `nesting::cleanup()`? Before cleanup, nesting edges are still present; after cleanup, they're excluded but title/border metadata is available.
- How should the reassignment handle nested subgraphs (subgraph inside subgraph)? The title of the inner subgraph should rank relative to the inner subgraph's content, not the outer one's.
- Should `assign_rank_minmax` be updated to use the reassigned title rank, or should a separate step update min_rank?
- Does the post-rank reassignment need a re-normalization pass to ensure ranks start at 0?

## Next Steps

- [ ] Modify `nesting::run()` to remove title node creation and title nesting edges
- [ ] Add `nesting::insert_title_nodes()` function
- [ ] Update pipeline in `mod.rs` to call `insert_title_nodes()` between cleanup and assign_rank_minmax
- [ ] Update nesting tests for new insertion point
- [ ] Wire `set_has_title()` in the render layer (Phase 4)
- [ ] Test with multi-subgraph example from the finding (`subgraph_edges.mmd`)
- [ ] Update Phase 5 integration tests to cover multi-subgraph title layouts

## Source Files

| File | Question |
|------|----------|
| `q1-render-only-approach.md` | Q1: Render-only title space approach |
| `q2-post-rank-reassignment.md` | Q2: Post-rank title rank reassignment |
| `q3-alternative-nesting-topology.md` | Q3: Alternative nesting topology |
| `q4-dagre-js-compound-titles.md` | Q4: How does dagre-js handle compound titles? |
| `q5-post-rank-title-insertion.md` | Q5: Post-rank title node insertion (recommended) |
