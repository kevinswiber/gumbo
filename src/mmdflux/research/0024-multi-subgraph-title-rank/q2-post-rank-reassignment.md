# Q2: Post-Rank Title Rank Reassignment

## Summary

Post-rank reassignment is theoretically safe for downstream phases (normalize, order, position) since they use ranks only for layer partitioning without validating monotonicity. However, it does not solve the core multi-subgraph collision problem: title nodes get rank 1 because longest-path ranking only counts hops from root via the nesting chain, not inter-subgraph edges that determine actual content ranks. Reassigning ranks post-hoc would be treating the symptom rather than the cause.

## Where

**Sources consulted:**
- `src/dagre/rank.rs` (lines 11-74): `run()` implements Kahn's topological sort with longest-path ranking; `normalize()` (lines 76-83) shifts ranks to start at 0
- `src/dagre/nesting.rs` (lines 18-96): `run()` creates title→border_top→children→border_bottom nesting chain with high-weight edges; `assign_rank_minmax()` (lines 98-115) extracts min/max ranks from border nodes
- `src/dagre/mod.rs` (lines 110-118): Pipeline stage ordering: rank → normalize → nesting cleanup → assign_rank_minmax → normalize (edges) → border segments → order → position
- `src/dagre/order.rs` (lines 111-176): `run()` uses `rank::by_rank()` to get layers, then sweeps for barycenter ordering; downstream phases never re-validate rank constraints
- `src/dagre/position.rs` (lines 12-81): `assign_vertical()` and `assign_horizontal()` iterate through layers from `rank::by_rank()`, using ranks only to determine layer order
- `src/dagre/bk.rs` (lines 1-150): Brandes-Köpf algorithm processes layers sequentially but never checks rank invariants
- `src/dagre/border.rs` (lines 17-65): `add_segments()` uses `lg.min_rank` and `lg.max_rank` directly (set by `assign_rank_minmax`) to create left/right border nodes

## What

### Rank Invariants and How They're Maintained

1. **Kahn's Algorithm Creates Valid DAG Ranking** (rank.rs:run, lines 30-74)
   - Processes nodes in topological order (in-degree = 0 first)
   - For each edge (from → to) with minlen, sets `ranks[to] = max(ranks[to], ranks[from] + minlen)`
   - Result: All edges satisfy the minlen constraint; ranks form a valid topological ordering
   - No node has an outgoing edge to a lower rank

2. **Nesting Chain Creates High-Weight Constraints** (nesting.rs:run, lines 58-95)
   - For titled subgraphs: `root → title → border_top → children → border_bottom`
   - Each edge has weight `nesting_weight = (node_count * 2) as f64`
   - During ranking, these high-weight edges **dominate** all other edges
   - Result: Title ranks at minimum possible distance from root (rank 1), not relative to content rank
   - The actual content rank is determined by **real user edges** (e.g., A→B where A,B are children)

3. **Content Rank Problem**
   - Example: `sg1` with children A,B and titled subgraph `sg2` with children C,D
   - Nesting chain creates: `root → tt_sg1 → bt_sg1 → A, B → bb_sg1` and `root → tt_sg2 → bt_sg2 → C, D → bb_sg2`
   - With cross-edges (A→C, B→D), Kahn's algorithm ranks:
     - `tt_sg1=1, bt_sg1=2, A,B=3, bb_sg1=4` (via nesting edge weights)
     - `tt_sg2=1, bt_sg2=2, C,D=4` (via nesting edges forcing bt_sg2=2, then A→C forces C≥3+1=4)
   - But tt_sg2 at rank 1 **collides** with tt_sg1 at rank 1

### Why Ranks Can't Be Safely Reassigned Pre-Normalization

1. **Nesting edges are already excluded** (nesting.rs:cleanup, lines 122-134)
   - After `nesting::cleanup()`, nesting edges are marked with weight 0.0 and added to `excluded_edges`
   - When `assign_rank_minmax()` is called, we can see which title nodes exist and their current ranks
   - BUT: We cannot easily infer **which nodes are the content** without re-traversing the entire graph

2. **Downstream Phases Don't Assume Monotonicity** (order.rs, position.rs, bk.rs)
   - `order::run()` calls `rank::by_rank()` to partition nodes into layers
   - Ordering only uses rank as a layer index, never validates that edges respect ranks
   - `position::run()` iterates layers in rank order but doesn't re-validate edges
   - **Verdict**: If we reassigned title ranks after nesting cleanup but before normalization, these phases would still work

