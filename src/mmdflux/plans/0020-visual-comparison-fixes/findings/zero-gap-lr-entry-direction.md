# Finding: LR Zero-Gap Entry Direction Bug

**Type:** discovery
**Task:** 1.3
**Date:** 2026-01-28

## Details

`compute_layout_direct` with default `h_spacing=4` for LR layouts places adjacent-rank
nodes with only a 2-cell gap (e.g., Input ends at x=14, Process starts at x=16).
After `offset_from_boundary` pushes both attachment points 1 cell outward, they land
at the same coordinate (x=15, y=2).

`build_orthogonal_path_for_direction` then creates a zero-length `Vertical` segment
(because `start.x == end.x` is checked first). `entry_direction_from_segments` interprets
this as "upward" → `AttachDirection::Bottom` → `▲` arrow instead of `►`.

## Fix Applied

Added a `start == end` check in `route_edge_direct` that uses the canonical entry
direction for the layout (e.g., `Left` for LR) instead of deriving it from a degenerate
segment. This fixes the arrow character but doesn't address the underlying spacing issue.

## Impact

The zero-gap is a `compute_layout_direct` spacing issue — `h_spacing=4` produces
insufficient inter-rank spacing for edges. This likely also affects edge label placement
in LR. Consider increasing default `h_spacing` for LR in `layout_config_for_diagram`
or adjusting the scale factor calculation.

## Action Items
- [ ] Consider increasing minimum inter-rank gap for LR/RL in `compute_layout_direct`
