# Q4: How Does dagre-js Handle Compound Node Titles?

## Summary

Dagre-js has **no concept of compound node titles or labels** at the layout level. Its compound graph support uses structural border nodes (top, bottom, left, right) with zero dimensions to define cluster boundaries, but title/label rendering is handled entirely by the rendering layer (dagre-d3 or mermaid.js). Mermaid.js handles subgraph titles as a **render-level concern** — it draws the title inside the cluster SVG after layout, using `subGraphTitleTopMargin` for spacing — but this approach has persistent edge-title collision bugs that remain partially unresolved.

## Where

- [dagre nesting-graph.js](https://github.com/dagrejs/dagre/blob/master/lib/nesting-graph.js) — creates border top/bottom nodes
- [dagre add-border-segments.js](https://github.com/dagrejs/dagre/blob/master/lib/add-border-segments.js) — creates left/right border chains
- [dagre layout.js](https://github.com/dagrejs/dagre/blob/master/lib/layout.js) — final compound node dimension calculation
- [dagre order/sort-subgraph.js](https://github.com/dagrejs/dagre/blob/master/lib/order/sort-subgraph.js) — border node handling in ordering
- [dagre position/index.js](https://github.com/dagrejs/dagre/blob/master/lib/position/index.js) — converts to non-compound graph before positioning
- [dagre-d3 create-clusters.js](https://github.com/dagrejs/dagre-d3/blob/master/lib/create-clusters.js) — cluster label rendering with `clusterLabelPos`
- [dagre-d3 position-clusters.js](https://github.com/dagrejs/dagre-d3/blob/master/lib/position-clusters.js) — cluster positioning from dagre output
- [mermaid dagre-wrapper/clusters.js](https://github.com/mermaid-js/mermaid/blob/develop/packages/mermaid/src/dagre-wrapper/clusters.js) — `roundedWithTitle` shape and `subGraphTitleTopMargin`
- [mermaid issue #4935](https://github.com/mermaid-js/mermaid/issues/4935) — `titleTopMargin` doesn't affect subgraphs
- [mermaid issue #7264](https://github.com/mermaid-js/mermaid/issues/7264) — overlapping even with `subGraphTitleMargin`
- [mermaid PR #7268](https://github.com/mermaid-js/mermaid/pull/7268) — fix for edge-title collision via adjusted cluster boundaries
- [dagre PR #242](https://github.com/dagrejs/dagre/pull/242) — unmerged PR for separate cluster padding top/bottom

## What

### Dagre-js: Purely Structural Border Nodes, No Title Concept

Dagre-js implements compound graph support through four types of border nodes:

1. **`borderTop` / `borderBottom`** — Created in `nesting-graph.js`. These are dummy nodes set as children of the compound node, connected to all child top/bottom borders with weighted edges. They establish the rank range (`minRank` to `maxRank`) of the compound node.

2. **`borderLeft` / `borderRight`** — Created in `add-border-segments.js`. For each rank in the compound node's range, a left and right border node is created. These form vertical chains (each connected to the previous rank's border node). All border nodes have `width: 0, height: 0`.

3. **Border node handling in ordering** — `sort-subgraph.js` filters out `borderLeft` and `borderRight` from the movable set during barycenter ordering, then reattaches them at the extremes: `result.vs = [bl, result.vs, br].flat(true)`.

4. **Final dimension calculation** — `removeBorderNodes()` in `layout.js` computes compound node dimensions from border positions: `width = abs(right.x - left.x)`, `height = abs(bottom.y - top.y)`, centered at the midpoint. Then all border nodes are removed.

**Key finding:** There is no label, title, padding, or text property anywhere in dagre's compound node handling. The border nodes are purely structural. The `borderTop` node occupies the same rank as the topmost child — there is no extra rank or space reserved for a title.

### Dagre-d3: Render-Level Label Placement

Dagre-d3 adds cluster label rendering on top of dagre's layout:

- `createClusters()` identifies subgraph nodes and creates SVG groups with a label group
- Labels are created via `addLabel(labelGroup, node, node.clusterLabelPos)` where `clusterLabelPos` can be `'top'` or `'bottom'`
- `positionClusters()` translates cluster groups to dagre-computed coordinates and sizes rectangles to dagre-computed dimensions
- **No adjustment is made to dagre's layout to account for label space** — the label is drawn inside the already-computed cluster boundary

### Mermaid.js: Render-Level Title with Known Collision Problems

Mermaid.js builds on dagre with its own cluster rendering in `dagre-wrapper/clusters.js`:

- Uses a `roundedWithTitle` shape function for subgraph clusters
- Measures the title label's bounding box, then positions it:
  ```js
  label.attr('transform', `translate(${node.x - bbox.width / 2},
    ${node.y - node.height / 2 + subGraphTitleTopMargin})`)
  ```
- The title is placed at the **top of the cluster**, offset by `subGraphTitleTopMargin`
- The cluster width is expanded if the title is wider than the content: `width = node.width <= bbox.width + padding ? bbox.width + padding : node.width`

**This approach has persistent bugs:**
- [Issue #4935](https://github.com/mermaid-js/mermaid/issues/4935): `titleTopMargin` doesn't affect subgraphs, titles render too close to the top border
- [Issue #3806](https://github.com/mermaid-js/mermaid/issues/3806): Multiline titles are overlapped by nodes
- [Issue #3779](https://github.com/mermaid-js/mermaid/issues/3779): No way to add spacing between top node and subgraph name
- [Issue #7264](https://github.com/mermaid-js/mermaid/issues/7264): Overlapping even with `subGraphTitleMargin` — edges still collide with titles

### Mermaid.js Edge-Title Fix (PR #7268)

A recent fix (Dec 2025) addresses edge-title collisions by modifying edge intersection calculations:
- Added `getAdjustedClusterBoundary()` helper that computes a modified cluster boundary excluding the title area (label height + margins)
- Edge-to-cluster intersection calculations now use this adjusted boundary so edges terminate below the title
- This is a **post-hoc render fix** — it doesn't change the layout, only where edges visually connect to cluster borders

### Unmerged Dagre PR for Cluster Padding

[PR #242](https://github.com/dagrejs/dagre/pull/242) (2018, closed without merge) proposed adding `clusterpaddingtop` and `clusterpaddingbottom` to dagre's layout. This would have been a layout-level solution — modifying the separation function to account for asymmetric padding. It was never merged, possibly due to code quality issues (included IDE config files).

## How

### Dagre-js Approach
1. Create structural border nodes with zero dimensions
2. Use border nodes to constrain rank range and ordering
3. Compute final compound node dimensions from border positions
4. Remove border nodes — no title space is reserved

### Mermaid.js Approach
1. Run dagre layout (no title awareness)
2. Draw cluster rectangles at dagre-computed positions/dimensions
3. Overlay title text at top of cluster with configurable margin
4. Post-hoc fix: adjust edge intersection points to avoid title area

### The Collision Problem
Because dagre's layout places the compound node's top border at the same rank as the topmost child node, edges entering the subgraph from above terminate at the cluster boundary — which is exactly where the title is rendered. Mermaid's recent fix adjusts the edge endpoint downward, but this is fragile:
- It doesn't prevent nodes from being placed under the title
- It only fixes edges, not other potential overlaps
- The `subGraphTitleMargin` config still has reported issues

## Why

### Design Rationale
Dagre-js was designed as a **layout-only** library. Labels and visual elements are the renderer's responsibility. This separation of concerns means:
- Dagre doesn't need to know about text rendering, fonts, or label dimensions
- Different renderers (dagre-d3, mermaid, cytoscape) can handle labels differently
- But it also means there's no way for the layout to reserve space for titles

### Tradeoffs in Mermaid's Render-Level Approach
**Advantages:**
- Simple to implement — just offset the title text
- Doesn't require modifying dagre's internals
- Works for most simple cases

**Disadvantages:**
- Persistent collision bugs (5+ open issues over 4+ years)
- Title space isn't accounted for during layout, so nodes and edges don't know about it
- Fixes are reactive (adjust edge endpoints) rather than proactive (reserve space)
- Each new collision type requires a new render-level fix

### Why a Layout-Level Approach Would Be Better
The unmerged dagre PR #242 and mermaid's ongoing issues suggest that a **layout-level solution** — where title space is structurally reserved — would be more robust. By inserting a title node or reserving a rank for the title, the layout algorithm naturally routes edges and positions nodes to avoid the title area, eliminating an entire class of render-level bugs.

## Key Takeaways

- **Dagre-js has zero concept of compound node titles** — border nodes are purely structural with zero dimensions. No title, label, or padding space is reserved during layout.
- **Mermaid.js handles subgraph titles entirely at render time** — it draws the title inside dagre-computed boundaries with a margin offset. This causes persistent edge-title collision bugs.
- **Mermaid's fix for edge-title collision is post-hoc** — PR #7268 adjusts edge intersection calculations to avoid the title area, but this is fragile and doesn't prevent all collision types.
- **A layout-level solution (reserving title space structurally) is superior** — our approach of inserting title dummy nodes at a dedicated rank is architecturally better than mermaid's render-level approach, because the layout algorithm inherently avoids the title area.
- **The `borderTop` node in dagre occupies the same rank as the topmost child** — there is no gap between the compound node boundary and its content. This is the root cause of mermaid's title collision issues.
- **dagre-d3's `clusterLabelPos` is render-only** — it controls where the label SVG element is placed within the already-computed cluster rectangle, not where space is reserved during layout.

## Open Questions

- Does mermaid's ELK renderer handle subgraph titles better than its dagre renderer? (Users report it works better with ELK.)
- Would dagre's unmerged `clusterpaddingtop` approach (asymmetric padding in the separation function) be simpler than our title-node approach for cases where we just need a fixed amount of space?
- How does the `borderTop` rank interact with incoming edges in dagre? Since `borderTop` is at the same rank as the topmost child, do edges from above terminate at the border or at the child node?
