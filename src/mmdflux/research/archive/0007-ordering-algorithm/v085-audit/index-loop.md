# Audit: Main Ordering Loop — v0.8.5 vs HEAD vs Rust

## Complete v0.8.5 Algorithm Walkthrough

Source: `git show v0.8.5:lib/order/index.js`

### Step-by-step

1. **Compute maxRank** from the graph using `util.maxRank(g)`.

2. **Build layer graphs (once, reused across all iterations)**:
   - `downLayerGraphs = buildLayerGraphs(g, [1..maxRank], "inEdges")` — one per rank from 1 to maxRank. Each is a compound `Graph` containing nodes at that rank plus their in-edge neighbors from the rank above. Edges carry aggregated weights.
   - `upLayerGraphs = buildLayerGraphs(g, [maxRank-1..0], "outEdges")` — one per rank from maxRank-1 down to 0. Each contains nodes at that rank plus their out-edge neighbors from the rank below.
   - These layer graphs are **built once** before the loop and **never rebuilt**.

3. **Initial ordering via `initOrder(g)`**:
   - Filters to simple nodes (no children — compound graph support).
   - Sorts them by rank ascending.
   - Does recursive DFS from each unvisited node, appending each node to `layers[node.rank]` in visit order.
   - Returns `layers` — a 2D array of node IDs, one inner array per rank.

4. **`assignOrder(g, layering)`** — writes the initial ordering back to the graph:
   - For each layer, for each node at position `i`, sets `g.node(v).order = i`.
   - This is critical: it writes `node.order` to the **main graph** `g`, which the layer graphs reference via `setDefaultNodeLabel(function(v) { return g.node(v); })` — meaning layer graph nodes share the same node objects as the main graph.

5. **Main optimization loop**:
   ```javascript
   for (var i = 0, lastBest = 0; lastBest < 4; ++i, ++lastBest) {
   ```
   - `lastBest` counts consecutive non-improving iterations.
   - Terminates when 4 consecutive iterations fail to improve.

6. **Each iteration**:
   - **Select direction**: `i % 2 == 0` uses `upLayerGraphs` (sweep from bottom to top); `i % 2 == 1` uses `downLayerGraphs` (sweep from top to bottom).
   - **Select bias**: `i % 4 >= 2` means `biasRight = true`.
   - **Pattern over iterations 0-7**: up/left, down/left, up/right, down/right, up/left, down/left, up/right, down/right, ...
   - **Sweep**: `sweepLayerGraphs(layerGraphs, biasRight)`.
   - **Rebuild layering**: `layering = util.buildLayerMatrix(g)` — reads `node.order` from the main graph to reconstruct the layer arrays. Crucially, this uses `node.order` as an **array index**: `layering[rank][node.order] = v`. This means `node.order` values must be valid consecutive indices.
   - **Count crossings**: `cc = crossCount(g, layering)`.
   - **Track best**: If `cc < bestCC`, save `best = _.cloneDeep(layering)` and reset `lastBest = 0`.

7. **Restore best**: `assignOrder(g, best)` — writes the best layering's order values back to the graph.

### How `sweepLayerGraphs` works (v0.8.5)

```javascript
function sweepLayerGraphs(layerGraphs, biasRight) {
  var cg = new Graph();  // fresh constraint graph per sweep
  _.forEach(layerGraphs, function(lg) {
    var root = lg.graph().root;
    var sorted = sortSubgraph(lg, root, cg, biasRight);
    // Write new order to nodes (shared with main graph g)
    _.forEach(sorted.vs, function(v, i) {
      lg.node(v).order = i;
    });
    addSubgraphConstraints(lg, cg, sorted.vs);
  });
}
```

Key details:
- Creates a **fresh constraint graph** `cg` per sweep call.
- Iterates through layer graphs **in order** (top-to-bottom for down, bottom-to-top for up).
- For each layer graph, calls `sortSubgraph(lg, root, cg, biasRight)` which:
  1. Calls `barycenter(lg, movable)` — computes weighted barycenter for each movable node using `inEdges` and `node.order` of predecessors.
  2. Calls `resolveConflicts(barycenters, cg)` — merges nodes whose barycenters would violate constraints.
  3. Calls `sort(entries, biasRight)` — sorts by barycenter with bias-aware tie-breaking, interleaving unsortable nodes (those with no barycenter).
- After sorting, **immediately writes `node.order = i`** for the sorted positions. Because node objects are shared with the main graph, subsequent layer graphs in the same sweep see the updated orders from previous layers.
- Calls `addSubgraphConstraints` to record ordering constraints into `cg` for subsequent layers.

