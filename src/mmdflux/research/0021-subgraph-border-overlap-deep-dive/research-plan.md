# Research: Subgraph Border Overlap Deep Dive

## Status: SYNTHESIZED

---

## Goal

Understand exactly how Mermaid and dagre.js handle subgraph border spacing and edge-title collisions, compare with mmdflux's current behavior, and determine what it would take to replicate their approach. The attached Mermaid screenshot shows the target rendering: subgraphs have clear vertical separation, edges pass cleanly between borders, and the "Output" title sits above its subgraph content without edge collision.

## Context

Issue 0005 documents that mmdflux's subgraph borders overlap when cross-subgraph edges force vertical stacking. The root cause is that `convert_subgraph_bounds()` computes borders from member-node positions with fixed 2-cell padding, ignoring dagre's properly-spaced border nodes. A coordinate frame mismatch between dagre space and draw space (documented in Plan 0026 findings) prevents using dagre bounds directly.

Prior research (0016, 0019) explored compound graph architecture and identified 10 overlap/clipping issues. Plan 0026 attempted to use dagre bounds but reverted Phase 1 due to the coordinate mismatch. This research goes deeper into the specific mechanisms used by Mermaid and dagre.js, particularly around:
- How dagre.js border nodes create inter-subgraph gaps
- How Mermaid post-processes dagre output for subgraph titles
- How edges interact with subgraph title regions
- The exact coordinate transformation needed to use dagre bounds in mmdflux

## Questions

### Q1: How does dagre.js guarantee inter-subgraph spacing?

**Where:** `/Users/kevin/src/dagre/lib/` — `nesting-graph.js`, `add-border-segments.js`, `order/add-subgraph-constraints.js`, `layout.js`, `coordinate-system.js`
**What:** The exact mechanism by which dagre.js ensures sibling subgraphs don't overlap. Specifically: how border nodes are created, what weights/edges constrain them, how `removeBorderNodes()` derives final bounds, and what rankSep/nodeSep parameters affect the gap size.
**How:** Read the dagre.js source code for all compound-graph-related functions. Trace the lifecycle of border nodes from creation through positioning to removal. Document the exact formulas and constraints.
**Why:** We need to understand whether dagre's guarantees are sufficient on their own (if we could correctly transform bounds) or whether additional post-processing is needed.

**Output file:** `q1-dagre-inter-subgraph-spacing.md`

---

### Q2: How does Mermaid handle subgraph titles and edge-title collisions?

**Where:** `/Users/kevin/src/mermaid/packages/mermaid/src/dagre-wrapper/` and `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/`, web search for Mermaid subgraph rendering docs
**What:** How Mermaid positions subgraph titles relative to borders, whether it adjusts dagre output to make room for titles, and whether it has any mechanism to prevent edges from passing through title text. From the attached screenshot, the "Input" title is centered at the top of its subgraph border, and "Output" is similarly positioned — edges pass between the subgraphs without crossing title text.
**How:** Read Mermaid's cluster rendering code, search for `subGraphTitleTotalMargin`, `updateNodeBounds`, and title-related post-processing. Look for any edge-rerouting logic that avoids title regions.
**Why:** Mermaid's rendering is the gold standard for what users expect. Understanding their approach tells us what we need to replicate.

**Output file:** `q2-mermaid-title-edge-handling.md`

---

### Q3: What is mmdflux doing today and where does it break?

**Where:** `/Users/kevin/src/mmdflux-subgraphs/src/render/layout.rs` (convert_subgraph_bounds), `/Users/kevin/src/mmdflux-subgraphs/src/render/subgraph.rs`, `/Users/kevin/src/mmdflux-subgraphs/src/dagre/border.rs`, `/Users/kevin/src/mmdflux-subgraphs/src/dagre/nesting.rs`
**What:** The exact current implementation: how border nodes are created, how dagre bounds are computed but discarded, how member-node fallback computes bounds, how embedded titles are rendered, and precisely where the overlap occurs. Also check the coordinate mismatch finding from Plan 0026.
**How:** Read the Rust source in detail. Trace the data flow from dagre border node removal through `convert_subgraph_bounds()` to `render_subgraph_borders()`. Read the Plan 0026 Phase 1 revert context and the coordinate mismatch finding.
**Why:** We need a precise understanding of the current state to know exactly what needs to change.

