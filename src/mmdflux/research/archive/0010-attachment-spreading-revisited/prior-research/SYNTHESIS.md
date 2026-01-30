# Attachment Point Spreading: Research Synthesis

**Date:** 2026-01-27 (updated 2026-01-27)
**Issue:** Multiple edges sharing the same attachment point on nodes, causing visual overlap.
**Related Plan:** `plans/0015-attachment-point-spreading/`

---

## Executive Summary

Dagre does **not** use explicit ports or spreading. Instead, attachment point diversity is an **emergent property** of its layout pipeline: long edges get dummy node chains → ordering separates dummy nodes → `edgesep` enforces minimum pixel-level separation → `intersectRect` computes different boundary points from different waypoints.

mmdflux already uses dagre for layout and already inherits this emergent spreading for most cases. The **fan_in** and **fan_out** fixtures render correctly today — the approach angle mechanism works. The overlap problem is specific to cases where the emergent mechanism breaks down:

1. **Short edges (1-rank span) between vertically aligned nodes** — no waypoints, approach angles converge
2. **Backward edges whose waypoints are at the same cross-axis position as forward edges** — common in linear chains where all nodes share the same center_x
3. **Multiple edges from a node whose targets collapse to the same ASCII cell** — dagre's 20px edgesep may not survive the coordinate transform to character grid

### Update: Stagger Preservation Discovery

**A significant upstream root cause was identified.** Dagre computes staggered node x-positions when backward edges create dummy chains (e.g., A at x=41.75, B at x=16.75 for `multiple_cycles.mmd`). This stagger naturally produces different approach angles, which would spread attachment points. However, `compute_layout_dagre()` **discards this stagger entirely** during the grid-to-draw coordinate transform — `compute_grid_positions()` reduces dagre's continuous x-coordinates to sequential integer positions, and `grid_to_draw_vertical()` centers each layer independently.

This means the overlap problem for TD/BT backward edges is **self-inflicted** — we're throwing away information dagre computed specifically to handle this case. See [stagger-preservation-analysis.md](./stagger-preservation-analysis.md) for full details.

**Revised recommendation:** Investigate stagger preservation as an upstream fix (separate plan). This would naturally fix the most visible overlap cases (TD/BT backward edges) by aligning with how dagre/mermaid intended the layout to work. Plan 0015's port spreading would then be reduced in scope to handle remaining cases (LR/RL diamond fan-out, edge cases where stagger is insufficient at ASCII resolution).

A post-routing attachment point spreading pass is still needed for cases stagger can't fix, but the **primary fix should be upstream** — preserving the layout information dagre already computes.

---

## What: How Mermaid/Dagre Handles This

### The Mechanism (No Ports)

Dagre's attachment point computation is `assignNodeIntersects()` in `layout.js:266-283`. For each edge:
- Source attachment = `intersectRect(sourceNode, edge.points[0])` — ray from source center toward first waypoint
- Target attachment = `intersectRect(targetNode, edge.points[last])` — ray from target center toward last waypoint
- If no waypoints (short edge): ray toward the other node's center

### Where Spreading Comes From

The spreading is **upstream** in the layout pipeline, not in the intersection calculation:

| Stage | What Happens | Spreading Effect |
|-------|-------------|-----------------|
| `normalize.run` | Long edges split into dummy node chains | Each edge gets its own chain |
| `order` | Barycenter heuristic assigns order values | Different chains get different positions within each rank |
| `position/bk.js` | Brandes-Kopf assigns x-coordinates | `edgesep` (20px default) enforces min separation between dummy nodes |
| `normalize.undo` | Dummy positions become waypoints | Different edges → different waypoint x-coords |
| `assignNodeIntersects` | `intersectRect` from waypoint angle | Different waypoints → different boundary points |

For **short edges** (1-rank span): No dummy nodes, no waypoints. The approach point is the other node's center. Two short edges from the same source to different targets spread naturally because the targets are at different positions. Two edges (forward + backward) between the same pair of nodes do NOT spread.

### Mermaid's Additional Step

