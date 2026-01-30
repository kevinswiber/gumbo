# Research: Edge Sep Pipeline — mmdflux vs Dagre.js vs Mermaid

## Status: SYNTHESIZED

---

## Goal

Understand why `edge_sep` changes in mmdflux's BK compaction have no visible effect on rendered output, by comparing how dagre.js and Mermaid handle the full coordinate pipeline from dagre layout to final rendering. Determine whether mmdflux's `compute_stagger_positions()` proportional mapping is the root cause, and what the correct fix looks like.

## Context

Plan 0018 (LR/RL remaining fixes) discovered that `edge_sep` works correctly at the BK unit test level, but the dagre-to-draw coordinate pipeline neutralizes the effect. The proportional mapping in `compute_stagger_positions()` scales dagre coordinates based on `dagre_range / nodesep`, which washes out absolute spacing differences between dummy and real nodes.

Five findings files document this (see `plans/0018-lr-rl-remaining-fixes/findings/01-05`). The key open question: **is mmdflux's proportional stagger mapping an unnecessary intermediate step that dagre.js and Mermaid don't have?**

Preliminary exploration reveals:
- **Dagre.js** uses absolute coordinate assignment (BK → translate to origin) with no grid/stagger mapping
- **Mermaid** uses dagre coordinates directly (`node.x`, `node.y`) with only offset adjustments for subgraph titles
- **mmdflux** adds a layer-grouping → grid-position → stagger-mapping pipeline between dagre output and draw coordinates

This research investigates the details to inform whether mmdflux should adopt direct coordinate translation.

## Questions

### Q1: How does dagre.js translate BK output to final coordinates?

**Where:** `/Users/kevin/src/dagre/lib/position/bk.js`, `position/index.js`, `coordinate-system.js`, `layout.js`
**What:** The exact transformation chain from BK's `place_block()` output to the final `node.x`/`node.y` values. How `edgesep` flows through to final coordinates without being neutralized.
**How:** Trace the code path: `horizontalCompaction()` → `positionX()` → `position()` → `coordinateSystem.undo()` → `translateGraph()`. Document each transformation and whether any step loses the edge_sep distinction.
**Why:** If dagre.js preserves edge_sep effects through to final coordinates, mmdflux's pipeline is adding unnecessary lossy transformations.

**Output file:** `q1-dagre-bk-to-final-coords.md`

---

### Q2: Does Mermaid add any coordinate transformations beyond dagre?

**Where:** `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/layout-algorithms/dagre/index.js`, `rendering-util/rendering-elements/nodes.ts`, `rendering-util/rendering-elements/edges.js`, `diagrams/flowchart/flowRenderer-v3-unified.ts`
**What:** Every transformation Mermaid applies to dagre's output coordinates before SVG rendering. Does it do grid snapping, proportional scaling, or stagger mapping? Does it pass `edgesep` to dagre at all?
**How:** Read the `recursiveRender()` function and trace `node.x`/`node.y` from dagre output to `positionNode()` SVG transform. Read `insertEdge()` to see how `edge.points` are consumed. Check `setGraph()` config for which dagre parameters are passed.
**Why:** Mermaid is the reference consumer of dagre. If Mermaid uses coordinates directly, mmdflux's additional pipeline stages are the likely cause of edge_sep ineffectiveness.

**Output file:** `q2-mermaid-post-dagre-transforms.md`

---

### Q3: What is mmdflux's stagger mapping doing that dagre.js/Mermaid don't?

**Where:** `/Users/kevin/src/mmdflux/src/render/layout.rs` (especially `compute_stagger_positions()`, `compute_layout_dagre()`, `grid_to_draw_horizontal()`, `map_cross_axis()`)
**What:** The exact steps where mmdflux diverges from dagre.js's direct coordinate model. Why does mmdflux group into layers, sort by cross-axis, assign grid positions, then proportionally map back? Is this necessary for ASCII rendering or an artifact of the original grid-based design?
**How:** Compare the mmdflux pipeline step-by-step against dagre.js's pipeline from Q1. Identify which stages are necessary for ASCII constraints (integer coordinates, character cells) and which are unnecessary indirection.
**Why:** This is the core question — understanding whether the stagger mapping is architecturally necessary or whether mmdflux can adopt a more direct translation that preserves edge_sep effects.

