# Q1: How should the title dummy node be created in nesting::run()?

## Summary

The title dummy node should follow the exact pattern of border_top/border_bottom: created via `add_nesting_node()` with ID `_tt_{compound_id}`, stored in a new `border_title: HashMap<usize, usize>` on LayoutGraph, and connected via high-weight nesting edges in the chain `root → title → border_top → children → border_bottom`. Cleanup and rank assignment require no special handling because title edges are tracked in `nesting_edges` and automatically excluded after ranking.

## Where

- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/nesting.rs` (lines 18-78): `run()` creates border_top/border_bottom per compound, connects them with high-weight nesting edges
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/nesting.rs` (lines 84-94): `assign_rank_minmax()` extracts min/max ranks from border node ranks
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/nesting.rs` (lines 101-113): `cleanup()` zeros and excludes all nesting edges
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/graph.rs` (lines 363-374): `add_nesting_node()` creates zero-dimension dummy nodes
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/normalize.rs` (line 212): excluded edges are skipped during normalization

## What

### Current nesting implementation

For each compound node, `nesting::run()`:

1. Creates `border_top` (`_bt_{id}`) and `border_bottom` (`_bb_{id}`) via `add_nesting_node()`
2. Connects `border_top → each child` and `each child → border_bottom` with weight `(n * 2) as f64`
3. Connects root → border_top for top-level compound nodes
4. All edges tracked in `lg.nesting_edges` HashSet

`add_nesting_node()` appends to all parallel arrays (node_ids, ranks, order, positions, dimensions, parents), initializing rank=0, dimensions=(0.0, 0.0), parent=None.

### Cleanup mechanism

After ranking, `cleanup()`:
1. Marks all nesting edges with zero weight
2. Adds them to `excluded_edges`
3. Clears `nesting_edges` and `nesting_root`
4. Border nodes remain in graph for later use

The `excluded_edges` set is checked in normalize.rs to skip processing nesting edges.

### Rank assignment

`assign_rank_minmax()` extracts final ranks from border_top/border_bottom positions:
- `min_rank[compound] = ranks[border_top]`
- `max_rank[compound] = ranks[border_bottom]`

## How

### Proposed design

**Node creation** (in `run()`, after border_top/border_bottom):
```rust
let title_id = NodeId(format!("_tt_{}", compound_id));
let title_idx = lg.add_nesting_node(title_id);
lg.border_title.insert(compound_idx, title_idx);
```

**Edge connections** — replace `root → border_top` with `root → title → border_top`:
```rust
// root → title (instead of root → border_top)
let e = lg.add_nesting_edge(root_idx, title_idx, nesting_weight);
lg.nesting_edges.insert(e);

// title → border_top
let e = lg.add_nesting_edge(title_idx, top_idx, nesting_weight);
lg.nesting_edges.insert(e);
```

This creates the chain: `root → title → border_top → children → border_bottom`

**Data structure** (in graph.rs LayoutGraph):
```rust
pub border_title: HashMap<usize, usize>,
```

**ID naming**: `_tt_` follows the convention of `_bt_` (border top), `_bb_` (border bottom), `_bl_` (border left), `_br_` (border right).

### Why this approach

1. Title edges use the same `nesting_weight`, so ranking forces title above border_top
2. Title edges are nesting edges → automatically excluded after ranking
3. `assign_rank_minmax()` still uses border_top for min_rank (title is above it, not part of content span)
4. No interference with normalization (excluded edges are skipped)
5. Index-safe: `add_nesting_node()` is append-only

## Why

- **Connecting to border_top only** (not all children) avoids O(n) edges per compound and follows the existing border pattern
- **Replacing root → border_top** with root → title → border_top preserves clear layering hierarchy
- **Using existing nesting_weight** ensures deterministic rank ordering without new weight calculation

## Key Takeaways

- Title node follows the exact border_top/border_bottom pattern — no new abstractions needed
- Chain is `root → title → border_top → children → border_bottom`
- ID pattern: `_tt_{compound_id}`
- Stored in new `border_title: HashMap<usize, usize>` on LayoutGraph
- Cleanup and normalization require zero changes — nesting edge tracking handles everything
- `assign_rank_minmax()` continues using border_top/border_bottom for min/max ranks

## Open Questions

- Should `assign_rank_minmax()` update min_rank to use title rank instead of border_top rank, so the compound span includes the title?
- Should the title node have explicit height dimensions (for title text) rather than zero dimensions?
- If a compound has no title, should the title node be skipped entirely, or created with zero dimensions as a no-op?
