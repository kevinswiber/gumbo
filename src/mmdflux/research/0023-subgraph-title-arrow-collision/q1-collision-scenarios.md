# Q1: Concrete Collision Scenarios

## Summary

The analysis reveals that collisions between subgraph title characters and edge arrows are **geometrically possible but structurally uncommon**. The title is embedded in the top border row, while arrows are placed at target node attachment points. For a collision to occur, an edge arrow must land on the border row at a position occupied by a title character. This happens when edges cross subgraph boundaries — the edge segment passes through the border (via junction merging), but the arrow itself is placed at the target node's boundary, which is inside the subgraph. However, edge *segments* (not arrows) do cross the border row and can be blocked by title protection.

## Where

- Test fixtures: `simple_subgraph.mmd`, `subgraph_edges.mmd`, `multi_subgraph.mmd`, `backward_in_subgraph.mmd`
- Snapshots: `tests/snapshots/` for rendered output
- `src/render/canvas.rs` — cell protection (lines 127-137, 158-182)
- `src/render/subgraph.rs` — title embedding (lines 25-56)
- `src/render/edge.rs` — arrow drawing (lines 568-585)
- `src/render/router.rs` — attachment points and entry direction (lines 95-111, 540-612)
- `src/render/mod.rs` — rendering pipeline (lines 57-77)

## What

### Title Location
The title is embedded WITHIN the top border row (`┌── Title ──┐`), sharing the same y-coordinate as the border. Title characters are marked `is_subgraph_title = true`.

### Arrow Placement
Arrows are placed at the target node's attachment point via `draw_arrow_with_entry()` using `canvas.set()`. The attachment point is on the node boundary, which is always inside the subgraph (below the border row for TD layout).

### Edge Segment Crossing
Edge segments use `canvas.set_with_connection()`, which also refuses to write to `is_subgraph_title` cells. When an edge crosses a subgraph border, the segment needs to create a junction character (e.g., `┼`) on the border row. If a title character occupies that cell, the junction is blocked.

### Per-Direction Analysis

**TD (Top-Down):** Edges enter subgraph from top. Segments cross top border row — potential collision with title. Arrow lands at target node top boundary (below border).

**BT (Bottom-Top):** Edges enter subgraph from bottom. Top border row is not in the entry path. No collision.

**LR (Left-Right):** Edges enter from left border. Title is on top border row. No collision (different rows).

**RL (Right-Left):** Same as LR — title on top, edges enter from right. No collision.

### Real Example: subgraph_edges.mmd
```
 ┌────▼── Output ──▼─────┐
```
Here the `▼` arrows land on the top border row but at positions NOT occupied by the title "Output". The title is centered, and the arrows happen to fall in the `─` regions flanking the title. This works by luck of geometry, not by design.

## How

For a collision to occur, ALL of these must be true:
1. Layout direction causes edges to cross the top border (TD, or edges entering from above)
2. The edge's path through the border row coincides with a title character position
3. The title is wide enough or positioned such that it overlaps the edge crossing point

The wider the title and the more centered it is, the more likely a collision. A centered title on a narrow subgraph with a centered edge is the worst case.

## Why

The protection mechanism treats title cells as inviolable — both `set()` and `set_with_connection()` refuse to write. This was designed to prevent edges from corrupting title text, but it also prevents legitimate edge crossings from rendering properly.

The root cause is that the title shares canvas cells with the border, and the border is a legitimate routing surface for edges.

## Key Takeaways

- Collisions primarily affect **TD layout** where edges cross the **top border**
- The collision is between **edge segments and title chars**, not arrows and title chars (arrows land at nodes, not borders)
- Current fixtures don't trigger the collision due to geometric luck, but it's not guaranteed
- The wider/more centered the title, the higher the collision risk
- LR/RL/BT layouts are safe because edges don't cross the top border row

## Open Questions

- Should we construct a test fixture that deliberately triggers the collision?
- Are there edge cases with backward edges that could route across the top border?
- If titles move to other borders (e.g., left border for LR), does the collision surface change?