### Critical detail: node object sharing

`buildLayerGraph` sets `setDefaultNodeLabel(function(v) { return g.node(v); })`. This means `lg.node(v)` returns **the same object** as `g.node(v)`. When `sweepLayerGraphs` does `lg.node(v).order = i`, it is mutating the main graph's node data. This is how ordering information flows between layers within a single sweep and how `buildLayerMatrix(g)` can read updated orders after the sweep.

---

## v0.8.5 vs HEAD Differences

### Confirmed (from doc 05, verified here)

| # | Feature | v0.8.5 | HEAD |
|---|---------|--------|------|
| 1 | `cc === bestCC` overwrite | Not present. Only saves on strict improvement. | Adds `else if (cc === bestCC) { best = structuredClone(layering); }` |
| 2 | `customOrder` callback | Not present | `opts.customOrder` can replace entire algorithm |
| 3 | `constraints` parameter | Not present | `opts.constraints` array passed to `sweepLayerGraphs`, edges added to `cg` |
| 4 | `disableOptimalOrderHeuristic` | Not present | Early return after `assignOrder` if set |

### Additional differences found

| # | Feature | v0.8.5 | HEAD |
|---|---------|--------|------|
| 5 | **`buildLayerGraphs` optimization** | Iterates all `g.nodes()` inside `buildLayerGraph` for every rank — O(ranks * nodes) | HEAD pre-builds a `nodesByRank` Map outside, passes filtered node list to each `buildLayerGraph` call — O(nodes + ranks) |
| 6 | **lodash vs util** | Uses `_.range()` from lodash | Uses `util.range()` — removed lodash dependency |
| 7 | **`assignOrder` implementation** | Iterates with `_.forEach` over array of arrays | Uses `Object.values(layering)` — treats layering as object, not array |
| 8 | **Deep clone method** | `_.cloneDeep(layering)` | `Object.assign({}, layering)` for strict improvement, `structuredClone(layering)` for equal case |
| 9 | **`sweepLayerGraphs` constraints injection** | `cg` starts empty, only filled by `addSubgraphConstraints` | Also adds `constraints.forEach(con => cg.setEdge(con.left, con.right))` at start of each layer |

### Differences that do NOT affect behavior for our use case

Items 2, 3, 4 are irrelevant because Mermaid doesn't pass any options. Items 5, 6, 7, 8 are performance/API changes that don't affect algorithmic output. Item 1 (the `cc === bestCC` overwrite) is the only one that changes results, and was already fixed in our Rust code per doc 05.

---

## Our Rust vs v0.8.5 Detailed Comparison

### 1. How initOrder is called and results used

**v0.8.5:**
```javascript
var layering = initOrder(g);  // returns layers[][] of node IDs
assignOrder(g, layering);     // writes node.order = position-in-layer
```
- `initOrder` returns the full layer matrix.
- `assignOrder` writes `order` values to node objects on the main graph.
- The returned `layering` is also used as the initial value for the `layering` variable in the loop.

**Our Rust:**
```rust
init_order(graph);  // writes graph.order[node] directly
let layers = layers_sorted_by_order(graph);  // rebuilds layers from order values
```
- `init_order` directly writes to `graph.order[node]`.
- We then rebuild the layer vectors sorted by order.

**Assessment:** Functionally equivalent. Both end up with `order` values set on nodes and layers available.

### 2. How sweepLayerGraphs works vs our sweep_up/sweep_down

**v0.8.5 `sweepLayerGraphs`:**
- Operates on pre-built **layer graphs** (compound graphs with hierarchy).
- Uses `sortSubgraph` which does:
  - `barycenter()` — weighted average of predecessor positions using edge weights.
  - `resolveConflicts()` — enforces subgraph constraint ordering.
  - `sort()` — sorts entries by barycenter with bias-aware tie-breaking; interleaves unsortable (no-barycenter) nodes at their original index positions.
- Handles compound graphs (subgraphs with `borderLeft`/`borderRight` nodes).
- Writes `node.order = i` immediately, so subsequent layers in the same sweep see updated values.
- Uses `addSubgraphConstraints` to propagate inter-subgraph ordering constraints.

