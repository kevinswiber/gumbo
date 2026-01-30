# Dagre Stagger Preservation Analysis

**Date:** 2026-01-27
**Issue:** Dagre computes staggered x-positions for nodes when backward edges create dummy chains, but `compute_layout_dagre()` discards this stagger during the grid-to-draw coordinate transform.

---

## Discovery

When rendering `multiple_cycles.mmd` (a TD graph with backward edges C→A and C→B), Mermaid shows nodes staggered horizontally — "Top" shifted right, "Middle" and "Bottom" shifted left. This stagger is a natural consequence of dagre's layout algorithm responding to backward edge dummy chains.

mmdflux's dagre Rust port computes the same stagger (A at x=41.75, B at x=16.75, C at x=15.0), but the ASCII coordinate transform discards it, placing all nodes at approximately the same center_x (5-6).

### Mermaid's Rendering (With Backward Edges)

Nodes are staggered. "Top" is shifted right. Backward edges C→A and C→B curve through the right side with room to spare. Forward edges and backward edges attach at clearly different positions on each node because the approach angles differ.

### Mermaid's Rendering (Without Backward Edges)

Nodes are vertically centered (same x-axis). No stagger needed because there's no contention for attachment points.

### mmdflux Current Rendering

All nodes are vertically centered regardless of backward edges. Forward and backward edges share the same attachment points, causing visual overlap.

---

## Why Dagre Produces Stagger

For `multiple_cycles.mmd`:

1. **Acyclic phase**: C→A and C→B are reversed to effective A→C and B→C
2. **Normalization**: A→C spans 2 ranks → 1 dummy node at rank 1 alongside real node B
3. **Ordering**: Rank 1 now has [B, dummy_for_A→C]. Barycenter heuristic gives them different order values.
4. **Brandes-Kopf positioning**: B and the dummy form separate vertical blocks. `edgesep` (20px) enforces minimum separation. A aligns with the dummy (forming one block), B and C align together (forming another block).
5. **Result**: A at x=41.75 (rightward), B at x=16.75, C at x=15.0 (leftward). The ~25px stagger is significant.

This stagger means:
- Edge A→B: ray from A (right) toward B (left) → exits A's bottom-left area
- Edge C→A backward: ray from waypoint (right side) toward A (right) → enters A's bottom-right area
- **Different approach angles → different attachment points → no overlap**

---

## Where the Stagger Is Lost

The ASCII coordinate transform in `compute_layout_dagre()` (`src/render/layout.rs`) discards dagre's cross-axis positions through a four-stage process:

### Stage 1: Layer Grouping (lines 256-303)

Nodes are grouped into layers by primary coordinate (y for TD). The secondary coordinate (x for TD) is extracted but used **only for within-layer sorting**.

```rust
let mut layer_coords: Vec<(String, f64, f64)> = result.nodes
    .iter()
    .map(|(id, rect)| {
        let primary = if is_vertical { rect.y } else { rect.x };
        let secondary = if is_vertical { rect.x } else { rect.y };
        (id.0.clone(), primary, secondary)
    })
    .collect();
```

### Stage 2: Grid Position Assignment (lines 574-591)

`compute_grid_positions()` converts each node to a `GridPos { layer, pos }` where `pos` is a sequential integer (0, 1, 2...). **The dagre x-coordinate is reduced to an ordinal position.**

For `multiple_cycles.mmd`, each layer has 1 node → every node gets `pos: 0`.

### Stage 3: Draw Position Computation (lines 630-731)

`grid_to_draw_vertical()` centers each layer horizontally and places nodes sequentially with fixed `h_spacing` (default 4 chars). The centering formula:

```rust
let layer_start_x = config.padding + config.left_label_margin
    + (max_layer_content_width - total_layer_width) / 2;
```

Since each layer has 1 node, each is independently centered. **A's center_x ≈ B's center_x ≈ C's center_x.**

### Stage 4: Waypoint Anchors (lines 361-388)

`map_cross_axis()` attempts to map dagre waypoint coordinates to draw coordinates using anchor points `(dagre_x, draw_x)`. But the anchors are built from draw positions that **already lost the stagger**. So waypoints are mapped relative to centered nodes, not staggered ones.

### Summary of Loss Points

| Stage | What's Lost | Why |
|-------|-------------|-----|
| GridPos conversion | Continuous x → ordinal position | Grid model only stores layer/pos indices |
| Layer centering | Cross-layer x-offset | Each layer is independently centered |
| Fixed spacing | Relative x-distances between nodes | `h_spacing` is constant, not proportional to dagre spacing |
| Waypoint anchors | Waypoint stagger relative to nodes | Anchors use already-centered draw positions |

---

## What Preserving Stagger Would Require

### Option A: Use Dagre X-Coordinates Directly

Instead of the grid model, compute draw positions proportionally from dagre's coordinates.

**Changes needed:**
1. In `compute_layout_dagre()`, after extracting dagre node positions, compute draw x-coordinates by scaling dagre x-values to ASCII character space (rather than centering each layer independently)
2. Determine a scale factor: dagre uses `nodesep=50, edgesep=20`. ASCII needs ~1 char per unit. So `edgesep=20` → ~2-4 chars in ASCII.
3. Compute a global x-offset so the leftmost node starts at the padding column
4. Let each node's draw_x = `padding + scale * (dagre_x - min_dagre_x)`

**Complexity:** Medium. Requires replacing `grid_to_draw_vertical()` / `grid_to_draw_horizontal()` with a coordinate-scaling approach.

