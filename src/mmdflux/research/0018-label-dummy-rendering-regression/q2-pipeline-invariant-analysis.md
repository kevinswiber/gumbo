# Q2: How does the targeted minlen=2 approach break the Sugiyama pipeline invariants?

## Summary

The targeted minlen=2 approach breaks the Sugiyama pipeline because it violates a critical invariant: **the rank assignment phase assumes all edges span exactly 1 rank (minlen=1) when computing layer-by-layer increments**. When labeled edges are given minlen=2, the longest-path algorithm creates larger rank gaps that don't directly correspond to dummy node insertion, leading to misalignment between:

1. **Rank assignment**: produces 3+ layer ranks based on minlen=2
2. **Normalization**: only inserts 1 dummy node (at the midpoint), creating a structure that assumes minlen=1 again
3. **Ordering and positioning**: operates on layers expecting uniform 1-rank spacing but encounters isolated label dummies with no corresponding real nodes at their rank

## Where

- `/Users/kevin/src/mmdflux-label-dummy/src/dagre/mod.rs` (lines 49-59, 94-95)
- `/Users/kevin/src/mmdflux-label-dummy/src/dagre/rank.rs` (lines 22-26, 54)
- `/Users/kevin/src/mmdflux/src/dagre/rank.rs` (lines 22-27, 54)
- `/Users/kevin/src/mmdflux-label-dummy/src/dagre/graph.rs` (line 144)
- `/Users/kevin/src/mmdflux/src/dagre/graph.rs` (line 142)
- `/Users/kevin/src/mmdflux-label-dummy/src/render/layout.rs` (lines 749-799)
- `/Users/kevin/src/mmdflux-label-dummy/plans/0024-label-as-dummy-node/findings/label-position-layer-starts-mismatch.md`

## What

The label-dummy branch implements targeted minlen=2 for labeled edges via `make_space_for_edge_labels()` (mod.rs:49-59). This function:

```rust
fn make_space_for_edge_labels(
    lg: &mut LayoutGraph,
    edge_labels: &HashMap<usize, normalize::EdgeLabelInfo>,
) {
    for &edge_idx in edge_labels.keys() {
        if edge_idx < lg.edge_minlens.len() {
            lg.edge_minlens[edge_idx] = 2;  // Force 2-rank spacing
        }
    }
}
```

**Key structural difference**: The label-dummy branch has `edge_minlens: Vec<i32>` field in `LayoutGraph` (graph.rs:144), while the main branch does not have this field at all.

**Rank computation differences**:
- Label-dummy branch rank.rs (line 26, 54): Uses `minlen` from edges: `ranks[succ] = ranks[succ].max(ranks[node] + minlen);`
- Main branch rank.rs (line 24, 54): Always uses implicit minlen=1: `ranks[succ] = ranks[succ].max(ranks[node] + 1);`

For the `labeled_edges.mmd` example:
```
Start(rank 0) -->|initialize| Setup(rank?)
Setup -->|configure| Config(rank?)
Config -->|yes| Run(rank?)
Config -->|no| Error(rank?)
Error -.->|retry| Setup
```

With minlen=2 applied to labeled edges:
- Start→Setup edge: minlen=2 → Setup gets rank 2 (not rank 1)
- Setup→Config edge: minlen=2 → Config gets rank 4 (not rank 2)
- Config→Run edge: minlen=1 (unlabeled "yes") → Run gets rank 5
- Config→Error edge: minlen=1 (unlabeled "no") → Error gets rank 5
- Error→Setup edge (dotted, "retry"): minlen=1 → constraint back to Setup

This creates rank sequence: 0, 2, 4, 5 — **skipping ranks 1 and 3**.

## How

**Phase 1 (Ranking)**: The longest-path algorithm respects minlen constraints, so edges with minlen=2 push targets 2 ranks lower instead of 1. The algorithm works correctly for this phase — the issue is downstream.

