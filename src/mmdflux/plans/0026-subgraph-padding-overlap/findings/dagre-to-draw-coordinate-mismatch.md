# Finding: Dagre-to-Draw Coordinate Frame Mismatch

**Type:** plan-error
**Task:** 1.2
**Date:** 2026-01-29

## Details

Phase 1 (commit 95aa390) changed `convert_subgraph_bounds()` to transform dagre
border-node Rects via `TransformContext::to_ascii()`. This caused subgraph borders
to render far to the right of their member nodes — the border and nodes ended up
in completely different screen positions.

**Root cause:** The dagre coordinate space and the node draw coordinate space use
incompatible formulas:

- **Node draw positions** compute center as:
  `cx = (rect.x + rect.width/2.0 - dagre_min_x) * scale_x`
  where `rect.x` is the dagre center, so `rect.x + rect.width/2.0` is the right
  edge. `dagre_min_x` is `min(rect.x)` — the minimum center, not minimum left edge.

- **`to_ascii()`** computes:
  `x = (dagre_x - dagre_min_x) * scale_x + overhang + padding`
  treating the input as a raw point in dagre space.

When we pass the subgraph Rect's top-left corner `(rect.x - rect.width/2.0)` to
`to_ascii()`, it subtracts `dagre_min_x` (a center coordinate), producing a
different offset than the node formula. The result is that the subgraph border
position is inconsistent with node positions.

**Example:** For a subgraph with dagre center=(89.5, 138), nodes at draw x=1,
the border computed x=16 — 15 cells to the right of the actual nodes.

## Impact

Phase 1's dagre Rect path was a regression. The original member-node draw position
approach was correct because it operates entirely in draw coordinate space (after
all scaling, overhang correction, and padding have been applied).

The dagre compound layout *does* correctly position border nodes to contain member
nodes in dagre space, but the rendering pipeline's coordinate transformation is
not a simple linear mapping from dagre to draw space — the right-edge offset and
overhang correction create a non-trivial relationship.

## Fix

Reverted to always using member-node draw positions for subgraph bounds (commit
d1a0e6e). The `_dagre_bounds` and `_ctx` parameters are now unused but kept in
the signature for API stability.

## Action Items

- [x] Revert to member-node draw position bounds
- [ ] If dagre Rect bounds are ever needed (e.g., for multi-subgraph overlap
      prevention), the fix is to transform dagre Rects using the same formula
      as node positions (right-edge offset + overhang), not via `to_ascii()`
