# Research: Subgraph Padding, Borders, and Title Rendering

## Status: SYNTHESIZED

---

## Goal

Understand how mmdflux currently calculates subgraph bounds, renders borders and titles, and identify overlap/clipping issues. Compare with dagre.js and Mermaid's approaches to inform fixes for padding, title placement, and border-edge interactions.

## Context

Plan 0023 implemented single-level subgraph support across all 5 phases (parser, layout core, layout refinement, rendering, integration). The implementation works but has known quality issues:

- Subgraph borders may overlap with adjacent nodes or edges
- Title placement uses a hardcoded 1-row offset above the border
- Padding is a fixed 2-cell constant, not derived from layout config (node_sep/rank_sep)
- Border nodes in dagre have zero dimensions, so layout doesn't account for border thickness
- Edges crossing subgraph boundaries don't route around borders

Prior research (0016-compound-graph-subgraphs) covered the high-level pipeline design but predates the actual implementation. This research drills into the specifics now that we have working code to examine.

## Questions

### Q1: mmdflux subgraph bounds calculation

**Where:** `/Users/kevin/src/mmdflux-subgraphs/src/render/layout.rs` (convert_subgraph_bounds, lines 692-749), `/Users/kevin/src/mmdflux-subgraphs/src/dagre/border.rs` (add_segments, remove_nodes)
**What:** Exact padding values, how bounds derive from member node positions, how border_padding and title_height constants interact with dagre's node_sep/rank_sep, whether the dagre Rect output from remove_nodes is used or ignored
**How:** Read the code path from dagre border node positioning through remove_nodes() through convert_subgraph_bounds(). Trace what _dagre_bounds parameter contains vs what's actually used. Check if border nodes get any width/height that creates layout space.
**Why:** Understanding the current calculation reveals whether padding is consistent with the layout algorithm's spacing or applied as an afterthought that can cause overlap

**Output file:** `q1-bounds-calculation.md`

---

### Q2: mmdflux subgraph title rendering

**Where:** `/Users/kevin/src/mmdflux-subgraphs/src/render/subgraph.rs` (render_subgraph_borders), `/Users/kevin/src/mmdflux-subgraphs/src/render/layout.rs` (SubgraphBounds struct, title_height constant)
**What:** Where the title is placed relative to the border box (currently y-1), what happens when the title is wider than the border, what happens with empty/missing titles, whether title text can collide with nodes or edges above the subgraph
**How:** Read render_subgraph_borders code, trace the title placement logic, construct test cases with wide titles and title-less subgraphs, check for canvas boundary issues
**Why:** Title placement is one of the most visible quality issues — incorrect placement or missing overflow handling creates visual artifacts

**Output file:** `q2-title-rendering.md`

---

### Q3: Overlap and clipping inventory

**Where:** `/Users/kevin/src/mmdflux-subgraphs/` — run the CLI with various subgraph inputs
**What:** Catalog all overlap/clipping scenarios: (a) edges crossing subgraph borders without routing around them, (b) subgraph borders clipping adjacent nodes that are close, (c) title text overlapping with content above the subgraph, (d) multiple subgraphs whose borders collide
**How:** Construct test inputs exercising edge cases — subgraphs with outgoing edges, subgraphs side-by-side, subgraphs with long titles, subgraphs with edges entering from multiple directions. Run `cargo run -q` in `/Users/kevin/src/mmdflux-subgraphs/` and capture output. Also check existing test fixtures in tests/fixtures/ for any subgraph overlap evidence.
**Why:** Need a concrete inventory of what's broken before designing fixes

**Output file:** `q3-overlap-inventory.md`

---

### Q4: dagre.js compound node sizing and padding

**Where:** `/Users/kevin/src/dagre/lib/position.js`, `/Users/kevin/src/dagre/lib/normalize.js`, `/Users/kevin/src/dagre/lib/parent-dummy-chains.js`, `/Users/kevin/src/dagre/lib/nesting-graph.js`, `/Users/kevin/src/dagre/lib/order/add-subgraph-constraints.js`
**What:** How dagre.js assigns dimensions to border nodes (do they get nonzero width/height?), how the `marginx`/`marginy` graph config affects compound padding, how border nodes participate in coordinate assignment, whether dagre produces a bounding rect for compounds or leaves that to the renderer
**How:** Read the dagre.js source focusing on border node creation and dimension assignment. Trace the padding/margin config through position.js. Check if border nodes get synthetic dimensions that force the layout to allocate space.
**Why:** dagre.js is our reference implementation — understanding its padding model reveals what mmdflux should be doing differently

**Output file:** `q4-dagre-compound-sizing.md`

---

### Q5: Mermaid subgraph box and label post-processing

**Where:** `/Users/kevin/src/mermaid/packages/mermaid/src/dagre-wrapper/`, `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/`, `/Users/kevin/src/mermaid/packages/mermaid/src/diagrams/flowchart/`
**What:** How Mermaid extracts subgraph bounds after dagre layout, what padding it adds around the dagre output, how it positions the title label (inside vs outside the box, alignment), how it handles edges that cross subgraph boundaries, whether it adjusts SVG viewbox for subgraph overflow
**How:** Read the Mermaid rendering pipeline for flowcharts, focusing on subgraph-specific code paths. Look for functions like `positionNode`, `insertCluster`, `updateNodeBounds` or similar. Check CSS for subgraph label styling.
**Why:** Mermaid is the upstream reference for visual output — understanding its post-processing reveals the gap between dagre's layout output and the final visual rendering

**Output file:** `q5-mermaid-subgraph-rendering.md`

---

## Sources

| Source | Location | Used by |
|--------|----------|---------|
| mmdflux-subgraphs | `/Users/kevin/src/mmdflux-subgraphs/` | Q1, Q2, Q3 |
| dagre.js | `/Users/kevin/src/dagre/` | Q4 |
| Mermaid | `/Users/kevin/src/mermaid/` | Q5 |
| Prior research 0016 | `/Users/kevin/src/mmdflux/research/0016-compound-graph-subgraphs/` | Q1, Q4, Q5 |

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-bounds-calculation.md` | Q1: mmdflux subgraph bounds calculation | Complete |
| `q2-title-rendering.md` | Q2: mmdflux subgraph title rendering | Complete |
| `q3-overlap-inventory.md` | Q3: Overlap and clipping inventory | Complete |
| `q4-dagre-compound-sizing.md` | Q4: dagre.js compound node sizing and padding | Complete |
| `q5-mermaid-subgraph-rendering.md` | Q5: Mermaid subgraph box and label post-processing | Complete |
| `synthesis.md` | Combined findings | Complete |
