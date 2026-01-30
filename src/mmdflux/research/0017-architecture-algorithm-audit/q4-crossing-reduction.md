# Q4: Crossing Reduction

## Summary

Both mmdflux and Dagre.js use the same core algorithm: DFS-based initial ordering followed by iterative barycenter sweeps with alternating direction and bias, terminating after 4 non-improving iterations. The key structural difference is that Dagre's 9-file implementation adds compound graph awareness (subgraph-constrained sorting, border node handling, conflict resolution via constraint graphs) and an O(E log V) bilayer cross count using an accumulator tree, while mmdflux uses a flat single-layer sort with O(E^2) cross counting. For simple (non-compound) graphs, mmdflux's approach produces equivalent results; the extra Dagre machinery is specifically needed for nested subgraph support.

## Where

Sources consulted:

- mmdflux: `/Users/kevin/src/mmdflux/src/dagre/order.rs` (single file, ~830 lines including tests)
- Dagre.js: `/Users/kevin/src/dagre/lib/order/index.js` (main orchestrator)
- Dagre.js: `/Users/kevin/src/dagre/lib/order/init-order.js` (DFS initial ordering)
- Dagre.js: `/Users/kevin/src/dagre/lib/order/barycenter.js` (barycenter computation)
- Dagre.js: `/Users/kevin/src/dagre/lib/order/sort-subgraph.js` (recursive subgraph-aware sorting)
- Dagre.js: `/Users/kevin/src/dagre/lib/order/resolve-conflicts.js` (constraint conflict resolution)
- Dagre.js: `/Users/kevin/src/dagre/lib/order/add-subgraph-constraints.js` (subgraph ordering constraints)
- Dagre.js: `/Users/kevin/src/dagre/lib/order/cross-count.js` (bilayer accumulator tree cross count)
- Dagre.js: `/Users/kevin/src/dagre/lib/order/build-layer-graph.js` (per-layer compound graph construction)
- Dagre.js: `/Users/kevin/src/dagre/lib/order/sort.js` (partition-and-interleave final sort)

## What

### Shared Algorithm Structure

Both implementations follow the same high-level algorithm:

1. **Init order**: DFS from nodes sorted by rank, assigning order as nodes are first visited per rank.
2. **Iterative sweeps**: Alternating up/down sweeps with alternating left/right bias (pattern: `i%2` for direction, `i%4 >= 2` for bias).
3. **Best-order tracking**: Keep the best crossing count seen; terminate after 4 consecutive non-improving iterations.
4. **Barycenter heuristic**: Compute weighted average position of neighbors in fixed layer; sort free layer by barycenter.
5. **Sortable/unsortable partition**: Nodes with no neighbors in the fixed layer are "unsortable" and interleaved at their original positions.

### Dagre's Extra Machinery (6 capabilities mmdflux lacks)

#### 1. Compound Graph Layer Construction (`build-layer-graph.js`)
Dagre constructs a per-layer compound `Graph` object that preserves the subgraph hierarchy. Each layer graph:
- Contains all base nodes and subgraph nodes at that rank
- Preserves parent-child relationships from the original compound graph
- Creates a synthetic root node so parentless nodes have a common ancestor
- Handles nodes with `minRank`/`maxRank` ranges (border nodes that span multiple ranks)
- Aggregates edge weights for parallel edges (since the layer graph is not a multigraph)

mmdflux operates on flat layer vectors with no hierarchy.

#### 2. Recursive Subgraph Sorting (`sort-subgraph.js`)
Dagre's sorting is recursive over the compound graph hierarchy:
- `sortSubgraph(g, root, cg, biasRight)` gets `movable = g.children(v)` for a given subgraph
- If a movable child is itself a subgraph (has children), it recurses
- Barycenters from child subgraphs are merged upward (`mergeBarycenters`)
- Border nodes (`borderLeft`, `borderRight`) are excluded from sorting and pinned to the edges of the result

mmdflux sorts each layer as a flat list.

#### 3. Constraint Graph and Conflict Resolution (`resolve-conflicts.js`)
Dagre maintains a **constraint graph** (`cg`) that records ordering constraints between subgraphs:
- Based on Forster's "A Fast and Simple Heuristic for Constrained Two-Level Crossing Reduction"
- When a barycenter-based ordering would violate a constraint, conflicting nodes are **coalesced** into a single entry with merged barycenters and weights
- Uses topological processing: builds indegree counts, processes sources first, merges predecessors that would violate ordering
- Result entries have a `vs` array (may contain multiple coalesced nodes) instead of single nodes

mmdflux has no constraint mechanism.

#### 4. Subgraph Constraint Accumulation (`add-subgraph-constraints.js`)
After each layer is sorted, Dagre walks the sorted order and records which subgraphs appeared in which relative order:
- For each node in the sorted layer, it walks up the parent hierarchy
- If two different children of the same parent appear, it adds a constraint edge (prev -> current) to the constraint graph
- This ensures subsequent layers respect the established subgraph ordering
- The constraint graph accumulates across layers during a sweep

