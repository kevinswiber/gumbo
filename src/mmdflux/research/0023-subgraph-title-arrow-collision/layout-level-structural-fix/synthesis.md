# Research Synthesis: Layout-Level Structural Fix for Title-Arrow Collision

## Summary

Adding a title dummy node to dagre's nesting system is structurally sound. The title node follows the existing border_top/border_bottom pattern — created via `add_nesting_node()`, connected with high-weight nesting edges, and automatically excluded after ranking. The dagre pipeline (normalize, position, BK) handles the extra rank without architectural changes. Two targeted fixes are needed: (1) ordering must handle the single-child title rank for border placement, and (2) the render layer's `convert_subgraph_bounds()` must account for title-rank vertical space since it independently recomputes bounds from member positions.

## Key Findings

### 1. Title node insertion is straightforward (Q1)

The title dummy node mirrors the existing border_top/border_bottom pattern exactly:
- ID: `_tt_{compound_id}`, created via `add_nesting_node()`
- Stored in new `border_title: HashMap<usize, usize>` on LayoutGraph
- Chain: `root → title → border_top → children → border_bottom`
- Nesting edges are automatically excluded after ranking — no cleanup changes needed
- `assign_rank_minmax()` continues using border_top/bottom for content span

### 2. Ordering has a single-child gap (Q2)

`apply_compound_constraints()` skips border placement when `child_positions.len() < 2`. The title rank has only one child (the title dummy), so border_left/right at the title rank are created but not positioned. This is the one structural issue requiring a fix — either handle the `== 1 child` case or skip border creation at the title rank entirely.

### 3. BK and coordinate assignment are unaffected (Q3)

BK operates perpendicular to rank direction (horizontal for TD/BT) and correctly handles zero-dimension nodes. Rank spacing is `max_height + rank_sep` per rank — a zero-height title rank adds exactly `rank_sep` (50.0 default). To control title space precisely, the title node should have explicit height dimensions rather than relying on `rank_sep` alone.

### 4. Render-layer bounds need adjustment, not dagre (Q4)

`remove_nodes()` handles the title rank automatically through border aggregation. But `convert_subgraph_bounds()` independently recomputes bounds from member-node positions and has no title-rank awareness. This is where the title's vertical footprint must be accounted for — extending the top y-bound by the title height.

### 5. Cross-subgraph edges work seamlessly (Q5)

Long edges spanning the title rank get an extra dummy node at that rank — standard normalization behavior. The dummy becomes a waypoint during denormalization, is transformed via `layer_starts[title_rank]`, and is routed like any other waypoint. No special handling needed.

## Recommendations

1. **Add `border_title` to LayoutGraph** — New `HashMap<usize, usize>` mapping compound index to title dummy node index. Follow the `border_top`/`border_bottom` storage pattern.

2. **Insert title node in `nesting::run()`** — Create `_tt_{compound_id}`, connect as `root → title → border_top` with `nesting_weight`. Only create for compounds that have a title string.

3. **Fix ordering for single-child ranks** — Either: (a) extend `apply_compound_constraints()` to handle the `== 1 child` case by placing left border before and right border after the single child, or (b) skip border creation at the title rank in `add_segments()` and rely on vertical linking from adjacent ranks. Option (a) is more robust.

4. **Give title node explicit dimensions** — Set height to match the rendered title text (1 row in character grid, mapped to dagre float units). This ensures `rank_sep` is additive space below the title, not the only space.

5. **Adjust `convert_subgraph_bounds()`** — When a compound has a title, extend the top y-bound upward by the title height. Replace the current "draw title into top border row" approach with "title has its own dedicated rank space."

6. **No changes needed for**: `normalize.rs`, `denormalize()`, `router.rs`, `bk.rs`, `nesting::cleanup()`, `nesting::assign_rank_minmax()`.

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | `nesting.rs` (title creation), `graph.rs` (new field), `order.rs` (single-child fix), `render/layout.rs` (bounds fix) |
| **What** | Title dummy node reserves a rank between border_top and content, preventing title-arrow collisions by construction |
| **How** | High-weight nesting edge chain `root → title → border_top → children → border_bottom`; title node gets explicit dimensions; ordering handles single-child rank; render adjusts top y-bound |
| **Why** | Structural fix eliminates collision class entirely vs. per-case workarounds. Follows existing border node patterns, minimizing new abstractions |

## Open Questions

- Should `assign_rank_minmax()` set min_rank to the title rank (expanding the compound span) or keep it at border_top rank?
- How does the title node's dagre float height map to character-grid rows? Need to verify the scaling factor.
- If a compound has no title, should the title node be omitted entirely or created with zero dimensions?
- Does the extra rank affect `layer_starts` initialization for the title rank when no real nodes occupy it?
- Should this approach be validated with a prototype before full implementation?

## Next Steps

- [ ] Create implementation plan based on this research (reference `research/0023-subgraph-title-arrow-collision/layout-level-structural-fix/`)
- [ ] Prototype the title node insertion in `nesting::run()` on the `mmdflux-subgraphs` worktree
- [ ] Verify with `subgraph_edges.mmd` and other subgraph test fixtures
- [ ] Determine dagre float ↔ character grid scaling for title height
- [ ] Test edge cases: subgraphs without titles, nested subgraphs with titles, cross-subgraph edges through title ranks

## Source Files

| File | Question |
|------|----------|
| `q1-nesting-insertion.md` | Q1: Title node in nesting::run() |
| `q2-border-ordering-impact.md` | Q2: Border segments and ordering |
| `q3-coordinate-assignment.md` | Q3: BK/position coordinate effects |
| `q4-bounds-extraction.md` | Q4: Subgraph bounds extraction |
| `q5-cross-subgraph-edges.md` | Q5: Cross-subgraph edge impact |
