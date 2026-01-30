# Dagre Stagger Preservation Implementation Plan

## Status: ✅ COMPLETE

**Completed:** 2026-01-27

**Commits:**
- `987db2b`
- `212f8aa`

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Dagre computes staggered cross-axis positions for nodes when backward edges create dummy chains (e.g., node A at x=41.75, B at x=16.75, C at x=15.0 in `multiple_cycles.mmd`). This stagger naturally produces different approach angles for `intersect_rect`, spreading attachment points without explicit port allocation.

Currently, `compute_layout_dagre()` discards this stagger during the grid-to-draw coordinate transform. The fix preserves dagre's cross-axis positioning so that the ASCII output matches Mermaid's staggered rendering.

## Current State

### Where Stagger Is Lost

The coordinate transform in `compute_layout_dagre()` (`src/render/layout.rs`) discards dagre's cross-axis positions through four stages:

1. **Layer Grouping (lines ~256-303)**: Secondary coordinate extracted but only used for within-layer sorting
2. **`compute_grid_positions()` (lines ~574-591)**: Continuous dagre x → sequential integer GridPos. Single-node layers → pos=0 for every node
3. **`grid_to_draw_vertical()` (lines ~630-731)**: Centers each layer independently with fixed h_spacing. Single-node layers all get the same center_x
4. **`map_cross_axis()` anchors (lines ~361-388)**: Built from draw positions that already lost the stagger

### What Dagre Computes

For `multiple_cycles.mmd` (TD, backward edges C→A and C→B):
- A at x=41.75 (rightward — aligned with dummy chain for reversed A→C edge)
- B at x=16.75 (leftward)
- C at x=15.0 (leftward — aligned with B)
- ~25px stagger between A and B/C

### What mmdflux Produces

All nodes at center_x ≈ 5-6 (effectively same position). Forward and backward edges overlap at same attachment points.

## Implementation Approach: Option A — Scale Dagre Cross-Axis Coordinates

Replace the grid-based cross-axis positioning with scaled dagre coordinates. Keep the primary axis (Y for TD, X for LR) layer-based (unchanged), but derive the cross axis from dagre's computed positions.

### Key Design Decisions

1. **Primary axis unchanged**: Layer-based Y-positioning for TD/BT, X-positioning for LR/RL stays as-is. Only the cross axis changes.

2. **Scale factor**: Derive from the ratio of ASCII content width to dagre coordinate range. For layers with multiple nodes, the existing grid spacing already works; the scale factor ensures single-node-layer stagger is preserved proportionally.

3. **Fallback for non-staggered layouts**: When dagre produces no stagger (all nodes at same cross-axis position), the result is identical to current centering behavior. No visual regression for simple diagrams.

4. **Per-layer centering preserved**: Each layer is still centered within the canvas, but the relative offsets between layers are preserved.

5. **Waypoint anchor update**: `map_cross_axis()` anchors must be rebuilt from the new stagger-aware draw positions so waypoints map correctly.

### Why Option A Over Options B and C

- **Option B (Hybrid)** requires heuristics to detect when stagger matters — complex, fragile
- **Option C (Waypoint-only)** doesn't move nodes, so the stagger may be too small at ASCII resolution to produce different attachment points
- **Option A** is the most faithful to dagre's output and produces the same visual result as Mermaid

## Files to Modify/Create

| File | Change |
|------|--------|
| `src/render/layout.rs` | New `dagre_cross_axis_positions()` function; modify `grid_to_draw_vertical()` and `grid_to_draw_horizontal()` to accept dagre coords; update anchor building |
| `src/render/layout.rs` | Modify `compute_layout_dagre()` to pass dagre cross-axis data to draw functions |
| `tests/integration.rs` | Add stagger verification tests |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Extract dagre cross-axis positions | [tasks/1.1-extract-dagre-cross-axis.md](./tasks/1.1-extract-dagre-cross-axis.md) |
| 1.2 | Compute scaled cross-axis draw positions | [tasks/1.2-compute-scaled-cross-axis.md](./tasks/1.2-compute-scaled-cross-axis.md) |
| 1.3 | Integrate into `grid_to_draw_vertical()` | [tasks/1.3-integrate-vertical.md](./tasks/1.3-integrate-vertical.md) |
| 1.4 | Integrate into `grid_to_draw_horizontal()` | [tasks/1.4-integrate-horizontal.md](./tasks/1.4-integrate-horizontal.md) |
| 2.1 | Update `map_cross_axis()` anchors | [tasks/2.1-update-anchors.md](./tasks/2.1-update-anchors.md) |
| 2.2 | Handle canvas sizing for stagger | [tasks/2.2-canvas-sizing.md](./tasks/2.2-canvas-sizing.md) |
| 3.1 | Add stagger integration tests | [tasks/3.1-stagger-tests.md](./tasks/3.1-stagger-tests.md) |
| 3.2 | Visual regression testing | [tasks/3.2-visual-regression.md](./tasks/3.2-visual-regression.md) |
| 3.3 | Update snapshot tests | *(Covered in 3.2)* |

## Research References

- [stagger-preservation-analysis.md](../../research/archive/0009-attachment-point-spreading/stagger-preservation-analysis.md) — Where stagger is lost, three options analyzed, impact assessment
- [SYNTHESIS.md](../../research/archive/0009-attachment-point-spreading/SYNTHESIS.md) — Overall attachment point spreading research, stagger discovery section
- [mmdflux-current-analysis.md](../../research/archive/0009-attachment-point-spreading/mmdflux-current-analysis.md) — Current pipeline analysis
- [dagre-edge-points-analysis.md](../../research/archive/0009-attachment-point-spreading/dagre-edge-points-analysis.md) — How dagre creates waypoint spread

## Testing Strategy

### Stagger should appear (backward edges present)
- `multiple_cycles.mmd` — A should be offset right of B and C
- `complex.mmd` — nodes with backward edges should shift
- `simple_cycle.mmd` — nodes should stagger

### Stagger should NOT appear (no backward edges)
- `simple.mmd` — remain centered (all same x in dagre)
- `chain.mmd` — remain centered
- `fan_in.mmd` — spreading from multi-node layers, not stagger
- `fan_out.mmd` — spreading from multi-node layers, not stagger

### Directional tests
- All four directions (TD, BT, LR, RL) must handle stagger on the correct axis

### Attachment point verification
- `multiple_cycles.mmd`: forward and backward edges should attach at different positions on shared nodes
