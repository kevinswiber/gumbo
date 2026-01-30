# Research: Architecture & Algorithm Audit — mmdflux vs Mermaid vs Dagre

## Status: SYNTHESIZED

---

## Goal

Audit the fundamental data structures, algorithms, and architectural patterns in mmdflux against Mermaid.js and Dagre.js to identify gaps that would matter for supporting multiple diagram types. Focus on diagram-type-agnostic infrastructure — not SVG rendering specifics.

## Context

mmdflux currently supports only flowchart diagrams. Before adding support for other diagram types (class, sequence, ER, etc.), we need to understand what foundational infrastructure we're missing or have implemented differently. Mermaid.js supports 28+ diagram types and Dagre.js is a general-purpose layout library — both represent mature reference implementations. This audit compares algorithms, data structures, and architectural patterns rather than rendering-specific code.

## Questions

### Q1: Graph Data Structures — What graph representations exist and what capabilities do they provide?

**Where:** mmdflux `src/dagre/graph.rs`, `src/graph/`, Dagre.js `lib/` + `@dagrejs/graphlib`, Mermaid `dagre-wrapper/mermaid-graphlib.js`
**What:** Compare graph data structures: what operations they support (compound/nested graphs, multigraph, node/edge metadata, traversal APIs). Document what graphlib provides that mmdflux's DiGraph does not.
**How:** Read the graph data structure implementations side-by-side. Catalog supported operations, node/edge metadata patterns, and compound graph (cluster/subgraph) support.
**Why:** The graph representation is the foundation everything else builds on. If mmdflux's DiGraph lacks capabilities that other diagram types need (e.g., compound graphs, typed edges, hierarchical grouping), we need to know before building on it.

**Output file:** `q1-graph-data-structures.md`

---

### Q2: Layout Pipeline — What steps does Dagre.js perform that mmdflux skips or implements differently?

**Where:** Dagre.js `lib/layout.js` (27-step pipeline), mmdflux `src/dagre/mod.rs` (layout orchestration), Dagre.js `lib/nesting-graph.js`, `lib/parent-dummy-chains.js`, `lib/add-border-segments.js`, `lib/coordinate-system.js`
**What:** Map each of Dagre.js's 27 pipeline steps to their mmdflux equivalents (or note absence). Specifically investigate: nesting graph construction, parent dummy chains, border segments, coordinate system adjustments, self-edge handling, edge label proxies, and rank normalization.
**How:** Walk through Dagre's `layout()` function step by step. For each step, find the corresponding mmdflux code (or confirm it's missing). Document what each missing step does and whether it's needed for non-flowchart diagram types.
**Why:** Dagre.js has evolved over years of real-world use. Missing steps may represent edge cases or features we'll need for correctness with more complex diagrams.

**Output file:** `q2-layout-pipeline-comparison.md`

---

### Q3: Ranking Algorithms — How do the rank assignment strategies compare?

**Where:** mmdflux `src/dagre/rank.rs`, Dagre.js `lib/rank/` (network-simplex.js, feasible-tree.js, util.js)
**What:** Compare mmdflux's longest-path ranking with Dagre's network simplex algorithm. Document what network simplex provides (optimal rank assignment minimizing total edge length) vs. longest-path (simpler but suboptimal). Also check if Dagre supports alternative ranking strategies.
**How:** Read both implementations. Understand the mathematical formulation of network simplex for ranking. Identify cases where longest-path produces suboptimal layouts compared to network simplex.
**Why:** Ranking quality directly affects layout compactness and visual clarity. Network simplex is the standard algorithm in the Sugiyama framework literature and may be necessary for good layouts of complex diagrams.

**Output file:** `q3-ranking-algorithms.md`

---

### Q4: Crossing Reduction — How do the ordering/crossing-reduction implementations compare?

**Where:** mmdflux `src/dagre/order.rs`, Dagre.js `lib/order/` (9 files: index.js, barycenter.js, sort-subgraph.js, resolve-conflicts.js, add-subgraph-constraints.js, cross-count.js, build-layer-graph.js, init-order.js, sort.js)
**What:** Compare crossing reduction approaches. mmdflux uses a barycenter heuristic — Dagre has 9 files for this phase including subgraph-aware sorting, conflict resolution, and constraint handling. Document what the extra complexity in Dagre buys.
**How:** Read both implementations. Map Dagre's subgraph constraints, conflict resolution, and multi-pass strategy against mmdflux's simpler approach. Identify what's needed for compound graphs vs. simple graphs.
**Why:** Crossing reduction is the most impactful visual quality step. Understanding Dagre's more sophisticated approach tells us what we'd need for compound/nested diagram types.

