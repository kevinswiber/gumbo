# Q1: Why do LR forward edges lack horizontal segments and have wrong arrows?

## Summary

LR forward edges fail to render horizontal connecting segments and display incorrect arrows (upward `▲` instead of rightward `►`) due to a mismatch between attachment point selection and segment generation for same-rank edges. The core issue is in `resolve_attachment_points()` (router.rs lines 315-346), which forces LR/RL attachment points to use `center_y()` of each node independently. When nodes have different heights or vertical positions, this produces misaligned attachment points where `start.y != end.y`, causing `build_orthogonal_path_for_direction()` to generate an H-V-H path instead of a simple horizontal segment, with the final segment becoming vertical and producing an upward arrow.

## Where

**Files and line numbers investigated:**

1. **`src/render/router.rs`:**
   - Lines 300-347: `resolve_attachment_points()` — forces LR attachments to side faces (**core problem**)
   - Lines 449-475: `entry_direction_from_segments()` — determines arrow from final segment
   - Lines 488-563: `build_orthogonal_path_for_direction()` — creates H-V-H paths for LR/RL
   - Lines 230-291: `route_edge_direct()` — calls path builder
   - Lines 375-417: `offset_from_boundary()` — offsets attachment points outward by 1 cell
   - Lines 569-603: `build_orthogonal_path_with_waypoints()` — waypoint routing

2. **`src/render/edge.rs`:**
   - Lines 518-535: `draw_arrow_with_entry()` — maps AttachDirection to arrow character

3. **Test fixtures:** `tests/fixtures/left_right.mmd`, `tests/fixtures/fan_in_lr.mmd`

## What

### The Core Problem: Attachment Point Misalignment

`resolve_attachment_points()` at lines 316-326:

```rust
Direction::LeftRight => {
    // Source exits on right face
    (
        from_bounds.x + from_bounds.width - 1,  // rightmost column
        from_bounds.center_y(),                 // CENTER Y — PROBLEMATIC
    )
}
```

For LR layouts, source nodes exit from right face, targets enter from left face. But the code uses each node's `center_y()` independently without ensuring both are at the same y-coordinate.

**Example that breaks:**
- Node A: bounds `(0, 0, 10, 3)` → `center_y() = 1`
- Node B: bounds `(15, 1, 10, 5)` → `center_y() = 3`
- Source attachment: `(9, 1)`, Target attachment: `(15, 3)`
- After offset: `start = (10, 1)`, `end = (14, 3)`
- Since `start.y != end.y` → path becomes H-V-H instead of straight H

### Path Generation for Misaligned Nodes

`build_orthogonal_path_for_direction()` at lines 488-563:

When `start.y != end.y` for LR, creates:
1. `Segment::Horizontal { y: start.y, x_start, x_end: mid_x }` — H at start.y
2. `Segment::Vertical { x: mid_x, y_start: start.y, y_end: end.y }` — V to target.y
3. `Segment::Horizontal { y: end.y, x_start: mid_x, x_end }` — H at end.y

When `start.y == end.y`, creates a single horizontal segment with rightward arrow `►`.

### Arrow Direction Consequence

`entry_direction_from_segments()` at lines 449-475 reads the final segment to determine arrow direction. When the path is H-V-H and the vertical segment moves upward, the last segment's entry direction becomes `AttachDirection::Bottom`, producing arrow `▲` instead of `►`.

The output `│ User Input │▲│ Process Data │` shows the `▲` drawn vertically between nodes — confirming the final segment is vertical, not horizontal.

### Why Same-Y Condition Isn't Met

For same-rank LR forward edges:
1. `src_attach` is on right face at y-coordinate Y1 (source's center_y)
2. `tgt_attach` is on left face at y-coordinate Y2 (target's center_y)
3. Y1 ≠ Y2 when nodes have different heights
4. After offset, `start.y ≠ end.y`
5. H-V-H path generated; first H segment too short or invisible
6. Visual path dominated by V segment in the middle

## How

**Current (broken) flow for LR forward edges:**

1. `route_edge()` called → checks for waypoints → calls `route_edge_direct()`
2. `route_edge_direct()` → `resolve_attachment_points()`:
   - Gets raw attachment using `center_y()` for each node independently
   - Points may have different y-coordinates
3. Clamps points to boundaries, offsets outward by 1 cell (preserves y-difference)
4. `build_orthogonal_path_for_direction(start, end, LR)`:
   - `start.y != end.y` → creates H-V-H (3 segments)
   - Final segment vertical → arrow direction is Bottom → renders `▲`

**Correct flow:**

1. For LR same-rank edges, attachment points must share the **same y-coordinate**
2. After offset, `start.y == end.y` holds
3. Single horizontal segment generated, source right → target left
4. Arrow direction is `AttachDirection::Left` (entering from left) → renders `►`

**The fix should:** ensure `resolve_attachment_points()` uses a consensus y-coordinate for same-rank LR/RL edges (e.g., average of both `center_y()` values, or alignment to a common baseline), rather than each node's independent center.

## Why

**Design assumptions baked in:**

1. **LR edges must have horizontal final segments** — enforced by H-V-H pattern in `build_orthogonal_path_for_direction()`, but the prerequisite (same y for start/end) isn't validated.

2. **`center_y()` is sufficient for LR attachments** — works only if nodes at the same rank have the same vertical baseline. Fails when nodes have different heights, which dagre allows.

3. **The segment generation and arrow logic are correct** — `build_orthogonal_path_for_direction()` properly creates paths, and `entry_direction_from_segments()` properly identifies direction. The problem is upstream in attachment point selection.

4. **The "missing horizontal segment" symptom** is actually a vertical segment being rendered instead. The initial H segment is generated but too short, and the visual path is dominated by the V segment.

## Key Takeaways

- The root cause is in `resolve_attachment_points()` forcing LR attachments to side faces using unconstrained `center_y()`, which doesn't account for vertical misalignment of nodes at different heights
- Same-rank edges break when `source.center_y() != target.center_y()` — the path becomes 3-segment H-V-H instead of a simple horizontal line
- The segment generation and arrow logic downstream are correct; the bug is in the input they receive
- Fix should either: (a) use a consensus y-coordinate in `resolve_attachment_points()`, or (b) fall back to `calculate_attachment_points()` for geometric accuracy
- This affects all LR layouts (issues 1, 4, 6) and is the highest-impact fix category

## Open Questions

- Why does dagre place same-rank LR nodes at different y-coordinates? Is this a BK stagger effect or a height difference?
- Should `resolve_attachment_points()` use consensus y for same-rank edges, or should dagre enforce same-y for same-rank nodes?
- For fan-in edges in `fan_in_lr.mmd`, are the three sources at different y-coordinates? Should each have its own horizontal connection?
- How do backward edges with waypoints handle LR entry/exit in intermediate routing?
- Should `offset_from_boundary()` validate that the offset point remains on the correct face?
