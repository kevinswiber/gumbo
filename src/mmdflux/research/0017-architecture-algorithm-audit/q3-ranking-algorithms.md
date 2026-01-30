# Q3: Ranking Algorithms

## Summary

mmdflux uses a longest-path algorithm via Kahn's topological sort for rank assignment, while Dagre.js defaults to the network simplex algorithm with longest-path and tight-tree available as alternatives. Network simplex is the standard algorithm from the Sugiyama framework literature (Gansner et al., "A Technique for Drawing Directed Graphs") and produces optimal rank assignments that minimize total weighted edge length. Longest-path is fast but pushes nodes to the lowest possible layer, creating unnecessarily wide bottom ranks and longer edges, which directly increases the number of dummy nodes and degrades layout compactness.

## Where

- **mmdflux ranking:** `/Users/kevin/src/mmdflux/src/dagre/rank.rs` (75 lines + tests)
- **Dagre.js rank entry:** `/Users/kevin/src/dagre/lib/rank/index.js`
- **Dagre.js network simplex:** `/Users/kevin/src/dagre/lib/rank/network-simplex.js` (236 lines)
- **Dagre.js feasible tree:** `/Users/kevin/src/dagre/lib/rank/feasible-tree.js` (96 lines)
- **Dagre.js rank utilities:** `/Users/kevin/src/dagre/lib/rank/util.js` (longestPath, slack)
- **mmdflux normalization:** `/Users/kevin/src/mmdflux/src/dagre/normalize.rs` (shows downstream impact of ranking on dummy node insertion)

## What

### Dagre.js: Three Ranking Strategies

Dagre.js supports three named rankers plus a custom function callback (see `index.js` lines 29-42):

1. **`"network-simplex"` (default):** Optimal rank assignment minimizing total weighted edge length. This is the algorithm described in Gansner et al. and is the standard choice in the Sugiyama framework.

2. **`"tight-tree"`:** Runs longest-path first, then constructs a feasible tight tree (adjusting ranks so all spanning tree edges have zero slack). This is an intermediate quality/speed tradeoff -- better than longest-path alone but not optimal.

3. **`"longest-path"`:** The simplest and fastest ranker. Assigns each node to the lowest rank possible. Dagre.js's own comments describe this as "fast and simple, but results are far from optimal."

4. **Custom function:** A user-supplied `ranker` function can be passed via the graph options.

### mmdflux: Longest-Path Only

mmdflux implements only the longest-path strategy. The code comment at line 4 of `rank.rs` acknowledges this: "For optimal results, network simplex would be used (Dagre's approach)."

### Key Concept: `minlen` and `weight`

Dagre.js edges carry two attributes that the ranking algorithms use:

- **`minlen`:** Minimum number of ranks an edge must span (default 1). This allows edges to enforce minimum separation between nodes.
- **`weight`:** Importance of the edge for optimization. Network simplex minimizes the sum of `weight * (actual_length - minlen)` across all edges.

mmdflux has `edge_weights` (default 1.0 for all edges) but does **not** use them during ranking -- they are only used later during crossing reduction (barycenter calculation) and coordinate assignment (Brandes-Kopf). mmdflux has no `minlen` concept; all edges implicitly have minlen=1.

### Key Concept: Slack

Slack is defined as `rank(w) - rank(v) - minlen(v,w)` for edge (v,w). An edge is "tight" when slack = 0. Network simplex works by iteratively reducing slack on non-tree edges, which is equivalent to minimizing total weighted edge length.

## How

### mmdflux Longest-Path Algorithm

The implementation in `rank.rs` uses Kahn's topological sort:

1. **Build adjacency:** Compute in-degree and successor lists from effective edges (with cycle reversals applied from the acyclic phase).
2. **Initialize queue:** All nodes with in-degree 0 start at rank 0.
3. **Process in topological order:** For each node dequeued, update successors: `rank[succ] = max(rank[succ], rank[node] + 1)`. Decrement in-degrees; enqueue when in-degree reaches 0.
4. **Fallback:** Any unprocessed nodes (shouldn't happen post-acyclic phase) get assigned max_rank + 1.

This produces a valid ranking where every edge goes from a lower rank to a higher rank, and every edge spans at least 1 rank. However, it pushes nodes as far down as possible, which means:

- Sink nodes cluster at the bottom.
- Edges that could be shorter are stretched to their maximum length.
- More dummy nodes are needed during normalization.

**Time complexity:** O(V + E) -- linear in graph size.

### Dagre.js Longest-Path Algorithm

The Dagre.js longest-path (`util.js` lines 31-59) uses a DFS approach from source nodes:

1. For each source node, recursively compute: `rank(v) = min over out-edges e: rank(e.w) - minlen(e)`.
2. Leaf nodes (no out-edges) get rank 0.
3. All other nodes get the minimum rank that satisfies all their outgoing edge constraints.

This pushes nodes to the **lowest** (most negative) rank possible. The result is then normalized. This is equivalent to mmdflux's approach in result but uses a different traversal strategy (DFS vs BFS/Kahn's).

