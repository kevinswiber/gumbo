# Q5: Why does LR label placement use the wrong position?

## Summary

In LR mode, edge labels for backward edges (e.g., Deploy->Staging, Deploy->Production in ci_pipeline) are placed at the far edges of the diagram rather than centered on actual horizontal segments. The root cause is that `select_label_segment_horizontal()` returns None for certain waypoint-routed backward edges, triggering a fallback midpoint calculation that averages start/end coordinates — producing a (mid_x, mid_y) that doesn't correspond to any drawn edge segment.

## Where

**Files investigated:**
- `src/render/edge.rs` (lines 104-137) - LR label placement logic
- `src/render/edge.rs` (lines 418-451) - `select_label_segment_horizontal()`
- `src/render/router.rs` (lines 540-562) - LR segment generation (H-V-H pattern)
- `tests/fixtures/ci_pipeline.mmd` - affected test case
- `issues/0002-visual-comparison-issues/issues/issue-05-lr-label-placement.md`

## What

### LR Label Placement Code (edge.rs lines 104-137)

For LR direction with >=3 segments:

1. Calls `select_label_segment_horizontal()` to find a suitable horizontal segment
2. If found: centers label on that segment, places above at `y - 1`
3. If None (fallback): computes `mid_y = (start.y + end.y) / 2` and `mid_x = (start.x + end.x) / 2`, places label at `(mid_x - label_len/2, mid_y)`

### select_label_segment_horizontal() (edge.rs lines 418-451)

- For 3-5 segments (forward edges): returns the **last** horizontal segment
- For 6+ segments (backward/waypoint edges): returns the **longest inner** horizontal segment (excluding first and last), falling back to last horizontal from entire list
- Returns None when no horizontal segments are found in the inner region and fallback also fails

### Segment Generation for LR (router.rs lines 540-562)

Forward edges get H-V-H pattern (3 segments). Backward edges get 6+ segments from waypoint routing around the diagram perimeter, potentially with all-vertical inner segments.

### The Fallback Failure

For a backward edge like Deploy (Y=5) -> Staging (Y=1):
- `mid_y = (5 + 1) / 2 = 3` — Y=3 is empty space, not on any drawn segment
- `mid_x = (Deploy.x + Staging.x) / 2` — may also miss the actual path
- Label placed in empty space, then shifted further by collision avoidance

### TD vs LR Asymmetry

TD/BT fallback (lines 56-102) uses `routed.end.x` (target's X position) as anchor, keeping the label near the actual edge. LR fallback uses averaged mid_x/mid_y, losing the anchor entirely. This asymmetry is the design flaw.

## How

The issue manifests when:

1. Waypoint routing creates a backward edge path with 6+ segments
2. The inner segments (excluding first/last) are all vertical
3. `select_label_segment_horizontal()` finds no inner horizontal segments and returns None
4. The fallback computes an averaged midpoint that doesn't lie on any drawn segment
5. Labels appear at diagram edges (X=0 or X=max) after collision avoidance shifts

The correct behavior would anchor the label to an actual segment coordinate — either the source's exit Y (mirroring TD's target X strategy) or any horizontal segment regardless of position.

## Why

**Root cause:** The fallback logic assumes a simple path where averaging start/end coordinates gives a reasonable midpoint. Waypoint backward paths snake around the diagram, so the averaged point falls in empty space.

**Design flaw:** TD's fallback uses a fixed anchor point (`routed.end.x`), while LR's uses averaged coordinates. The LR code should mirror TD's strategy with `routed.start.y` or `routed.end.y` as the Y anchor.

**Secondary cause:** `select_label_segment_horizontal()` is too strict in its inner-segment filtering for waypoint paths, causing it to return None when horizontal segments exist but only at the path boundaries.

## Key Takeaways

- The fallback path (lines 118-122) is triggered when `select_label_segment_horizontal()` returns None, which happens for certain waypoint-routed backward edges
- The fallback midpoint calculation `(start.y + end.y) / 2` doesn't align with any drawn segment in complex waypoint paths
- TD/BT's fallback uses a target anchor point; LR's uses averaged coordinates — this asymmetry is the design flaw
- The fix is likely small: either make `select_label_segment_horizontal()` always return a segment, or fix the fallback to use a Y anchor like `routed.start.y`

## Open Questions

- Why does `select_label_segment_horizontal()` return None for ci_pipeline backward edges? Are all inner segments vertical?
- Should the fallback use `routed.start.y` instead of `mid_y` to mirror TD's strategy?
- Is the fix to ensure the selector never returns None, or to fix the fallback, or both?
- Do other LR diagrams (left_right.mmd, git_workflow.mmd) also trigger the fallback path?
