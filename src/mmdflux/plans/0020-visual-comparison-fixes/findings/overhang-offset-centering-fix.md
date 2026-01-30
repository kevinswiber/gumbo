# Finding: Overhang Offset Required for Dagre Center Consistency

**Type:** discovery
**Task:** 2.2
**Date:** 2026-01-28

## Details

The centering jog bug was caused by `saturating_sub` in the layout code. When
computing draw positions from dagre centers:

```rust
let x = center_x.saturating_sub(w / 2) + padding + margin;
```

If `center_x < w / 2` (which happens for wide nodes near the coordinate origin
after dagre_min_x normalization), the subtraction clips to 0, and the stored
`dagre_center_x` becomes inconsistent with the actual box position.

Example: node "Start" (width 9) with dagre center_x=1. Needs 4 cells to the
left of center, but only has 1. The box gets pushed right, but dagre_center_x
stays at 2 (1+padding), while the actual geometric center is at column 5.

## Fix

Two-pass approach:
1. First pass: compute all raw dagre centers and find the maximum overhang
   (`max(w/2 - center_x)` across all nodes, and similarly for y)
2. Second pass: add the overhang offset to all centers before computing draw
   positions, guaranteeing `center_x >= w/2` for every node

This eliminates the need for `saturating_sub` entirely — the subtraction can
never underflow.

## Impact

Fixes the 1-cell edge jog visible in simple.mmd and other TD/BT diagrams where
nodes have different widths. Edges now route through the true dagre-assigned
center, producing straight vertical segments for aligned nodes.
