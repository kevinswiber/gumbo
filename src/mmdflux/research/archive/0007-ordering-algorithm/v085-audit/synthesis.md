# v0.8.5 Audit Synthesis

## Executive Summary

We audited all 9 files in dagre's `lib/order/` directory, comparing v0.8.5 (what Mermaid uses) against HEAD (v2.0.4-pre, what we initially based our research on), then comparing our Rust implementation (`src/dagre/order.rs`) against v0.8.5.

**Good news:** v0.8.5 and HEAD are functionally identical in 8 of 9 files. The only behavioral difference is in `index.js` (the `cc === bestCC` overwrite), which we already fixed in commit 62ad474. All other HEAD changes are lodash-to-native-JS modernization with no behavioral impact.

**Our implementation status:** The main loop, init ordering, sweep directions, termination logic, and crossing detection are all correct. Two behavioral gaps were found in the sort/barycenter pipeline — both have now been fixed (P1 in plan 0013, P2 infrastructure in plan 0013). However, both fixes are currently no-ops for typical mermaid flowcharts (see Implementation Status below).

## Version Comparison: v0.8.5 vs HEAD

| File | Behavioral difference? | Details |
|------|----------------------|---------|
| `index.js` | **YES** (already fixed) | `cc===bestCC` overwrite, `customOrder`, `constraints`, `disableOptimalOrderHeuristic` |
| `init-order.js` | No | Lodash removal only |
| `barycenter.js` | No | Lodash removal, default parameter |
| `resolve-conflicts.js` | No | Lodash removal |
| `sort.js` | No | Lodash removal |
| `sort-subgraph.js` | No | Lodash removal |
| `cross-count.js` | No | Lodash removal, redundant `_.forEach` wrapper |
| `build-layer-graph.js` | No | Lodash removal, `nodesWithRank` perf optimization |
| `add-subgraph-constraints.js` | No | Lodash removal |

## Our Rust vs v0.8.5: What Matches

These aspects are **correctly implemented** and match v0.8.5 behavior:

- **`init_order()`** — DFS-based initial ordering, rank-sorted start nodes, visit-once semantics. Behaviorally equivalent. *(init-order.md)*
- **Main loop structure** — Alternating up/down sweeps, left/right bias pattern (`i%4 >= 2`), strict-improvement-only best tracking, `lastBest < 4` termination. *(index-loop.md)*
- **Sweep directions** — `sweep_up` fixes layer below, reorders using successors. `sweep_down` fixes layer above, reorders using predecessors. Matches dagre exactly. *(index-loop.md)*
- **Layer reuse** — Fixed `layers` vec used as rank-membership sets is correct; ordering is read from `graph.order[node]`. *(index-loop.md)*
- **Crossing detection** — Pairwise inversion check is mathematically equivalent to dagre's bilayer tree accumulator for unweighted graphs. *(cross-count.md)*
- **Bias-aware tie-breaking** — `original_pos` tie-breaking with direction flip matches `compareWithBias`. *(sort-pipeline.md)*

## Prioritized Changes Needed

### P1: Unsortable Node Interleaving — ✅ FIXED (plan 0013)

**Gap:** Nodes with no connections to the fixed layer are handled differently.

- **Dagre v0.8.5:** `barycenter.js` returns `{v}` (no barycenter). `sort.js` partitions these as "unsortable" and interleaves them at their original index positions among the sorted nodes via `consumeUnsortable()`. They never displace barycenter-sorted nodes.
- **Our Rust (before fix):** Assigned `graph.order[node]` as a synthetic barycenter, making neighborless nodes compete with connected nodes in the sort.
- **Our Rust (after fix):** Partitions into sortable/unsortable and interleaves using `consumeUnsortable` pattern matching dagre.

**Current impact:** No-op for typical mermaid flowcharts. After normalization, every node has neighbors in both adjacent layers (dummy nodes fill long edges), so all nodes are sortable and the interleaving loop never executes. Only affects graphs with truly isolated nodes sharing a rank.

**Files:** `sort-pipeline.md` (section 4.1), `index-loop.md` (Bug 2)

### P2: Edge Weight Support in Barycenter — ✅ INFRASTRUCTURE ADDED (plan 0013)