**Our Rust `sweep_down`/`sweep_up`:**
- Operates on plain `Vec<Vec<usize>>` layers.
- Uses `reorder_layer` which does:
  - Simple unweighted barycenter: `sum(order[neighbor]) / count(neighbors)`.
  - No edge weights considered.
  - No constraint resolution.
  - No compound graph support.
  - Nodes with no neighbors keep their current `graph.order[node]` as barycenter.
  - Sorts by barycenter with bias-aware tie-breaking.
- Writes `graph.order[node] = new_pos` immediately, so subsequent layers see updates.

**Differences:**

| Aspect | v0.8.5 | Our Rust |
|--------|--------|----------|
| Edge weights | Weighted barycenter (`edge.weight * node.order`) | Unweighted average of neighbor positions |
| Unsortable nodes | Interleaved at original index by `sort()` | Keep current order value as barycenter |
| Constraint resolution | `resolveConflicts` merges conflicting groups | None |
| Subgraph constraints | `addSubgraphConstraints` + constraint graph `cg` | None |
| Compound graph support | Full (borderLeft/borderRight, hierarchy) | None |
| Layer graph structure | Compound `Graph` objects with edges | Plain node ID vectors + global edge list |

### 3. How layer ordering is assigned — `assignOrder` analysis

**v0.8.5 `assignOrder`:**
```javascript
function assignOrder(g, layering) {
  _.forEach(layering, function(layer) {
    _.forEach(layer, function(v, i) {
      g.node(v).order = i;
    });
  });
}
```
- Called twice: once after `initOrder`, once at the end with `best`.
- Simply writes the array index as the `order` attribute.
- Note: `buildLayerMatrix` uses `layering[rank][node.order] = v` — it uses order as an index. So after `assignOrder`, calling `buildLayerMatrix` reconstructs the same layering.

**Our Rust:**
- After `init_order`, `graph.order[node]` is directly set.
- After the loop, `graph.order = best_order` restores the best snapshot.
- We never have an explicit `assignOrder` function, but the effect is equivalent.

**Assessment:** Functionally equivalent for simple (non-compound) graphs.

### 4. The best-order tracking logic

**v0.8.5:**
```javascript
var bestCC = Number.POSITIVE_INFINITY, best;
// ...
if (cc < bestCC) {
  lastBest = 0;
  best = _.cloneDeep(layering);  // deep clone of 2D array
  bestCC = cc;
}
// At end: assignOrder(g, best);
```
- Saves a deep clone of the full layering matrix (2D array of node IDs).
- Restores by calling `assignOrder` which re-writes `node.order` from the saved matrix.

**Our Rust:**
```rust
let mut best_order: Vec<usize> = Vec::new();
// ...
if cc < best_cc {
  last_best = 0;
  best_cc = cc;
  best_order = graph.order.clone();
}
// At end: graph.order = best_order;
```
- Saves a clone of the order vector (1D array indexed by node ID).
- Restores by replacing the order vector.

**Assessment:** Functionally equivalent. Our approach is simpler (1D vector vs 2D matrix) but captures the same information since order values uniquely determine the layering.

### 5. Termination condition

**v0.8.5:**
```javascript
for (var i = 0, lastBest = 0; lastBest < 4; ++i, ++lastBest) {
```
- Both `i` and `lastBest` increment every iteration in the `for` statement.
- `lastBest` is reset to `0` inside the body when improvement found.
- Net effect: `lastBest` increments each iteration, is reset to 0 on improvement.

**Our Rust:**
```rust
while last_best < 4 {
    // ...
    if cc < best_cc {
        last_best = 0;
        // ...
    }
    i += 1;
    last_best += 1;
}
```

**Assessment:** Equivalent. In dagre's `for` loop, `++lastBest` happens at the end of each iteration (in the increment expression), and if `lastBest` was set to 0 in the body, it becomes 1 after the increment. In our Rust, `last_best = 0` followed by `last_best += 1` produces 1. Same behavior.

### 6. How layers are rebuilt/reused between iterations

**v0.8.5:**
- **Layer graphs** (`downLayerGraphs`, `upLayerGraphs`) are built once and reused. They share node objects with the main graph, so `node.order` mutations in sweeps are visible.
- **Layering matrix** (`layering`) is **rebuilt from scratch** after each sweep via `buildLayerMatrix(g)`. This reads current `node.order` values and reconstructs the 2D array.
- The layering matrix is used only for `crossCount` and for saving `best`.

**Our Rust:**
- **`layers`** (the `Vec<Vec<usize>>`) is built once from `layers_sorted_by_order(graph)` and **never rebuilt**.
- `graph.order[node]` is updated by `reorder_layer` during sweeps.
- `count_all_crossings` uses the fixed `layers` vectors but reads current `graph.order[node]` values for position comparisons.

