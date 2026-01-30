# Q4: TD Label Ambiguous Pairing

## Summary

TD diagram labels for edges leaving decision nodes are positioned at the final vertical segment near the target node, causing ambiguity when multiple edges target the same node. The algorithm selects the last vertical segment for label placement, positioning it mid-segment at that location. For forward edges with few segments (3-4), this places labels too close to the target node where they can appear to belong to multiple edges or cluster ambiguously. The root cause is that `select_label_segment()` prefers the last vertical segment for short paths without considering label proximity to the target node boundary.

## Where

**Files consulted:**
- src/render/edge.rs (lines 43-182, 220-250, 374-418) — label placement logic
- src/render/router.rs (lines 1-200) — edge routing and segment creation
- tests/fixtures/decision.mmd — test case demonstrating issue
- tests/fixtures/labeled_edges.mmd — additional label examples
- src/dagre/normalize.rs (lines 39-50, 366-387) — label position infrastructure

**Specific functions:**
- `draw_edge_label_with_tracking()` — main label placement entry point (line 43)
- `find_label_position_on_segment_with_side()` — places label on a segment (line 220)
- `select_label_segment()` — chooses which segment gets the label (line 383)
- `label_adjacent_to_edge_on_far_side()` — collision detection (line 348)

## What

### Observed Problem

In decision.mmd, the "No" label from the edge `B -->|No| D` (Decision → Debug) appears to the right of the Decision node rather than along the edge between them:

```
      │    │
      │    │
      └──┐ └──────────────┐│
         │ Yes            ││No
         ▼                ▼└┐
```

The "Yes" label is positioned to the left of the edge, while "No" clusters near the junction point on the right. This creates visual ambiguity about which edge each label belongs to, especially when multiple edges leave the same node.

### Algorithm Behavior

For TD layouts with 3+ segments, the label placement algorithm:

1. **Segment selection** (`select_label_segment()`, line 383):
   - For short paths (< 6 segments): returns the **last vertical segment** found when iterating in reverse
   - For long paths (6+ segments): returns the **longest inner vertical segment**
   - For the B→D edge in decision.mmd: likely 3-4 segments, so returns the final vertical segment approaching the target

2. **Position calculation** (`find_label_position_on_segment_with_side()`, line 220):
   - Calculates midpoint of the selected segment: `mid_y = (y_start + y_end) / 2`
   - Places label at distance x ± 2 from the segment: `x + 2` (right) or `x - label_len` (left)

3. **Side selection** (line 71):
   - Initial choice: `place_right = routed.end.x > routed.start.x`
   - For B→D edge: end (Debug) is to the right of start (Decision), so `place_right = true`
   - Label positioned to the right of the segment at x = segment.x + 2

4. **Collision detection** (lines 79-86):
   - Checks if an edge cell exists on the far side via `label_adjacent_to_edge_on_far_side()`
   - If collision detected, flips `place_right` and repositions
   - However, this only checks for edges on the **far side**, not whether the label is too close to the target node

### Root Cause Analysis

The issue stems from three compounding factors:

1. **Last-segment heuristic is flawed for branching**: When multiple edges leave a decision node and target different nodes, their final vertical segments are in different X positions. Placing labels at the **midpoint** of each segment can cause them to cluster near the target node where they appear associated with the target rather than the source edge.

2. **No minimum distance from target node**: The algorithm places labels based purely on segment midpoint, with no consideration for proximity to the target node boundary. For short edges (3-4 segments), the final vertical segment may be only 1-2 cells away from the target node.

3. **Place-right logic driven by relative positions, not label clarity**: The `place_right = routed.end.x > routed.start.x` heuristic (line 71) aims to spread branching edges outward, but this can cause labels on edges targeting nodes to the right to bunch on the right edge's final segment—precisely where they appear ambiguous.

### Label Position in Code Flow

The label position is determined once during rendering in `draw_edge_label_with_tracking()`:
- No pre-computed label position from dagre (normalize.rs creates dummy nodes for very long edges only)
- The heuristic is applied inline, not a separate layout phase
- Position is finalized at line 184-185 via `find_safe_label_position()`, which applies collision avoidance but doesn't prevent ambiguity at the junction point

## How

### Current Algorithm: Step-by-Step for B→D Edge

Given:
- Diagram direction: TD (Top Down)
- Edge: B (Is it working?) → D (Debug)
- Label: "No"
- Segments: approximately 3-4 segments forming Z-path from B exit to D entry

**Step 1: Select label segment**
```rust
let is_long_path = segments.len() >= 6; // false for 3-4 segments
let chosen_seg = segments.iter().rev().find(...) // last vertical segment
```
Returns the vertical segment closest to the target node D.

**Step 2: Calculate base position**
```rust
let mid_y = (y_start + y_end) / 2; // midpoint of final segment
let place_right = routed.end.x > routed.start.x; // true (D.x > B.x)
let (trial_x, trial_y) = find_label_position_on_segment_with_side(...)
  // returns (segment.x + 2, mid_y)
```

