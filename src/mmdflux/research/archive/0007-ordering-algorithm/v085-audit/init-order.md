# init-order.js Audit: v0.8.5 vs HEAD vs Rust

## v0.8.5 vs HEAD differences

The algorithm is structurally identical. Changes are purely mechanical:

1. **lodash removal**: v0.8.5 uses `_.filter`, `_.max`, `_.map`, `_.range`, `_.has`, `_.sortBy`, `_.forEach`. HEAD replaces these with native JS methods (`.filter()`, `.map()`, `.sort()`, `.forEach()`) plus a custom `util.range()` and `util.applyWithChunking(Math.max, ...)`.

2. **`_.has(visited, v)` vs `visited[v]`**: v0.8.5 checks `_.has(visited, v)` which tests if the key exists in the object. HEAD checks `if (visited[v])` which is truthy check. Behaviorally identical because the only values ever stored are `true`.

3. **Sort stability**: v0.8.5 uses `_.sortBy` (stable sort). HEAD uses native `.sort()` which is stable in modern JS engines (V8, SpiderMonkey). No behavioral difference in practice.

4. **Max rank computation**: v0.8.5 uses `_.max(_.map(...))`. HEAD uses `util.applyWithChunking(Math.max, simpleNodesRanks)` to avoid `Math.max.apply` stack overflow on large arrays. No behavioral difference for reasonable graph sizes.

5. **`var` vs `let`**: Pure syntax modernization.

**Conclusion**: No behavioral differences between v0.8.5 and HEAD for `initOrder`. The mermaid/dagre-d3-es copy is identical to v0.8.5 (still uses lodash-es).

## Our Rust vs v0.8.5

### Exact behavioral matches

- **DFS traversal**: Both perform DFS from nodes sorted by rank ascending, assigning order within each rank as nodes are first visited.
- **Visit-once semantics**: Both skip already-visited nodes.
- **Successor ordering**: Rust pushes successors in reverse onto the stack so first successor is popped first, matching recursive DFS visit order.
- **Rank-based ordering**: Start nodes sorted by rank ascending, matching `_.sortBy(simpleNodes, v => g.node(v).rank)`.

### Differences that don't matter

1. **Iterative vs recursive DFS**: Rust uses an explicit stack instead of recursion. This is behaviorally equivalent when successors are pushed in reverse order (which the code does).

2. **No `layers` return value**: v0.8.5 returns a `layers` matrix (array of arrays). Rust instead writes directly to `graph.order[node]` using a `layer_next_idx` counter per rank. This is equivalent -- `layers[rank][i] = node` means `node` gets order `i` in that rank, which is exactly what `graph.order[node] = layer_next_idx[rank]` computes.

3. **No `simpleNodes` filter**: v0.8.5 filters to nodes without children (`!g.children(v).length`) to skip compound/subgraph parent nodes. Rust iterates all nodes `(0..n)`. This is intentionally correct because we don't support subgraphs, so all nodes are "simple nodes."

4. **Start node set**: v0.8.5 sorts only `simpleNodes` by rank and starts DFS from those. Rust sorts all nodes by rank. Equivalent given no compound nodes exist.

### Differences that matter

**None identified.** The Rust implementation is behaviorally equivalent to v0.8.5 for simple (non-compound) graphs.

## Bugs or gaps

No bugs found. The implementation correctly replicates dagre v0.8.5 behavior.

One minor observation: if `graph.ranks` contains negative values, the `as usize` cast on line 49 would panic. However, dagre's rank assignment always produces non-negative ranks (the `normalize` step adjusts ranks to start from 0), so this is not a real concern.

## Action items

None. The Rust `init_order()` is a correct port of dagre v0.8.5's `initOrder` for non-compound graphs.
