# Research Synthesis: Architecture & Algorithm Audit — mmdflux vs Mermaid vs Dagre

## Summary

mmdflux faithfully implements the core Sugiyama layout pipeline (acyclic, rank, normalize, order, position) with results equivalent to Dagre.js for flat (non-compound) flowcharts. The single largest architectural gap is compound graph support — subgraphs/clusters require changes to the graph data structure and at least 6 additional pipeline steps, all tightly interdependent. The second most impactful gap is the ranking algorithm: mmdflux uses longest-path (fast but suboptimal) while Dagre.js uses network simplex (optimal). For multi-diagram support, Mermaid's architecture reveals that the essential abstraction is a universal layout data format (nodes + edges + config) shared across diagram types, with surprisingly thin shared infrastructure beyond that.

## Key Findings

### 1. Compound Graph Support Is the Dominant Gap

Compound graphs (subgraphs/clusters) are not just a data structure addition — they require coordinated changes across 6+ pipeline phases: nesting graph construction, parent dummy chains, border segments, rank min/max assignment, subgraph-aware crossing reduction, and border node removal. The graph data structure itself needs parent-child relationships, node/edge removal, and O(1) adjacency queries (currently O(|E|) linear scan). This is the single largest architectural difference between mmdflux and Dagre.js, touching Q1, Q2, Q4, and Q5.

### 2. Core Algorithms Are Equivalent for Flat Graphs

For non-compound flowcharts, mmdflux produces equivalent results to Dagre.js across all Sugiyama phases:
- **Crossing reduction** (Q4): Same DFS init, alternating barycenter sweeps, best-order tracking
- **Coordinate assignment** (Q5): Same Brandes-Kopf four-pass algorithm, block graph compaction (aligned by Plan 0022)
- **Normalization**: Same dummy node chain approach for long edges
- **Acyclic**: Same DFS-based cycle removal (mmdflux uses logical reversal tracking instead of physical edge reversal)

### 3. Ranking Quality Is the Most Impactful Algorithm Gap

mmdflux's longest-path ranking (Q3) pushes all nodes to the lowest possible rank, producing unnecessarily long edges and more dummy nodes. Dagre.js's network simplex minimizes total weighted edge length — the standard optimal algorithm from the Sugiyama literature. The practical impact is most visible in graphs with loosely connected components, asymmetric fan patterns, or multiple paths of different lengths. A tight-tree intermediate ranker exists in Dagre.js that could be a pragmatic first improvement.

### 4. Two Concrete Performance/Quality Gaps in Crossing Reduction

Even for flat graphs, mmdflux has two measurable gaps (Q4):
1. **O(E^2) cross counting** vs Dagre's O(E log V) accumulator tree (Barth et al.)
2. **Unweighted cross counting** while using weighted barycenters — a mismatch between the optimization target and sorting signal

### 5. Self-Edge Handling Is Missing

Self-loops (A --> A) are treated as back-edges in mmdflux, producing incorrect visual results (Q2). Dagre.js has 3 coordinated pipeline steps: remove before layout, insert positioned dummy after ordering, generate 5-point loop path after positioning. This is the most notable correctness gap for current functionality.

### 6. Edge Routing Is Mostly Diagram-Type-Agnostic

The waypoint generation, node intersection, and label positioning algorithms work unchanged across diagram types (Q7). mmdflux's ASCII-specific innovations — attachment point spreading, orthogonal path construction, backward edge routing — solve real problems unique to character-grid rendering. The main algorithmic improvement would be adopting Dagre's label-as-dummy-node approach to replace the current heuristic label placement.

### 7. Multi-Diagram Architecture Requires Minimal New Abstraction

Mermaid's plugin architecture (Q6) reveals that the essential contract is four functions: detect (regex), parse (text → data model), build layout data (data model → nodes + edges), and render (layout → output). The shared infrastructure is surprisingly thin: just a common DB mixin for titles, text sanitization, and the unified Node/Edge type. A Rust `DiagramType` trait with `detect`/`parse`/`to_layout_graph` methods would capture the essential abstraction.

## Recommendations

