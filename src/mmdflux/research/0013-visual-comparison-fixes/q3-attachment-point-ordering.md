# Q3: Why are attachment points ordered incorrectly?

## Summary

The attachment point ordering problem stems from an inconsistency between how `compute_attachment_plan()` classifies which face an edge approaches (using waypoint approach points) and how `sort_face_group()` orders edges on that face (using opposite node geometric center). This mismatch causes edges to attach at positions that don't reflect their actual approach angles, producing crossings. Additionally, arrow characters get unconditionally overwritten by later-drawn edges when attachment points are too close together.

## Where

**Primary files investigated:**
- `src/render/router.rs` (lines 809-935) - `compute_attachment_plan()`, `sort_face_group()`
- `src/render/intersect.rs` (lines 61-97) - `spread_points_on_face()`
- `src/render/edge.rs` (lines 1-536) - edge rendering logic, `draw_segment()`, `draw_arrow_with_entry()`

**Issue documentation:**
- `issues/0002-visual-comparison-issues/issues/issue-07-fan-attachment-point-crossing.md`
- `issues/0002-visual-comparison-issues/issues/issue-08-attachment-overlap-missing-arrow.md`

## What

### 1. Attachment Point Computation Flow

`compute_attachment_plan()` (router.rs, lines 809-912) performs:

1. **Face classification** (lines 814-874): Groups edges by `(node_id, face)` tuple
   - LR/RL: forces side faces (Right for source, Left for target)
   - TD/BT: uses `classify_face()` with approach points (first/last waypoint or opposite node center)

2. **Sorting within face groups** (line 891): `sort_face_group(&mut sorted, edges, layout, *face)` reorders edges by cross-axis position

3. **Spreading points** (line 895): `spread_points_on_face(*face, fixed, extent, sorted.len())` distributes N attachment points evenly along the face extent

4. **Override assignment** (lines 897-908): Maps each sorted edge index to a spread point

### 2. The Sorting Function

`sort_face_group()` (lines 917-935) sorts edges by the cross-axis position of the **opposite endpoint**:

- For top/bottom faces: sort by `other_bounds.center_x()`
- For left/right faces: sort by `other_bounds.center_y()`

This looks correct on the surface but creates a mismatch with face classification.

### 3. Spreading Logic

`spread_points_on_face()` (intersect.rs, lines 66-97) distributes N points evenly:
- Divides the face extent into (count+1) equal parts
- Places points at positions 1, 2, ..., count
- Mathematically sound in isolation

### 4. The Mismatch

- **Face classification** (for TD/BT) uses waypoint approach points (lines 850-857) to determine which face an edge approaches from
- **Sorting** uses the opposite node's geometric center (lines 917-935) to order edges on that face
- These two positional sources diverge significantly for backward edges routed far around the diagram

### 5. Arrow Overwriting (Issue 8)

- `draw_segment()` (edge.rs, lines 476-512) uses `canvas.set_with_connection()` which respects previous characters
- `draw_arrow_with_entry()` (edge.rs, lines 518-535) uses `canvas.set()` which **unconditionally overwrites**
- When edges are 1 cell apart, a later edge's vertical line character overwrites an earlier edge's arrow

## How

The algorithm fails in practice due to:

1. **Mixed forward and backward edges on same face**: In `multiple_cycles.mmd`, both forward and backward edges may attach to the same face. Both share the face but have very different geometric relationships to their targets.

2. **Sorting key doesn't account for edge directionality**: The sort only considers the spatial position of the opposite node. For backward edges routed around the diagram, the opposite node's position doesn't reflect the actual waypoint-based approach angle.

3. **Face classification inconsistency**: For TD/BT, an edge's face classification reflects where the first/last waypoint is, not where the target actually is. When sorted by the target's position, the edge ordering doesn't match the spreading logic's assumption about the approach angle.

4. **For fan patterns** (fan_in.mmd): A, B, C at increasing x-positions all connect to D's top face. Sorting by center_x should order A→left, B→center, C→right. The crossing occurs when the approach angle classification and sort axis diverge.

## Why

**Root causes:**

1. **Inconsistent approach point sources** (lines 850-857 vs 917-935): Face classification uses waypoints; sorting uses opposite node center. These don't always align.

2. **No validation of spread extent vs approach angle** (lines 893-895): `spread_points_on_face()` divides the face evenly without considering which edges approach from which directions.

3. **Mixed edge types on same face** (issue-08): Forward edges approach from one direction; backward edges may swing around from waypoints far away. Both are spread with the same logic.

4. **Character overwrite in rendering**: `draw_arrow_with_entry()` unconditionally overwrites, so when edges are adjacent, earlier arrows disappear.

## Key Takeaways

- The spreading algorithm itself is mathematically correct — the issue is in the mismatch between face classification (waypoint-based) and sorting (opposite-node-based)
- LR/RL layouts force side faces unconditionally (lines 342-343), masking this problem for horizontal layouts
- Arrow overwriting (issue-08) is a separate rendering-layer problem: later edges unconditionally overwrite earlier ones
- The fix requires either: (a) consistent approach point sources for both classification and sorting, (b) separate handling for forward vs backward edges on the same face, or (c) smarter spreading that accounts for actual waypoint approach vectors

## Open Questions

- Why does `resolve_attachment_points()` force LR/RL layouts to side faces instead of allowing geometric approach angles?
- Should backward edges with long waypoints use a different attachment spreading strategy?
- Could the spreading algorithm detect conflicting approach angles and split edges into separate face groups?
- Is there a minimum gap enforcement needed between attachment points to prevent arrow overwriting?
