# Finding: Post-BK Centering Was Already Adequate After node_sep Reduction

## Summary

Task 3.1 added a post-BK centering pass for layer-0 source nodes. The RED phase test passed before implementation, meaning BK already centered source nodes correctly after the `node_sep` reduction from task 2.2.

## Why BK Centers Correctly With Small node_sep

With `node_sep=6.0` (LR), the BK algorithm's median-based alignment produces center positions that are already close to the midpoint of successors. The large `node_sep=50.0` created more room for alignment drift, but the smaller value constrains positions enough that centering happens naturally.

## The Pass Is Still Valuable

The post-BK centering pass was implemented anyway because:
1. It provides robustness for more complex graphs where BK may not center layer-0 nodes
2. It's a cheap operation (single pass over layer-0 nodes)
3. It matches dagre.js behavior more closely

## Implementation Note

The centering pass uses `LayoutGraph.edges` directly rather than petgraph methods (the plan suggested petgraph, but `LayoutGraph` doesn't expose petgraph's `edges_directed`). The iteration pattern:

```rust
// Find successors by scanning edges
let succ_ys: Vec<f64> = graph.edges.iter()
    .filter(|&&(from, _, _)| from == node)
    .filter_map(|&(_, to, _)| y_coords.get(&to).copied())
    .collect();
```

This is O(E) per layer-0 node but acceptable since layer-0 typically has few nodes.
