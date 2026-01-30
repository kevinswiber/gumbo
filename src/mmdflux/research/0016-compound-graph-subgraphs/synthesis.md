# Research Synthesis: Compound Graph (Subgraph) Support

## Summary

Adding compound graph support to mmdflux requires coordinated changes across all four pipeline stages: Parser, Graph, Layout, and Render. The investigation reveals a well-understood problem space -- Mermaid's subgraph syntax is straightforward, dagre.js's compound pipeline is proven and well-documented, and mmdflux's architecture cleanly separates concerns at each stage. The core complexity lies in the dagre layout pipeline, which needs 5 new phases interspersed with existing Sugiyama phases, plus modifications to ordering and BK positioning. The parser and graph layer changes are relatively small; rendering requires a new pass but follows naturally from the layout output.

## Key Findings

### 1. Mermaid Subgraph Syntax is Well-Defined

Mermaid supports three subgraph notations (`subgraph id[title]`, `subgraph title`, anonymous `subgraph`), nested to arbitrary depth. Edges cross boundaries freely with no special syntax. The parser produces a flat list of `FlowSubGraph` objects with node membership lists; parent-child nesting is implicit. Direction overrides within subgraphs are supported but have inheritance limitations. Auto-ID generation handles anonymous and multi-word-title cases.

### 2. dagre.js Compound Pipeline is Proven and Maps Cleanly to mmdflux