Mermaid strips dagre's rectangular intersection points and recomputes using shape-specific geometry (`edges.js:507-544`). For diamonds, this uses `intersect-polygon.js` which traces the ray against each polygon edge. The approach angle is still determined by dagre's waypoints — Mermaid just refines the boundary math.

### What Dagre Cannot Handle

Even Dagre/Mermaid has a limitation: **true multi-edges** (two edges between the same pair of nodes, e.g., a forward and backward edge) compute toward the same waypoints and get the same attachment points. Mermaid gets away with this because SVG bezier curves can cross without visual confusion. ASCII cannot.

---

## Where: How mmdflux Currently Handles This

### The Pipeline

```
compute_layout_dagre() → route_all_edges() → render_all_edges_with_labels()
                              ↓
                     for each edge independently:
                         route_edge()
                             ↓
                     calculate_attachment_points()
                             ↓
                     intersect_node() → intersect_rect() / intersect_diamond()
```

### What Already Works

**Fan-in/fan-out patterns** — verified in current output:
```
 ┌──────────┐    ┌──────────┐    ┌──────────┐
 │ Source A │    │ Source B │    │ Source C │
 └──────────┘    └──────────┘    └──────────┘
           │           │           │
           └───────┐   │   ┌───────┘
                   ▼   ▼   ▼
                  ┌────────┐
                  │ Target │
                  └────────┘
```

Three edges arrive at distinct x-positions on Target's top face. This works because:
- Source A, B, C are at different x-positions
- `intersect_rect` on Target computes different boundary points for different approach angles
- Dagre's waypoint system preserves this information through the coordinate transform

### What Breaks

**1. Short forward + backward edges on vertically aligned nodes** (`multiple_cycles.mmd`):
```
  ┌───────┐
  │ Top   │     ← A→B forward and C→A backward share center-bottom/center-top
  └───────┘
      │ ▲
      └┐└───┐
       ▼    │
  ┌────────┐│
  │ Middle ││
  └────────┘│
       │    │
       │    │
       ▼┌───┘
    ┌──────┐
    │Bottom│
    └──────┘
```

Node A has:
- Outgoing forward A→B: approach = B's center (directly below) → bottom-center attachment
- Incoming backward C→A: approach = last waypoint (near center_x because all nodes are vertically aligned) → also bottom-center-ish attachment

**2. Multiple outgoing edges from diamond in LR** (`ci_pipeline.mmd`):
The Deploy diamond has two outgoing edges to Staging (above) and Production (below). Both exit from the same right-boundary point because the first waypoints are at similar positions.

### Root Cause Summary

The `route_all_edges()` function at `router.rs:712-721` processes each edge independently via `.filter_map()`. There is no aggregation step that detects when two edges share a boundary cell and spreads them apart. The `calculate_attachment_points()` function at `intersect.rs:153-178` has no concept of other edges.

---

## How: Proposed Solution and Alternatives

### Option A: Post-Routing Attachment Spreading (Current Plan 0015)

A pre-pass inside `route_all_edges()` that:
1. Classifies which face each edge uses on each node
2. Groups edges by (node, face)
3. Spreads groups with >1 edge evenly across the face
4. Passes pre-computed attachment points into routing

**Pros:** Targeted fix, handles all overlap cases, no changes to dagre or layout
**Cons:** Doesn't match how dagre/mermaid works (they don't spread post-hoc)

### Option B: Fix Upstream — Ensure dagre's edgesep survives coordinate transform

The dagre layout already separates dummy nodes by `edgesep`. If the coordinate transform (`map_cross_axis()` in layout.rs:863) better preserved this separation at ASCII resolution, long-edge spreading would work automatically.

**Pros:** Matches dagre's mechanism, no new systems
**Cons:** Only helps long edges with waypoints; short edges and backward edges still overlap

### Option C: Synthetic waypoints for short edges

Generate synthetic waypoints for short edges that need spreading. If A→B is short and C→A is a backward edge, generate a waypoint for A→B that's offset from center to make room.

**Pros:** Uses existing intersection mechanism naturally
**Cons:** Complex to determine when synthetic waypoints are needed; could create odd-looking bends

