# Research: Compound Graph (Subgraph) Support

## Status: SYNTHESIZED

---

## Goal

Investigate everything needed to add compound graph (subgraph) support to mmdflux. Mermaid's `subgraph ... end` syntax groups nodes into visual clusters with labeled borders. dagre.js has full compound graph support via graphlib's compound mode, including border node generation, rank constraint propagation, and nested layout. mmdflux currently has no concept of subgraphs — its parser, graph builder, and layout pipeline all operate on flat node/edge graphs.

This research will produce a complete understanding of the problem space across all layers: parsing, graph representation, layout algorithm, and rendering.

## Context

- mmdflux renders Mermaid flowcharts as terminal text using a 4-stage pipeline: Parser → Graph → Layout → Render
- The parser grammar (`grammar.pest`) has no `subgraph` keyword; the AST has no `Subgraph` type
- The `Diagram` struct uses a flat `HashMap<String, Node>` with no parent-child relationships
- The dagre layout pipeline implements phases 1-4 of Sugiyama (acyclic, rank, normalize, order, position) but none of the compound-graph phases (nesting graph, border segments, rank constraints)
- Prior research (0015-q2) confirmed that dagre.js's `borderType` guard in BK Pass 2 is compound-graph-only and currently irrelevant in mmdflux
- The original architecture (research/archive/0000) planned `subgraphs: Vec<Subgraph>` in the Diagram struct but never implemented it

## Questions

### Q1: Mermaid subgraph syntax and parsing

**Where:** mermaid-js source (`/Users/kevin/src/mermaid/packages/mermaid/src/diagrams/flowchart/`), Mermaid documentation online
**What:** Full subgraph syntax including: `subgraph id [title]`, nesting, edges crossing boundaries, subgraph-to-subgraph edges, direction overrides within subgraphs, implicit vs explicit IDs. What AST representation does mermaid-js produce?
**How:** Read the mermaid-js parser/grammar for flowcharts, trace how subgraph blocks are parsed into the internal graph representation. Document edge cases: deeply nested subgraphs, edges from inside to outside, edges targeting the subgraph itself.
**Why:** We need precise syntax knowledge to extend mmdflux's PEG grammar correctly. Edge cases determine how the graph builder must handle boundary-crossing edges.

**Output file:** `q1-mermaid-subgraph-syntax.md`

---

### Q2: dagre.js compound graph layout pipeline

**Where:** `/Users/kevin/src/dagre/lib/` — `layout.js`, `add-border-segments.js`, `nesting-graph.js`, `util.js`, `parent-dummy-chains.js`, `rank/util.js`; also `/Users/kevin/src/dagre/lib/order/` for compound-aware ordering
**What:** Complete compound graph pipeline: how graphlib represents parent-child relationships, how `nestingGraph.run()` builds the nesting hierarchy, how `addBorderSegments` creates border nodes with `borderType`, how ranks are constrained within subgraphs (`assignRankMinMax`), how the ordering phase handles compound nodes, how `parentDummyChains` assigns dummies to correct compound parents, and how `removeBorderNodes` cleans up after positioning.
**How:** Trace the dagre.js `layout()` function step by step for compound graph paths. Read each compound-related module. Cross-reference with prior findings in research/0015-q2.
**Why:** dagre.js is our reference implementation. Understanding its compound graph pipeline precisely tells us what phases to add to mmdflux's dagre module and how they interact with existing phases.

**Output file:** `q2-dagre-compound-pipeline.md`

---

### Q3: mmdflux parser extension design

**Where:** `/Users/kevin/src/mmdflux/src/parser/grammar.pest`, `/Users/kevin/src/mmdflux/src/parser/ast.rs`, `/Users/kevin/src/mmdflux/src/parser/flowchart.rs`
**What:** What grammar rules are needed for `subgraph ... end` blocks? What AST types must be added? How should nested subgraphs be represented — recursive `Statement` containing `Subgraph` variants, or flat list with parent references? How does the pest PEG parser handle the recursive/nested structure?
**How:** Review the current grammar and AST, then design the minimal extension. Consider pest's capabilities for recursive rules. Look at how mermaid-js structures its AST for comparison.
**Why:** The parser is the entry point — getting the grammar and AST right determines the data available to all downstream stages. Pest PEG has specific constraints on recursion that may influence the design.

**Output file:** `q3-parser-extension-design.md`

---

### Q4: Graph layer changes for compound structure

