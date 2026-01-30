# Q3: Layout-Level Structural Fixes

## Summary

Five layout-level approaches were evaluated. **Option A (add a title rank in dagre)** is the strongest structural fix — it prevents collisions by construction using dagre's existing nesting infrastructure, works for all directions, and requires ~50 lines across 3 files. **Option B (conditional top padding)** is the simplest (~10 lines) but is empirical rather than structural. The recommended long-term solution is Option A, with Option B as a lightweight alternative if dagre changes are too invasive.

## Where

- `src/render/layout.rs` — `convert_subgraph_bounds()` (line 696), `compute_layout_direct()`
- `src/dagre/nesting.rs` — compound node / border node system
- `src/dagre/graph.rs` — LayoutGraph structure
- `src/dagre/rank.rs` — ranking/layer assignment
- `src/dagre/normalize.rs` — dummy nodes for long edges

## What

### Option A: Add Extra Rank/Row for Title (RECOMMENDED)
- Insert a dummy "title node" at the top of each subgraph during `nesting::run()`
- Creates nesting edges: `border_top -> title_node -> first_child`
- Pushes member nodes down by one rank, creating guaranteed title space
- **~50 lines** across 3 files (`nesting.rs`, `position.rs`, `layout.rs`)
- **Robustness: 5/5** — structural guarantee, direction-agnostic, leverages existing infrastructure

### Option B: Conditional Top Padding in convert_subgraph_bounds()
- Increase top `border_padding` from 2 to 3 when title exists
- **~10 lines** in 1 file (`layout.rs`)
- Only moves border, not nodes — creates visual gap but doesn't prevent geometric collision
- **Robustness: 3/5** — empirical, doesn't guarantee prevention

### Option C: Use dagre Border Nodes to Reserve Title Space
- Give `border_top` dummy nodes non-zero dimensions (title height)
- dagre's position phase would respect dimensions and create space
- **~30 lines** across 2 files
- **Robustness: 4/5** — near-structural, but unclear if dummy node dimensions are handled correctly

### Option D: Post-Layout Node Offset
- After dagre, shift member nodes down by 1 row within their subgraph
- **Severely fragile** — invalidates collision repair, edge routing, waypoints
- **Robustness: 2/5** — not recommended

### Option E: Entry-Edge-Aware Padding
- Check which sides have incoming edges, pad only those sides
- **~30 lines** in 1 file
- Only handles external edges; misses internal backward edges
- **Robustness: 3/5** — incomplete solution

## How

### Option A Implementation
1. In `nesting::run()`, create a title dummy node for each compound node with a title
2. Add nesting edges: `border_top -> title_dummy` and `title_dummy -> each child`
3. Title dummy has zero or minimal dimensions (just occupies a rank)
4. In `layout.rs`, filter title dummies when computing subgraph bounds
5. Result: guaranteed 1-rank gap between border and first content node

### Comparison Table

| Criterion | A (Title Rank) | B (Padding) | C (Border Dims) | D (Offset) | E (Entry) |
|-----------|---------------|-------------|-----------------|------------|-----------|
| Node Position Impact | Moderate | None | Moderate | Severe | None |
| Robustness | 5/5 | 3/5 | 4/5 | 2/5 | 3/5 |
| Code Complexity | ~50 lines | ~10 lines | ~30 lines | ~20 lines | ~30 lines |
| Structural guarantee | Yes | No | Partial | No | No |

## Why

Option A is the "correct forever" solution because:
1. **Prevention by construction** — the title rank creates physical separation in the layout graph
2. **Leverages existing infrastructure** — dagre's nesting system already manages border nodes and ranks
3. **Direction-agnostic** — works identically for TD/BT/LR/RL
4. **No render-time heuristics** — collision prevention is built into the layout
5. **Handles all edge types** — forward, backward, cross-subgraph edges all respect rank separation

## Key Takeaways

- The most robust fix operates at the dagre nesting level (Option A)
- The simplest fix operates at the bounds computation level (Option B) but isn't structural
- Post-layout adjustments (Option D) are dangerous because they invalidate earlier pipeline stages
- dagre's existing border node system is designed for exactly this kind of extension

## Open Questions

- Does adding a title rank increase diagram height noticeably for small subgraphs?
- How does the title rank interact with cross-subgraph edges that span multiple ranks?
- Should the title rank have zero width/height or some minimum dimensions?