### Recommended: Option A (with awareness of Options B and C)

Option A is the correct approach for ASCII because:
1. **ASCII is fundamentally different from SVG** — overlapping curves are fine in SVG but destructive in ASCII. This is not a bug that dagre was designed to solve.
2. **The existing mechanism already works for most cases** — fan-in/fan-out renders correctly today. We only need the spreading fix for the specific cases where approach angles converge.
3. **It's the simplest targeted fix** — touches only the routing layer, no layout changes needed.
4. **It matches what ELK and dagre-d3 do with their port models** — explicit port allocation is a well-understood technique for edge libraries.

---

## Why: Holistic Analysis and Global Optimum Concerns

### Will this hurt the cases that already work?

**No.** The spreading pre-pass only activates for faces with >1 edge. For fan-in/fan-out patterns where each face has 1 edge, the existing `intersect_rect` computation is used unchanged. Single-edge faces are the common case.

### Potential risks of the spreading approach

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Spread point causes edge-node collision | Medium | The spread stays on the face, and `offset_from_boundary` pushes 1 cell out. Path routing is orthogonal, so the path avoids nodes. |
| Spreading creates unnecessary crossings | Low | Sort edges by other-endpoint position (plan task 2.2) to match the spatial order of targets. |
| Narrow nodes with many edges look cramped | Low | For nodes with >3 edges on one face, the spread will be tight but still better than overlapping. |
| Backward edges get wrong face classification | Medium | Need to use the reversed waypoints (not the original direction) for face classification. Plan task 2.1 must handle this correctly. |

### What about the coordinate transform losing dagre's spread?

This is a real secondary issue. The `map_cross_axis()` function uses piecewise linear interpolation between real node anchor positions. When two dummy nodes at dagre coordinates (x=90, x=110) map through the transform, their separation may compress to 0 or 1 cells if the anchor spacing is narrow. This is NOT addressed by the current plan.

However, this secondary issue only affects long edges with waypoints. The primary issue (short edges and backward edges) is addressed by the plan. We can pursue Option B as a follow-up if needed.

### Are we solving a local optimum?

The concern is whether fixing attachment points could make the overall diagram look worse — e.g., creating new crossings or misaligned edges.

