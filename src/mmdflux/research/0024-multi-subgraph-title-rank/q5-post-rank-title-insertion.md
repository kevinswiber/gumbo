# Q5: Post-Rank Title Node Insertion

## Summary

Post-rank title node insertion is **feasible, robust, and simpler than all previously investigated approaches**. By removing title nodes from the nesting chain and inserting them after ranking at `border_top_rank - 1`, the ranking of all other nodes (border_top, children, border_bottom) remains identical to the working no-title case. The title is an extra node injected at a known-correct position. No renormalization needed, no cascading rank updates, and all downstream phases (normalize, border segments, ordering, position) work unchanged.

## Feasibility

### Pipeline Position

The insertion goes between `nesting::cleanup()` and `nesting::assign_rank_minmax()` in `mod.rs:115-118`:

```
rank::run()                     // Phase 2: assign ranks
rank::normalize()               // Shift to 0-based
nesting::cleanup()              // Remove nesting edges, clear root
>>> insert_title_nodes() <<<    // NEW: create title nodes at correct ranks
nesting::assign_rank_minmax()   // Extract min/max rank per compound
```

### Data Structure Requirements

`add_nesting_node()` in `graph.rs` handles all vector extensions (node_ids, ranks, dimensions, parents, positions, etc.). Post-rank insertion requires:
1. Call `add_nesting_node()` to create the title node
2. Set `ranks[title_idx] = border_top_rank - 1`
3. Set `parents[title_idx] = Some(compound_idx)`
4. Insert into `border_title` map

No edges needed — title nodes are structural-only for rank occupancy and ordering.

### Renormalization Not Needed

After `rank::normalize()`, the minimum rank is 0 (the root). Root is at rank 0, all border_tops are at rank ≥ 1 (due to `root → border_top` nesting edges with minlen=1). So title = `border_top_rank - 1` ≥ 0. No negative ranks can occur.

After `nesting::cleanup()`, root remains at rank 0 with no edges (effectively dead). Title also at rank 0 in the base case. Root and title coexist at rank 0 harmlessly — root is excluded from output (beyond `original_node_count`) and has zero dimensions.

## Robustness

### Traced Example: Two Subgraphs with Cross-Edge

**Graph:** `sg1{A→B}`, `sg2{C→D}`, `A→C`, both titled.

**Without titles (current working behavior):**
```
Rank 0: root (dead after cleanup)
Rank 1: bt_sg1, bt_sg2
Rank 2: A, B, D
Rank 3: C, bb_sg1
Rank 4: bb_sg2

min_rank: sg1=1, sg2=1  |  max_rank: sg1=3, sg2=4
Border segments: sg1 at ranks 1-3, sg2 at ranks 1-4
```
This works correctly — overlapping border ranges are handled by ordering.

**With post-rank title insertion (proposed):**
```
Rank 0: root (dead), tt_sg1, tt_sg2    ← NEW title row
Rank 1: bt_sg1, bt_sg2
Rank 2: A, B, D
Rank 3: C, bb_sg1
Rank 4: bb_sg2

min_rank: sg1=0, sg2=0  |  max_rank: sg1=3, sg2=4
Border segments: sg1 at ranks 0-3, sg2 at ranks 0-4
```
**Identical to no-title case plus one extra rank at the top.** The ranking of border_top, children, and border_bottom is completely unchanged.

### Downstream Phase Analysis

**normalize::run() (long edge splitting):** Title nodes have no edges, so they create no long edges. Unaffected.

**border::add_segments():** Uses `min_rank` and `max_rank` from `assign_rank_minmax()`. With titles, min_rank includes the title rank (one rank lower). Border left/right nodes span one extra rank. This is correct — the title rank needs border segments for containment.

**order::run() + apply_compound_constraints():** Title nodes have `parents[title_idx] = Some(compound_idx)`, so they're grouped with their compound's children at each rank. At the title rank (e.g., rank 0), the compound's children are: title, border_left, border_right. Phase 3's ordering code already handles this pattern (single non-border child at a rank).

