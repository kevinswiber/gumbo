# Finding: Canvas Expansion and Direct Label Drawing

**Type:** diversion
**Task:** 4.1
**Date:** 2026-01-29

## Details

The plan's Task 4.1 suggested using the existing `draw_label_at_position()` for backward edge labels. Two issues surfaced:

1. **`draw_label_at_position()` re-centers the label** by subtracting `label_len / 2` from the x coordinate. For backward edge labels, the position from `offset_label_from_path()` is already the left edge of the label, not the center. Using the existing function would misplace the label.

2. **Canvas width was too narrow** for backward edge labels. The backward edge routes to the right of nodes, and the label placed beside it extends beyond the initial canvas bounds (which are computed from node positions only, not labels).

## Resolution

- Added `draw_label_direct()` — draws label at exact (x, y) without centering adjustment.
- Added `Canvas::expand_width()` — expands the canvas if a backward edge label extends beyond current bounds.

## Impact

These are localized additions. The `draw_label_at_position` function remains unchanged for forward edge labels. Future work may want to unify the two draw functions or pre-compute canvas size to account for labels.

## Action Items

- [ ] Consider computing canvas width accounting for potential backward edge labels during layout phase
- [ ] Consider unifying `draw_label_at_position` and `draw_label_direct` with a `centered: bool` parameter
