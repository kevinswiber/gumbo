# Q1: Graph Data Structures

## Summary

Graphlib (used by Dagre.js and Mermaid) provides a single unified `Graph` class supporting three orthogonal capabilities -- directed/undirected, multigraph (parallel edges with names), and compound (hierarchical parent-child nesting) -- with rich metadata on nodes, edges, and the graph itself. mmdflux has two separate, simpler graph structures: `src/graph/` (domain model with typed nodes/edges) and `src/dagre/graph.rs` (layout-focused `DiGraph` and `LayoutGraph`). Neither mmdflux structure supports compound graphs, multigraphs, node/edge removal, or the dynamic metadata pattern that dagre.js relies on heavily for its layout pipeline.

## Where

Sources consulted:

- **mmdflux domain graph**: `/Users/kevin/src/mmdflux/src/graph/diagram.rs`, `node.rs`, `edge.rs`, `builder.rs`
- **mmdflux layout graph**: `/Users/kevin/src/mmdflux/src/dagre/graph.rs`, `types.rs`, `normalize.rs`
- **graphlib (Graph class)**: `/Users/kevin/src/dagre/node_modules/@dagrejs/graphlib/lib/graph.js`
- **graphlib algorithms**: `/Users/kevin/src/dagre/node_modules/@dagrejs/graphlib/lib/alg/index.js`
- **Dagre.js layout**: `/Users/kevin/src/dagre/lib/layout.js`, `nesting-graph.js`, `normalize.js`, `parent-dummy-chains.js`, `add-border-segments.js`, `util.js`, `order/sort-subgraph.js`
- **Mermaid mermaid-graphlib**: `/Users/kevin/src/mermaid/packages/mermaid/src/dagre-wrapper/mermaid-graphlib.js`

## What

### Side-by-Side Operation Catalog

| Operation | graphlib `Graph` | mmdflux `DiGraph<N>` | mmdflux `LayoutGraph` | mmdflux `Diagram` |
|---|---|---|---|---|
| **Add node** | `setNode(v, label)` | `add_node(id, data)` | Built from DiGraph | `add_node(node)` |
| **Remove node** | `removeNode(v)` (cascading edge removal) | Not supported | Not supported | Not supported |
| **Get node data** | `node(v)` -> any JS object | `get_node(id)` -> `&N` | By index into `node_ids`/`dimensions` | `get_node(id)` -> `&Node` |
| **Has node** | `hasNode(v)` | Implicit via `node_index` | Implicit via `node_index` | Implicit via `HashMap` |
| **List nodes** | `nodes()` -> `[string]` | `node_ids()` / `nodes()` | `node_ids: Vec<NodeId>` | `node_ids()` |
| **Add edge** | `setEdge(v, w, label, name)` | `add_edge(from, to)` | Built from DiGraph | `add_edge(edge)` |
| **Remove edge** | `removeEdge(v, w, name)` | Not supported | Not supported | Not supported |
| **Get edge data** | `edge(v, w, name)` -> any JS object | Not supported (edges are `(NodeId, NodeId)`) | Via `edges[idx]`, `edge_weights[idx]` | By index into `edges: Vec<Edge>` |
| **List edges** | `edges()` -> `[{v, w, name}]` | `edges()` -> `&[(NodeId, NodeId)]` | `edges: Vec<(usize, usize, usize)>` | `edges: Vec<Edge>` |
| **In-edges** | `inEdges(v, u?)` -> filtered edge objs | Not supported directly | Not supported directly | Not supported |
| **Out-edges** | `outEdges(v, w?)` -> filtered edge objs | Not supported directly | Not supported directly | Not supported |
| **Successors** | `successors(v)` | `successors(id)` (linear scan) | Via `effective_edges()` | Not supported |
| **Predecessors** | `predecessors(v)` | `predecessors(id)` (linear scan) | Via `effective_edges()` | Not supported |
| **Neighbors** | `neighbors(v)` (union of pred+succ) | Not supported | Not supported | Not supported |
| **In-degree** | Via `inEdges(v).length` | `in_degree(id)` (linear scan) | Not supported | Not supported |
| **Out-degree** | Via `outEdges(v).length` | `out_degree(id)` (linear scan) | Not supported | Not supported |
| **Sources** | `sources()` (nodes with 0 in-edges) | Not supported | Not supported | Not supported |
| **Sinks** | `sinks()` (nodes with 0 out-edges) | Not supported | Not supported | Not supported |
| **Graph label** | `setGraph(label)` / `graph()` | Not supported | Not supported | `direction` field |
| **Filter nodes** | `filterNodes(fn)` | Not supported | Not supported | Not supported |
| **Set path** | `setPath(vs, value)` | Not supported | Not supported | Not supported |
| **Multigraph** | `setEdge(v, w, label, name)` with named edges | Not supported | Not supported | Not supported |
| **Compound: setParent** | `setParent(v, parent)` | Not supported | Not supported | Not supported |
| **Compound: parent** | `parent(v)` | Not supported | Not supported | Not supported |
| **Compound: children** | `children(v?)` | Not supported | Not supported | Not supported |
| **isLeaf** | `isLeaf(v)` | Not supported | Not supported | Not supported |
| **Directed/undirected** | Constructor flag `directed` | Always directed | Always directed | Always directed |

