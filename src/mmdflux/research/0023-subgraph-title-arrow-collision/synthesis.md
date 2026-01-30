# Research Synthesis: Subgraph Title vs Edge Arrow Collision

## Summary

Subgraph titles embedded in the top border row (`┌── Title ──┐`) can block edge segments and arrows from rendering when they cross the border at a title character's position. The canvas protection system (`is_subgraph_title`) silently rejects writes. The collision primarily affects TD layouts where edges enter subgraphs from above, though it can occur in any direction where edges cross a titled border. Mermaid avoids this via SVG z-ordering and post-layout coordinate shifting — neither of which translates to ASCII. Two complementary fixes are recommended: a render-layer quick fix (render titles last, dodge occupied cells) and a layout-level structural fix (reserve a title rank in dagre's nesting system).

## Key Findings

### 1. The collision is real but geometry-dependent

Edges crossing subgraph borders create junctions on the border row. When a junction position coincides with a title character, the title protection blocks the junction from rendering. The current `subgraph_edges.mmd` fixture doesn't trigger this because the arrows happen to land in the `─` regions flanking the centered title — but this is luck, not design. A wider title or differently-positioned edge would collide.

The collision primarily affects:
- **TD layout**: edges entering from above cross the top border (where the title lives)
- **Cross-subgraph edges**: these must pass through the border to reach interior nodes
- Wider/longer titles increase collision probability since they occupy more of the border row

### 2. Mermaid's solution doesn't translate to ASCII

Mermaid solves this with SVG-specific properties: titles are separate text elements with z-ordering (paint order), edges are clipped at expanded cluster boundaries, and `subGraphTitleTotalMargin` shifts node coordinates post-layout. In ASCII, a cell can only hold one character — there's no layering. We need a fundamentally different approach.

### 3. Two complementary fixes cover both short-term and long-term

**Quick fix (render layer):** Render titles AFTER edges, placing title chars only where cells are unoccupied. This is ~35-50 lines across `subgraph.rs` and `mod.rs`, requires no new parameters, and degrades gracefully (partial title if many edges cross the border).

**Structural fix (layout layer):** Add a "title rank" in dagre's nesting system, pushing member nodes down by one rank to create guaranteed space between the border and content. This is ~50 lines across `nesting.rs`, `position.rs`, and `layout.rs`, and prevents collisions by construction.

### 4. The render-layer fix is sufficient for now

Given that actual collisions are geometry-dependent and the centering change already reduces collision probability (title occupies the middle, edges tend toward the sides), the render-layer fix provides adequate protection. The structural fix is the "correct forever" solution but involves dagre changes that warrant their own implementation plan.

## Recommendations

1. **Implement Option C (render titles last, dodge occupied cells)** — Split `render_subgraph_borders()` into border-lines and title-placement phases. Render titles after edges, only writing chars to unoccupied cells. This is minimally invasive and handles all directions.

2. **File an issue for the structural fix (title rank in dagre)** — Option A from Q3 is the correct long-term solution. It requires more careful design (nesting.rs changes, interaction with cross-subgraph edges) and should be a separate plan.

3. **Add a collision-triggering test fixture** — Create a `.mmd` file where the title and edge crossing are guaranteed to overlap, to validate the fix and prevent regression.

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | Collision in `canvas.rs` protection logic; title in `subgraph.rs`; edges in `edge.rs`/`router.rs`; layout in `layout.rs`/`nesting.rs` |
| **What** | Title chars marked `is_subgraph_title` block edge segment/arrow writes via `set()` and `set_with_connection()` |
| **How** | Rendering order: borders+titles first, edges last. Edges try to write through protected title cells and silently fail |
| **Why** | ASCII grid has no z-ordering — one char per cell. Title and edge can't coexist. Mermaid uses SVG layering; we need structural separation or render-order reversal |

## Open Questions

- Should the title render with a minimum number of characters even if edges occupy some positions? (e.g., always show at least the first 3 chars)
- Does the title rank approach interact well with cross-subgraph edges that span multiple ranks?
- Should titles on other borders (left for LR, bottom for BT) be supported in the future? If so, the fix should be direction-aware from the start.

## Next Steps

- [ ] **Investigate layout-level structural fix** — deep dive into dagre title-rank approach (Option A from Q3). See `layout-level-structural-fix/` subdirectory research.
- [ ] Implement render-layer quick fix (Option C) as interim: split title rendering, render after edges
- [ ] Add collision-triggering test fixture
- [ ] Consider whether future title placement (inside box vs on border) changes the calculus

## Source Files

| File | Question |
|------|----------|
| `q1-collision-scenarios.md` | Q1: Concrete collision scenarios |
| `q2-render-layer-fixes.md` | Q2: Quick-fix options at render layer |
| `q3-layout-level-fixes.md` | Q3: Layout-level structural fixes |
| `q4-mermaid-approach.md` | Q4: How Mermaid solves this |
