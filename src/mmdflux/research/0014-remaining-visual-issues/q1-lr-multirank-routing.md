# Q1: LR Multi-Rank Edge Routing

## Summary

Plan 0020 Phase 1 fixed simple LR forward edges by computing a consensus-y coordinate that ensures same-rank attachment points share the same row. However, LR backward edges (both single-rank and multi-rank) had three deeper root causes beyond consensus-y propagation: **(1)** backward edges attached to the wrong target face (LEFT instead of RIGHT), **(2)** `offset_from_boundary()` resolved corner ambiguity incorrectly for LR layouts (choosing vertical offset over horizontal), and **(3)** side face extents excluded corner rows, preventing edge spreading on minimum-height nodes.

All three issues were fixed in the `fix/lr-rl-routing` branch. The consensus-y waypoint propagation issue identified in the original research turned out to be secondary — the primary problems were face assignment, offset direction, and face extent.

## Where

**Files modified:**
- `src/render/router.rs` — backward edge face assignment, face-aware offset, attachment plan face classification
- `src/render/shape.rs` — side face extent to include full height

**Files investigated:**
- `src/render/intersect.rs` — `spread_points_on_face()` behavior
- `tests/fixtures/git_workflow.mmd` — LR with backward edge (Remote→Working)
- Mermaid reference rendering of `graph LR; A-->B-->C-->D; D-->A`

## What

### Root Cause 1: Wrong target face for backward edges

`resolve_attachment_points()` placed backward LR edges on LEFT/LEFT faces (source exits left, target enters left). This put the backward edge arrow ◄ on the target's LEFT face — the same face forward edges use for entry (►). Mermaid places backward edge arrows on the RIGHT face of the target, with the edge approaching from the right side.

**Fix:** Changed backward LR from LEFT/LEFT to LEFT/RIGHT (source exits left, target enters right). Symmetric fix for backward RL: RIGHT/RIGHT → RIGHT/LEFT.

**Before:** `◄│ A │───►│ B │` (backward arrow on A's left face, col 0)
**After:** `│ A │◄───│ B │` (backward arrow on A's right face)

### Root Cause 2: Corner offset ambiguity

`offset_from_boundary()` checked faces in fixed order: top → bottom → left → right. When a consensus-y attachment point landed on a corner cell (e.g., top-right corner where both `on_top` and `on_right` are true), the function chose vertical offset (up) instead of horizontal offset (right). This caused LR edges to appear to exit/enter from top or bottom faces.

**Example:** Node A at y=2, height=3. Consensus-y with B at y=0 produces y=2 (A's top row). Attachment point (A.right, 2) is at A's top-right corner. `offset_from_boundary` sees `on_top = true` first and offsets upward to (A.right, 1) — appearing to exit from A's top face.

**Fix:** Replaced `offset_from_boundary()` with `offset_for_face()`, which takes an explicit `NodeFace` parameter computed by the new `edge_faces()` function. No ambiguity — LR edges always offset horizontally, TD edges always offset vertically.

### Root Cause 3: Side face extent too narrow for spreading

`face_extent()` for Left/Right faces excluded corner rows: `start = y + 1, end = y + height - 2`. For height-3 nodes (the minimum: top border, content, bottom border), this produced a single-cell extent `(y+1, y+1)`. When two edges shared a side face, `spread_points_on_face()` mapped both to the same cell — no spreading occurred.

**Fix:** Changed Left/Right face extent to include full height: `start = y, end = y + height - 1`. For height-3 nodes, this gives 3 cells `(y, y+2)`, allowing 2 edges to spread to positions y and y+1.

### Root Cause 4 (secondary): Attachment plan face classification

`compute_attachment_plan()` always classified LR edges as Right/Left regardless of backward status. This meant backward edge targets were grouped on the LEFT face (with forward edge targets) instead of the RIGHT face. Edge spreading couldn't separate forward from backward edges because they were classified on the same face.

**Fix:** Updated face classification to use `edge_faces(direction, is_backward)`, matching the faces used by `resolve_attachment_points()`.

### What the original research got right and wrong

**Correct:**
- The H-V-H path generation for misaligned y-coordinates is a real visual issue
- Backward edges are the primary victims
- The routing architecture has an abstraction boundary mismatch

**Incorrect/incomplete:**
- The diagnosis focused on consensus-y propagation through waypoints, but the actual root causes were face assignment, offset ambiguity, and face extent
- The arrow appearing on the LEFT of the target was not caused by waypoint y-misalignment — it was caused by backward edges being assigned to the LEFT target face
- Forward edges also had a face attachment problem when nodes were at different y-levels (the corner offset bug)

## How

Four changes in two files:

1. **`resolve_attachment_points()`** — Backward LR: `(from.x, center_y)` / `(to.x + to.width - 1, center_y)` (LEFT/RIGHT). Backward RL: `(from.x + from.width - 1, center_y)` / `(to.x, center_y)` (RIGHT/LEFT).

2. **`edge_faces()` + `offset_for_face()`** — New functions replace `offset_from_boundary()`. `edge_faces(direction, is_backward)` returns `(src_face, tgt_face)`. `offset_for_face(point, face)` offsets 1 cell in the face direction. Used in both `route_edge_with_waypoints()` and `route_edge_direct()`.

3. **`compute_attachment_plan()`** — Uses `edge_faces()` for LR/RL face classification instead of hardcoded Right/Left.

4. **`face_extent()`** — Left/Right faces use `(self.y, self.y + self.height - 1)` instead of excluding corner rows.

Also removed `offset_from_boundary()` and `effective_final_direction()` (both now unused).

## Why

The original design assumed edges always flow in the canonical direction (source exits forward face, target enters forward face). Backward edges were initially not considered, then added with a LEFT/LEFT face assumption that didn't match Mermaid's behavior. The offset function was position-based rather than intent-based, which worked when all edges used the expected faces but broke at corner cells where two faces overlap. The face extent conservatively excluded corners to avoid visual overlap with box-drawing characters, but this prevented spreading on minimum-height nodes.

## Key Takeaways

- **Face assignment is the primary concern for backward edges** — not consensus-y propagation. Forward edges enter LEFT, backward edges enter RIGHT (for LR). This is the fundamental insight.
- **Position-based offset is fragile** — inferring the face from point position fails at corners. Explicit face parameters are more robust.
- **Minimum-height nodes expose spreading limitations** — height-3 nodes with 1-cell face extents can't spread 2+ edges. Including corners in the extent fixes this.
- **The fix also answers the open questions from the original research:**
  - RL backward edges are affected symmetrically (RIGHT/LEFT fix applied)
  - Constraining waypoints to consensus-y is not the right fix — face assignment and offset direction are
  - Forward edges with staggered nodes WERE affected (the corner offset bug)

## Open Questions

- The spread formula `((i+1) * range) / (count+1)` centers edges within the extent. For 2 edges on a 3-cell face, positions are y+0 and y+1 (not y+0 and y+2). An endpoint-based formula `(i * range) / (count - 1)` would maximize separation. Is this worth changing?
- Backward edges without waypoints (single-rank, e.g., `A-->B-->A`) route straight through the gap between nodes. They don't route "around" the nodes. Mermaid curves these below. Should we add synthetic waypoints for short backward edges to route them below/above?
- The `┌` connector at corner attachment points overwrites the node's corner character. Is this visually acceptable, or should corner positions be avoided?