**Critical question: Is our fixed `layers` vec correct?**

In dagre, `buildLayerMatrix` reconstructs the layer arrays using `layering[rank][node.order] = v`. This means the **position** of each node in the array corresponds to its order. If two nodes swap positions, the array changes.

In our Rust, `layers` is a `Vec<Vec<usize>>` where each inner vec lists node IDs. The node IDs don't move within these vectors — only `graph.order[node]` changes. This is used in two ways:

1. **`reorder_layer`**: Iterates over `free` (a fixed list of node IDs) and `fixed` (another fixed list). The order within these vectors doesn't matter for barycenter computation because it looks up `graph.order[n]` for neighbor positions and uses `graph.order[node]` for nodes without neighbors. It then sorts by barycenter and writes new `graph.order` values as 0, 1, 2, ...

2. **`count_all_crossings`**: Iterates over edges, checks `layer1.contains(&from)` and `layer2.contains(&to)`, then uses `graph.order[from]` and `graph.order[to]` for position comparison. Layer membership doesn't change, so this is correct.

**Verdict: The fixed `layers` approach is correct for our use case.** The `layers` vectors serve only to identify which nodes belong to which rank — they are used as sets, not as ordered sequences. The actual ordering information is always read from `graph.order[node]`. Dagre rebuilds `layering` because it uses the array structure itself (position = order) for `crossCount`, but our code separates membership from ordering.

However, there is a subtle difference in **`reorder_layer`** for nodes without neighbors: we use `graph.order[node] as f64` as their barycenter. Dagre's `sort()` handles unsortable nodes differently — they are interleaved at their original index position `i` (from `resolveConflicts`), which is their position in the `movable` list, not their `node.order`. This could produce different results for disconnected nodes within a layer.

---

## Critical Question: Does `assignOrder` update `node.order`? Does it rebuild layering arrays?

**Yes, `assignOrder` updates `node.order`.** It writes `g.node(v).order = i` for each node in each layer.

**No, it does not rebuild the layering arrays.** It takes an existing layering and writes order values from it. The layering arrays are rebuilt separately by `buildLayerMatrix(g)`.

**Importantly, within a sweep, dagre does NOT call `assignOrder` or `buildLayerMatrix`.** The sweep directly mutates `node.order` via `lg.node(v).order = i` in `sweepLayerGraphs`. The `buildLayerMatrix` call happens AFTER the sweep completes, before `crossCount`.

**Our Rust mirrors this correctly**: `reorder_layer` writes `graph.order[node] = new_pos` during the sweep, and `count_all_crossings` reads the updated values after.

---

## Bugs and Gaps

### Bug 1: Unweighted barycenter (MEDIUM)

Our Rust uses unweighted barycenter:
```rust
let sum: f64 = neighbors.iter().map(|&n| graph.order[n] as f64).sum();
sum / neighbors.len() as f64
```

Dagre v0.8.5 uses weighted barycenter:
```javascript
result = _.reduce(inV, function(acc, e) {
  var edge = g.edge(e), nodeU = g.node(e.v);
  return {
    sum: acc.sum + (edge.weight * nodeU.order),
    weight: acc.weight + edge.weight
  };
}, { sum: 0, weight: 0 });
return { barycenter: result.sum / result.weight, weight: result.weight };
```

**Impact:** For simple graphs where all edges have weight 1, no difference. But dagre adds dummy nodes for long edges during normalization, and edge weights may vary. If our graph has non-uniform weights, results diverge.

**Current risk:** Low for simple flowcharts. Edge weights in mmdflux are likely uniform. But this gap should be closed for correctness.

### Bug 2: Unsortable node handling (MEDIUM)

Dagre's `sort()` function handles nodes without barycenters (no incoming edges from the fixed layer) by interleaving them at their original position index among the sorted nodes. Our code gives them their current `graph.order[node]` as a barycenter, which means they sort among the sortable nodes by their current position.

**Impact:** For disconnected nodes within a layer, dagre preserves their relative position more carefully. Our approach may move them.

### Bug 3: No subgraph constraint support (LOW for mmdflux)

Dagre uses `addSubgraphConstraints` and `resolveConflicts` to maintain ordering invariants for compound graph subgraphs. Our code has none of this.

**Impact:** Not relevant for mmdflux since we don't use compound graphs. Only matters if we ever add subgraph support.