### Node/Edge Metadata Patterns

**graphlib**: Nodes and edges carry arbitrary JS objects as labels. The layout pipeline mutates these in-place, adding properties like `rank`, `order`, `x`, `y`, `width`, `height`, `dummy`, `borderTop`, `borderBottom`, `borderLeft`, `borderRight`, `edgeLabel`, `edgeObj`, `selfEdges`, etc. Edge labels include `weight`, `minlen`, `labelpos`, `labeloffset`, `width`, `height`, `points`. The graph itself carries a label with `rankdir`, `ranksep`, `nodesep`, `edgesep`, `marginx`, `marginy`, `acyclicer`, `ranker`, `nestingRoot`, `nodeRankFactor`, `dummyChains`, `maxRank`.

**mmdflux DiGraph<N>**: Nodes carry a generic type `N` (typically `(f64, f64)` for dimensions). Edges are bare `(NodeId, NodeId)` pairs with no metadata at all.

**mmdflux LayoutGraph**: Uses parallel vectors for all layout data: `ranks: Vec<i32>`, `order: Vec<usize>`, `positions: Vec<Point>`, `dimensions: Vec<(f64, f64)>`, `edge_weights: Vec<f64>`. Dummy node info stored in separate `HashMap<NodeId, DummyNode>` and `Vec<DummyChain>`. This is a struct-of-arrays design vs. graphlib's array-of-structs (object-per-node).

**mmdflux Diagram**: Nodes carry typed `Node` structs (id, label, shape). Edges carry typed `Edge` structs (from, to, label, stroke, arrow). This is the domain model; layout data lives elsewhere.

### Compound Graph Support

**graphlib**: Full compound graph support when constructed with `{compound: true}`. Maintains `_parent` (v -> parent) and `_children` (v -> {children}) maps. Dagre.js uses this extensively:

1. **`nesting-graph.js`**: Creates border dummy nodes for subgraph tops/bottoms, adds weighted edges to enforce subgraph containment during rank assignment. Uses `g.children()`, `g.setParent()`, `g.parent()`.

2. **`parent-dummy-chains.js`**: After normalization, assigns dummy nodes to correct compound parents by traversing the LCA path. Uses `g.parent()`, `g.setParent()`, `g.children()`.

3. **`add-border-segments.js`**: Creates left/right border nodes for each rank within a subgraph. Uses `g.children()`, `g.setParent()`.

4. **`order/sort-subgraph.js`**: Crossing reduction operates recursively on subgraphs. Uses `g.children(v)` to get movable nodes within each compound node.

5. **`layout.js`**: `removeBorderNodes()` computes final compound node positions from border nodes. `buildLayoutGraph()` copies parent relationships via `g.setParent(v, inputGraph.parent(v))`.

**Mermaid mermaid-graphlib.js**: Adds another layer on top of graphlib's compound support for cluster handling. Maintains `clusterDb`, `descendants`, and `parents` maps. Key operations: `extractDescendants()` recursively gathers all descendants, `adjustClustersAndEdges()` rewires edges to/from clusters to internal anchor nodes, `extractor()` recursively extracts isolated subgraphs into nested `Graph` instances. Creates graphs with `{multigraph: true, compound: true}`.

**mmdflux**: No compound graph support at all. No parent/child relationships, no subgraph concept, no border nodes, no nesting graph transformation. The `LayoutGraph` is entirely flat.

### Multigraph Support