dagre.js implements compound graphs through phases strategically inserted into the Sugiyama pipeline:
- **Before ranking:** Nesting graph setup (weighted edges bias ranking to keep children contiguous)
- **After ranking:** Rank constraint extraction (minRank/maxRank per compound node)
- **After normalization:** Parent dummy chain assignment (LCA-based) + border segment creation
- **During ordering:** Compound-aware constraints (nodes can't cross parent boundaries)
- **During positioning:** BK Pass 2 borderType guard (prevents border node misplacement)
- **After positioning:** Border removal with bounding box extraction

The pipeline is conditional -- simple graphs skip all compound phases with no overhead.

### 3. Parser Extension is Minimal

The pest PEG grammar needs one new rule (`subgraph_stmt`) added to the `statement` alternative, plus a `subgraph_spec` rule for the ID/title header. The AST gains a `Subgraph` struct with `id`, `title`, and recursive `Vec<Statement>`. Pest's right-recursive pattern handles arbitrary nesting naturally. The parser auto-generates IDs for anonymous subgraphs. Total change: ~30 lines of grammar, ~20 lines of AST types, ~50 lines of parser logic.

### 4. Graph Layer Needs Two-Tier Compound Representation

The recommended design adds `parent: Option<String>` to Node and a `Subgraph` struct (id, title, nodes, parent) to Diagram. This mirrors graphlib's compound API with O(1) parent lookup and O(1) children lookup. Edges remain abstract at the graph layer; subgraph-targeting edges are resolved to border nodes during layout. The builder flattens the recursive AST into this structure in a single traversal.

### 5. Layout Pipeline is the Primary Complexity

Five new phases must be added to the dagre pipeline, three new modules created (`nesting.rs`, `border.rs`, `parent_dummies.rs`), and LayoutGraph/DiGraph extended with ~8 new fields. The ordering phase needs hierarchy-respecting constraints, and BK needs the borderType guard. The nesting graph tree traversal and LCA computation in parent dummy chains are the most algorithmically complex additions.

### 6. Rendering Follows Naturally from Layout

Subgraph borders render as labeled rectangles drawn BEFORE nodes and edges (z-ordering via render sequence). The Layout struct gains `subgraph_bounds`, the Canvas gains `is_subgraph_border` cell flag, and a new render pass inserts between canvas creation and node rendering. Thin box-drawing characters distinguish subgraph borders from node borders. Labels go outside the top-left corner.

## Recommendations

1. **Follow dagre.js's pipeline exactly** -- The compound pipeline is proven across thousands of projects. Copy the phase order, insertion points, and guard conditions. Deviating risks subtle layout bugs.

2. **Implement incrementally in 4 phases:**
   - **Phase A: Parser + Graph** -- Add subgraph parsing and Diagram representation. Test with fixture files. No layout/render changes yet.
   - **Phase B: Layout core** -- Add nesting graph, border segments, rank constraints. Get basic compound layout working with flat output (no visual borders yet).
   - **Phase C: Layout refinement** -- Add parent dummy chains, compound-aware ordering, BK borderType guard. Handle edge cases (nested subgraphs, boundary-crossing edges).
   - **Phase D: Rendering** -- Add subgraph border rendering, label placement, canvas changes.

3. **Gate all compound logic on `has_compound_nodes()`** -- Zero overhead for simple graphs. This preserves existing test suite behavior exactly.

4. **Use recursive AST, flatten in builder** -- The parser produces a tree (natural for pest PEG); the builder flattens to the layout-friendly representation. Clean separation.

5. **Start with single-level subgraphs** -- Defer nested subgraph support to a follow-up. Single-level exercises all pipeline phases without the LCA complexity in parent dummy chains.

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | All 4 pipeline stages: `src/parser/` (grammar + AST), `src/graph/` (Diagram + builder), `src/dagre/` (5 new phases + 3 modifications), `src/render/` (new border pass) |
| **What** | Subgraph syntax parsing, compound graph representation, 5 new layout phases (nesting, minmax, parent dummies, borders, removal), border rendering with z-order |
| **How** | Recursive PEG grammar -> flat Diagram with parent refs -> dagre compound pipeline (nesting edges bias ranking, border nodes constrain ordering, BK guard prevents misplacement) -> render borders first on canvas |
| **Why** | Matches dagre.js's proven approach; recursive AST mirrors syntax; two-tier graph enables O(1) lookups; render-order z-layering is the only option for terminal grids |

## Open Questions

- **Direction overrides within subgraphs** -- Mermaid supports `direction TD` inside a subgraph. How should this interact with mmdflux's layout? Likely deferred to a follow-up.
- **Subgraph-to-subgraph edges** -- Mermaid allows edges targeting subgraph IDs. Resolution to border nodes during layout is the right approach, but edge routing details need design.
- **Deeply nested subgraphs (3+ levels)** -- LCA computation complexity and visual padding/spacing at deep nesting need practical testing.
- **Empty subgraphs** -- Should be allowed but need graceful rendering (border with no contents).
- **Edge routing through subgraph borders** -- Should edges avoid borders (like nodes) or pass through? Current design: pass through (borders are not `is_node`).

## Next Steps

- [ ] Create implementation plan (`/plan:create`) based on this research, targeting Phase A (parser + graph) first
- [ ] Add test fixtures for subgraph syntax: `simple_subgraph.mmd`, `nested_subgraph.mmd`, `subgraph_edges.mmd`
- [ ] Prototype grammar extension in `grammar.pest` to validate pest handles the recursive structure
- [ ] Design the LayoutResult extension to expose subgraph bounds to the rendering layer
- [ ] Investigate whether dagre.js's nesting graph weight calculation can be simplified for single-level subgraphs

## Source Files

| File | Question |
|------|----------|
| `q1-mermaid-subgraph-syntax.md` | Q1: Mermaid subgraph syntax and parsing |
| `q2-dagre-compound-pipeline.md` | Q2: dagre.js compound graph layout pipeline |
| `q3-parser-extension-design.md` | Q3: mmdflux parser extension design |
| `q4-graph-layer-design.md` | Q4: Graph layer changes for compound structure |
| `q5-dagre-pipeline-changes.md` | Q5: Dagre layout pipeline changes for compound graphs |
| `q6-rendering-pipeline-changes.md` | Q6: Rendering pipeline changes for subgraph borders |