### Bug 4: Sweep direction mapping (VERIFY)

**v0.8.5:**
- `i % 2 == 0` (even) selects `upLayerGraphs` (ranks maxRank-1 down to 0, using outEdges)
- `i % 2 == 1` (odd) selects `downLayerGraphs` (ranks 1 to maxRank, using inEdges)

**Our Rust:**
- `i % 2 == 0` calls `sweep_up` (iterates `layers.len()-2` down to 0, fixing layer i+1, reordering layer i)
- `i % 2 == 1` calls `sweep_down` (iterates 1 to `layers.len()-1`, fixing layer i-1, reordering layer i)

In dagre's up sweep: `upLayerGraphs` iterates ranks from maxRank-1 to 0. For each rank, it builds a layer graph using `outEdges` — meaning it connects the current rank's nodes to their successors (the rank below/after). The `barycenter` function then looks at `inEdges` of each node in the layer graph. Since the relationship was `outEdges`, the "inEdges" in the layer graph are from the fixed (already-ordered) layer.

Wait — this requires more careful analysis. The `buildLayerGraph` for rank `r` with relationship `"outEdges"` calls `g.outEdges(v)` for each node at rank `r`. For an edge `v -> w` where `v` is at rank `r` and `w` is at rank `r+1`, this creates an edge from `w` to `v` in the layer graph (`result.setEdge(u, v, ...)`). Then `barycenter` computes using `g.inEdges(v)` on the layer graph, which gives edges from `w` to `v` — so the barycenter of `v` is based on the positions of its successors `w`.

For the **up sweep** (processing ranks maxRank-1 down to 0): each rank `r` is ordered based on the positions of successors at rank `r+1`. Since we go top-down in reverse (maxRank-1 first, which looks at maxRank), the fixed layer is always the one below (already processed or initial).

Actually no — for up sweep, we go from maxRank-1 down to 0. Rank maxRank-1 looks at successors at maxRank (the bottom-most rank). Then rank maxRank-2 looks at successors at maxRank-1 (just reordered). So the sweep goes upward: fixing the bottom, reordering toward the top.

**Our `sweep_up`:**
```rust
for i in (0..layers.len() - 1).rev() {
    let fixed = &layers[i + 1];  // layer below
    let free = &layers[i];       // current layer
    reorder_layer(graph, fixed, free, edges, false, bias_right);
}
```
Iterates from the second-to-last layer down to 0, fixing the layer below and reordering the current layer. With `downward=false`, neighbors are successors (outEdges). This matches dagre.

**Our `sweep_down`:**
```rust
for i in 1..layers.len() {
    let fixed = &layers[i - 1];  // layer above
    let free = &layers[i];       // current layer
    reorder_layer(graph, fixed, free, edges, true, bias_right);
}
```
Iterates from layer 1 to the last, fixing the layer above and reordering the current layer. With `downward=true`, neighbors are predecessors (inEdges). This matches dagre.

**Assessment:** Direction mapping is correct.

### Gap 5: `buildLayerMatrix` sparse array behavior (INFO)

Dagre's `buildLayerMatrix` does `layering[rank][node.order] = v`, which can create sparse arrays if `node.order` values have gaps. In practice, `sweepLayerGraphs` assigns consecutive order values (0, 1, 2, ...) so this shouldn't happen. Our code doesn't have this concern since we don't reconstruct layer arrays.

---

## Action Items

### Priority 1 (High) — Should fix for correctness

1. **Add edge weight support to barycenter computation** — When edges have non-uniform weights (e.g., from dummy node splitting), our unweighted average will produce different orderings than dagre. Modify `reorder_layer` to use `edge.weight * order` / `sum(weights)` instead of simple average.

### Priority 2 (Medium) — Should fix for fidelity

2. **Fix unsortable node handling** — Nodes with no connections to the fixed layer should be interleaved at their original positions rather than sorted by their current order value. Implement something similar to dagre's `sort()` function's `consumeUnsortable` logic.

### Priority 3 (Low) — Track for future

3. **Compound graph / subgraph support** — Not needed for mmdflux today. Document as a known gap.

4. **Constraint graph across layers** — Dagre accumulates constraints in `cg` across layers within a sweep. We have no equivalent. Not impactful without compound graphs.

### Priority 4 (Verify)

5. **Verify edge weights in practice** — Check what edge weights look like in mmdflux after rank assignment and normalization. If all weights are 1, Bug 1 is not impactful. If weights vary, it's a real bug.