**Output file:** `q3-mmdflux-stagger-vs-direct.md`

---

### Q4: Does `compute_stagger_positions()` consider edge_sep, and should it?

**Where:** `/Users/kevin/src/mmdflux/src/render/layout.rs:1034-1157`, `/Users/kevin/src/dagre/lib/position/bk.js:389-425` (dagre's `sep()` function)
**What:** How the proportional mapping formula `target_stagger = (dagre_range / nodesep * (spacing + 2.0))` interacts with edge_sep. Does the formula need to distinguish dummy nodes from real nodes? What would a dummy-aware stagger look like?
**How:** Analyze the formula mathematically. Consider: if dagre produces a range where dummy nodes are closer together (due to edge_sep), but the proportional mapping divides by `nodesep` (which is the real-node separation), the ratio is wrong for dummy-heavy layers. Compute example values for a layer with 2 real nodes + 3 dummy nodes at both edge_sep=20 and edge_sep=2.4.
**Why:** If direct coordinate translation (Q3) isn't feasible for ASCII, making stagger mapping dummy-aware is the alternative fix. Need to know what the correct formula would be.

**Output file:** `q4-stagger-edge-sep-awareness.md`

---

### Q5: What would a direct dagre-to-ASCII coordinate translation look like?

**Where:** All three codebases — dagre.js for the source coordinates, Mermaid for the SVG analogy, mmdflux for ASCII constraints
**What:** A design sketch for replacing mmdflux's layer-grouping/grid-position/stagger-mapping pipeline with direct dagre coordinate translation, adapted for ASCII character cells. What rounding/snapping is needed? How do you handle the fact that ASCII cells are ~2:1 aspect ratio (characters are taller than wide)?
**How:** Take a concrete example (e.g., `fan_in_lr.mmd`), trace the dagre output coordinates, and show how they could be directly mapped to ASCII positions using a simple scale+round approach. Compare the result against the current stagger-based output.
**Why:** This is the actionable output — a concrete proposal for fixing the edge_sep ineffectiveness by eliminating the lossy intermediate steps.

**Output file:** `q5-direct-translation-design.md`

---

## Sources

| Source | Location | Used by |
|--------|----------|---------|
| dagre.js BK implementation | `/Users/kevin/src/dagre/lib/position/bk.js` | Q1, Q4 |
| dagre.js position entry | `/Users/kevin/src/dagre/lib/position/index.js` | Q1 |
| dagre.js coordinate system | `/Users/kevin/src/dagre/lib/coordinate-system.js` | Q1 |
| dagre.js layout orchestration | `/Users/kevin/src/dagre/lib/layout.js` | Q1 |
| Mermaid dagre renderer | `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/layout-algorithms/dagre/index.js` | Q2 |
| Mermaid node positioning | `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/nodes.ts` | Q2 |
| Mermaid edge rendering | `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/edges.js` | Q2 |
| Mermaid flowchart renderer | `/Users/kevin/src/mermaid/packages/mermaid/src/diagrams/flowchart/flowRenderer-v3-unified.ts` | Q2 |
| mmdflux layout pipeline | `/Users/kevin/src/mmdflux/src/render/layout.rs` | Q3, Q4, Q5 |
| mmdflux BK implementation | `/Users/kevin/src/mmdflux/src/dagre/bk.rs` | Q4 |
| Plan 0018 findings | `/Users/kevin/src/mmdflux/plans/0018-lr-rl-remaining-fixes/findings/` | All |

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-dagre-bk-to-final-coords.md` | Q1: Dagre.js BK to final coordinates | Complete |
| `q2-mermaid-post-dagre-transforms.md` | Q2: Mermaid post-dagre transforms | Complete |
| `q3-mmdflux-stagger-vs-direct.md` | Q3: mmdflux stagger vs direct translation | Complete |
| `q4-stagger-edge-sep-awareness.md` | Q4: Stagger mapping edge_sep awareness | Complete |
| `q5-direct-translation-design.md` | Q5: Direct translation design sketch | Complete |
| `synthesis.md` | Combined findings and recommendation | Complete |