**graphlib**: Edges identified by `{v, w, name}` triple. The `name` field allows multiple parallel edges between the same pair of nodes. Dagre.js creates its layout graph with `{multigraph: true, compound: true}` and preserves edge names through normalization (`g.setEdge(v, dummy, {weight: ...}, name)`).

**mmdflux**: No multigraph support. Edges are `(NodeId, NodeId)` pairs (or `(from, to)` in DiGraph). Duplicate edges between the same pair are stored as separate entries in a Vec but have no distinguishing name/key. The domain `Diagram` also allows parallel edges in its `Vec<Edge>` but with no named identity.

## How

### graphlib Internal Storage

```
_nodes: { v: label }           -- O(1) lookup by node id
_in:    { v: { edgeId: edgeObj } }  -- incoming edges per node
_out:   { v: { edgeId: edgeObj } }  -- outgoing edges per node
_preds: { v: { u: count } }   -- predecessor counts (for multigraph)
_sucs:  { v: { w: count } }   -- successor counts (for multigraph)
_edgeObjs:   { edgeId: {v, w, name} }
_edgeLabels: { edgeId: label }
_parent:   { v: parent }       -- compound only
_children: { v: { child: true } }  -- compound only
```

Edge IDs are constructed as `v + \x01 + w + \x01 + name` (with DEFAULT_EDGE_NAME `\x00` for unnamed edges). This gives O(1) edge lookup, O(1) node removal with cascading edge cleanup, and O(1) parent/child operations.

### mmdflux DiGraph<N> Internal Storage

```
nodes: Vec<(NodeId, N)>           -- ordered list, O(1) index access
edges: Vec<(NodeId, NodeId)>      -- ordered list, no indexing by node
node_index: HashMap<NodeId, usize>  -- O(1) id -> index lookup
```

Successor/predecessor queries do a linear scan of all edges (O(|E|)). No adjacency list structure. No edge removal. No edge indexing by endpoint.

### mmdflux LayoutGraph Internal Storage

```
node_ids: Vec<NodeId>             -- parallel with all other vecs
edges: Vec<(usize, usize, usize)>  -- (from_idx, to_idx, orig_edge_idx)
node_index: HashMap<NodeId, usize>
reversed_edges: HashSet<usize>     -- edge indices reversed for acyclicity
ranks: Vec<i32>                    -- per-node rank
order: Vec<usize>                  -- per-node order within rank
positions: Vec<Point>              -- per-node position
dimensions: Vec<(f64, f64)>        -- per-node dimensions
edge_weights: Vec<f64>             -- per-edge weight
dummy_nodes: HashMap<NodeId, DummyNode>  -- dummy metadata
dummy_chains: Vec<DummyChain>      -- normalized edge chains
```

New nodes can be appended (for dummy nodes during normalization) by pushing to all parallel vectors. No node removal is needed since the Sugiyama pipeline only adds nodes. Edge reversal is tracked via a `HashSet<usize>` rather than actually swapping edge endpoints.

### How Dagre.js Uses Graph Features That mmdflux Lacks

1. **Dynamic node/edge mutation**: Dagre.js freely adds/removes nodes and edges throughout the pipeline (e.g., `removeSelfEdges`, `insertSelfEdges`, `normalize.run`/`undo`, `nesting-graph.run`/`cleanup`, `removeBorderNodes`). mmdflux's LayoutGraph only supports appending nodes/edges (for normalization).

2. **Arbitrary metadata on edges**: Dagre.js stores `weight`, `minlen`, `labelpos`, `labeloffset`, `points`, `reversed`, `nestingEdge` etc. on edge labels. mmdflux stores only `edge_weights` as a parallel vector; other metadata is tracked via separate data structures.

3. **Edge identity via {v, w, name}**: Dagre.js passes edge objects through the pipeline (e.g., `normalizeEdge` preserves `name`, `edgeObj`). mmdflux uses edge indices.

4. **Graph-level label as config bag**: Dagre.js stores `dummyChains`, `nestingRoot`, `nodeRankFactor`, `maxRank` etc. on the graph label. mmdflux uses separate fields on `LayoutGraph`.

## Why

### Design Rationale

**graphlib chose maximum flexibility**: A single Graph class with runtime flags for directed/multigraph/compound. All metadata is arbitrary JS objects, enabling the layout pipeline to freely annotate nodes, edges, and the graph during processing. This is idiomatic JavaScript -- duck-typed, mutable, dynamic.

