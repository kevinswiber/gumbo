# Sort Pipeline Audit: dagre v0.8.5 vs HEAD vs Rust `reorder_layer()`

## Files Reviewed

- `lib/order/barycenter.js` - Computes barycenter values from in-edges
- `lib/order/resolve-conflicts.js` - Merges constraint graph conflicts
- `lib/order/sort.js` - Sorts entries by barycenter, interleaves unsortable nodes
- `lib/order/sort-subgraph.js` - Orchestrator: barycenter -> resolve-conflicts -> sort

---

## 1. v0.8.5 vs HEAD Differences

### barycenter.js

- **v0.8.5**: Uses `var`, lodash `_.map`, `_.reduce`
- **HEAD**: Uses `let`, native `.map()`, `.reduce()`, adds `movable = []` default parameter
- **Behavioral change**: None. Logic is identical. Both return `{ v }` (no barycenter/weight) for nodes with no in-edges, and `{ v, barycenter, weight }` for nodes with in-edges.

### resolve-conflicts.js

- **v0.8.5**: Uses `var`, lodash `_.forEach`, `_.filter`, `_.map`, `_.pick`, `_.isUndefined`, `_.has`
- **HEAD**: Uses `let`, native `.forEach`, `.filter`, `.map`, custom `util.pick`, direct `=== undefined` checks, `Object.values()`
- **Behavioral change**: None. Logic is identical.

### sort.js

- **v0.8.5**: Uses `var`, lodash `_.sortBy`, `_.flatten`, `_.has`, `_.last`, `_.forEach`, `util.partition`
- **HEAD**: Uses `let`, native `.sort()`, `.flat()`, `Object.hasOwn()`, array index for last element, `util.partition`
- **Behavioral change**: None. Logic is identical.

### sort-subgraph.js

- **v0.8.5**: Uses `var`, lodash `_.filter`, `_.forEach`, `_.flatten`, `_.has`, `_.isUndefined`
- **HEAD**: Uses `let`, native `.filter`, `.forEach`, `.flatMap`, `Object.hasOwn`, direct `!== undefined`
- **Behavioral change**: None. Logic is identical.

### Summary: v0.8.5 and HEAD are functionally identical across all 4 files. All changes are lodash-to-native modernization.

---

## 2. Dagre v0.8.5 Sort Pipeline Architecture

The dagre sort pipeline processes one subgraph at a time. For flat graphs (no compound nodes), the root graph is the only subgraph. The pipeline is:

```
sortSubgraph(g, root, cg, biasRight)
  1. movable = g.children(root)             // all nodes in this layer
  2. barycenters = barycenter(g, movable)    // compute {v, barycenter?, weight?}
  3. entries = resolveConflicts(barycenters, cg)  // merge constrained groups
  4. expandSubgraphs(entries, subgraphs)     // flatten nested subgraph results
  5. result = sort(entries, biasRight)        // final ordering
```

### Key details of each stage:

#### barycenter.js
- For each movable node, looks at **in-edges** only (predecessors)
- If a node has **no in-edges**: returns `{ v }` -- **no barycenter or weight properties**
- If a node has in-edges: returns `{ v, barycenter: weightedAvg, weight: totalWeight }`
- Uses `edge.weight * nodeU.order` for weighted average (edge weights matter)
- **Only looks at in-edges**. dagre's `buildLayerGraph()` reverses the graph for upward sweeps, so "in-edges" always means "edges from the fixed layer."

#### resolve-conflicts.js
- Takes barycenter entries + a constraint graph (cg)
- The constraint graph encodes ordering constraints (e.g., border nodes of subgraphs must stay left/right)
- For each entry, builds an internal node with `indegree`, `in[]`, `out[]`, `vs[]`, `i` (original index)
- **Preserves the undefined barycenter**: if an entry has no barycenter, the internal node also has no barycenter
- Topological sort through constraint graph, merging nodes when:
  - Either node has undefined barycenter, OR
  - The predecessor's barycenter >= the successor's barycenter (conflict)
- `mergeEntries()`: combines `vs` arrays, aggregates weighted barycenters, takes min `i`, marks source as merged
- Output: `[{ vs, i, barycenter?, weight? }]` -- entries may still lack barycenter

#### sort.js
- Partitions entries into **sortable** (has barycenter) and **unsortable** (no barycenter)
- Sortable entries: sorted by barycenter with `compareWithBias` tie-breaking
- Unsortable entries: sorted by descending `i` (original index), then **interleaved into gaps**
- `consumeUnsortable()`: places unsortable entries at positions where their original index `i` fits in the current output position
- This means **nodes with no neighbors stay approximately in their original position**
- Returns `{ vs, barycenter?, weight? }` for the whole sorted layer

#### sort-subgraph.js
- Orchestrator that adds subgraph handling (recursive sortSubgraph calls, border node fixup)
- For flat graphs: effectively just barycenter -> resolveConflicts -> sort

---

## 3. Our Rust `reorder_layer()` vs v0.8.5

### What we replicate

| Feature | dagre v0.8.5 | Our Rust | Match? |
|---------|-------------|----------|--------|
| Barycenter computation | Weighted average of neighbor positions | Average of neighbor positions (unweighted) | PARTIAL -- see gap below |
| Bias-right tie-breaking | `compareWithBias`: ties broken by original index, direction depends on biasRight | `sort_by` with original_pos tie-breaking, direction depends on bias_right | YES |
| Sort by barycenter | Ascending barycenter sort | Ascending barycenter sort | YES |
| Order update | Sets result.vs ordering | Sets graph.order for each node | YES (different mechanism, same effect) |

