# Q3: Alternative Nesting Topology (bt → title → children)

## Summary

The alternative nesting topology `root → border_top → title → children → border_bottom` **would not solve the multi-subgraph rank collision**. While it changes where the title node is constrained from (by border_top instead of root), the fundamental issue persists: border_top itself is unconstrained by real edges and ranks at the minimum possible value (rank 0, one hop from root). Both title nodes still end up at rank 1, causing the same collision. The problem is structural decoupling between nesting topology distance and actual subgraph content position.

## Where

Sources consulted:
- `src/dagre/nesting.rs` (lines 18-96, 98-115): Current nesting structure creation, title node insertion, and rank assignment
- `src/dagre/rank.rs` (lines 11-74): Longest-path ranking algorithm via Kahn's topological sort
- `src/dagre/border.rs` (lines 17-65): Border segment creation using min_rank/max_rank
- `src/dagre/order.rs` (lines 307-435): `apply_compound_constraints` ordering enforcement
- `plans/0030-subgraph-title-rank/findings/multi-subgraph-rank-collision.md`: Problem description with concrete example
- `src/dagre/nesting.rs` (lines 265-285): Test case showing current title rank ordering

## What

### Current Topology (Lines 85-94 in nesting.rs)

The current code implements `root → title → border_top`:
```rust
if let Some(&title_idx) = lg.border_title.get(&compound_idx) {
    let e = lg.add_nesting_edge(root_idx, title_idx, nesting_weight);  // root→title
    lg.nesting_edges.insert(e);
    let e = lg.add_nesting_edge(title_idx, top_idx, nesting_weight);    // title→border_top
    lg.nesting_edges.insert(e);
}
```

With high-weight nesting edges, longest-path ranking assigns all title nodes to rank 1 (one hop from root), regardless of where that subgraph's content actually ranks.

### Proposed Alternative Topology

Change to `root → border_top → title → children`:
```rust
// Proposed (pseudocode):
let e = lg.add_nesting_edge(root_idx, top_idx, nesting_weight);     // root→border_top
let e = lg.add_nesting_edge(top_idx, title_idx, nesting_weight);    // border_top→title
```

This would make title rank depend on border_top's rank. But border_top also has no dependency on real content — it's still just one hop from root.

### Tracing Rank Assignment: Two-Subgraph Example

**Graph:** `sg1{A→B} with title, sg2{C→D} with title, edge A→C`

**Nesting edges (alternative topology):**
```
root → border_top_sg1, border_top_sg1 → title_sg1, title_sg1 → A, B → border_bottom_sg1
root → border_top_sg2, border_top_sg2 → title_sg2, title_sg2 → C, D → border_bottom_sg2
A → C (real cross-subgraph edge)
```

**Kahn's longest-path ranking:**
- root: 0
- border_top_sg1: 0 (min path from root)
- border_top_sg2: 0 (min path from root)
- title_sg1: 1 (0 + 1 from border_top_sg1)
- **title_sg2: 1** (0 + 1 from border_top_sg2) — **STILL COLLIDES**
- A: 2, C: 2, B: 3, D: 3
- border_bottom_sg1: 4, border_bottom_sg2: 4

Both title nodes at rank 1 — collision persists.

### Comparison: Current vs. Alternative

| Aspect | Current (root→title→bt) | Alternative (root→bt→title) |
|--------|--------------------------|------------------------------|
| Title rank determination | min hops from root | min hops from border_top |
| All titles rank at | 1 | 1 |
| Why titles collide | Both 1 hop from root | Both border_tops at rank 0 |
| Subgraph min_rank | Title rank (always 1) | Title rank (always 1) |

### Impact on assign_rank_minmax and add_segments

**assign_rank_minmax**: Still sets `min_rank` to `title_idx` rank. If both titles at rank 1, both subgraphs' `min_rank = 1`, causing overlapping spans.

**add_segments**: Border left/right nodes placed at all ranks from min_rank to max_rank. If min_rank is 1 for both subgraphs, both borders occupy rank 1, causing ordering collisions.

### Impact on Ordering

The ordering constraints in `apply_compound_constraints` (lines 307-435) ensure border nodes are at edges of children at each rank. With both subgraphs having borders at rank 1, the algorithm must interleave sg1 and sg2 border nodes at shared ranks — still a collision.

## How

### Why the Alternative Doesn't Help

1. **border_top is also unconstrained**: The alternative assumes border_top will rank near the subgraph's content, but it doesn't. It ranks at the minimum possible value (after root), just like title in the current approach.

2. **Longest-path doesn't backfill**: When C is ranked at 2 via A→C, the algorithm doesn't retroactively increase border_top_sg2's rank. Ranking is a forward pass; once a node's rank is set, it doesn't change.

3. **No title-to-all-children edges**: The nesting chain only adds edges through one child. Other children are ranked via real edges, not relative to the title.

### Why Longest-Path Breaks for Titles

Longest-path ranking is designed for **static hierarchy**: find the maximum distance from a source to each node. It struggles with **mixed constraints**:
- Nesting edges create an artificial hierarchy (root → border → children)
- Real edges create a real hierarchy (A → C based on graph semantics)
- When these hierarchies diverge, longest-path ranks by nesting depth first, creating misalignment

A proper fix would require either:
- **Explicit content-relative constraints**: Add edges from title to *all* children, forcing title to rank above all of them
- **Post-rank adjustment**: After ranking, move title ranks based on actual content positions
- **Render-only approach**: Don't use title ranks at all; add title space when rendering

## Why

The fundamental issue with both topologies is **structural decoupling**: the title rank is determined solely by nesting chain topology distance (hops from root or border_top), not by the actual longest path through real graph edges to the subgraph's content. The alternative changes **who constrains the title** (border_top instead of root) but doesn't change the underlying mechanism.

## Key Takeaways

- The alternative topology `root → border_top → title → children` does **not prevent the rank collision**
- Both title nodes still rank at 1 because border_top also ranks at minimum (0)
- The issue is structural decoupling: title rank is determined by nesting topology distance, not actual content position
- `assign_rank_minmax` and `add_segments` behave identically under both topologies
- Ordering constraints still face interleaving conflicts

## Open Questions

- Would explicitly adding nesting edges from title to **all** children force titles to rank above all content? (Different topology: `root → border_top → {title→all_children} → border_bottom`)
- What if border_top is constrained by an edge that depends on the subgraph's actual longest path (post-rank analysis)?
- Could a hybrid approach work: render-only title space for most cases, structural title ranks only for subgraphs with external incoming edges?