mmdflux has no inter-layer constraint propagation.

#### 5. Border Node Handling (in `sort-subgraph.js`)
Compound graphs in Dagre use "border nodes" (left/right boundary markers for subgraphs):
- `borderLeft` and `borderRight` nodes are removed from the movable set
- After sorting, they are prepended/appended to the result: `[bl, ...sorted, br]`
- Border node predecessors contribute to the subgraph's aggregate barycenter
- This ensures subgraph boundaries are visually maintained

No equivalent in mmdflux (no compound graph support).

#### 6. O(E log V) Bilayer Cross Counting (`cross-count.js`)
Dagre uses an **accumulator tree** (binary indexed tree) algorithm from Barth et al., "Bilayer Cross Counting":
- Builds a tree of size `2 * firstIndex - 1` where `firstIndex` is the smallest power of 2 >= south layer size
- For each edge (sorted by north position then south position), inserts into the tree and accumulates weighted crossings
- Computes **weighted** crossing count (honors edge weights)
- Time complexity: O(E log V) per layer pair

mmdflux uses a naive O(E^2) pairwise comparison:
```rust
for i in 0..edge_positions.len() {
    for j in i + 1..edge_positions.len() {
        // check if edges cross
    }
}
```
This counts unweighted crossings only (ignores edge weights in the crossing count, though it uses weighted barycenters).

### Additional Dagre Feature: Custom Order Hook and External Constraints

Dagre's `index.js` supports:
- `opts.customOrder` callback for completely custom ordering logic
- `opts.constraints` array for external ordering constraints (e.g., user-specified "A must be left of B")
- `opts.disableOptimalOrderHeuristic` to skip the iterative improvement loop

mmdflux has none of these extension points.

## How

### mmdflux Algorithm Flow

```
run(graph)
  1. init_order(graph)          -- DFS-based initial ordering
  2. layers = layers_sorted_by_order(graph)
  3. edges = graph.effective_edges_weighted()
  4. Loop (terminate after 4 non-improving iterations):
     a. sweep_up or sweep_down (alternating by i%2)
        - For each adjacent layer pair:
          reorder_layer(fixed, free, edges, downward, bias_right)
            - Compute weighted barycenter for each free node
            - Partition into sortable (has neighbors) / unsortable (no neighbors)
            - Sort sortable by barycenter with bias tie-breaking
            - Interleave unsortable at original positions
            - Assign new order values
     b. count_all_crossings() -- O(E^2) per layer pair
     c. Track best crossing count; save/restore best ordering
```

### Dagre.js Algorithm Flow

```
order(g, opts)
  1. Build downLayerGraphs and upLayerGraphs (compound Graph per layer)
  2. layering = initOrder(g)  -- DFS-based initial ordering
  3. assignOrder(g, layering)
  4. Loop (terminate after 4 non-improving iterations):
     a. sweepLayerGraphs(direction, biasRight, constraints)
        - For each layer graph:
          i.   Apply external constraints to constraint graph (cg)
          ii.  sortSubgraph(lg, root, cg, biasRight)  -- RECURSIVE
               - Get movable children of current subgraph
               - Remove border nodes from movable set
               - Compute barycenters for movable nodes
               - Recurse into child subgraphs, merge barycenters upward
               - resolveConflicts(barycenters, cg)
                 - Build dependency graph from constraint edges
                 - Topological sort; coalesce nodes that violate constraints
               - expandSubgraphs(entries, subgraphs) -- flatten subgraph results
               - sort(entries, biasRight) -- partition sortable/unsortable, interleave
               - Pin border nodes at edges of result
          iii. addSubgraphConstraints(lg, cg, sorted.vs)
               - Walk sorted order, record subgraph relative positions as constraints
     b. crossCount(g, layering) -- O(E log V) bilayer accumulator tree, weighted
     c. Track best crossing count; save/restore best layering
```

### Key Algorithmic Differences Table

| Aspect | mmdflux | Dagre.js |
|--------|---------|----------|
| Graph model | Flat layers (Vec<Vec<usize>>) | Compound Graph per layer |
| Sorting unit | Individual nodes | Nodes or coalesced subgraph groups |
| Barycenter | Weighted (uses edge weights) | Weighted (uses edge weights) |
| Sort/unsort partition | Yes, interleave pattern | Yes, identical interleave pattern |
| Bias tie-breaking | Yes (i%4 >= 2) | Yes (i%4 >= 2) |
| Cross counting | O(E^2) unweighted | O(E log V) weighted (accumulator tree) |
| Constraint propagation | None | Constraint graph across layers |
| Subgraph awareness | None | Full recursive compound support |
| Border nodes | None | Pinned at subgraph boundaries |
| Conflict resolution | None | Forster's coalescing algorithm |
| Extension points | None | customOrder, constraints, disableOptimalOrderHeuristic |