**Output file:** `q3-mmdflux-current-behavior.md`

---

### Q4: What would it take to use dagre bounds correctly in mmdflux?

**Where:** `/Users/kevin/src/mmdflux-subgraphs/src/render/layout.rs` — node position formula vs `to_ascii()`, `/Users/kevin/src/mmdflux-subgraphs/src/dagre/mod.rs`, Plan 0026 findings (`dagre-to-draw-coordinate-mismatch.md`)
**What:** The exact mathematical difference between the node position formula (right-edge offset + overhang correction) and the `to_ascii()` linear transformation. What formula would correctly transform dagre subgraph Rects into draw coordinates. Whether the gap dagre provides between sibling subgraph border nodes is sufficient for the inter-border gap needed in text rendering (including the embedded title row).
**How:** Read both coordinate transformation paths in detail. Work through the math with concrete examples from the `subgraph_edges.mmd` fixture. Determine whether a correct transformation formula exists or whether additional adjustments (e.g., title row reservation) are needed beyond what dagre provides.
**Why:** This is the core technical question — if we can correctly transform dagre bounds, we get non-overlapping borders for free. If not, we need a different approach.

**Output file:** `q4-coordinate-transformation-fix.md`

---

### Q5: How should edges interact with subgraph title regions?

**Where:** `/Users/kevin/src/dagre/lib/`, `/Users/kevin/src/mermaid/packages/mermaid/src/`, `/Users/kevin/src/mmdflux-subgraphs/src/render/router.rs`, web search for "dagre subgraph edge title collision"
**What:** Whether dagre.js or Mermaid have any mechanism to prevent edges from passing through subgraph title text. From the Mermaid screenshot, edges pass between the Input and Output subgraphs without crossing the title text — is this by design (title is positioned where edges don't go) or by accident (edge routing avoids titles)?
**How:** Analyze the Mermaid screenshot geometry. Check if dagre's border node placement naturally creates enough gap for titles. Search for any edge clipping or rerouting logic in Mermaid related to cluster labels. Consider what mmdflux would need: the embedded title approach (`┌─ Title ─┐`) means edges crossing the top border pass through the title row.
**Why:** This is a UX concern — edges passing through title text makes diagrams hard to read. We need to know if this is solved architecturally (by the spacing/positioning) or requires explicit avoidance logic.

**Output file:** `q5-edge-title-collision-avoidance.md`

---

## Sources

| Source | Location | Used by |
|--------|----------|---------|
| dagre.js source | `/Users/kevin/src/dagre/lib/` | Q1, Q5 |
| Mermaid source | `/Users/kevin/src/mermaid/packages/mermaid/src/` | Q2, Q5 |
| mmdflux-subgraphs worktree | `/Users/kevin/src/mmdflux-subgraphs/src/` | Q3, Q4 |
| Plan 0026 findings | `/Users/kevin/src/mmdflux/plans/0026-subgraph-padding-overlap/findings/` | Q3, Q4 |
| Research 0019 | `/Users/kevin/src/mmdflux/research/0019-subgraph-padding-overlap/` | Q3 |
| Issue 0005 | `/Users/kevin/src/mmdflux/issues/0005-subgraph-border-overlap/` | All |
| Mermaid screenshot | (attached to conversation) | Q2, Q5 |

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-dagre-inter-subgraph-spacing.md` | Q1: dagre.js inter-subgraph spacing | Complete |
| `q2-mermaid-title-edge-handling.md` | Q2: Mermaid title and edge handling | Complete |
| `q3-mmdflux-current-behavior.md` | Q3: mmdflux current behavior | Complete |
| `q4-coordinate-transformation-fix.md` | Q4: Coordinate transformation fix | Complete |
| `q5-edge-title-collision-avoidance.md` | Q5: Edge-title collision avoidance | Complete |
| `synthesis.md` | Combined findings | Complete |
