# Finding: Fundamental Gap Between Dagre Coordinates and Draw Coordinates

## Summary

The biggest architectural insight from this plan is that the dagre layout engine and the draw coordinate system are loosely coupled. Changes to dagre parameters (`node_sep`, `edge_sep`, centering) have **indirect and often invisible** effects on the final rendered output.

## The Pipeline

```
Dagre (float coords) -> Layer grouping -> Order sorting -> Grid positions -> Stagger mapping -> Draw coords (int)
```

Each stage loses information:
1. **Layer grouping**: Discards primary-axis positions, keeps only ordering
2. **Order sorting**: Preserves cross-axis ordering but discards magnitudes
3. **Grid positions**: Assigns integer (layer, position) indices
4. **Stagger mapping**: Re-introduces dagre cross-axis positions proportionally

## Implications

- **Dagre node_sep**: Affects relative cross-axis positions, but these are proportionally scaled to fit grid-based content width. The absolute value matters less than the ratios between nodes.
- **Dagre edge_sep**: Same proportional scaling applies. Dummy nodes being closer in dagre space only helps if the stagger mapping preserves that closeness at char resolution.
- **Dagre centering**: Affects which cross-axis position a node gets, which flows through to stagger positions. This has the most direct effect since it changes which grid position a node occupies.

## Recommendation for Future Work

If finer control over LR/RL spacing is needed, the changes should target `compute_stagger_positions()` and/or `grid_to_draw_horizontal()` directly, rather than (or in addition to) tuning dagre parameters. The dagre parameters are useful for getting correct ordering and relative positioning, but the final visual spacing is determined by the draw coordinate system.

Consider:
1. Making `compute_stagger_positions()` dummy-aware (use tighter spacing for waypoints)
2. Adding a post-draw equalization pass for nodes within the same layer
3. Investigating whether the proportional mapping should be replaced with a direct dagre-to-draw coordinate conversion for the cross axis