**Assessment: No.** The current behavior (overlapping edges that destroy each other's visual characters) is unambiguously wrong. Spreading edges apart may not be perfect, but it's always better than having invisible edges. The sorting heuristic (task 2.2) minimizes new crossings.

The one scenario where spreading could look worse is when a node is very narrow (e.g., a single-letter label `A`) and has 3+ edges on one face — the spread positions would be tightly packed. But even this is better than stacking them on the same cell.

### What dagre DOES solve that we should preserve

1. **Long edge waypoints already spread** — dagre's ordering + edgesep mechanism works. Don't override spread waypoints that already differ.
2. **Fan-in/fan-out already works** — the approach angle mechanism is correct. Don't interfere with working cases.
3. **Edge ordering within ranks minimizes crossings** — the spreading sort should align with dagre's ordering to avoid contradicting it.

### What dagre CANNOT solve for ASCII

1. **Two edges in the same cell** — dagre assumes continuous coordinates; ASCII has integer cells
2. **Forward + backward edge sharing a node face** — dagre reverses backward edges and routes them as forward edges in the opposite direction, so they naturally use different corridors. mmdflux routes backward edges in post-processing through waypoint corridors on the side, but the attachment points on the node itself still overlap.
3. **Diagonal attachment** — dagre can place an edge at x=96.7 on a face; ASCII must round to an integer cell, potentially collapsing two nearby floating-point positions to the same cell.

---

## Gaps in the Current Plan (0015)

### Gap 1: Backward edge face classification

The plan's `classify_face()` function uses the first waypoint as the approach direction. For backward edges, the waypoints are reversed in `route_edge()` at router.rs:127-131. The pre-pass must apply the same reversal before classifying — otherwise backward edges get classified on the wrong face.

**Action:** Task 2.1 must reverse waypoints for backward edges before calling `classify_face()`.

### Gap 2: Partial overrides

When only one side of an edge needs spreading (e.g., source face has 2 edges but target face has 1), the plan uses `(0, 0)` as a sentinel for "no override." This is fragile — `(0, 0)` could be a valid coordinate.

**Action:** Use `Option<(usize, usize)>` for each side instead of sentinel values.

### Gap 3: Interaction with `offset_from_boundary`

After spreading, the attachment point is on the node boundary. `offset_from_boundary()` then pushes it 1 cell outward. If the spread moves an attachment point from center to a corner, the offset direction changes. Need to verify the offset logic works correctly for non-center attachment points.

**Action:** Test spread + offset interaction for edge-of-face attachment positions.

### Gap 4: Edge segment routing after spread

The routing functions (`route_edge_direct`, `route_edge_with_waypoints`) build orthogonal segments from the attachment point. If the attachment point is moved from center to an offset position, the first segment may need a different direction. The existing routing should handle this (it computes segments from the actual attachment point), but needs verification.

**Action:** Verify segment construction handles non-center attachment points correctly.

### Gap 5: Backward edges on opposite face

In the current waypoint-based backward edge system (plan 0014), backward edges exit from the "upstream" face — i.e., in TD, they exit from the top of the source and enter the bottom of the target (going upward). This means a forward edge A→B uses A's bottom face, and a backward edge C→A uses A's **bottom** face (incoming backward = entering from below). Both use the same face. The spreading must handle this mixed forward/backward grouping.

**Action:** Verify face classification correctly identifies that incoming backward edges (target side) use the same face as outgoing forward edges (source side) when appropriate.

---

## Comparison Matrix: Dagre vs mmdflux

| Aspect | Dagre/Mermaid | mmdflux Current | mmdflux Planned |
|--------|--------------|-----------------|-----------------|
| Attachment point computation | `intersectRect` from waypoint angle | Same algorithm (`intersect_rect`) | Same, but with spread overrides |
| Long edge spreading | Emergent from dummy node ordering + `edgesep` | Inherits dagre's mechanism via waypoints | Same, plus spreading for collisions |
| Short edge spreading | Uses target center as approach → different targets spread naturally | Same | Add explicit spreading when targets are aligned |
| Forward + backward overlap | Doesn't occur (backward edges reversed in layout) | Occurs (backward edges routed post-hoc) | Spreading pre-pass fixes this |
| Diamond node handling | Polygon intersection in Mermaid | `intersect_diamond()` in intersect.rs | Same, with spread overrides |
| Coordinate precision | Floating-point (sub-pixel) | Integer (character cells) | Same integer grid + spreading |
| Port model | None (emergent) | None | Effective port allocation via spreading |

---

## Recommendations

1. **Proceed with Plan 0015** — the post-routing spreading approach is correct for ASCII
2. **Address the 5 gaps identified above** — especially backward edge face classification and sentinel values
3. **Don't change the layout or dagre integration** — the existing waypoint system is correct
4. **Consider Option B as follow-up** — verify that `map_cross_axis()` preserves dagre's edgesep separation; if not, fix the transform for better baseline spreading
5. **Add diagnostic logging** — a `--debug-attachments` flag that prints which edges share faces and how they're spread would help future debugging

---

## Source Documents

- [dagre-mermaid-analysis.md](./dagre-mermaid-analysis.md) — How Dagre's `intersectRect` and Mermaid's shape-aware intersection work
- [dagre-edge-points-analysis.md](./dagre-edge-points-analysis.md) — How Dagre's normalization, ordering, and Brandes-Kopf positioning create waypoint spread
- [mmdflux-current-analysis.md](./mmdflux-current-analysis.md) — mmdflux's rendering pipeline, exact overlap code paths, and missing spreading logic
- [stagger-preservation-analysis.md](./stagger-preservation-analysis.md) — Discovery that dagre's cross-axis stagger is discarded during coordinate transform; analysis of how to preserve it
- [../0004-backward-edge-overlap/SYNTHESIS.md](../0004-backward-edge-overlap/SYNTHESIS.md) — Earlier research on backward edge overlap root causes
