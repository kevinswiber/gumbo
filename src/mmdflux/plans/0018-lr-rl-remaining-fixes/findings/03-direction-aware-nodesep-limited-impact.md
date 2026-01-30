# Finding: Direction-Aware node_sep Has Limited Visual Impact

## Summary

Task 2.2 changed LR/RL `node_sep` from 50.0 to `(avg_height * 2.0).max(6.0)` (typically ~6.0 for standard nodes). The RED phase test passed *before* implementation, suggesting the draw coordinate system was already producing tight spacing.

## Why the Test Passed Pre-Implementation

The draw coordinate system uses `v_spacing` (default 3) and `h_spacing` (default 4) to control character-level spacing. These are independent of dagre's `node_sep`. The dagre `node_sep` controls abstract positioning which is then mapped to grid positions. For simple fan-out layouts, the grid ordering is identical regardless of `node_sep` value.

The dagre `node_sep` *does* affect:
- **Relative cross-axis positions** which flow through `compute_stagger_positions()`
- **Whether nodes are evenly spaced** (BK compaction may produce uneven gaps with large `node_sep` when node counts vary per layer)

## Visual Impact Observed

5-target LR fan-out (`A->B,C,D,E,F`) showed identical output before and after. The uneven spacing (2 blank lines between some pairs, 0 between others) persisted. This unevenness comes from the stagger algorithm, not from `node_sep`.

## The Real Bottleneck: compute_stagger_positions()

The stagger algorithm (`layout.rs:1018-1115`) maps dagre cross-axis positions to draw positions. It:
1. Computes the dagre range (min to max cross-axis value)
2. Computes the maximum content width needed at grid spacing
3. Maps dagre positions proportionally into the draw coordinate range

The proportional mapping preserves relative positions from dagre but scales them to fit the grid-based content width. This means:
- If dagre produces evenly spaced nodes, draw positions are even
- If dagre produces uneven spacing (due to BK alignment choices), draw positions reflect that

## Recommendation

The `node_sep` change is still correct (it prevents dagre from over-separating LR nodes in its abstract space), but further visual improvement requires either:
1. Modifying `compute_stagger_positions()` to enforce minimum/maximum gaps
2. Post-processing draw positions to equalize spacing
3. Investigating why BK produces uneven centering for fan patterns
