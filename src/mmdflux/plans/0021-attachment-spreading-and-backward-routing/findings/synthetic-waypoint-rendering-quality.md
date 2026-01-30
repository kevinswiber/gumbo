# Finding: Synthetic waypoint rendering quality needs refinement

**Type:** note
**Task:** 3.2
**Date:** 2026-01-28

## Details

The synthetic backward waypoint routing works functionally — single-rank backward edges now route around the right side (TD/BT) or bottom side (LR/RL) of nodes instead of straight through. However, the rendering quality has some rough edges:

1. **Arrow overlap with node borders**: In some cases, arrow characters render on top of node border characters (e.g., `└────────▼`), creating visual noise.

2. **Entry direction change**: LR backward edges previously entered from the left (◄) but now enter from below (▲ via the bottom routing path) or from the right (► at the corner). The arrow character may not match visual expectations.

3. **Orthogonalization direction**: The `build_orthogonal_path_with_waypoints` uses layout direction for segment ordering, which may not be optimal for synthetic waypoints that route perpendicular to the normal flow.

## Impact

The core routing improvement is correct — edges now route around nodes instead of through them. The rendering artifacts are cosmetic and could be addressed in a follow-up refinement.

## Action Items
- [ ] Consider filing an issue for backward edge rendering polish
- [ ] Investigate arrow placement at node boundaries for synthetic paths
- [ ] Consider whether orthogonalization segment ordering should be waypoint-aware
