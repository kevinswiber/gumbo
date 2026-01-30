# Q3: Does the DFS vs BFS traversal order matter for block graph compaction?

## Summary

No, the traversal order does not matter for the final compaction result. Both DFS post-order (dagre.js) and BFS/Kahn's algorithm (mmdflux) must process nodes in a valid topological order, and for DAGs, the constraint-satisfaction algorithm (Pass 1) produces the same result regardless of which valid topological ordering is chosen. The compaction result is determined entirely by the DAG structure and edge weights, not the traversal strategy.

## Where

- `src/dagre/bk.rs` lines 756-790 (`BlockGraph::topological_order` — Kahn's algorithm)
- `src/dagre/bk.rs` lines 640-691 (`horizontal_compaction` — two-pass algorithm)
- `/Users/kevin/src/dagre/lib/position/bk.js` lines 216-264 (`iterate` function — DFS post-order)
- `/Users/kevin/src/dagre/lib/position/bk.js` lines 206-264 (`horizontalCompaction` — two-pass algorithm)
- `plans/0022-bk-block-graph-compaction/findings/block-graph-is-noop.md`
- `research/0014-remaining-visual-issues/q2-bk-block-graph.md`

## What

### dagre.js: DFS Post-Order

dagre.js implements `iterate()` (lines 216-236) as a stack-based DFS with post-order processing. It maintains a stack initialized with all block graph nodes, marks visited nodes, and pushes neighbors before processing. For Pass 1, `nextNodesFunc` is `blockG.predecessors`, traversing backward (sinks toward sources), ensuring predecessors are processed before successors.

### mmdflux: Kahn's Algorithm (BFS)

mmdflux implements `topological_order()` (lines 756-790) as Kahn's algorithm: initialize in-degree counts, collect source nodes (in-degree 0) into a queue, pop nodes and decrement successor in-degrees, adding newly zero-in-degree nodes to the queue. Sources and successors are sorted at each step for determinism.

### Both Are Valid Topological Orders

Both algorithms guarantee: for every edge A→B, A is processed before B. When a node is processed, all its predecessors have already been processed in both implementations. The orderings may differ for nodes with no dependency between them, but this doesn't affect the result.

## How

### Pass 1: Longest-Path Computation

Pass 1 computes:
```
For each node v in topological order:
  x[v] = max over predecessors p of (x[p] + weight(p → v))
```

This is a longest-path computation on a DAG. Each node has a unique longest-path distance from sources, determined by the DAG structure and edge weights. This value is independent of traversal order because:

1. When we process v, all predecessors have been processed (true for any valid topological order)
2. Each predecessor's x-value is the unique longest path to that predecessor
3. Therefore `max(x[p] + w)` over predecessors is identical regardless of ordering

**Formal argument:** Suppose two different topological orderings produced different x[v] for some node v. This would mean the max over predecessors differs — but the set of predecessors is fixed, and each predecessor's value is unique. Contradiction.

### Pass 2: No-Op for DAGs

After Pass 1, by construction: `x[s] >= x[v] + weight(v → s)` for every edge v → s. Rearranging: `x[s] - weight(v → s) >= x[v]`. Therefore `min(x[s] - weight(v → s)) >= x[v]`, and the update condition `min > x[v]` is never satisfied. Pass 2 never modifies any coordinates, regardless of traversal order.

### Empirical Confirmation

Plan 0022 replaced the old recursive `place_block` (neither DFS nor Kahn's) with block graph + Kahn's and produced byte-for-byte identical results on all 27 test fixtures. The `test_pass2_is_noop` test confirms Pass 2 never modifies coordinates for all 4 alignments.

## Why

### Why dagre.js chose DFS post-order
- Standard graph algorithm pattern, common in academic literature
- Works naturally for any DAG regardless of starting point

### Why mmdflux chose Kahn's algorithm
- Deterministic with sorting — reproducible and testable
- Layer-by-layer processing aligns with the Sugiyama framework
- Explicit in-degree tracking makes dependencies transparent

### Why it doesn't matter
The longest-path computation has a unique result determined by the DAG structure. This is analogous to computing a sum: order of operations doesn't change the result. The max-over-predecessors operation produces a DAG-structure-determined result regardless of processing order.

## Key Takeaways

- Traversal order is not a variable for Pass 1 correctness — both DFS and Kahn's produce identical longest-path coordinates because the longest path from sources to any node is unique
- Pass 1 is constraint-satisfaction, not traversal-dependent
- Pass 2 is provably a no-op for DAGs regardless of traversal order
- Both implementations are provably equivalent when given the same block graph and edge weights
- Empirical confirmation from Plan 0022: replacing one traversal strategy with another produced identical output on all 27 fixtures

## Open Questions

- Could different traversal orders affect floating-point rounding? (Unlikely — each coordinate is a single max/min reduction, not accumulated sums)
- Could multi-pass or iterative variants of compaction exhibit traversal-dependent behavior? (Possibly, but the BK algorithm as implemented is deterministic and order-independent)
