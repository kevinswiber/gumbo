# Audit: build-layer-graph.js and add-subgraph-constraints.js

## v0.8.5 vs HEAD differences

### build-layer-graph.js

- **HEAD** adds a `nodesWithRank` parameter (optional; defaults to `g.nodes()` if not provided). This is a performance optimization that avoids iterating all nodes when the caller already knows which nodes belong to the rank. v0.8.5 always iterates all nodes.
- **HEAD** uses `Object.hasOwn(node, "minRank")` instead of `_.has(node, "minRank")`.
- **HEAD** uses `@dagrejs/graphlib` instead of the vendored `../graphlib`.
- **HEAD** uses arrow functions and `let` instead of `var`.
- **HEAD** uses `util.uniqueId` instead of `_.uniqueId` in `createRootNode`.
- No behavioral changes to the core algorithm logic (edge aggregation, node selection, parent assignment).

### add-subgraph-constraints.js

- **HEAD** removes the lodash import (no longer uses `_.forEach`), using native `forEach` instead.
- No behavioral changes. The commented-out DFS function remains commented out in both versions.

## What these files do

### build-layer-graph.js

Creates a **per-layer bipartite graph** used for sorting. For a given rank, it:

1. Selects all nodes at that rank (base nodes by `rank`, subgraph nodes by `minRank`/`maxRank` range).
2. Preserves the compound (subgraph) hierarchy by calling `setParent()`.
3. Creates a synthetic root node; parentless nodes become children of this root.
4. Copies edges incident on selected nodes using the `relationship` parameter (`"inEdges"` for downward sweep, `"outEdges"` for upward sweep).
5. **Aggregates multi-edge weights**: when multiple edges connect the same (u, v) pair, their weights are summed into a single edge. The layer graph is not a multigraph.
6. For subgraph nodes, copies `borderLeft`/`borderRight` at the specific rank.

The resulting layer graph is passed to `sortSubgraph()`, which recursively sorts using barycenter values.

### add-subgraph-constraints.js

Adds ordering constraints between subgraph nodes to the constraint graph (`cg`). Walks up the compound hierarchy from each node to find sibling subgraphs and constrains their order. This ensures subgraph boundaries are respected during sorting. The constraint graph persists across layers within a sweep.

## Do we need them?

### add-subgraph-constraints.js: NO

This is purely subgraph machinery. Without compound graphs, there are no subgraph siblings to constrain. Correctly skipped.

### build-layer-graph.js: PARTIALLY - we miss edge weight aggregation

The layer graph construction serves three purposes:

1. **Subgraph hierarchy** - Not needed (no compound graphs).
2. **Edge filtering by direction** - Our `reorder_layer()` does this inline: it filters edges to find predecessors (downward) or successors (upward) in the fixed layer.
3. **Edge weight aggregation** - This is where our implementation diverges.

## Edge handling

### What build-layer-graph.js does with edges

The critical edge-handling code:

```javascript
_.forEach(g[relationship](v), function(e) {
    var u = e.v === v ? e.w : e.v,
        edge = result.edge(u, v),
        weight = !_.isUndefined(edge) ? edge.weight : 0;
    result.setEdge(u, v, { weight: g.edge(e).weight + weight });
});
```

This **aggregates weights of parallel edges** (multi-edges between the same pair). Since the layer graph is a simple graph (not a multigraph), if two edges connect u->v with weights 1 and 2, the layer graph gets a single u->v edge with weight 3.

Dagre's `barycenter.js` then uses these weights for a **weighted barycenter**:

```javascript
let result = inV.reduce((acc, e) => {
    let edge = g.edge(e),
        nodeU = g.node(e.v);
    return {
        sum: acc.sum + (edge.weight * nodeU.order),
        weight: acc.weight + edge.weight
    };
}, { sum: 0, weight: 0 });
return { barycenter: result.sum / result.weight, weight: result.weight };
```

The barycenter is `sum(weight_i * position_i) / sum(weight_i)`, not a simple average of neighbor positions.

### What our Rust code does

Our `reorder_layer()` computes an **unweighted barycenter**:

```rust
let sum: f64 = neighbors.iter().map(|&n| graph.order[n] as f64).sum();
sum / neighbors.len() as f64
```

This treats every edge connection equally (weight = 1).

### When this difference matters

Edge weights in dagre come from two sources:

1. **Original edge weights** - User-specified `weight` attribute on edges (default: 1).
2. **Normalization** - When long edges are split into chains of dummy nodes, each segment gets the original edge's weight.

For our use case (mermaid flowcharts), all edges have the default weight of 1. After normalization, all edge segments also have weight 1. **Multi-edges between the same pair are not produced by normalization** (each long edge becomes its own chain of dummy nodes with unique intermediate nodes).

The only scenario where weight aggregation matters is when the **original graph has multiple edges between the same two nodes with different weights**. This doesn't happen in mermaid flowcharts.

### Self-loops

`build-layer-graph.js` does not explicitly filter self-loops. However, self-loops are removed earlier in dagre's pipeline (in `acyclic.js`), so they never reach the ordering phase. Our pipeline also handles this upstream.

## Action items

1. **No changes needed for current use case.** All edges have weight 1 and there are no multi-edges between identical node pairs after normalization. The unweighted barycenter produces identical results to the weighted version when all weights are 1.

2. **Future consideration**: If we ever support user-specified edge weights (e.g., mermaid's `weight` attribute or custom graph inputs), we would need to:
   - Store edge weights in `LayoutGraph`.
   - Modify `reorder_layer()` to compute weighted barycenters: `sum(weight_i * order_i) / sum(weight_i)`.
   - Aggregate parallel edges (sum weights for same source-target pair).

3. **No need to implement build-layer-graph or add-subgraph-constraints.** Our inline edge filtering in `reorder_layer()` is functionally equivalent to dagre's layer graph construction for the non-compound, uniform-weight case.
