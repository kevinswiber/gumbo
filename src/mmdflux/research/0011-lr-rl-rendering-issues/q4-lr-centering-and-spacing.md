# Q4: Dagre Coordinate Mapping for LR Layouts

## Summary

The source node centering and target spacing issues in LR layouts stem from a fundamental mismatch between how dagre assigns y-coordinates using the Brandes-Kopf (BK) algorithm and how those coordinates are scaled to ASCII draw coordinates. Specifically: (1) BK doesn't align layer-0 source nodes to the vertical midpoint of their target children because it only uses predecessor neighbors, not successors; (2) dagre's hardcoded `node_sep=50.0` is calibrated for TD layouts where it applies to horizontal separation, but for LR layouts it incorrectly applies to vertical separation with much smaller node dimensions, causing excessive spacing; and (3) the stagger position scaling uses nodesep=50.0 as a normalization factor without accounting for layout direction.

## Where

- `src/render/layout.rs` lines 177-398 — `compute_layout_dagre()` extracts dagre cross-axis (y) coordinates
- `src/render/layout.rs` lines 321-333 — dagre cross-position extraction for LR (y-axis)
- `src/render/layout.rs` lines 370-379 — stagger computation call for LR
- `src/render/layout.rs` lines 851-986 — `grid_to_draw_horizontal()` applies stagger centers
- `src/render/layout.rs` lines 927-938 — stagger mode positioning
- `src/render/layout.rs` lines 1017-1131 — `compute_stagger_positions()` core coordinate scaling
- `src/render/layout.rs` line 1078 — target_stagger formula using nodesep
- `src/render/layout.rs` lines 1083-1087 — scale computation
- `src/dagre/position.rs` lines 83-124 — `assign_horizontal()` calls BK for y-coordinate assignment
- `src/dagre/bk.rs` lines 265-271 — `get_neighbors()` uses predecessors only for downward sweep
- `src/dagre/bk.rs` lines 636-754 — `horizontal_compaction()` enforces minimum separation
- `src/dagre/bk.rs` line 739 — min_separation calculation using node_sep=50.0
- `src/dagre/types.rs` lines 81-110 — LayoutConfig with node_sep and rank_sep
- `src/dagre/mod.rs` lines 239-246 — hardcoded node_sep=50.0, rank_sep=50.0
- `issues/0001-lr-layout-and-backward-edge-issues/issues.md` lines 51-96 — Issues 2 and 3

## What

### Coordinate Assignment for LR Layouts

**Phase 1: Dagre BK Y-Coordinate Assignment** (`position.rs:83-124`)

For LR layouts, `assign_horizontal()` calls `position_x()` to compute y-coordinates (cross-axis). The BK algorithm:
1. Computes vertical alignment based on median **predecessors** only (neighbors in previous layer)
2. Applies minimum separation: `(node_height_left + node_height_right) / 2.0 + node_sep` (`bk.rs:739`)
3. With node_sep=50.0 and heights ~3.0 chars, minimum separation = 53.0 dagre units

For a 3-target fan-out (A -> B, C, D):
- Layer 0: [A] alone — no predecessors, gets default position ~50.0
- Layer 1: [B, C, D] — B aligns with A at ~50.0, C at ~150.0, D at ~250.0

**Phase 2: Stagger Position Scaling** (`layout.rs:1017-1131`)

The `compute_stagger_positions()` function scales dagre y-values to ASCII coordinates:

1. dagre_range = 250.0 - 50.0 = 200.0
2. target_stagger = (dagre_range / nodesep * (spacing + 2.0)) = (200.0 / 50.0 * 5.0) = 20.0 characters
3. scale = target_stagger / dagre_range = 20.0 / 200.0 = 0.1
4. Per-node: center = canvas_center + (dagre_y - dagre_center) * scale

Result: A and B both map to the same low Y position, while C and D are spaced far apart. Source A ends up at center ~3, but targets span centers [3, 8, 18] with visual midpoint ~10.

**Phase 3: Draw Coordinate Conversion** (`layout.rs:927-938`)

Converts stagger centers to top-left corners: `y_topleft = stagger_center - height/2`. The mapping itself is mathematically correct; the problem is in upstream parameters.

### Problem 1: Source Not Vertically Centered

BK's `get_neighbors()` (`bk.rs:265-271`) only returns predecessors for downward sweeps. Layer 0 has no predecessors, so A becomes a singleton block with default positioning. A.y aligns with its first child (B) at ~50.0, not the center of all children.

