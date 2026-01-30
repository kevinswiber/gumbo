# Q3: How does the title rank affect coordinate assignment (BK)?

## Summary

The title dummy node's zero dimensions cause no issues in Brandes-Köpf — BK optimizes perpendicular (horizontal) coordinates, while rank spacing uses `rank_sep` plus maximum node height per rank. A zero-height title node at rank N creates exactly `rank_sep` (50.0 default) spacing from rank N-1. To guarantee adequate title space, the title node should have explicit height dimensions rather than relying on implicit spacing from `rank_sep` alone.

## Where

- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/position.rs` (lines 41-82): `assign_vertical()` computes y-coordinates from rank order
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/position.rs` (lines 76-80): rank spacing = `max_height + rank_sep`
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/bk.rs` (lines 836-844): `compute_sep()` uses node dimensions for horizontal separation
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/bk.rs` (lines 912-920): `separation_for()` computes per-node separation
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/bk.rs` (lines 286-298): `get_width()` extracts perpendicular dimension
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/types.rs` (lines 82-114): `LayoutConfig` with `rank_sep` default 50.0

## What

### Y-coordinate assignment (rank-based, NOT BK)

Y-coordinates are assigned strictly by rank position:
```rust
let mut y = config.margin;
for layer in layers.iter() {
    // assign y to all nodes in layer
    let max_height = layer.iter().map(|&n| graph.dimensions[n].1).fold(0.0, f64::max);
    y += max_height + config.rank_sep;
}
```

Each rank contributes `max_height + rank_sep`. A zero-height title rank contributes `0 + 50 = 50` units.

### BK operates perpendicular to rank direction only

- TD/BT layouts: BK assigns X-coordinates; Y is determined by rank
- LR/RL layouts: BK assigns Y-coordinates; X is determined by rank

BK does NOT influence inter-rank spacing.

### BK and zero-dimension nodes

In `compute_sep()`:
```rust
left_width / 2.0 + (left_sep + right_sep) / 2.0 + right_width / 2.0
```

For a zero-dimension title node: width/2 = 0, contributing only the separation gap. This is correct — the node takes up no perpendicular space.

### Spacing analysis with title rank

For `border_top(rank 0) → title_dummy(rank 1) → content(rank 2)`:
- border_top at y=margin
- title_dummy at y=margin + 0 + 50 = margin + 50
- content at y=margin + 50 + 0 + 50 = margin + 100

Without title rank:
- border_top at y=margin
- content at y=margin + 0 + 50 = margin + 50

The title rank adds exactly 50 units (one `rank_sep`) of vertical gap.

## How

### Impact on coordinate assignment

1. **Vertical spacing**: Title rank adds exactly `rank_sep` (50.0) vertical space. This is the minimum gap — adequate for a single line of title text in most configurations.

2. **Horizontal positioning**: BK treats the zero-width title node as transparent. It receives an x-coordinate via median alignment but exerts no separation pressure.

3. **No configurable per-rank spacing**: All inter-rank gaps use the same `rank_sep` value. The title rank cannot have custom spacing without modifying the position algorithm.

4. **Subgraph bounds**: A zero-height title node does not expand subgraph bounds vertically — the rank exists but contributes zero to the max_height calculation.

### If title node has explicit dimensions

If the title node is given height matching the title text (e.g., height=1 in char coords → some dagre float):
- Title rank contributes `title_height + rank_sep` instead of just `rank_sep`
- This creates more space but may be excessive if `rank_sep` is already large enough

## Why

- **Fixed spacing is predictable**: Every rank gets the same treatment, making layout behavior consistent
- **Zero dimensions are safe**: BK's separation formula correctly handles zero-dimension nodes
- **Explicit dimensions recommended**: Rather than relying on implicit `rank_sep` spacing, giving the title node dimensions matching the title text ensures adequate space regardless of `rank_sep` configuration
- **No per-rank customization exists**: Adding variable rank spacing would require non-trivial changes to `assign_vertical()`

## Key Takeaways

- BK handles zero-dimension nodes correctly — no issues with perpendicular coordinate assignment
- Inter-rank spacing is `max_height + rank_sep` per rank — a zero-height title rank adds exactly `rank_sep` (50.0)
- Spacing is NOT configurable per-rank — all ranks use the same `rank_sep`
- Title node should have explicit height dimensions to guarantee adequate space for title text
- The title rank's contribution to subgraph bounds depends on whether it has non-zero dimensions

## Open Questions

- Should the title node have explicit height (matching rendered title text) or remain zero-dimension?
- Is `rank_sep` (50.0 dagre units) sufficient for a single-line title in the rendered character grid?
- How does the dagre float dimension for title height map to character-grid rows in the render layer?
- If title node has height, does the extra `rank_sep` gap below it create too much visual spacing?