## Why

### Why the Extra Complexity Matters

**1. Compound/nested graphs are the primary driver.** Five of Dagre's nine order files exist specifically for compound graph support: `build-layer-graph.js`, `sort-subgraph.js`, `resolve-conflicts.js`, `add-subgraph-constraints.js`, and the border node logic. Without nested subgraphs, these are unnecessary. For mmdflux's current scope (flat flowcharts), the simpler approach is correct.

**2. Constraint propagation prevents subgraph fragmentation.** In compound graphs, a subgraph might span multiple ranks. Without constraints, the ordering phase could scatter a subgraph's children across different positions in different layers, making it impossible to draw a contiguous bounding box. The constraint graph ensures that once two subgraphs are ordered relative to each other in one layer, that ordering is preserved in subsequent layers.

**3. Conflict resolution handles impossible constraints gracefully.** When a constraint says "A before B" but barycenters say "B before A," Dagre coalesces them into a single unit with merged barycenters rather than violating either requirement. This is essential for compound graphs where subgraph containment creates hard ordering constraints.

**4. The O(E log V) cross count matters for performance at scale.** For graphs with hundreds of edges per layer pair, the quadratic cross count becomes a bottleneck since it runs once per iteration (typically 4-8 iterations). Dagre's accumulator tree algorithm (Barth et al.) reduces this significantly. Additionally, Dagre's cross count is weighted, which means edges with higher weight (e.g., normalized long edges that represent multiple original edges) are counted proportionally, giving a better quality signal.

**5. Border nodes maintain visual integrity.** When a subgraph spans multiple ranks, Dagre adds left and right border dummy nodes at each rank. These nodes are pinned at the edges of the subgraph's sorted order, ensuring the subgraph rectangle can be drawn without overlap. The border nodes also contribute to the subgraph's aggregate barycenter, pulling the entire subgraph toward its connections.

### What mmdflux Would Need for Compound Graphs

To support Mermaid's `subgraph` syntax with proper crossing reduction:
1. A compound graph representation (parent-child relationships)
2. Per-layer compound graph construction (equivalent to `build-layer-graph.js`)
3. Recursive subgraph sorting with barycenter merging
4. A constraint graph that accumulates across layers during a sweep
5. Conflict resolution (Forster's algorithm) to handle constraint/barycenter conflicts
6. Border node creation and pinning

### What mmdflux Could Improve Without Compound Graphs

Even for flat graphs, two improvements from Dagre would be beneficial:
1. **O(E log V) cross counting**: The accumulator tree algorithm would improve performance on larger diagrams.
2. **Weighted cross counting**: Currently mmdflux uses weighted barycenters but unweighted cross counting, which is a mismatch -- the optimization target (unweighted crossings) doesn't match the sorting signal (weighted barycenters).

## Key Takeaways

- mmdflux faithfully implements the core Dagre crossing reduction algorithm (DFS init, alternating sweeps with bias, barycenter sort with sortable/unsortable interleaving, best-order tracking). For flat graphs, the results should be equivalent.
- The majority of Dagre's extra complexity (6 of 9 files) exists specifically for compound graph support: hierarchical layer graphs, recursive subgraph sorting, constraint propagation, conflict resolution, and border node handling. This is irrelevant for mmdflux's current flat flowchart scope.
- mmdflux has two concrete algorithmic gaps even for flat graphs: (a) O(E^2) vs O(E log V) cross counting, and (b) unweighted vs weighted cross counting. The first affects performance on large graphs; the second could affect ordering quality when edge weights are non-uniform (e.g., after long-edge normalization).
- The sortable/unsortable partition-and-interleave pattern in mmdflux's `reorder_layer` correctly matches Dagre's `sort.js`, including the `consumeUnsortable` logic and bias-aware tie-breaking.
- Dagre's external extension points (`customOrder`, `constraints`, `disableOptimalOrderHeuristic`) provide flexibility that mmdflux may want to consider if it needs to support user-specified ordering hints.

## Open Questions

- Does mmdflux's long-edge normalization produce non-uniform edge weights? If so, the unweighted cross counting could be making suboptimal decisions compared to Dagre's weighted version.
- How much does the O(E^2) cross counting actually cost in practice for typical Mermaid diagrams (usually <50 nodes)? It may not matter at mmdflux's current scale.
- When mmdflux adds subgraph support, should it adopt Dagre's approach (constraint graph + conflict resolution) or explore alternative compound graph ordering algorithms from the literature?
- Dagre's `cc === bestCC` branch (line 58-60 of index.js) saves the current layering even on ties, which differs from mmdflux's strict-improvement-only tracking. Does this produce meaningfully different results?
