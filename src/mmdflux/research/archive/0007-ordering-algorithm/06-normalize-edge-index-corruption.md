# 06: Normalize Edge Index Corruption

## Discovery

After implementing the Dagre-style ordering algorithm (DFS init_order, adaptive sweeps with bias), `complex.mmd` still had G (Log Error) and H (Notify Admin) in the wrong order. The root cause was in `normalize.rs`, not in the ordering algorithm itself.

## The Bug

`normalize.rs` removes long edges from `graph.edges` using `Vec::remove(pos)`, which shifts all subsequent elements. This creates three problems:

1. **`edge_weights` desync** — The corresponding weight at `pos` is never removed, so `edge_weights[i]` no longer matches `edges[i]` for indices after the removed position.

2. **`reversed_edges` corruption** — `reversed_edges` stores positional indices into the `edges` vec. After a `remove()`, those indices become stale. An index that pointed at a reversed edge now points at whatever shifted into that position.

3. **Chain direction** — For reversed edges (e.g., E→A stored as the reverse of A→E), the chain of dummy nodes was built in stored direction (E→d0→d1→A) instead of effective direction (A→d0→d1→E). This created backward-pointing edges in the effective graph.

## Root Cause Trace (complex.mmd)

The graph has edge E→A which gets reversed during acyclic phase. Tracing the corruption:

1. Acyclic phase marks edge at position 4 (E→A) as reversed: `reversed_edges = {4}`
2. Normalize identifies E→A as a long edge (spans multiple ranks) and calls `graph.edges.remove(4)`
3. Edge D→G, previously at position 6, shifts to position 4
4. `reversed_edges` still contains `{4}`, now incorrectly pointing at D→G
5. `effective_edges()` reverses D→G to G→D
6. `init_order` DFS from D finds only H as a successor (G→D is reversed, so D→G is gone)
7. H gets order 1, G gets order 2 — wrong order

## Fix

Replaced the in-place mutation with a **collect-and-rebuild** strategy:

**Phase 1 — Collect:** Iterate all edges, identify long edges, generate chain data (dummy nodes + replacement edges) without mutating `graph.edges`. For reversed edges, build chains in effective direction (lower rank → higher rank).

**Phase 2 — Rebuild:** After processing all long edges:
- Filter `graph.edges` to exclude removed long edges, tracking old→new index mapping
- Append all chain edges (none are reversed — they flow in effective direction)
- Remap `reversed_edges` using the old→new mapping; removed edges drop out
- Replace `graph.edges`, `graph.edge_weights`, and `reversed_edges` atomically

This avoids all three corruption modes: weights stay aligned, reversed_edges indices are remapped, and chain edges point in the correct direction.

## Key Insight

Positional indices into mutable vectors are fragile. Any removal invalidates all subsequent indices and any external data structures (like `reversed_edges`) that reference them by position. The collect-and-rebuild pattern avoids this entirely by deferring all mutations to a single atomic rebuild step.

## Dagre Comparison

Dagre doesn't have this exact bug because it uses a different graph representation (`graphlib` with string-keyed edge maps rather than positional vectors). Its edge removal is O(1) key-based deletion that doesn't shift other entries.

However, the ordering results still differ between mmdflux and dagre because:
- Dagre uses even-only ranks with dummies on odd ranks; mmdflux uses consecutive ranks
- Edge insertion order differs, leading to different DFS traversal and barycenter tie-breaking
- Both orderings are valid — the fix ensures G is correctly a successor of D in init_order

## Verification

- All 251 unit tests + 27 integration tests pass
- `complex.mmd` renders with G (Log Error) left of H (Notify Admin)
- Debug tracing (`MMDFLUX_DEBUG_ORDER=1`) confirms init_order places G at order 1, H at order 2 in rank 3