3. **But Normalize Depends on Rank Positions** (normalize.rs:189-230)
   - Long edges are broken into dummy chains based on rank spans
   - Title nodes shouldn't be sources/targets of regular edges (they're dummy nesting nodes), so this shouldn't matter for user edges

### The Border Segment Dependency Issue

In `border::add_segments()`:
```rust
for rank in min_r..=max_r {
    let left_idx = lg.add_nesting_node(left_id);
    lg.ranks[left_idx] = rank;
    ...
}
```

The loop creates border nodes at every rank from `min_rank` to `max_rank`. These ranks come from:
- `min_rank[compound] = title_rank` (if has title) or `border_top_rank` (no title)
- `max_rank[compound] = border_bottom_rank`

**If we reassign title ranks post-hoc**:
- We must update `min_rank` to the new title rank
- Border segments will then create left/right nodes at the new range
- This cascades through the rest of the pipeline

## How

**Conceptual post-rank reassignment algorithm:**

```
After rank::run() + rank::normalize() + nesting::cleanup():

for each compound_idx in compound_titles:
    title_idx = border_title[compound_idx]

    # Find content minimum rank (skip title, borders, root)
    children = [i for i where parents[i] == compound_idx
                and i not in {title, border_top, border_bottom}]
    if children is empty:
        skip

    min_content_rank = min(ranks[c] for c in children)

    # Reassign title rank
    if ranks[title_idx] >= min_content_rank:
        new_title_rank = min_content_rank - 1
        ranks[title_idx] = new_title_rank
        min_rank[compound_idx] = new_title_rank

After reassignment:
    rank::normalize()  # Re-normalize to ensure ranks ≥ 0
```

**The algorithm fails at the last step**: We can't move children's ranks because they're already fixed by the real edges in Kahn's algorithm. The nesting edges were excluded from ranking, so moving the title doesn't automatically move the children.

**This reveals the fundamental issue**: The nesting chain (title → border_top → children) has its edges **removed** during cleanup, so there's no constraint force keeping them in order. Reassigning the title rank breaks the semantic "title is above content" expectation.

## Why

### Why It Breaks for Multi-Subgraph

With multiple subgraphs at different vertical positions:
- Each title gets a separate nesting chain starting from root
- Longest-path ranking only considers distance from root via nesting edges
- All titles end up at rank 1 (minimum possible) because they're all one hop from root
- Real user edges (A→C) then push content ranks higher, but titles stay at rank 1
- Result: Title ranks don't track content ranks; they collide at the top

### Why Post-Rank Reassignment Doesn't Solve It

1. **Treats the symptom, not the cause**: The cause is the nesting topology (all titles route through root). The symptom is title ranks not matching content ranks.
2. **Requires fragile cascading updates**: Changing title ranks requires updating min_rank, which requires updating border node ranks, which affects ordering and positioning.
3. **Loses the nesting force**: Once nesting edges are cleaned up, there's no mechanism keeping title→border_top→children in order. Reassignment only works once.
4. **One-shot fix**: If anything else tries to re-rank, title ranks could drift again.

### Tradeoffs

**Pros:**
- Locally confined to one function
- Doesn't require graph topology changes
- Phase 1-3 infrastructure doesn't change

**Cons:**
- Doesn't address root cause (nesting topology)
- Requires computing "content minimum rank" without explicit metadata
- Cascades through border_segment creation and possibly position
- Fragile: if nesting edges are ever re-introduced or ordering changes, ranks could drift

## Key Takeaways

- **Rank invariants after Kahn's**: All edges satisfy minlen constraints; ranks form a valid topological ordering. This is maintained but not re-validated downstream.
- **Nesting topology is the problem**: The `root → title → border_top → children` chain uses edges that are removed before reassignment, so there's no structural force keeping them in order post-rank.
- **Reassignment is technically feasible**: Normalize, order, and position phases don't validate rank constraints; they only use ranks for layer partitioning.
- **But reassignment cascades**: Changing title ranks requires updating min_rank, border node ranks, and possibly re-normalization. It's fragile and error-prone.
- **Not the right fix**: Safe yes, viable no. The real issue is nesting topology (Q3) or render-only approach (Q1).

## Open Questions

- Q3 (alternative nesting topology): Would placing title **between** border_top and children allow title ranks to track content better?
- How much does `assign_rank_minmax` actually depend on border_title existing? Could we compute content min-rank differently?
- Should the nesting chain maintain high-weight edges post-cleanup (as constraints without being effective edges) to preserve order invariants?