**position::run() + bk.rs:** Operate on layers from `by_rank()`. Title nodes appear in a layer and get positioned. They have zero dimensions, so they don't consume visual space but establish the rank's existence in the coordinate system.

### Edge Collision Resolution

The original problem: an edge from External → InternalNode passes through the subgraph border, and its waypoint overlaps the title text at `bounds.y`.

With post-rank insertion:
- Title is at rank `R` (e.g., 0)
- Border_top is at rank `R+1` (e.g., 1)
- Edge waypoints land at border_top's rank (R+1), which is BELOW the title
- Title text at rank R is clear of edge waypoints

### Nested Subgraphs

Inner compound's border_top ranks at ≥ 2 (root → outer_bt → inner_bt via nesting chain). Inner title at ≥ 1. Outer title at 0. Each title correctly sits one rank above its own border_top.

### Edge Cases

- **Empty subgraph (title only, no children):** border_top still exists and has a rank. Title goes at `border_top_rank - 1`. Border segments span title rank to border_bottom rank. Works correctly.
- **Multiple subgraphs at same level:** Both titles at same rank (e.g., 0). Ordering groups each compound's children contiguously. Same pattern as overlapping border_tops, which already works.
- **Root at same rank as title:** Root is dead after cleanup (no edges). It floats in the layer with zero dimensions. Harmless.

## Code Change Impact

### What Changes vs Phase 1-3

| Phase | Commit | Change Required |
|-------|--------|----------------|
| Phase 1 (storage fields) | `e1e1a36` | **KEEP** — `border_title`, `compound_titles` fields still needed |
| Phase 2 (nesting insertion) | `eb14a63` | **MODIFY** — remove title from nesting chain, add post-rank insertion |
| Phase 3 (ordering fix) | `21805ad` | **KEEP** — single-child rank handling still needed for title ranks |

### Specific Code Changes

**nesting.rs — Remove from `run()`:**
- Lines 36-42: Remove title node creation during compound loop (title is no longer created here)
- Lines 84-89: Remove `root → title → border_top` nesting edges; always use `root → border_top`

**nesting.rs — Add new function:**
```rust
/// Insert title dummy nodes at correct ranks after ranking is complete.
///
/// For each titled compound, creates a title node at `border_top_rank - 1`.
/// Must be called after rank::run() + rank::normalize() + nesting::cleanup()
/// and before assign_rank_minmax().
pub fn insert_title_nodes(lg: &mut LayoutGraph) {
    let compounds: Vec<usize> = lg.compound_titles.iter().copied().collect();
    for compound_idx in compounds {
        let compound_id = lg.node_ids[compound_idx].0.clone();
        let bt_idx = lg.border_top[&compound_idx];
        let title_rank = lg.ranks[bt_idx] - 1;

        let title_id = NodeId(format!("_tt_{}", compound_id));
        let title_idx = lg.add_nesting_node(title_id);
        lg.ranks[title_idx] = title_rank;
        lg.parents[title_idx] = Some(compound_idx);
        lg.border_title.insert(compound_idx, title_idx);
    }
}
```

**mod.rs — Update pipeline (line 115-118):**
```rust
if has_compound {
    nesting::cleanup(&mut lg);
    nesting::insert_title_nodes(&mut lg);  // NEW
    nesting::assign_rank_minmax(&mut lg);
}
```

### Line Count

- Remove: ~15 lines (title creation in `run()`, title nesting edges)
- Add: ~20 lines (new `insert_title_nodes()` function)
- Modify: 1 line (pipeline call)
- **Net: +5 lines**, significantly simpler than alternatives

### Test Updates

- `test_nesting_run_adds_title_node_for_titled_compound`: Update — title is no longer created in `run()`
- `test_assign_rank_minmax_uses_title_rank_for_min`: Update — call `insert_title_nodes()` before `assign_rank_minmax()`
- Add new test: `test_insert_title_nodes_sets_correct_rank`
- Add new test: `test_insert_title_nodes_multi_subgraph_no_collision`

