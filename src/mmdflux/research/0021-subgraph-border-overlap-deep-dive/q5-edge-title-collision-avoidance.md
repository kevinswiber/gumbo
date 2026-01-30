# Q5: How should edges interact with subgraph title regions?

## Summary

dagre.js does not explicitly prevent edges from passing through subgraph titles. Instead, Mermaid handles this by positioning cluster labels **above** the cluster boundary (not embedded in it) and using edge-to-cluster boundary clipping (`cutPathAtIntersect()`) to ensure edges are clipped at the cluster perimeter. In mmdflux's embedded-title approach (where titles are rendered in the top border row `┌─ Title ─┐`), edges crossing that row would naturally pass through title characters, requiring either repositioning titles or implementing edge avoidance logic.

## Where

**dagre.js:**
- `/Users/kevin/src/dagre/lib/nesting-graph.js` (lines 8-26) — Nesting graph creates dummy border nodes for subgraph tops/bottoms
- `/Users/kevin/src/dagre/lib/add-border-segments.js` (lines 14-22) — Creates left/right border segment nodes with zero width/height
- `/Users/kevin/src/dagre/lib/layout.js` (lines 44, 50) — `addBorderSegments()` and `removeBorderNodes()` phases

**Mermaid:**
- `/Users/kevin/src/mermaid/packages/mermaid/src/utils/subGraphTitleMargins.ts` (lines 3-21) — Configurable margins for subgraph titles
- `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/clusters.js` (lines 95-99) — Positions cluster labels above the cluster box
- `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/edges.js` (lines 303-366, 368-402, 546-562) — `cutPathAtIntersect()` clips edge paths at cluster boundaries

**mmdflux:**
- `/Users/kevin/src/mmdflux-subgraphs/src/render/subgraph.rs` (lines 25-46) — Renders titles embedded in the top border row
- `/Users/kevin/src/mmdflux-subgraphs/src/render/canvas.rs` (lines 151-175) — `set_with_connection()` allows edges to overwrite subgraph borders
- `/Users/kevin/src/mmdflux-subgraphs/src/render/router.rs` (lines 168-246) — Edge routing has no subgraph awareness

## What

### dagre.js Approach

dagre.js doesn't have edge-title collision avoidance. It uses:

1. **Border node creation** (nesting-graph.js): Dummy border nodes at top/bottom of each compound, ensuring separate ranks.
2. **Rank separation via edge constraints** (add-border-segments.js): Left/right border segments on every internal rank.
3. **Compound structure preserved through layout**: Nesting constraints space internal ranks from border ranks.

The key insight: **dagre doesn't worry about titles at all**. It only guarantees subgraph borders are properly spaced. What sits on or near the border is up to the renderer.

### Mermaid's Approach

Mermaid layers three strategies:

1. **Title position**: Places cluster labels **above** the cluster bounding box. The label's y-coordinate is `node.y - node.height / 2 + subGraphTitleTopMargin`, positioning it outside the cluster rect. Titles don't occupy cells within the cluster boundary.

2. **Edge-to-boundary clipping**: `cutPathAtIntersect()` clips edge paths at cluster boundaries:
   - Walks the edge path
   - Computes geometric intersection where edge enters/exits cluster
   - Removes waypoints inside the cluster
   - Ensures no edge path passes through cluster interior

   From edges.js (lines 546-562):
   ```javascript
   if (edge.toCluster) {
     points = cutPathAtIntersect(edge.points, clusterDb.get(edge.toCluster).node);
   }
   if (edge.fromCluster) {
     points = cutPathAtIntersect(points.reverse(), clusterDb.get(edge.fromCluster).node).reverse();
   }
   ```

3. **SVG z-ordering**: Clusters (including labels) render on top of edges, so even if coordinates overlap, labels visually sit above edges.

### mmdflux's Current Behavior

1. **Embedded titles**: Titles rendered **within** the top border row: `┌─ Title ─┐`. Saves vertical space but creates collision risk.

2. **Subgraph borders not protected**: `is_subgraph_border` flag does NOT prevent overwrite. Only `is_node` prevents overwrite (canvas.rs line 159).

3. **Edge-to-border merging**: When edge crosses border, `set_with_connection()` merges directions to create junction characters.

4. **No title avoidance**: Router has no awareness of subgraph titles or positions.

## How

### Mermaid's Edge Clipping Algorithm

```javascript
cutPathAtIntersect(_points, boundaryNode):
  for each point in edge path:
    if point is inside cluster AND was outside last point:
      intersection = geometricIntersect(boundary, lastPoint, point)
      points.push(intersection)  // Cut at boundary
      mark as inside
    else if point is outside cluster:
      points.push(point)
      mark as outside
  return filtered points
```

### mmdflux's Edge-to-Border Merging

When an edge renders across a subgraph border (canvas.rs lines 164-167):
```rust
if cell.is_subgraph_border {
    let border_conns = charset.infer_connections(cell.ch);
    cell.connections.merge(border_conns);
}
```

Border character infers connection directions, edge directions merge in, junction character chosen from all four directions.

**Problem**: If title text occupies those cells, the edge passes through letter characters instead of border characters, creating collisions like `│` through "Output".

## Why

### Why dagre doesn't handle titles

dagre is a pure graph layout algorithm. It doesn't know about text or rendering. **Titles are a rendering concern**, not a layout concern.

### Why Mermaid separates title from border

SVG has infinite canvas with free z-ordering. Mermaid can:
- Position titles above clusters (outside bounding box)
- Render edges beneath titles (z-order)
- Use defensive clipping as failsafe

Titles and edges physically don't overlap — different vertical regions.

### Why mmdflux's embedded approach has constraints

Text rendering has no z-order. A cell contains one character. mmdflux chose embedded titles to save space, but this creates a collision zone.

Possible strategies:
1. **Accept collisions**: Let edges pass through title text, use junction characters
2. **Reserve space above border**: Add title-only row above border (like Mermaid)
3. **Reroute edges**: Extend router to detect title presence and route around it
4. **Use corner/edge entry points**: Ensure edges enter/exit subgraph at corners, not through top border

## Key Takeaways

- **dagre.js**: Provides spacing between subgraph borders via nesting constraints. Does not handle titles.
- **Mermaid**: Positions titles above cluster boundaries (external), clips edges at expanded boundaries, layers edges below titles via SVG z-order.
- **mmdflux current**: Embeds titles in border row. Router has no subgraph awareness. Edges can overwrite title characters.
- **Text rendering limitation**: Unlike SVG, text has no z-order. A cell can't be "edge below title."
- **Embedding makes collision inevitable**: If an edge must cross a subgraph's top border and the title is embedded there, collision is unavoidable unless routed around.

## Open Questions

- Would moving the title to a separate row above the border conflict with compact rendering goals?
- Could the router detect subgraph parent relationships and avoid the top border row for entry points?
- What's the expected behavior when an edge must cross a border with an embedded title?
- Does dagre's rankSep guarantee sufficient space for a title row above the border?
- Would implementing Mermaid-style `cutPathAtIntersect` logic work for text rendering?