### Dagre.js Feasible Tree Construction

The feasible tree (`feasible-tree.js`) takes an initial ranking (from longest-path) and constructs a spanning tree of tight edges:

1. Start from an arbitrary node; add it to tree.
2. Greedily add tight edges (slack = 0) via DFS.
3. If the tree doesn't span all nodes, find the minimum-slack edge crossing the tree boundary, shift all tree node ranks by that slack amount to make it tight, and repeat.

This process adjusts ranks to create as many tight edges as possible, which effectively shortens many unnecessarily long edges from the longest-path assignment.

### Dagre.js Network Simplex Algorithm

Network simplex (`network-simplex.js`) is an iterative optimization algorithm:

1. **Initialize:** Run longest-path to get a feasible ranking.
2. **Construct feasible tree:** Build a spanning tree of tight edges (using the feasible tree algorithm).
3. **Assign low/lim values:** DFS numbering for efficient descendant queries. Each node gets `low` and `lim` values such that node `u` is a descendant of `v` iff `v.low <= u.lim <= v.lim`.
4. **Compute cut values:** For each tree edge, compute a "cut value" that measures the benefit of removing that edge. The cut value considers the weights of all edges crossing the partition created by removing the tree edge.
5. **Pivot loop:** Repeatedly:
   - **Leave edge:** Find a tree edge with negative cut value (removing it would improve the objective).
   - **Enter edge:** Find the non-tree edge with minimum slack that crosses the same partition (this edge becomes tight when added).
   - **Exchange:** Remove the leaving edge from the tree, add the entering edge, update low/lim values, cut values, and ranks.
6. **Terminate:** When no tree edge has a negative cut value, the ranking is optimal.

The cut value calculation (`calcCutValue`, lines 86-120) is the core mathematical operation:
- For a tree edge between child and parent, start with the edge's own weight.
- For each non-tree edge incident on the child: add weight if it points in the same direction as the tree edge, subtract if opposite.
- For each tree edge incident on the child (to other children): add or subtract the sub-tree's cut value.

**Time complexity:** O(V * E) in the worst case per pivot, but typically much faster in practice. The algorithm is polynomial and terminates because each pivot strictly improves the objective function.

**Optimality:** Network simplex finds a ranking that minimizes the sum of `weight(e) * length(e)` over all edges, where `length(e) = rank(target) - rank(source)`. This is provably optimal for the linear programming relaxation of the ranking problem.

## Why

### When Longest-Path Fails

Consider a graph with a "wide base" pattern:

```
    A
   / \
  B   C
  |   |
  D   E
   \ /
    F
```

With longest-path, all nodes are pushed to the lowest rank possible:
- A=0, B=1, C=1, D=2, E=2, F=3

This is optimal for this symmetric diamond -- both algorithms agree here.

Now consider an asymmetric case:

```
A --> B --> C --> D
A --> D
```

Longest-path assigns: A=0, B=1, C=2, D=3. The edge A-->D spans 3 ranks, requiring 2 dummy nodes.

Network simplex can potentially assign: A=0, B=1, C=2, D=3 as well -- but because A-->D has weight 1 and length 3, while B-->C and C-->D each have weight 1 and length 1, the total weighted length is 3+1+1+1=6. There's no way to improve this without violating constraints, so for this particular case both algorithms agree.

The critical difference emerges with **optional edges** or **varying minlen**. For example:

```
A --> B (minlen=1)
A --> C (minlen=1)
B --> D (minlen=1)
C --> D (minlen=3)
```

Longest-path: A=0, B=1, C=1, D=4 (C-->D forces D to rank 4). B-->D spans 3 ranks (2 dummies).

Network simplex could assign: A=0, B=3, C=1, D=4. Now B-->D spans only 1 rank (0 dummies), A-->B spans 3 ranks (2 dummies). The total weighted edge length is the same (3+1+3+1=8 vs 1+1+3+3=8), but the choice of which edges to lengthen may interact better with crossing reduction.