**Where:** `/Users/kevin/src/mmdflux/src/graph/diagram.rs`, `/Users/kevin/src/mmdflux/src/graph/node.rs`, `/Users/kevin/src/mmdflux/src/graph/edge.rs`, `/Users/kevin/src/mmdflux/src/graph/builder.rs`
**What:** What data structures represent parent-child relationships? Options: `parent: Option<String>` on Node, separate `Subgraph` struct with children list, or both. How should `build_diagram` handle subgraph membership? How are edges that cross subgraph boundaries represented? Should edges targeting a subgraph ID be resolved to border nodes or kept abstract?
**How:** Review current graph structures, compare with graphlib's compound graph model, and design the minimal Rust representation. Consider how the graph layer feeds into dagre layout.
**Why:** The graph layer bridges parsing and layout. The compound graph representation must support both the parser's output and the layout algorithm's input requirements.

**Output file:** `q4-graph-layer-design.md`

---

### Q5: Dagre layout pipeline changes for compound graphs

**Where:** `/Users/kevin/src/mmdflux/src/dagre/mod.rs`, `/Users/kevin/src/mmdflux/src/dagre/graph.rs`, `/Users/kevin/src/mmdflux/src/dagre/rank.rs`, `/Users/kevin/src/mmdflux/src/dagre/order.rs`, `/Users/kevin/src/mmdflux/src/dagre/position.rs`, `/Users/kevin/src/mmdflux/src/dagre/bk.rs`
**What:** What new phases are needed (nesting graph, border segments, rank constraints, parent dummy chains, border removal)? Where in the existing pipeline do they insert? What changes are needed to existing phases — does ordering need compound-awareness? Does BK need the borderType guard (already documented in 0015-q2)? What changes to `LayoutGraph` and `DiGraph` are needed?
**How:** Map dagre.js's compound pipeline onto mmdflux's existing pipeline. Identify each insertion point and each modification to existing phases. Reference the Q2 findings for dagre.js's pipeline details.
**Why:** The layout pipeline is the most complex part. Understanding exactly what changes are needed — and what can remain unchanged — determines the implementation scope and risk.

**Output file:** `q5-dagre-pipeline-changes.md`

---

### Q6: Rendering pipeline changes for subgraph borders

**Where:** `/Users/kevin/src/mmdflux/src/render/layout.rs`, `/Users/kevin/src/mmdflux/src/render/canvas.rs`, `/Users/kevin/src/mmdflux/src/render/shape.rs`, `/Users/kevin/src/mmdflux/src/render/chars.rs`, `/Users/kevin/src/mmdflux/src/render/edge.rs`
**What:** How should subgraph borders be drawn — labeled rectangles around node clusters? What box-drawing characters for subgraph borders (same as nodes, or distinct like thin lines)? How does the canvas handle overlapping rectangles (subgraph borders behind node shapes and edges)? What rendering order is needed? How does `compute_layout()` need to change to provide subgraph bounding box information?
**How:** Review the current rendering pipeline, understand the canvas model (2D character grid), and design the subgraph border rendering approach. Consider z-ordering: subgraph borders must render behind nodes and edges. Look at how other terminal tools render grouped boxes.
**Why:** Rendering is the user-visible output. Getting subgraph borders right — with proper labels, spacing, and layering — is critical for usability. Terminal rendering has unique constraints (character grid, no true overlapping).

**Output file:** `q6-rendering-pipeline-changes.md`

---

## Sources

| Source | Location | Used by |
|--------|----------|---------|
| mermaid-js flowchart parser | `/Users/kevin/src/mermaid/packages/mermaid/src/diagrams/flowchart/` | Q1 |
| dagre.js layout | `/Users/kevin/src/dagre/lib/` | Q2, Q5 |
| mmdflux parser | `/Users/kevin/src/mmdflux/src/parser/` | Q3 |
| mmdflux graph layer | `/Users/kevin/src/mmdflux/src/graph/` | Q4 |
| mmdflux dagre layout | `/Users/kevin/src/mmdflux/src/dagre/` | Q5 |
| mmdflux render layer | `/Users/kevin/src/mmdflux/src/render/` | Q6 |
| Prior research 0015-q2 | `research/0015-bk-block-graph-divergence/q2-border-type-guard.md` | Q2, Q5 |
| Prior research 0000 | `research/archive/0000-initial-research/synthesis.md` | Q4 |
| Prior research 0010 | `research/archive/0010-attachment-spreading-revisited/prior-research/dagre-edge-points-analysis.md` | Q2, Q5 |

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-mermaid-subgraph-syntax.md` | Q1: Mermaid subgraph syntax and parsing | Complete |
| `q2-dagre-compound-pipeline.md` | Q2: dagre.js compound graph layout pipeline | Complete |
| `q3-parser-extension-design.md` | Q3: mmdflux parser extension design | Complete |
| `q4-graph-layer-design.md` | Q4: Graph layer changes for compound structure | Complete |
| `q5-dagre-pipeline-changes.md` | Q5: Dagre layout pipeline changes for compound graphs | Complete |
| `q6-rendering-pipeline-changes.md` | Q6: Rendering pipeline changes for subgraph borders | Complete |
| `synthesis.md` | Combined findings | Complete |
