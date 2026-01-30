# Research Synthesis: Nested Subgraph Support

## Summary

Supporting nested subgraphs in mmdflux requires changes across three pipeline stages but no algorithmic changes to the core dagre layout. The parser already handles nested syntax correctly. The graph builder needs a `parent` field on `Subgraph` and recursive `collect_node_ids`. The dagre layout infrastructure already supports multi-level compound nesting once parent relationships are wired up via `set_parent`. The rendering layer needs inside-out (bottom-up) bounds computation and nested-aware overlap resolution. Mermaid.js uses a complex recursive extraction approach for dagre, but mmdflux's existing compound graph infrastructure should handle nesting without that complexity.

## Key Findings

### Finding 1: The parser works, the builder loses nesting info

The PEG grammar already parses nested subgraphs recursively. The `Subgraph` struct lacks a `parent` field, and `collect_node_ids` returns empty for `Statement::Subgraph` variants (builder.rs line 89). This means outer subgraphs don't know about inner subgraphs and may get empty node lists, causing them to be skipped entirely in bounds computation.

**Fix:** Add `parent: Option<String>` to `Subgraph`, propagate parent context in `process_statements`, and make `collect_node_ids` recurse into nested subgraphs.

### Finding 2: Dagre compound graph infrastructure already supports multi-level nesting

The nesting algorithm (`nesting.rs`) discovers children via the `parents` vec, creates border/title nodes for each compound, and adds nesting edges that constrain ranking. This works for arbitrary nesting depth because it operates on indices and processes all compounds. Rank assignment, ordering, and positioning all work on edges and don't need to know about nesting depth. The `from_digraph` conversion correctly propagates parent relationships if they exist in the input `DiGraph`.

**No algorithmic changes needed in dagre.** The only change is in `render/layout.rs`: call `set_parent(child_sg, parent_sg)` for nested subgraph relationships.

### Finding 3: Bounds computation is the main rendering challenge

`convert_subgraph_bounds()` computes bounds from direct member nodes only and skips subgraphs with empty node lists. For nested subgraphs, bounds must be computed bottom-up: inner subgraph bounds first, then outer subgraphs expand to include child subgraph bounds plus padding. Overlap resolution must distinguish nested pairs (containment — don't trim) from sibling pairs (adjacency — trim). Border rendering needs z-order sorting by nesting depth (outer first, inner last).

### Finding 4: Mermaid uses recursive extraction, but mmdflux may not need it

Mermaid's dagre backend uses a complex `extractor` pattern (~300 lines) that splits clusters without external connections into separate sub-graphs, each laid out independently via `recursiveRender()`. This works around dagre-d3's limited compound graph support. mmdflux's dagre already has `set_parent`, nesting edges, and border node infrastructure that should handle multi-level nesting natively. The recursive extraction approach is the fallback if the native compound approach has issues.

Key Mermaid patterns worth adopting:
- `makeUniq()`: Each node belongs to exactly one subgraph (innermost wins) — mmdflux already does this via `parent_subgraph` in `process_statements`
- Edge rewiring: Edges targeting subgraph nodes get redirected to leaf nodes — may be needed if edges target subgraph IDs
- Depth guard: Limit recursion to prevent runaway nesting

## Recommendations

1. **Start with builder changes (Q1 scope)** — Add `parent: Option<String>` to `Subgraph`, make `collect_node_ids` recursive. This is the prerequisite for everything else and the smallest change.

2. **Wire up `set_parent` for nested subgraphs in layout.rs** — In the `from_digraph` conversion, iterate subgraphs and call `set_parent(child_sg_id, parent_sg_id)` when a subgraph has a parent. This should make dagre's nesting algorithm handle the compound hierarchy automatically.

3. **Implement inside-out bounds computation** — Redesign `convert_subgraph_bounds()` to compute bottom-up using a recursive traversal or topological sort on the subgraph parent hierarchy. Include child subgraph bounds in parent bounds calculation.

4. **Add nested-aware overlap resolution** — Modify `resolve_subgraph_overlap()` to skip nested pairs (parent-child) and only trim sibling pairs.

5. **Add z-order rendering** — Sort subgraph borders by nesting depth before rendering (shallowest first, deepest last).

6. **Defer per-subgraph direction support** — Mermaid supports `direction LR` inside a subgraph. This is an advanced feature that can be added later.

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | `src/graph/builder.rs`, `src/graph/diagram.rs` (builder changes); `src/render/layout.rs` (set_parent + bounds); `src/render/subgraph.rs` (z-order rendering) |
| **What** | Parser works. Builder loses nesting info. Dagre handles nesting if parents are set. Bounds computation is node-only. Overlap resolution doesn't distinguish nested vs sibling. |
| **How** | Add `parent` field, recurse `collect_node_ids`, call `set_parent` in layout, compute bounds bottom-up, skip nested pairs in overlap resolution, sort borders by depth. |
| **Why** | Minimal changes leverage existing dagre compound graph infrastructure. Avoids Mermaid's complex recursive extraction. Inside-out bounds is the natural model for hierarchical containment. |

## Open Questions

- **Nesting root edge handling**: The nesting root connects to all compound border_tops (nesting.rs line 73-78). For deeply nested structures, inner compound border_tops also connect to root. Need to verify this doesn't create incorrect rank constraints.
- **Cross-boundary edge routing**: How should edges crossing multiple nesting levels be routed in ASCII? Mermaid rewires them to leaf nodes; mmdflux's router may need similar logic.
- **Empty nested subgraphs**: What should happen when a nested subgraph has no nodes and no children? Mermaid treats them as non-group nodes.
- **Nested border spacing**: What's the minimum gap between nested borders? Current `border_padding = 2` applies uniformly; nested subgraphs may need tighter or different spacing.
- **Per-subgraph direction**: Mermaid supports `direction LR` inside a TD subgraph. This requires independent layout per cluster, which is the Mermaid recursive extraction approach. Defer for now.

## Next Steps

- [ ] Create implementation plan based on these findings
- [ ] Phase 1: Builder changes (add parent field, recursive collect_node_ids)
- [ ] Phase 2: Layout wiring (set_parent for nested subgraphs)
- [ ] Phase 3: Bounds computation redesign (inside-out, nested-aware overlap)
- [ ] Phase 4: Rendering (z-order border sorting)
- [ ] Phase 5: Integration tests with nested subgraph fixtures

## Source Files

| File | Question |
|------|----------|
| `q1-builder-parent-tracking.md` | Q1: Builder parent tracking |
| `q2-dagre-compound-nesting.md` | Q2: Dagre compound nesting |
| `q3-rendering-nested-bounds.md` | Q3: Rendering nested bounds |
| `q4-mermaid-reference-implementation.md` | Q4: Mermaid reference impl |