### Problem 2: Excessive Vertical Spacing

BK enforces min_separation = 53.0 dagre units between adjacent targets. With scale factor 0.1, this maps to ~5.3 character separation — compared to Mermaid's 2-3 character gaps.

**Root cause:** `node_sep=50.0` is miscalibrated for LR. In TD layouts, node_sep applies to horizontal separation between nodes of width 50-100+ pixels (reasonable). For LR, node_sep applies to vertical separation between nodes of height 3-5 characters (excessive — 1000%+ of height).

### Problem 3: nodesep Parameter Mismatch

From `dagre/types.rs:88-91`, the comments acknowledge that node_sep and rank_sep swap meaning for LR, but the values don't change:

```rust
pub node_sep: f64,  // "Horizontal spacing between nodes (or vertical for LR/RL)"
pub rank_sep: f64,  // "Vertical spacing between ranks (or horizontal for LR/RL)"
```

In `dagre/mod.rs:240-246`, both are always 50.0 regardless of direction.

## How

### Trace: Dagre Output -> Stagger Positions -> Draw Coordinates

```
STEP 1: BK assigns dagre y-coordinates
  A.y=50.0, B.y=50.0, C.y=150.0, D.y=250.0

STEP 2: compute_stagger_positions() scales to ASCII
  dagre_range=200.0, nodesep=50.0, spacing=3
  target_stagger = (200/50 * 5) = 20 chars
  scale = 20/200 = 0.1
  canvas_center = padding + max_layer_content/2 = 1 + 15/2 = 8
  dagre_center = (50+250)/2 = 150

  A_center = 8 + (50-150)*0.1 = -2 → clamped to ~3
  B_center = 8 + (50-150)*0.1 = -2 → clamped to ~3
  C_center = 8 + (150-150)*0.1 = 8
  D_center = 8 + (250-150)*0.1 = 18

STEP 3: grid_to_draw_horizontal() converts to top-left
  A: y=2, B: y=2, C: y=7, D: y=17
  Source A at center=3, targets span centers [3,8,18], midpoint ≈ 10
  A is NOT centered among targets ❌
```

## Why

### Source Not Centered: Architectural Limitation in BK

The BK algorithm aligns nodes using median predecessors (upward edges). For layer-0 nodes with no predecessors, BK has no basis for alignment. A stays at the position of its first child rather than the center of all children. The fix would require BK to also consider successors when predecessors are absent, or a post-processing centering step.

### Excessive Spacing: Parameter Scale Mismatch

The hardcoded `node_sep=50.0` represents suitable separation for TD (pixel-scale widths) but not LR (character-scale heights). The same numeric value applied to different axes with different scales creates a 10-15x mismatch. In `bk.rs:737-739`:
- For TD: widths ∈ [50, 100], node_sep=50 is 50-100% of width → natural
- For LR: heights ∈ [3, 5], node_sep=50 is 1000%+ of height → excessive

### nodesep Not Direction-Aware: Design Oversight

The comments in `dagre/types.rs` acknowledge the semantic swap but the default values and initialization in `compute_layout_dagre()` don't adapt. The fix belongs in `dagre/mod.rs:240-246` where dagre config is created.

## Key Takeaways

- Source centering is an algorithmic gap: BK aligns via predecessors, and layer-0 has none. Fix requires either BK modification or post-processing centering.
- Excessive spacing stems from miscalibrated `node_sep=50.0` — appropriate for TD pixel widths but oversized for LR character heights. Root issue is at `dagre/mod.rs:240-246`.
- Stagger scaling amplifies the problem: the formula `(dagre_range / nodesep * spacing)` assumes nodesep is a meaningful scale for the layout direction.
- The coordinate mapping itself is mathematically correct — the problem is in upstream dagre parameters, not the transformation logic.
- Direction-awareness is missing: `LayoutConfig` should have direction-aware defaults, or `compute_layout_dagre()` should compute nodesep/ranksep based on direction and node dimensions.

## Open Questions

- Should BK use both predecessors and successors for layer-0 alignment?
- What should nodesep be for LR? Perhaps `avg_node_height * 2.0` (~6-10)?
- Should `compute_layout_dagre()` compute nodesep dynamically based on direction and node dimensions?
- Should stagger scaling use a different normalization instead of `dagre_range / nodesep`?
- Would fixing source centering also improve backward edge routing (Issues 4, 7)?