**Risk:** High. This changes the layout of ALL diagrams, including simple ones that currently look clean. Linear chains (A→B→C) would remain centered (dagre computes same x for all), but any diagram with fan-in/fan-out or backward edges would look different. Needs comprehensive visual regression testing.

### Option B: Hybrid — Use Grid for Simple Cases, Stagger for Complex Cases

Keep the current grid centering for layers with 1 node and no stagger, but shift nodes when dagre's stagger exceeds a threshold.

**Changes needed:**
1. After extracting dagre positions, detect when nodes in adjacent layers have significant x-offset (e.g., >1 `edgesep` apart from the layer's center of mass)
2. For staggered nodes, apply an ASCII x-offset proportional to the dagre offset
3. Keep non-staggered nodes centered as today

**Complexity:** Medium-High. Requires heuristics to decide when stagger matters.

**Risk:** Medium. Only affects diagrams where dagre produces stagger (backward edges, certain fan-out patterns). Simple diagrams unchanged.

### Option C: Preserve Stagger Only for Cross-Axis Waypoint Mapping

Don't move the nodes, but use the stagger information to produce better waypoint positions, which then feed into `intersect_rect` for different attachment points.

**Changes needed:**
1. Build `map_cross_axis()` anchors from dagre coordinates directly (not from draw positions)
2. Use a scaled mapping: `dagre_stagger_delta * scale_factor` → draw_offset from node center

**Complexity:** Low. Only changes waypoint mapping, not node positions.

**Risk:** Low. Node positions unchanged. Waypoints shift slightly, producing different approach angles → different attachment points. But the effect may be too small at ASCII resolution to make a visible difference.

---

## Impact on Attachment Point Overlap

### Would stagger preservation fix the overlap cases?

| Case | Stagger Helps? | Why |
|------|---------------|-----|
| `multiple_cycles.mmd` (TD, forward+backward overlap) | **Yes** | Different node x-positions → different approach angles → different attachment points |
| `complex.mmd` (TD, diamond with forward+backward) | **Likely yes** | Same mechanism as multiple_cycles |
| `ci_pipeline.mmd` (LR, diamond with 2 outgoing) | **No** | The stagger is in the primary axis (x for LR), not the cross axis. The two targets (Staging, Production) are already at different y-positions, but the diamond's right-face exit point is the same for both |
| Fan-in/fan-out (already works) | **No change needed** | These already work because targets are at different positions |

### Conclusion

Stagger preservation would fix the TD backward-edge overlap cases naturally (by providing different approach angles). It would NOT fix the LR diamond case. **Both the stagger fix and the port spreading fix are needed for complete coverage**, but the stagger fix handles the most visible cases and aligns with how dagre/mermaid intended the layout to work.

---

## Relationship to Plan 0015 (Port Spreading)

### Without stagger preservation

Plan 0015's port spreading pre-pass handles ALL overlap cases via explicit face-based spreading. It's a complete solution that doesn't depend on dagre's x-positions.

### With stagger preservation

The stagger fix would handle TD/BT backward-edge overlap naturally. Plan 0015 would still be needed for:
- LR/RL diamond fan-out (stagger doesn't help)
- Cases where stagger is too small for ASCII resolution (possible but rare)
- Any remaining cases where approach angles converge after integer rounding

### Recommended approach

1. **Investigate stagger preservation first** (separate plan) — it fixes the root cause for the most visible cases and aligns the ASCII output with mermaid's visual behavior
2. **Reduce Plan 0015 scope** to handle remaining cases (diamond fan-out, edge cases)
3. **If stagger preservation proves too risky** (visual regressions), fall back to Plan 0015 as the complete solution

---

## Test Cases for Stagger Preservation

### Should show stagger (backward edges present)

- `tests/fixtures/multiple_cycles.mmd` — A should be right of B and C
- `tests/fixtures/complex.mmd` — nodes with backward edges should shift
- `tests/fixtures/simple_cycle.mmd` — Start/End should shift relative to Process

### Should NOT show stagger (no backward edges)

- `tests/fixtures/simple.mmd` — remain centered
- `tests/fixtures/chain.mmd` — remain centered
- `tests/fixtures/fan_in.mmd` — spreading from dagre ordering, not stagger
- `tests/fixtures/fan_out.mmd` — spreading from dagre ordering, not stagger

### Directional tests

- `tests/fixtures/left_right.mmd` — stagger would be in y-axis for LR
- `tests/fixtures/bottom_top.mmd` — stagger would be in x-axis for BT
- `tests/fixtures/right_left.mmd` — stagger would be in y-axis for RL

---

## Key Code Locations

| File | Function | Lines | Role |
|------|----------|-------|------|
| `src/render/layout.rs` | `compute_layout_dagre()` | ~256-303 | Extracts dagre positions, groups into layers |
| `src/render/layout.rs` | `compute_grid_positions()` | ~574-591 | Converts to GridPos (loses stagger) |
| `src/render/layout.rs` | `grid_to_draw_vertical()` | ~630-731 | Centers layers (overrides dagre x) |
| `src/render/layout.rs` | `grid_to_draw_horizontal()` | ~733-850 | Same for LR/RL |
| `src/render/layout.rs` | `map_cross_axis()` | ~858-938 | Maps waypoints (uses already-centered anchors) |
| `src/dagre/acyclic.rs` | `run()` | | Reverses backward edges |
| `src/dagre/normalize.rs` | `run()` | ~196-320 | Creates dummy chains for reversed edges |
| `src/dagre/bk.rs` | `position_x()` | | Brandes-Kopf x-coordinate assignment |