**Step 3: Check for collision**
```rust
if label_adjacent_to_edge_on_far_side(canvas, trial_x, trial_y, label_len, place_right) {
    place_right = !place_right;
}
```
Checks cells at x ∈ [trial_x + label_len, trial_x + label_len + 1] for edges.
If found, flips to left side.

**Step 4: Final position**
```rust
let (label_x, label_y) = find_label_position_on_segment_with_side(...); // recompute with final place_right
```
Label positioned at mid-segment x ± 2, y = segment midpoint.

**Step 5: Collision avoidance**
```rust
let (label_x, label_y) = find_safe_label_position(canvas, base_x, base_y, ...);
```
Tries up/down/left/right shifts up to 3 cells if the base position collides with nodes.

### Why This Produces Ambiguity

For the "No" edge in decision.mmd:
1. The last vertical segment is near node D (Debug), placing the label near the junction point
2. Multiple edges (Yes, No) have final segments at similar Y but different X positions
3. Labels end up clustered on the right edge (Y = juncture, X = right side of D)
4. Visually, "No" appears to be labeling the entry to Debug rather than the edge from Decision

## Why

### Design Rationale Behind Current Approach

The label placement algorithm was designed with these constraints:

1. **Avoid crowding near source node**: For long backward edges, placing labels at the longest inner segment (away from source) keeps labels isolated and visible, which is correct.

2. **Handle Z-paths**: The algorithm assumes 3-segment Z-paths (horizontal, vertical, horizontal) and places labels on the vertical segment to keep them aligned with the edge's primary direction.

3. **Collision avoidance**: The `find_safe_label_position()` function includes logic to shift labels away from nodes and edges. This works for preventing overlaps but doesn't address ambiguity.

4. **Branching edge spreading**: The `place_right = end.x > start.x` heuristic spreads branching edges outward. This is correct for preventing label collision between edges from the same source, but it clusters labels near the target node for edges targeting nodes to the right.

### Why the Heuristic Fails for Short Forward Edges

- **Forward edges** (3-4 segments): The last vertical segment is very close to the target node. Labeling at the midpoint of this segment places the label immediately adjacent to the target, causing ambiguity.
- **Backward edges** (6+ segments): The longest inner vertical segment is far from both source and target, so labels are clearly associated with the edge.

The algorithm conflates two different edge types (short forward vs. long backward) and applies the same heuristic to both, which fails for the forward case.

## Key Takeaways

- **The label placement position is determined at render time**, not during layout (no pre-computed positions from dagre are used for typical edges)
- **The `select_label_segment()` heuristic is correct for long edges but flawed for short forward edges** — it prioritizes the last segment, which for short paths is too close to the target node
- **The collision detection checks for edge adjacency but not for proximity to nodes**, so labels can end up visually associated with the wrong edge at junction points
- **Multiple edges from a decision node produce a cluster of labels near the target**, causing ambiguity about which edge each label belongs to
- **The fix requires distinguishing between short forward edges and long backward edges** and using different label placement strategies (e.g., label at midpoint of **first or second** vertical segment for short paths, not the last)

## Resolution

**Fixed in commit 995a6ef** (`fix: TD label placement — source-near segment + horizontal jog overlap`).

The fix applies two complementary strategies for short forward TD/BT edges (<6 segments):

1. **Horizontal segment overlap:** For Z-paths with a horizontal jog wide enough to hold the label (>= `label_len + 2`), the label is centered directly **on** the horizontal segment, overwriting the `────` edge drawing characters. An `on_h_seg` flag skips edge collision checks so the label can intentionally overwrite the jog line. This places labels like `└─────No───────┐` or `┌─Yes──┘`.

2. **Source-near vertical fallback:** When no horizontal segment is wide enough, `select_label_segment()` now uses source-near tie-breaking (reversed iteration + `max_by_key` last-wins) to pick the vertical segment closest to the source node rather than the target.

The LR/RL horizontal variant (`select_label_segment_horizontal`) was intentionally **not** changed — the last-horizontal-segment heuristic is correct for LR/RL because sibling edges approach targets at different Y positions.

### Verified fixtures

- `decision.mmd` — "Yes"/"No" near source diamond, "No" on jog
- `labeled_edges.mmd` — "yes"/"no" on jogs, "configure" beside vertical
- `complex.mmd` — "invalid" on horizontal jog, "valid" beside vertical
- `http_request.mmd` — "Yes"/"No" centered on jogs
- `label_spacing.mmd` — "valid"/"invalid" beside vertical stubs (no wide h_seg)
- `ci_pipeline.mmd` — LR unchanged, "staging" top / "production" bottom

### Remaining open items

- **LR backward edge label overlap** (`git_workflow.mmd`): The "git pull" backward edge label overlaps with node content. This is a separate issue (LR routing, not TD label placement) tracked as issues 4 and 6.
- **Precomputed label positions from dagre** are only used for skip edges (dummy chains). Typical adjacent-rank edges rely entirely on the heuristic. This is adequate for now but could be revisited if more complex label scenarios arise.
