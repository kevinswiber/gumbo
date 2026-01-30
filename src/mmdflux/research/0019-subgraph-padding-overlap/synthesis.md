# Research Synthesis: Subgraph Padding, Borders, and Title Rendering

## Summary

mmdflux's subgraph implementation has a fundamental architectural disconnect: dagre computes compound node bounds via border nodes during layout, but the rendering layer discards those bounds and recomputes them from member-node draw positions with hardcoded padding. This produces at least 10 distinct visual defects including border collisions between adjacent subgraphs, title text overwriting other content, edges punching through borders, and backward edges escaping subgraph boundaries. Both dagre.js and Mermaid solve these problems through different mechanisms — dagre.js derives compound dimensions from positioned border nodes, while Mermaid applies post-layout adjustments for title margins and uses anchor-node replacement for cross-boundary edges.

## Key Findings

### 1. Dagre bounds are computed but discarded

The dagre layout engine positions border nodes and `remove_nodes()` computes a bounding `Rect` for each compound. This is passed to `convert_subgraph_bounds()` as `_dagre_bounds` — but the underscore prefix reveals it's entirely unused. Instead, bounds are recomputed from member-node draw positions with a fixed 2-cell padding and 1-row title height. This throws away dagre's inter-subgraph spacing guarantees, causing borders of adjacent subgraphs to overlap (Q1, Q3 Issues 5/6/10).

### 2. Title rendering has no integration with layout

Titles are placed at `(x, y-1)` using unprotected `canvas.set()` calls. Three problems result: (a) titles wider than the border are silently clipped, (b) titles collide with content above when the layout doesn't reserve title rows, (c) titles disappear entirely when the border starts at `y=0` (Q2, Q3 Issues 1/2/3/8/10). The layout reserves `title_height=1` when computing `border_y`, but this only moves the border down — it doesn't push external content away.

### 3. Edge routing has no subgraph awareness

The edge router treats the canvas as flat — nodes are obstacles, everything else is open space. Edges cross subgraph borders freely, overwriting border characters. `set_with_connection()` protects `is_node` cells but not `is_subgraph_border` cells. Backward edges route to the right of nodes and escape their enclosing subgraph entirely (Q3 Issues 4/7/9).

### 4. dagre.js uses border nodes as layout-time constraints

In dagre.js, border nodes have `width: 0, height: 0` and serve as invisible anchors. After positioning, `removeBorderNodes()` derives compound dimensions from border node coordinates: `width = |right.x - left.x|`, `height = |bottom.y - top.y|`. The compound's center is placed at the midpoint. This means compound dimensions emerge naturally from the layout algorithm rather than being imposed post-hoc (Q4).

### 5. Mermaid applies post-layout title margin adjustments

Mermaid shifts cluster nodes by `subGraphTitleTotalMargin` after dagre layout, and also shifts child nodes and edge waypoints by half that amount. Title labels are positioned outside the box using configurable margins. Edges targeting clusters are redirected to anchor nodes (first non-cluster child) to avoid cluster-to-cluster routing. The SVG viewBox is computed last as a safety net (Q5).

## Recommendations

1. **Use dagre's compound bounds instead of recomputing** — Transform the `_dagre_bounds` Rect through `TransformContext` to get draw-coordinate bounds. This preserves dagre's inter-subgraph spacing and eliminates border-border collisions. The hardcoded 2-cell padding would become unnecessary if dagre's border nodes already create adequate spacing.

2. **Factor title width into border sizing** — When computing subgraph bounds (whether from dagre or member nodes), ensure `border_width >= title.len() + 2` (for at least 1 cell margin on each side). This prevents title clipping.

3. **Reserve title rows in the layout** — Either give dagre's top border nodes nonzero height to account for the title row, or apply a post-layout shift (like Mermaid's `subGraphTitleTotalMargin`) that moves the subgraph and its children down to create title space. This prevents title-content collisions.

4. **Add subgraph-aware edge routing** — At minimum, create visual gaps in borders where edges cross (replace border character with edge character intentionally). A more thorough approach would constrain edge routing to exit/enter subgraphs at designated points (top/bottom for TD/BT, left/right for LR/RL).

5. **Contain backward edges within subgraph bounds** — Extend the subgraph border rightward to encompass backward edge routing space, or constrain backward edge routing to stay within the current border width.

6. **Consider embedding titles in the top border line** — Rendering titles as `┌─ Title ─┐` instead of above the box would eliminate the y=0 clipping problem and reduce vertical space usage. This is a design choice that trades the current Mermaid-like floating title for an integrated border title.

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | Bounds: `render/layout.rs:692-749`. Titles: `render/subgraph.rs:14-52`. Border nodes: `dagre/border.rs`. dagre.js: `lib/layout.js:309-330`. Mermaid: `rendering-util/rendering-elements/clusters.js` |
| **What** | 10 overlap/clipping issues. Dagre bounds discarded. Fixed 2-cell padding. Unprotected title rendering. No subgraph-aware edge routing. |
| **How** | mmdflux: member-node bbox + hardcoded padding. dagre.js: border node positions → derived dimensions. Mermaid: post-layout margin shifts + anchor node replacement + SVG bbox safety net. |
| **Why** | mmdflux took a pragmatic shortcut (recompute from draw coords) that avoids coordinate-space translation but loses dagre's spacing guarantees. dagre.js border nodes are invisible constraints. Mermaid separates layout from rendering with configurable post-processing. |

## Open Questions

- Should mmdflux adopt dagre.js's approach (use border node positions) or Mermaid's approach (post-layout shifts), or a hybrid?
- How should edge-border crossings be visualized in text mode — gaps in borders, or special crossing characters?
- Should backward edges inside subgraphs be constrained to stay within bounds, or should bounds expand to contain them?
- Should titles be embedded in the top border line (`┌─ Title ─┐`) to avoid the y=0 problem and save vertical space?
- How does this interact with future nested subgraph support (subgraphs within subgraphs)?

## Next Steps

- [ ] Create implementation plan to leverage dagre's `_dagre_bounds` via `TransformContext` scaling
- [ ] Prototype title-width-aware border sizing
- [ ] Design edge-border crossing strategy (gaps vs routing constraints)
- [ ] Evaluate embedded-title-in-border approach vs floating title

## Source Files

| File | Question |
|------|----------|
| `q1-bounds-calculation.md` | Q1: mmdflux subgraph bounds calculation |
| `q2-title-rendering.md` | Q2: mmdflux subgraph title rendering |
| `q3-overlap-inventory.md` | Q3: Overlap and clipping inventory |
| `q4-dagre-compound-sizing.md` | Q4: dagre.js compound node sizing and padding |
| `q5-mermaid-subgraph-rendering.md` | Q5: Mermaid subgraph box and label post-processing |