**Phase 2.5 (Normalization)**: The normalize.rs code checks `if to_rank <= from_rank + 1 { continue; }` (normalize.rs:208). For a minlen=2 edge from rank 0 to rank 2, this correctly identifies it as "long" and creates dummy nodes for intermediate ranks (rank 1 in this case).

However, normalize.rs:225-230 computes the label_rank as a midpoint:
```rust
let label_rank = if edge_labels.contains_key(&orig_edge_idx) {
    Some((from_rank + to_rank) / 2)  // (0 + 2) / 2 = 1
} else {
    None
};
```

For a Setup→Config edge (rank 2 to rank 4) with a label, this creates a label dummy at rank 3 (the midpoint). This single dummy is inserted at the exact rank where no real nodes exist — because the minlen=2 constraint skipped that rank in the original assignment!

**Phase 3 (Ordering) and Phase 4 (Positioning)**: Both phases build `layers` by calling `rank::by_rank()`, which groups nodes by their rank values. When a rank contains only dummy nodes (e.g., rank 3 contains only label dummies), these participate in crossing reduction and coordinate assignment. The BK algorithm assumes:
- All edges between layers span exactly 1 rank → TRUE for chain edges after normalization
- If a node is at rank R, there's a corresponding "layer" at position R with real nodes → FALSE for label-only ranks

**Phase 4.5 (Label Position Transform)**: The existing code in layout.rs:749-799 now handles `WaypointWithRank` data (label-dummy branch uses this), computing label positions as the midpoint between source and target node bounds:

```rust
let mid_y = (src_bottom + tgt_top) / 2;
```

This works when the label dummy's rank directly corresponds to node positions. But the rendering layer's `layer_starts` array is built from real nodes only, so `layer_starts[3]` would point to the target node's row, not the gap.

## Why

The design invariant the Sugiyama algorithm expects is: **after ranking, all edges span exactly 1 rank, enabling uniform treatment during normalization, ordering, and positioning.**

The targeted minlen=2 approach **breaks this invariant by design**:
1. Ranking creates 2+ rank gaps for labeled edges
2. Normalization assumes it's still filling in single-rank gaps, creating dummies at midpoints
3. Downstream phases see isolated rank layers with no real nodes
4. The rendering layer's coordinate transformation depends on real nodes existing at label ranks

The approach attempts to use minlen=2 to "pre-allocate space" for label dummies during ranking. But the Sugiyama framework's crossing reduction and positioning algorithms don't expect empty layers (ranks with only dummies). They compute alignments, barycenters, and vertical spacing based on the assumption that every rank has real nodes.

## Key Takeaways

- The label-dummy branch correctly implements minlen tracking in the ranking phase (rank.rs:54 uses it properly)
- Normalization correctly detects long edges and creates dummy chains (normalize.rs:208 condition works)
- The pipeline **breaks at the intersection of ranking and normalization**: minlen=2 creates 2-rank gaps, but normalization only inserts 1 dummy node per gap, leaving empty ranks
- Label position computation in render/layout.rs (lines 765-784) is correct for the gap-midpoint approach but requires that all intermediate ranks between source and target have at least some node (dummy or real)
- The rendering layer's layer_starts array construction assumes rank indices map directly to real node positions, which fails when labels occupy ranks with no real nodes
- Note: "yes" and "no" edge labels on Config→Run and Config→Error edges DO have labels, which means they should also get minlen=2 — need to verify whether the implementation correctly identifies all labeled edges

## Open Questions

- Why wasn't the edge_minlens field in graph.rs ever used in the ranking phase on the main branch? (It's initialized in from_digraph but never modified or consulted)
- Would the approach work if normalization inserted dummy nodes at **every** intermediate rank (including the label rank), so that label_rank wasn't the only node at that rank?
- Could the BK algorithm be modified to skip or handle "label-only" ranks during alignment?
- Is the intended design to make minlen=2 apply to ALL edges, not just labeled ones, so the entire graph respects uniform 2-rank spacing?