**Gap:** Dagre computes weighted barycenter: `sum(edge.weight * node.order) / sum(edge.weight)`. We computed unweighted: `sum(order) / count`.

**What was done:** Added `edge_weights: Vec<f64>` to `LayoutGraph`, `effective_edges_weighted()` method, and updated `reorder_layer()` to compute weighted barycenters. All weights default to 1.0.

**Current impact:** No-op — nothing sets weights to non-1.0 values yet. The weighted formula with all weights=1 produces identical results to the old unweighted formula. To have actual impact, a caller would need to set non-default weights (e.g., dagre's `buildLayerGraph` doubles weights for edges involving dummy nodes — this is not yet implemented).

**Files:** `sort-pipeline.md` (section 4.2), `build-layer-graph.md` (edge handling), `index-loop.md` (Bug 1)

### P3: Performance Optimizations (LOW priority)

These are correctness-equivalent but slower than dagre:

| Item | Our complexity | Dagre complexity | Source |
|------|---------------|-----------------|--------|
| Crossing count algorithm | O(e^2) per layer pair | O(e log n) bilayer tree | cross-count.md |
| Layer membership check | O(n) via `contains()` | O(1) via position map | cross-count.md |
| Edge filtering per layer | O(e) scan all edges | O(degree) via `inEdges`/`outEdges` | build-layer-graph.md |

**Recommended action:** Address only if profiling shows these are bottlenecks for real-world graphs.

### Not Needed

| Item | Why | Source |
|------|-----|--------|
| `resolve-conflicts.js` | Empty constraint graph without compound nodes — degenerates to identity transform | sort-pipeline.md |
| `add-subgraph-constraints.js` | Purely subgraph machinery | build-layer-graph.md |
| `sort-subgraph.js` recursion | No compound nodes | sort-pipeline.md |
| `build-layer-graph.js` | Our inline edge filtering is equivalent for non-compound, uniform-weight case | build-layer-graph.md |
| Edge weight in `crossCount` | All weights are 1 | cross-count.md |

## Implementation Status

**Plan 0013** (branch `dagre-ordering-algorithm`) implemented P1 and P2. Both changes are structurally correct but produce no observable output differences for any test fixture, including `complex.mmd`. This was confirmed by comparing the binary output before and after the changes.

### Why complex.mmd still differs from Mermaid

The `complex.mmd` rendering differs from Mermaid in two ways:

1. **G (Log Error) and H (Notify Admin) are swapped.** Both are successors of D (Error Handler) with identical barycenters. Their relative order is determined by tie-breaking across multiple sweep iterations with alternating bias. Both orderings produce the same crossing count (zero for that layer pair), so this is convergence to a different but equally valid local optimum. This is a tie-breaking sensitivity issue, not an algorithmic gap.

2. **The backward "yes" edge routes differently.** This is an edge routing / coordinate assignment difference, outside the ordering algorithm's scope.

Neither P1 nor P2 addresses these differences because:
- **P1** requires nodes with no neighbors in the fixed layer. After normalization, all nodes in `complex.mmd` are connected — every long edge is split with dummy nodes.
- **P2** requires non-uniform edge weights. All weights are 1.0.

### Remaining ordering differences to investigate

The G/H tie-breaking divergence could stem from:
- **Init order successor traversal order** — dagre's graphlib may enumerate successors in a different order than our `Vec<Vec<usize>>` adjacency list, leading to different DFS visit order and different initial positions.
- **Subtle differences in how `original_pos` is computed** — dagre's `sort.js` uses the index from `resolveConflicts` output, while we use the index in the `free` array. For non-compound graphs these should be equivalent, but edge cases may exist.

These are not covered by the v0.8.5 audit (which focused on algorithmic structure, not data structure iteration order).

## Audit Files

| File | Scope |
|------|-------|
| [init-order.md](init-order.md) | `init-order.js` |
| [sort-pipeline.md](sort-pipeline.md) | `sort-subgraph.js`, `sort.js`, `barycenter.js`, `resolve-conflicts.js` |
| [cross-count.md](cross-count.md) | `cross-count.js` |
| [build-layer-graph.md](build-layer-graph.md) | `build-layer-graph.js`, `add-subgraph-constraints.js` |
| [index-loop.md](index-loop.md) | `index.js` main loop |
