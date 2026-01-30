# cross-count.js Audit: v0.8.5 vs HEAD vs Rust

## v0.8.5 vs HEAD Differences

The algorithm is identical between v0.8.5 and HEAD. The only changes are
stylistic modernization:

| Aspect | v0.8.5 | HEAD |
|--------|--------|------|
| Imports | `var _ = require("../lodash")` | `let zipObject = require("../util").zipObject` |
| Variables | `var` throughout | `let` throughout |
| `southPos` | `_.zipObject(southLayer, _.map(...))` | `zipObject(southLayer, southLayer.map(...))` |
| `southEntries` | `_.flatten(_.map(northLayer, ...), true)` | `northLayer.flatMap(...)` |
| Sorting | `_.sortBy(_.map(g.outEdges(v), ...), "pos")` | `.map(...).sort((a, b) => a.pos - b.pos)` |
| Tree init | `_.map(new Array(treeSize), function() { return 0; })` | `new Array(treeSize).fill(0)` |
| forEach | `_.forEach(southEntries.forEach(...))` | `southEntries.forEach(...)` |

**Note on the v0.8.5 forEach bug:** v0.8.5 has `_.forEach(southEntries.forEach(...))`.
The inner `.forEach()` returns `undefined`, so `_.forEach(undefined)` is a no-op.
However, the side effects (updating `tree`, `cc`) all happen in the inner `.forEach()`
callback, so it works correctly. HEAD removes the redundant `_.forEach()` wrapper.

**Behavioral verdict:** No behavioral differences. The algorithm is the same.

### Mermaid (dagre-d3-es@7.0.13)

The mermaid copy matches v0.8.5 exactly (including the `_.forEach` wrapper and `var`
declarations), with minor formatting changes. It is the v0.8.5 code.

---

## Our Rust vs v0.8.5: Behavioral Comparison

### Algorithm

| | Dagre (v0.8.5 / HEAD) | Our Rust |
|---|---|---|
| Algorithm | Bilayer tree accumulator (Barth et al.) | Brute-force pairwise comparison |
| Complexity | O(e log n) per layer pair | O(e^2) per layer pair |
| Edge weights | Yes - multiplies `weight * weightSum` | No - counts 1 per crossing |
| Edge source | `g.outEdges(v)` for north-layer nodes | Iterates all edges, checks membership |
| Position mapping | Builds `southPos` map from layer order | Uses `graph.order[node]` directly |

### Correctness Equivalence

For **unweighted graphs** (all edge weights = 1), both algorithms produce the same
crossing count. The bilayer tree accumulator counts inversions in the south-position
sequence, which is mathematically equivalent to counting pairs where
`(u1 < u2 && v1 > v2) || (u1 > u2 && v1 < v2)`.

Our Rust code handles **both edge directions** correctly: it checks if `(from, to)`
matches `(layer1, layer2)` *or* `(layer2, layer1)`, normalizing the positions so
the first coordinate is always in `layer1` and the second in `layer2`. This matches
dagre's behavior because dagre uses `g.outEdges(v)` for north-layer nodes, which
captures all edges going from north to south (and in a properly layered graph with
long edges replaced by chains, all edges between adjacent layers go north-to-south).

---

## Bugs or Gaps

### 1. Missing edge weight support (Medium priority)

Dagre's cross count is **weighted**: each crossing contributes `weight_a * weight_b`
to the total. Our Rust code counts each crossing as 1. This matters because dagre
assigns `weight: 1` to normal edges but may assign different weights to edges created
during compound graph processing or other transformations.

For simple graphs where all weights are 1, the results are identical. But if we ever
support edge weights (e.g., from `minlen`/`weight` edge attributes), this would diverge.

**Current impact:** None for our use case - we don't set edge weights.

### 2. Layer membership check is O(n) per edge (Low priority)

Our code uses `layer1.contains(&from)` which is O(n) per call, making edge filtering
O(e * n). Dagre avoids this by iterating `g.outEdges(v)` for each north-layer node,
which naturally yields only relevant edges. This is a performance issue, not a
correctness issue.

### 3. Edges parameter is redundant (Low priority)

Our `count_crossings_between` takes an `edges` parameter and filters it. Dagre instead
queries `g.outEdges(v)` per north-layer node, which is more direct. Our approach works
but does redundant filtering work.

### 4. No bugs found in crossing detection logic

The core crossing detection `(u1 < u2 && v1 > v2) || (u1 > u2 && v1 < v2)` is
correct. It properly identifies inversions. Edges with shared endpoints (u1 == u2 or
v1 == v2) are correctly excluded from the crossing count, matching dagre's behavior
(equal positions don't create inversions in the tree accumulator either).

---

## Action Items

| Priority | Item | Rationale |
|----------|------|-----------|
| Low | Upgrade to O(e log n) tree accumulator | Performance only. O(e^2) is fine for typical graph sizes (<1000 edges). No correctness impact. |
| Low | Add edge weight support to crossing count | Not needed until we support edge weight attributes. All our edges currently have implicit weight 1. |
| Low | Replace `layer.contains()` with position lookup | Performance micro-optimization. Build a node-to-layer-index map for O(1) lookup instead of O(n) scan. |
| None | Fix crossing detection logic | No fix needed - logic is correct. |