**Output file:** `q4-crossing-reduction.md`

---

### Q5: Coordinate Assignment (Brandes-Köpf) — How do the implementations diverge?

**Where:** mmdflux `src/dagre/bk.rs` (2,288 LOC), Dagre.js `lib/position/bk.js`, mmdflux `src/dagre/position.rs`
**What:** Compare the Brandes-Köpf implementations. mmdflux's is significantly larger (2,288 LOC vs ~300 LOC in Dagre). Document what additional logic mmdflux includes (block graph compaction? grid quantization? special handling?). Identify algorithmic differences.
**How:** Read both implementations focusing on the four alignment passes, conflict detection, block placement, and compaction. Note any extensions or modifications in either implementation.
**Why:** Coordinate assignment determines final node positions. mmdflux's much larger implementation suggests significant divergence that should be understood — especially the block graph compaction work from recent plans.

**Output file:** `q5-coordinate-assignment.md`

---

### Q6: Mermaid's Diagram Plugin Architecture — What shared infrastructure supports multiple diagram types?

**Where:** Mermaid `src/diagram-api/`, `src/diagrams/common/`, `src/rendering-util/`, `src/Diagram.ts`, `src/config.ts`
**What:** Document Mermaid's diagram registration system, the DiagramDefinition interface (parser/db/renderer/detector), shared types (commonTypes.ts, commonDb.ts), and rendering utilities. Identify which pieces are diagram-type-agnostic infrastructure vs. flowchart-specific.
**How:** Read the diagram-api module, common types, and at least 2-3 different diagram type implementations (flowchart, class, ER) to understand what they share vs. what's unique.
**Why:** If mmdflux wants to support multiple diagram types, understanding Mermaid's plugin architecture reveals what abstractions are needed. This is the highest-level architectural question.

**Output file:** `q6-diagram-plugin-architecture.md`

---

### Q7: Edge Routing and Label Positioning — How do approaches compare across rendering targets?

**Where:** mmdflux `src/render/router.rs`, `src/render/edge.rs`, `src/render/intersect.rs`, Dagre.js `lib/layout.js` (assignNodeIntersects, positionSelfEdges), Mermaid `src/rendering-util/rendering-elements/edges.js`, `src/dagre-wrapper/edges.js`
**What:** Compare edge routing strategies: waypoint generation, node intersection calculation, self-loop handling, label placement on edges. Document what's rendering-target-specific vs. algorithmic.
**How:** Read edge routing code in all three codebases. Separate the algorithmic parts (waypoint computation, intersection math, label positioning logic) from the rendering parts (SVG path generation, ASCII line drawing).
**Why:** Edge routing algorithms are diagram-type-agnostic. Understanding the full algorithmic scope helps identify what mmdflux might need for non-flowchart edge types (e.g., association lines in class diagrams, message arrows in sequence diagrams).

**Output file:** `q7-edge-routing-labels.md`

---

## Sources

| Source | Location | Used by |
|--------|----------|---------|
| mmdflux (Rust) | `/Users/kevin/src/mmdflux/src/` | Q1-Q5, Q7 |
| Dagre.js | `/Users/kevin/src/dagre/lib/` | Q1-Q5, Q7 |
| Mermaid.js | `/Users/kevin/src/mermaid/packages/mermaid/src/` | Q1, Q6, Q7 |
| graphlib (@dagrejs) | Via Dagre.js dependency | Q1 |

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-graph-data-structures.md` | Q1: Graph Data Structures | Complete |
| `q2-layout-pipeline-comparison.md` | Q2: Layout Pipeline | Complete |
| `q3-ranking-algorithms.md` | Q3: Ranking Algorithms | Complete |
| `q4-crossing-reduction.md` | Q4: Crossing Reduction | Complete |
| `q5-coordinate-assignment.md` | Q5: Coordinate Assignment | Complete |
| `q6-diagram-plugin-architecture.md` | Q6: Diagram Plugin Architecture | Complete |
| `q7-edge-routing-labels.md` | Q7: Edge Routing & Labels | Complete |
| `synthesis.md` | Combined findings | Complete |