**mmdflux chose type safety and simplicity**: Two separate graph structures (domain vs. layout) with compile-time types. The struct-of-arrays layout in `LayoutGraph` avoids allocations and gives cache-friendly access patterns. No runtime polymorphism or dynamic metadata. This is idiomatic Rust.

### Tradeoffs

| Aspect | graphlib | mmdflux |
|---|---|---|
| Type safety | None (any JS object) | Strong (compile-time types) |
| Performance | Hash lookups, object allocation | Vec indexing, cache-friendly |
| Flexibility | Add any property at any time | Must modify struct definition |
| Compound graphs | Built-in | Not supported |
| Multigraphs | Built-in | Not supported |
| Node/edge removal | O(1) with cascade | Not supported |
| Adjacency queries | O(1) via in/out maps | O(|E|) via linear scan |

### What mmdflux Would Need to Add

For **subgraph/cluster support** (Mermaid `subgraph` blocks):
- Parent-child relationships on nodes (compound graph)
- `parent(v)`, `children(v)`, `setParent(v, parent)` operations
- Border node creation for subgraph containment
- Nesting graph transformation for rank assignment
- Subgraph-aware crossing reduction (`sort-subgraph` recurses on children)
- `parent-dummy-chains` to correctly parent dummy nodes within subgraphs
- `removeBorderNodes` to compute final subgraph dimensions

For **multigraph support** (multiple edges between same node pair):
- Named edge identity (beyond positional index)
- Edge deduplication/simplification (`util.simplify()`)

For **dynamic graph mutation** (if porting more dagre.js algorithms):
- Node removal (for removing border/dummy nodes in undo phases)
- Edge removal (for removing nesting edges, self-edges, etc.)
- Currently mmdflux's forward-only append model works because it does not implement compound graph layout or self-edge handling

For **adjacency performance**:
- The O(|E|) linear scan for successors/predecessors is adequate for small diagrams but would become a bottleneck for large compound graphs with border nodes (which significantly increase edge count)

## Key Takeaways

- graphlib provides a single, highly flexible Graph class with three orthogonal capabilities (directed, multigraph, compound). Dagre.js uses all three -- `new Graph({multigraph: true, compound: true})` -- and the compound graph support is deeply integrated into the layout pipeline (nesting graph, border segments, parent-dummy-chains, subgraph-aware ordering).

- mmdflux's `DiGraph<N>` and `LayoutGraph` are purpose-built for flat flowcharts with no subgraph nesting. They trade flexibility for type safety and performance (struct-of-arrays, no dynamic dispatch). This is a clean design for the current scope but would need significant extension for compound graph support.

- The biggest gap is compound graph support. It is not just a data structure addition -- it requires changes to at least 5 phases of the layout pipeline (nesting graph, rank, normalization parent assignment, crossing reduction, border node removal). This is the single largest architectural difference between mmdflux and dagre.js.

- Multigraph support is a smaller gap. mmdflux already allows parallel edges in its Vec storage; it just lacks named edge identity, which is mainly needed for preserving edge identity through normalization and undo.

- mmdflux's lack of node/edge removal is not currently a problem because the layout pipeline only moves forward (add dummies, never remove). But compound graph support would require undo operations (removing border nodes, nesting edges) that need removal capability.

- Adjacency query performance (O(|E|) in mmdflux vs. O(1) in graphlib) is a latent concern that would worsen with compound graph support, since border nodes and nesting edges significantly increase graph size.

## Open Questions

- Would compound graph support be better implemented as a new graph type (e.g., `CompoundDiGraph`) or by extending the existing `DiGraph<N>` with optional parent-child maps? The Rust type system could enforce compound-ness at compile time, unlike graphlib's runtime flag.

- How much of dagre.js's `nesting-graph.js` and `parent-dummy-chains.js` logic could be simplified for text rendering (where subgraphs are just box-drawing regions rather than SVG containers)?

- Mermaid's `mermaid-graphlib.js` adds substantial complexity on top of graphlib for cluster handling (extracting isolated subgraphs, rewiring edges to anchor nodes). How much of this is essential vs. working around dagre.js limitations?

- Should mmdflux build adjacency index structures (in-edges/out-edges per node) as part of `LayoutGraph::from_digraph()` to improve query performance, even before compound graph support is needed?

- The current BlockGraph (from plan-0022) appears to be a rendering-phase concept. What is its relationship to compound graph layout? Could it serve as the compound graph structure, or is a separate layout-phase compound graph needed?
