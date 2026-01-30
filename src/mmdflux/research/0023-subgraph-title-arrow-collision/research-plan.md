# Research: Subgraph Title vs Edge Arrow Collision

## Status: SYNTHESIZED

---

## Goal

Find the least invasive fix AND the architecturally correct long-term solution for preventing subgraph titles from blocking edge arrows that need to land on the same top border row.

## Context

Subgraph titles are embedded in the top border row (e.g., `┌── Title ──┐`). Titles are now centered horizontally. Edge arrows (e.g., `▼`) also land on the top border when entering a subgraph from above. The canvas marks title characters as `is_subgraph_title = true`, which protects them from being overwritten — so when an arrow and title character want the same cell, the arrow silently disappears.

The rendering order is: subgraph borders (with titles) first, then nodes, then edges. Edges use `canvas.set()` and `set_with_connection()`, both of which refuse to overwrite `is_subgraph_title` cells.

The edge router has no awareness of subgraph bounds or titles — it routes purely based on node positions and waypoints.

Key files:
- `src/render/canvas.rs` — cell protection logic (`set()`, `set_with_connection()`)
- `src/render/subgraph.rs` — title rendering (`render_subgraph_borders()`)
- `src/render/edge.rs` — arrow placement (`draw_arrow_with_entry()`)
- `src/render/layout.rs` — bounds computation (`convert_subgraph_bounds()`)
- `src/render/router.rs` — edge routing (no subgraph awareness)
- `src/render/mod.rs` — rendering pipeline order

## Questions

### Q1: What are the concrete collision scenarios?

**Where:** mmdflux-subgraphs test fixtures and manual experimentation
**What:** Enumerate all cases where a title character and an arrow compete for the same cell. Consider all 4 directions (TD, BT, LR, RL), cross-subgraph edges, and different title lengths. Which border side is affected for each direction?
**How:** Construct or modify test fixtures to trigger collisions. Render them and observe which arrows disappear. Map out the geometry: for a TD layout, arrows enter the top border; for LR, arrows enter the left border; etc.
**Why:** We need to know the full scope of the problem before choosing a fix. If collisions only happen on one border side per direction, the fix surface is smaller.

**Output file:** `q1-collision-scenarios.md`

---

### Q2: What are the quick-fix options at the canvas/render layer?

**Where:** `src/render/canvas.rs`, `src/render/subgraph.rs`, `src/render/edge.rs`, `src/render/mod.rs`
**What:** Evaluate render-time approaches: (a) let arrows overwrite title chars (reverse protection), (b) detect collision and shift title to avoid arrow positions, (c) render title AFTER edges and dodge occupied cells, (d) add a "title exclusion zone" that shifts the title left/right. For each, assess invasiveness, correctness, and edge cases.
**How:** Trace through the rendering pipeline for a collision case. For each option, identify which functions change, what new information is needed, and what breaks.
**Why:** We need a least-invasive option that can ship quickly without architectural changes.

**Output file:** `q2-render-layer-fixes.md`

---

### Q3: What are the layout-level options to prevent the collision structurally?

**Where:** `src/render/layout.rs`, `src/dagre/nesting.rs`, `src/dagre/graph.rs`
**What:** Evaluate layout-time approaches: (a) add an extra rank/row for the title inside the subgraph (so border row never has content beneath it), (b) add top padding to subgraph bounds conditionally when a title exists, (c) use dagre compound-node border nodes to reserve space for the title, (d) offset member nodes downward within the subgraph.
**How:** Examine how dagre's nesting/border-node system works and whether it can be extended. Look at how Mermaid's dagre post-processing adds `subGraphTitleTotalMargin`. Assess whether each approach changes node positions (affecting edge routing).
**Why:** A structural fix at the layout layer would eliminate the problem by construction rather than patching it at render time. This is the "correct forever" solution.

**Output file:** `q3-layout-level-fixes.md`

---

### Q4: How does Mermaid solve this exact problem?

**Where:** `~/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/clusters.js`, `~/src/mermaid/packages/mermaid/src/rendering-util/layout-algorithms/dagre/index.js`, `~/src/mermaid/packages/mermaid/src/utils/subGraphTitleMargins.ts`
**What:** Trace exactly how Mermaid prevents title-edge collisions. Does it reserve space for the title inside the cluster box? Does it shift node positions down? Does it use a separate label element that SVG layers above/below edges?
**How:** Read Mermaid's cluster rendering and post-layout adjustment code. Focus on `subGraphTitleTotalMargin`, how it's applied, and the SVG layering model. Compare with our text-grid constraints.
**Why:** Mermaid has solved this in the SVG domain. Understanding their approach helps identify what translates to our ASCII domain and what doesn't.

**Output file:** `q4-mermaid-approach.md`

---

## Sources

| Source | Location | Used by |
|--------|----------|---------|
| mmdflux-subgraphs render pipeline | `~/src/mmdflux-subgraphs/src/render/` | Q1, Q2, Q3 |
| mmdflux-subgraphs dagre layout | `~/src/mmdflux-subgraphs/src/dagre/` | Q3 |
| mmdflux-subgraphs test fixtures | `~/src/mmdflux-subgraphs/tests/fixtures/` | Q1 |
| Mermaid cluster rendering | `~/src/mermaid/packages/mermaid/src/rendering-util/` | Q4 |
| Mermaid dagre post-processing | `~/src/mermaid/packages/mermaid/src/rendering-util/layout-algorithms/dagre/` | Q4 |
| Prior research 0019 | `~/src/mmdflux/research/0019-subgraph-padding-overlap/` | Q3, Q4 |
| Prior research 0021 | `~/src/mmdflux/research/0021-subgraph-border-overlap-deep-dive/` | Q3 |

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-collision-scenarios.md` | Q1: Concrete collision scenarios | Pending |
| `q2-render-layer-fixes.md` | Q2: Quick-fix options at render layer | Pending |
| `q3-layout-level-fixes.md` | Q3: Layout-level structural fixes | Pending |
| `q4-mermaid-approach.md` | Q4: How Mermaid solves this | Pending |
| `synthesis.md` | Combined findings and recommendation | Pending |