More importantly, network simplex can **pull nodes upward** when doing so reduces total edge length. Consider:

```
A --> B --> C --> D
      B --> D
E --> D
```

Longest-path: A=0, B=1, C=2, D=3, E=0. Edge B-->D spans 2 ranks, E-->D spans 3 ranks = 5 dummy edges.

Network simplex: A=0, B=1, C=2, D=3, E=2. E-->D now spans only 1 rank = 2 dummy edges. E was pulled up because it has no constraint forcing it to rank 0 (no predecessors, so any rank works). Longest-path always pushes unconnected source nodes to rank 0; network simplex places them optimally.

### Practical Impact on mmdflux

Since mmdflux does not support `minlen` (all edges have implicit minlen=1) and all edge weights are 1.0 during ranking, the difference between longest-path and network simplex manifests primarily in:

1. **Disconnected components or independent subgraphs:** Longest-path pushes all source nodes to rank 0, even when placing them at a higher rank would reduce total edge length. Network simplex optimally places free-floating nodes.

2. **Graphs with multiple paths of different lengths between the same pair of nodes:** Network simplex balances which path gets stretched, potentially reducing the maximum stretch.

3. **Total dummy node count:** Since each extra rank span requires a dummy node during normalization, reducing total edge length directly reduces the number of dummies, which improves crossing reduction performance and layout quality.

4. **Layout compactness:** Fewer ranks with the same node count means a more compact vertical layout. Longest-path tends to produce the maximum number of ranks; network simplex may reduce the rank count.

### Design Tradeoffs

| Property | Longest-Path | Network Simplex |
|---|---|---|
| Time complexity | O(V + E) | O(V * E) typical |
| Optimality | Feasible but not optimal | Optimal (min weighted edge length) |
| Implementation complexity | ~50 lines | ~200+ lines (+ feasible tree, cut values) |
| `minlen` support | Not needed (all=1) | Core feature |
| Weight sensitivity | Not used | Core feature |
| Layout quality | Adequate for simple graphs | Superior for complex graphs |

## Key Takeaways

- mmdflux uses the simplest ranking strategy (longest-path via Kahn's topological sort), which is O(V+E) and produces valid but potentially suboptimal rankings. Dagre.js defaults to network simplex, which is the standard optimal algorithm from the Sugiyama framework literature.

- Network simplex provides provably optimal rank assignments minimizing total weighted edge length. It works by maintaining a spanning tree of tight edges and iteratively pivoting to improve the objective. The implementation requires feasible tree construction, cut value computation, low/lim DFS numbering, and a leave/enter/exchange pivot loop -- roughly 4x the code of longest-path.

- The practical difference matters most for graphs with independent subgraphs, multiple paths between the same nodes, or nodes with few constraints. For simple linear chains and symmetric diamonds, both algorithms produce identical results.

- Dagre.js also supports a `"tight-tree"` ranker that is intermediate in quality: it runs longest-path then constructs a feasible tight tree to shorten edges, without the full pivot optimization. This could be a simpler incremental improvement for mmdflux than full network simplex.

- mmdflux does not currently use `minlen` or edge weights during ranking. Adding network simplex would be a prerequisite for supporting `minlen` constraints, which enable features like subgraph rank constraints and minimum edge separation.

- The absence of network simplex in mmdflux likely causes noticeable layout quality degradation primarily in complex diagrams with many fan-in/fan-out patterns, optional paths, or loosely connected components where source nodes get unnecessarily pushed to rank 0.

## Open Questions

- How much does the tight-tree intermediate strategy improve layout quality over pure longest-path in mmdflux's typical diagrams? Could this be a simpler first step before full network simplex?
- Does mmdflux need `minlen` support for any current or planned features (e.g., subgraph constraints, minimum edge gaps)?
- What is the performance impact of network simplex on mmdflux's target diagram sizes? For small ASCII diagrams (10-50 nodes), the O(V*E) cost may be negligible.
- Should edge weights be incorporated into ranking (not just crossing reduction) to give users control over which edges are kept short?
- The Dagre.js network simplex implementation reinitializes all cut values and low/lim values on every pivot (`exchangeEdges` at line 194-202). Gansner et al. describe incremental updates. Would an optimized implementation be needed for mmdflux's use cases, or is the naive approach sufficient?
