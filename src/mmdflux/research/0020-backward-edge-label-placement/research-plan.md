# Research: Backward Edge Label Placement

## Status: SYNTHESIZED

---

## Goal

Understand why backward edge labels in mmdflux render at wrong cross-axis positions (far from their edges), determine how dagre and mermaid handle this, identify the gap in mmdflux's approach, and propose a concrete fix.

## Context

Issues 0004-01 through 0004-03 all report backward edge labels rendering far from their actual routed edges. The root cause is a coordinate mismatch: label positions are computed from dagre's label dummy coordinates (which reflect the original graph layout), but backward edges are routed via synthetic waypoints (`generate_backward_waypoints()`) that place the edge at a completely different cross-axis position.

Mermaid solves this by recomputing label positions from the actual rendered edge path (`calcLabelPosition(path)` — geometric midpoint traversal), rather than using dagre's raw label coordinates. mmdflux currently uses dagre's coordinates directly via `transform_label_positions_direct()`.

Plan 0025 introduced rank-based label snapping (Phase 2) and backward edge waypoint stripping (Phase 3), which partially addressed the primary-axis positioning but left the cross-axis mismatch unresolved.

## Questions

### Q1: How does mmdflux compute backward edge label positions today?

**Where:** `src/render/layout.rs`, `src/render/edge.rs`, `src/dagre/mod.rs`, `src/dagre/normalize.rs`
**What:** The complete data flow from dagre label dummy creation through coordinate transformation to final canvas placement. Trace a specific backward edge label (e.g., from `labeled_edges.mmd`) through the entire pipeline, noting the coordinates at each stage.
**How:** Read the code path, add trace logging if needed, compare dagre output coordinates with final ASCII positions. Identify exactly where the cross-axis coordinate diverges from the routed edge path.
**Why:** We need precise understanding of the current behavior to design a targeted fix.

**Output file:** `q1-mmdflux-current-pipeline.md`

---

### Q2: How do dagre and mermaid handle edge label positioning for backward edges?

**Where:** `~/src/dagre/lib/normalize.js`, `~/src/dagre/lib/layout.js`, `~/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/edges.js`, `~/src/mermaid/packages/mermaid/src/utils.ts`
**What:** The dagre label dummy lifecycle (creation → layout → extraction) and mermaid's post-processing strategy (path-based midpoint recomputation via `calcLabelPosition`). Whether dagre provides any backward-edge-specific label handling, and how mermaid compensates.
**How:** Read the dagre normalization and denormalization code, read mermaid's `positionEdgeLabel` and `calcLabelPosition`, compare the approach with mmdflux's `transform_label_positions_direct()`.
**Why:** Mermaid's approach (recompute from routed path) appears to be the right strategy. We need to confirm this and understand the specifics to adapt it for ASCII rendering.

**Output file:** `q2-dagre-mermaid-comparison.md`

---

### Q3: What is the best fix strategy for mmdflux?

**Where:** `src/render/edge.rs` (segment-based placement logic), `src/render/router.rs` (routed edge segments), `src/render/layout.rs` (coordinate transformation)
**What:** Design a concrete fix that computes backward edge label positions from the actual routed edge path rather than from dagre coordinates. Consider: (a) adapting mermaid's geometric midpoint approach for ASCII grid, (b) using the existing `select_label_segment_*` heuristics that already find good segments, (c) whether to fix in the coordinate transform layer vs the rendering layer.
**How:** Analyze the existing segment-based placement code in `edge.rs` (which already works for edges without precomputed positions), determine whether it can be extended to backward edges, identify what information is available at each pipeline stage (routed segments, edge direction, label text).
**Why:** The fix must handle TD/BT and LR/RL layouts, work for both short and long backward edges, and not regress forward edge labels. Understanding the tradeoffs between approaches is essential.

**Output file:** `q3-fix-strategy.md`

---

## Sources

| Source | Location | Used by |
|--------|----------|---------|
| mmdflux render/layout | `src/render/layout.rs` | Q1, Q3 |
| mmdflux render/edge | `src/render/edge.rs` | Q1, Q3 |
| mmdflux render/router | `src/render/router.rs` | Q1, Q3 |
| mmdflux dagre/normalize | `src/dagre/normalize.rs` | Q1, Q2 |
| mmdflux dagre/mod | `src/dagre/mod.rs` | Q1 |
| dagre JS | `~/src/dagre/lib/normalize.js`, `~/src/dagre/lib/layout.js` | Q2 |
| mermaid JS | `~/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/edges.js`, `~/src/mermaid/packages/mermaid/src/utils.ts` | Q2 |
| Issues 0004 | `issues/0004-label-placement-backward-edges/` | Q1, Q3 |
| Research 0018 Q3 | `research/archive/0018-label-dummy-rendering-regression/q3-render-layer-analysis.md` | Q1 |
| Plan 0025 | `plans/0025-label-dummy-regression-fix/` | Q1 |

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-mmdflux-current-pipeline.md` | Q1: mmdflux backward edge label pipeline | Complete |
| `q2-dagre-mermaid-comparison.md` | Q2: dagre/mermaid label positioning | Complete |
| `q3-fix-strategy.md` | Q3: Fix strategy proposal | Complete |
| `synthesis.md` | Combined findings and recommendation | Complete |
