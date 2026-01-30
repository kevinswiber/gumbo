# Research Synthesis: Subgraph Border Overlap Deep Dive

## Summary

The subgraph border overlap problem (Issue 0005) stems from mmdflux discarding dagre's properly-computed subgraph bounds due to a coordinate transformation mismatch, then recomputing borders from member-node positions with fixed padding that has no inter-subgraph awareness. dagre.js guarantees non-overlapping bounds through border nodes, nesting edges, and Brandes-Köpf spacing — these guarantees are already implemented in mmdflux's dagre port but unused. Mermaid also places titles inside borders (not above them, as the Q2 agent incorrectly reported — the screenshot confirms titles render inside the cluster rect). Mermaid reserves title space by expanding cluster height, shifting content down, clipping edges at cluster boundaries, and using SVG z-ordering so titles layer above edges. The fix path for mmdflux is to either (a) apply the correct coordinate transformation to dagre bounds (matching the node position formula rather than `to_ascii()`), or (b) add post-hoc inter-subgraph collision detection to the member-node approach. For edge-title collisions, mmdflux's embedded title approach (`┌─ Title ─┐`) is the right design for text rendering, but title characters need protection from edge overwrite since text has no z-ordering.

## Key Findings

### 1. dagre already guarantees non-overlapping subgraph bounds — mmdflux just can't use them