## Tradeoffs

### Advantages
- **No rank collision**: Title never participates in ranking → no multi-subgraph collision by construction
- **Deterministic placement**: Title rank = `border_top_rank - 1`, always correct
- **Minimal change**: ~5 net lines changed, same Phase 1/3 infrastructure
- **No cascading updates**: No need to shift other nodes' ranks
- **No renormalization**: Title rank is always ≥ 0
- **Identical non-title behavior**: All other nodes rank exactly as they would without titles

### Disadvantages
- **Title doesn't influence ranking**: If we ever wanted the title to affect how edges are ranked (e.g., attract edges to specific waypoints), we'd need a different approach. Currently this is not needed.
- **Post-ranking node addition**: Nodes are added after ranking, which is unusual but well-supported by `add_nesting_node()`. Border segments already do this.
- **Title has no edges**: No structural edges connect the title to other nodes. It relies purely on rank assignment and ordering constraints. This is fine because border_left/right (also edgeless within ranks) work the same way.

### What We Lose
Nothing meaningful. The title node's only purpose is to occupy a rank and be positioned by the ordering/coordinate phases. It doesn't need to participate in ranking.

### What We Gain
A correct, simple solution that eliminates the entire class of multi-subgraph title rank collisions. The approach is architecturally clean: ranking determines node positions, then structural markers (titles) are placed at derived positions.

## Potential Problems

### 1. Root coexistence at rank 0
**Severity:** Low
**Analysis:** After cleanup, root has no edges and zero dimensions. It occupies rank 0 alongside title nodes but doesn't affect ordering or positioning. It's excluded from output.
**Mitigation:** None needed.

### 2. border_top at rank 0 after normalization
**Severity:** None — cannot happen
**Analysis:** All border_tops are ≥ 1 hop from root via nesting edges (minlen=1). After normalize (min rank → 0), root is at 0, border_tops at ≥ 1. Title at ≥ 0.

### 3. Title at same rank as nodes from other subgraphs
**Severity:** Low
**Analysis:** This already happens with border_top nodes. The ordering phase handles multiple compounds' children at the same rank via `apply_compound_constraints()`. Title nodes get the same treatment.
**Mitigation:** Phase 3 ordering code (already committed) handles this.

### 4. BK algorithm placing title node incorrectly
**Severity:** Low
**Analysis:** BK operates on layer order. Title nodes have zero dimensions and appear in a layer with border_left and border_right from the same compound. BK assigns them x-coordinates based on neighbors, which should place them within the subgraph's horizontal span.
**Mitigation:** If title x-position needs adjustment, the render layer can center it (existing title centering code handles this).

### 5. Backward edges crossing the title rank
**Severity:** Low
**Analysis:** Backward edges are routed separately via `generate_backward_waypoints()` in the render layer. They don't use dagre waypoints. The title rank adds one more rank to the subgraph span, but backward edge routing already handles variable span sizes.
**Mitigation:** None needed.

### 6. Test suite impact
**Severity:** Low
**Analysis:** Only 2 existing tests directly test title node creation in `nesting::run()`. These need updating. All other tests (including 70 integration tests) don't call `set_has_title()` and are unaffected.
**Mitigation:** Update the 2 tests, add 2-3 new tests.

## Recommendation

**Go — high confidence (90%+).**

This approach is architecturally cleaner, simpler to implement, and more robust than all previously investigated alternatives:
- Q1 (render-only): Not viable — waypoints and bounds are decoupled
- Q2 (post-rank reassignment): Fragile — cascading updates, treats symptom
- Q3 (alternative topology): Doesn't work — same collision under longest-path
- Q5 (post-rank insertion): Clean — title never has a wrong rank, no cascading

**Conditions:**
- Verify the multi-subgraph example produces correct rendered output
- Verify nested subgraphs (subgraph inside subgraph) work correctly
- Verify all 70 existing integration tests still pass