### What we skip

| Feature | dagre v0.8.5 | Our Rust | Risk |
|---------|-------------|----------|------|
| resolve-conflicts | Merges constrained nodes via constraint graph | Skipped entirely | **LOW** -- constraint graph is only populated for compound/subgraph border nodes. Without subgraph support, the constraint graph is empty, and resolveConflicts degenerates to wrapping each entry in `{vs: [v], i: i}` with no merges. |
| sort-subgraph recursion | Recursively sorts nested subgraphs | N/A | **LOW** -- no compound node support needed |
| Subgraph border nodes | borderLeft/borderRight handling | N/A | **LOW** -- no compound node support needed |
| Edge weights in barycenter | `edge.weight * nodeU.order` | Unweighted `graph.order[n]` | **MEDIUM** -- see gap below |
| Unsortable interleaving | Nodes with no neighbors placed in gaps by original index | Nodes with no neighbors get `graph.order[node]` as barycenter | **HIGH** -- different behavior, see key differences below |

---

## 4. Key Behavioral Differences

### 4.1 Handling of nodes with NO neighbors (CRITICAL)

This is the most significant difference between our implementation and dagre.

**Dagre v0.8.5 behavior:**
1. `barycenter.js` returns `{ v }` -- **no barycenter property at all**
2. `resolveConflicts` preserves the missing barycenter, outputs `{ vs: [v], i: originalIndex }`
3. `sort.js` partitions these into the **unsortable** set
4. Unsortable nodes are sorted by **descending original index** and interleaved into gaps between sortable nodes using `consumeUnsortable()`
5. The interleaving places each unsortable node at a position where its **original index** (`i`) is <= the current output slot index (`vsIndex`)
6. Effect: nodes without neighbors approximately maintain their original relative position among the sorted nodes

**Our Rust behavior:**
1. Nodes with no neighbors get `graph.order[node] as f64` as their barycenter
2. They participate in the normal sort alongside nodes that have real barycenters
3. Effect: nodes without neighbors are placed according to their current position value, sorted among real barycenters

**Why this matters:**
- In dagre, unsortable nodes are treated as **positionally sticky** -- they stay roughly where they were originally. They don't interfere with the barycenter-based ordering of connected nodes.
- In our code, neighborless nodes compete with connected nodes in the sort. Their "barycenter" of `graph.order[node]` is their current integer position, while real barycenters are fractional averages. This could cause different placements.
- **However**: for many practical graphs (connected, few isolated nodes per layer), the difference is minimal. The dagre interleaving algorithm is subtle but mainly matters when a layer has multiple disconnected nodes intermixed with connected ones.

### 4.2 Edge weights in barycenter

**Dagre**: `edge.weight * nodeU.order` -- edge weights scale the contribution of each neighbor.
**Our Rust**: Unweighted average -- each neighbor contributes equally.

In dagre, edge weights default to 1 for user edges. The only case where edge weights differ from 1 is when `minLen > 1` causes dagre to chain edges, or when edges are explicitly weighted. For typical mermaid flowcharts with `minLen=1` and no explicit weights, this difference is negligible.

**Risk**: LOW for our use case (mermaid flowcharts typically have uniform edge weights).

### 4.3 Tie-breaking semantics

**Dagre `sort.js`**: Tie-breaking uses the `i` property, which is the **original index in the barycenter array** (which corresponds to the order of `g.children(root)`). This is the input ordering from the previous iteration.

**Our Rust**: Tie-breaking uses `original_pos`, which is the enumeration index of `free.iter()` -- i.e., the position within the free layer array.

These should be equivalent as long as `free` is ordered consistently with the previous iteration's output (which it should be, since both represent the current layer ordering).

---

## 5. Bugs or Gaps Found

### BUG: Nodes with no neighbors are treated differently (MEDIUM-HIGH severity)

Our code assigns `graph.order[node]` as a synthetic barycenter for neighborless nodes. Dagre instead keeps them unsortable and interleaves them into gaps. The dagre approach has these properties:
1. Unsortable nodes never displace sortable nodes from their barycenter-optimal positions
2. Unsortable nodes maintain their relative order from the previous iteration
3. The interleaving preserves positional stability

Our approach can cause a neighborless node at position 3 (barycenter=3.0) to sort between connected nodes with barycenters 2.5 and 3.5, potentially disrupting what would otherwise be a crossing-free arrangement.

**When this matters**: Layers with a mix of connected and disconnected nodes. For fully-connected graphs (common in mermaid flowcharts), every node has at least one neighbor and this gap is irrelevant.

### MINOR: No edge weight support in barycenter

All edges are treated as weight 1. For mermaid flowcharts this is correct, but if we ever support edge weights, this would need updating.

---

## 6. Action Items

### P1 (Should fix)
- **Match dagre's unsortable interleaving behavior**: Separate neighborless nodes from connected nodes. Sort connected nodes by barycenter. Place neighborless nodes in gaps at their original positions. This is the `sort.js` partition + `consumeUnsortable()` algorithm.
  - Alternatively, verify via testing that the current approach produces identical or better crossing counts on our test corpus. If it does, document the intentional divergence and move on.

### P2 (Nice to have)
- **Add edge weight support to barycenter calculation**: When/if edge weights are added to the graph model, multiply neighbor position by edge weight in the barycenter sum.

### P3 (Not needed now)
- **resolve-conflicts**: Only needed if we add compound/subgraph node support. The constraint graph is empty without border nodes, so resolveConflicts is a no-op for flat graphs.
- **sort-subgraph recursion**: Same -- only needed for compound nodes.