dagre.js (and mmdflux's port) creates zero-width border nodes at every rank for each compound node, connected by high-weight nesting edges. The Brandes-Köpf algorithm positions these with `edgeSep` (default 20) between sibling subgraphs horizontally and `rankSep` (default 50) vertically. After layout, `removeBorderNodes()` derives bounding boxes from positioned border nodes. These bounds are non-overlapping by construction — but mmdflux passes them as `_dagre_bounds` (unused) in `convert_subgraph_bounds()`.

The reason: `to_ascii()` treats coordinates as raw points, but dagre Rects use center-based coordinates. The node position formula includes a `rect.width/2.0` right-edge offset term that `to_ascii()` lacks, causing ~5-character systematic displacement.

### 2. The member-node approach is correct but incomplete

The current fallback — computing bounds from already-transformed member-node draw positions — is mathematically correct within its own frame. Every node in `draw_positions` has been through the full transformation pipeline (scaling, overhang correction, collision repair). The problem is that this approach has no way to enforce inter-subgraph spacing: each subgraph computes its bounds independently with a fixed 2-cell `border_padding`, so adjacent subgraphs can (and do) overlap when their member nodes are close together.

### 3. Mermaid positions titles inside borders and clips edges at cluster boundaries

As visible in the Mermaid screenshot, titles ("Input", "Output") render **inside** the subgraph border, just below the top edge — the same approach mmdflux uses with its embedded `┌─ Title ─┐`. Mermaid uses `subGraphTitleTotalMargin` to reserve vertical space within the cluster for the title, expanding the cluster height and shifting internal content downward. Edge paths are clipped at cluster boundaries via `cutPathAtIntersect()`, and SVG z-ordering ensures titles render above edges even if their coordinates overlap. The key mechanisms are:
1. Cluster height expanded to include title space (internal, not external)
2. Internal node coordinates shifted downward to make room for the title row
3. Edge paths clipped at cluster boundary via `cutPathAtIntersect()`
4. SVG z-ordering so titles visually sit above any overlapping edge paths

### 4. Text rendering has no z-order — title collision requires character-level protection

Both Mermaid and mmdflux place titles inside subgraph borders. In SVG, Mermaid can layer titles above edges via z-ordering. In text rendering, a character cell holds one character — there's no layering. mmdflux's `┌─ Title ─┐` means edges crossing the top border row will pass through title characters. The current canvas protection logic (`is_subgraph_border`) doesn't prevent edge overwrite — only `is_node` does. Title characters need similar protection.

### 5. The gap from dagre's rankSep is sufficient for text rendering

With `rank_sep=50.0` and typical `scale_y ≈ 0.113`, the vertical gap between ranks translates to ~6 text rows. This provides room for: top border (1 row), bottom border (1 row), and 4 rows of visual separation between stacked subgraphs. This is more than enough for borders, titles, and edge routing.

## Recommendations

1. **Fix the coordinate transformation (preferred approach)** — Apply the same formula as node positions to dagre subgraph Rects: use `rect.x + rect.width/2.0` as the scaling input (not raw `rect.x`), apply overhang correction, then compute the top-left corner. This gives non-overlapping borders for free, leveraging the guarantees dagre already provides. The member-node approach can remain as a fallback for edge cases.

2. **Keep the embedded title approach** — Both Mermaid and mmdflux place titles inside subgraph borders. mmdflux's `┌─ Title ─┐` is a good text-rendering equivalent. If the borders are properly spaced (via dagre bounds), the main collision scenario (overlapping borders) disappears.

3. **Protect title characters from edge overwrite** — Extend `set_with_connection()` to check whether a cell contains title text (not just `is_subgraph_border`). Title characters should be treated like node characters — edges should not overwrite them. Instead, edges should use junction characters at the border line segments to either side of the title.

4. **Route edges to avoid the title region when possible** — For cross-subgraph edges entering a subgraph from above (TD layout), prefer entering at positions outside the title text range. This is a soft constraint: if the edge's horizontal position falls within the title, accept the junction character; if it's outside, it cleanly crosses the border line.

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | dagre: `nesting-graph.js`, `add-border-segments.js`, `layout.js`. Mermaid: `clusters.js`, `edges.js`, `dagre/index.js`. mmdflux: `layout.rs` (convert_subgraph_bounds), `subgraph.rs`, `canvas.rs`, `border.rs` |
| **What** | dagre computes non-overlapping subgraph bounds via border nodes; Mermaid places titles inside borders, reserves space, and clips edges at boundaries; mmdflux discards dagre bounds and uses member-node fallback with no inter-subgraph awareness |
| **How** | dagre: border nodes → nesting edges → BK spacing → removeBorderNodes(). Mermaid: expanded cluster height → internal Y-offset → cutPathAtIntersect() → SVG z-order. mmdflux: member-node bounding box → fixed 2-cell padding → embedded title → unprotected border cells |
| **Why** | dagre's border node architecture is general and reuses standard Sugiyama machinery. Mermaid post-processes because dagre doesn't know about titles. mmdflux discards dagre bounds because `to_ascii()` uses a different formula than the node position transformation |

## Open Questions

- Should `border_padding` be derived from dagre parameters (e.g., `edgeSep` scaled) rather than hardcoded at 2?
- Should the coordinate transformation fix be a new `to_ascii_rect()` method on `TransformContext`, or integrated into `convert_subgraph_bounds()`?
- For nested subgraphs, does the embedded title approach compound the spacing issues (title row of inner subgraph colliding with content of outer)?
- Should backward edge containment be tied to actual waypoint positions rather than a fixed expansion constant?

## Next Steps

- [ ] Create implementation plan to fix the dagre-to-draw coordinate transformation for subgraph Rects
- [ ] Prototype the correct transformation formula with the `subgraph_edges.mmd` fixture
- [ ] Evaluate whether title character protection (treating title chars like node chars) is sufficient or if edge routing avoidance is needed
- [ ] Consider whether the member-node fallback should be kept as a safety net alongside dagre bounds

## Source Files

| File | Question |
|------|----------|
| `q1-dagre-inter-subgraph-spacing.md` | Q1: dagre.js inter-subgraph spacing |
| `q2-mermaid-title-edge-handling.md` | Q2: Mermaid title and edge handling |
| `q3-mmdflux-current-behavior.md` | Q3: mmdflux current behavior |
| `q4-coordinate-transformation-fix.md` | Q4: Coordinate transformation fix |
| `q5-edge-title-collision-avoidance.md` | Q5: Edge-title collision avoidance |
