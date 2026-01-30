# Edge Label & Routing Session Summary

## Commits Made

### 1. Fix edge label collision (0566770)
- Added `PlacedLabel` struct to track label bounding boxes
- Labels that would overlap are shifted to alternative positions
- Fixed "vyesd" mashup of "valid" and "yes" in complex.mmd

### 2. Place backward edge labels along actual path (b9e3cb9)
- Backward edge labels now placed on corridor segment, not straight-line midpoint
- Fixed "git pull" label appearing in middle of diagram instead of on bottom corridor
- Fixed "yes" label appearing near "Validate" instead of on right-side corridor

## Remaining Issue

**Visual ambiguity in backward edge origins** (not yet fixed)

In `complex.mmd`, the backward edge from "More Data?" to "Input" exits from the right side and travels horizontally through the same row as "Log Error" and "Notify Admin", making it look like all three nodes connect to the upward line:

```
 < More Data? >────│ Log Error │────│ Notify Admin │──┘
```

This is an **edge routing** issue, not a label issue. Mermaid's label-as-node approach wouldn't help here.

## Files Changed

- `src/render/edge.rs` - Label placement logic
  - `draw_edge_label_with_tracking()` - Main label placement function
  - `find_label_position_on_segment()` - NEW: Places labels on corridor segments
  - `PlacedLabel` struct - NEW: Tracks placed labels for collision detection
  - `label_has_collision()` - NEW: Checks node + label collisions

## Research Files Created

- `research/edge-label-routing/mermaid-label-approach.md` - How Mermaid handles edge labels
- `research/edge-label-routing/backward-edge-routing-issues.md` - Analysis of routing ambiguity + potential fixes

## Next Steps

Investigate Option 1 from the routing issues doc: Have backward edges exit from the **top** of the source node (in TD layouts) rather than the right side. This would clearly show where the edge originates.

Implementation would be in `src/render/router.rs` in `route_backward_edge_vertical()`.