1. **Implement network simplex ranking** — This is the highest-impact algorithm improvement. Start with the tight-tree intermediate ranker for a simpler first step, then add the full pivot loop. Requires adding `minlen` support to edges.

2. **Add self-edge handling** — Three coordinated steps: remove self-edges before layout, create positioned dummies after ordering, render loop paths. This fixes a current correctness issue.

3. **Defer compound graph support** — This is the largest single effort (data structure + 6 pipeline phases). Defer until subgraph rendering is explicitly needed. When undertaken, consider whether Rust's type system can enforce compound-ness at compile time rather than runtime.

4. **Upgrade cross-counting to O(E log V)** — Implement the Barth et al. accumulator tree algorithm and switch to weighted cross counting. Improves both performance and quality.

5. **Adopt label-as-dummy-node** — Replace heuristic label placement with Dagre's approach of giving labels width/height during layout. Eliminates post-hoc collision avoidance.

6. **Design multi-diagram trait** — When ready to add a second diagram type, define a `DiagramType` trait based on Mermaid's four-function contract. The existing `Diagram` struct becomes the flowchart implementation. Start with a simple second type (class diagram or ER) that reuses the Sugiyama layout pipeline.

7. **Consider coordinate system transform pattern** — Dagre.js uses adjust/undo transforms so the position algorithm is direction-agnostic. mmdflux's separate vertical/horizontal code paths work but duplicate logic. A transform approach would be more maintainable as features grow.

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | mmdflux `src/dagre/` implements core Sugiyama; Dagre.js `lib/` adds compound graph + network simplex + O(E log V) crossing; Mermaid `src/diagram-api/` provides plugin architecture |
| **What** | 8 core pipeline steps implemented, 21 missing (6 compound, 3 self-edge, 4 label infra, 2 coord system, 6 misc). Longest-path ranking vs optimal network simplex. O(E^2) vs O(E log V) cross counting. |
| **How** | Same algorithmic foundations (Sugiyama, Brandes-Kopf, barycenter heuristic). mmdflux adds ASCII-specific innovations (attachment spreading, orthogonalization, backward routing). Dagre adds compound-graph-specific machinery. |
| **Why** | mmdflux was purpose-built for flat flowcharts — the simplifications are appropriate for that scope. Compound graphs and network simplex are needed for broader diagram support and better layout quality respectively. |

## Open Questions

- Should compound graph support use Dagre's nesting-graph approach or explore alternatives (e.g., layout each subgraph independently, then compose)?
- Would a Rust `CompoundDiGraph` type be better than extending `DiGraph<N>` with optional parent-child maps?
- Is the tight-tree ranker sufficient for mmdflux's typical diagrams, or is full network simplex necessary?
- Should mmdflux adopt the coordinate system transform/un-transform pattern before adding more features?
- What is the minimal viable second diagram type to validate the plugin architecture?
- How should edge `minlen` be exposed — implicit from diagram semantics, or configurable?

## Next Steps

- [ ] Create implementation plan for network simplex ranking (or tight-tree as intermediate step)
- [ ] Create implementation plan for self-edge handling (3 pipeline steps)
- [ ] Create implementation plan for O(E log V) weighted cross counting
- [ ] Create implementation plan for label-as-dummy-node edge label positioning
- [ ] File issues for the algorithmic gaps identified (conflict detection efficiency, `has_conflict` O(1) lookup, `labelpos` support)
- [ ] When multi-diagram support is scoped, design `DiagramType` trait based on Q6 findings

## Source Files

| File | Question |
|------|----------|
| `q1-graph-data-structures.md` | Q1: Graph Data Structures |
| `q2-layout-pipeline-comparison.md` | Q2: Layout Pipeline Comparison |
| `q3-ranking-algorithms.md` | Q3: Ranking Algorithms |
| `q4-crossing-reduction.md` | Q4: Crossing Reduction |
| `q5-coordinate-assignment.md` | Q5: Coordinate Assignment (Brandes-Kopf) |
| `q6-diagram-plugin-architecture.md` | Q6: Mermaid's Diagram Plugin Architecture |
| `q7-edge-routing-labels.md` | Q7: Edge Routing & Labels |
