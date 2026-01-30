# Q4: How Mermaid Solves This

## Summary

Mermaid solves the title-edge collision through a multi-layered approach: (1) positioning titles **above** the cluster boundary (not embedded within it), (2) post-layout Y-coordinate shifting that reserves vertical space for titles (`subGraphTitleTotalMargin`), (3) expanding cluster border height to include title space in collision geometry, and (4) leveraging SVG z-ordering and edge-to-cluster boundary clipping. The solution separates layout (dagre) from rendering (SVG), treating title spacing as a post-processing problem.

## Where

- `~/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/clusters.js` (lines 13-122)
- `~/src/mermaid/packages/mermaid/src/utils/subGraphTitleMargins.ts` (lines 1-21)
- `~/src/mermaid/packages/mermaid/src/rendering-util/layout-algorithms/dagre/index.js` (lines 170-258)
- Prior research: `research/0019-subgraph-padding-overlap/`, `research/0021-subgraph-border-overlap-deep-dive/`

## What

### Title Positioning
Mermaid places titles **outside and above** the cluster box, not embedded in the border:
```javascript
labelEl.attr('transform',
  `translate(${node.x - bbox.width / 2}, ${node.y - node.height / 2 + subGraphTitleTopMargin})`
);
```
Comment in source: *"This puts the label on top of the box instead of inside it"*

### Configurable Margins
```typescript
const subGraphTitleTopMargin = flowchart?.subGraphTitleMargin?.top ?? 0;
const subGraphTitleBottomMargin = flowchart?.subGraphTitleMargin?.bottom ?? 0;
const subGraphTitleTotalMargin = subGraphTitleTopMargin + subGraphTitleBottomMargin;
```
Defaults to 0 — relies on SVG layering as the primary collision avoidance.

### Post-Layout Coordinate Adjustment
After dagre computes layout, Mermaid shifts coordinates to reserve title space:
- Recursive clusters: `node.y += subGraphTitleTotalMargin` (full shift)
- Non-recursive clusters: `node.height += subGraphTitleTotalMargin` (height expansion)
- Regular nodes: `node.y += subGraphTitleTotalMargin / 2` (half shift)
- Edge waypoints: `point.y += subGraphTitleTotalMargin / 2` (half shift)

### Edge Clipping at Expanded Boundaries
Edges entering/exiting clusters are clipped at the expanded boundary:
```javascript
if (edge.toCluster) {
  points = cutPathAtIntersect(edge.points, clusterDb.get(edge.toCluster).node);
}
```
The expanded height ensures the clipping boundary encompasses title space.

### SVG Z-Ordering
Paint order: clusters first (bottom), then edges, then nodes (top). Titles render beneath edges in DOM order, but as separate SVG text elements they don't interfere with edge paths.

## How

The pipeline:
1. **Parse** — subgraph nodes marked `clusterNode: true`, titles measured
2. **Dagre layout** — pure algorithm, ignores titles
3. **Post-layout adjustment** — shift Y coordinates and expand heights for title space
4. **Cluster rendering** — SVG rect + positioned title label
5. **Edge rendering** — edges clipped at expanded cluster boundaries
6. **SVG layering** — z-order handles any remaining visual overlap

## Why

### Why This Works for SVG but Not ASCII
- **SVG has infinite canvas** — titles can be positioned arbitrarily without grid constraints
- **SVG has z-ordering** — visual overlap is handled by paint order, not cell exclusion
- **SVG separates text from geometry** — title is a text element, border is a rect; they don't share cells
- **ASCII has one char per cell** — title and border MUST share the same row; no layering possible

### Key Design Principles
1. **Separation of concerns** — dagre doesn't know about titles; post-processing handles spacing
2. **Expansion over avoidance** — rather than routing edges around titles, expand the boundary so edges clip at a safe distance
3. **Configurable margins** — title spacing is a tunable parameter, not hardcoded geometry

## Key Takeaways

1. Mermaid places titles **outside** the box boundary, not embedded in it
2. Space is reserved **post-layout** by shifting Y coordinates and expanding cluster height
3. **Edge clipping** at expanded boundaries prevents edges from entering title space
4. **SVG z-ordering** provides a visual failsafe that ASCII cannot replicate
5. The approach is modular: layout, rendering, and collision avoidance are independent
6. Default margins are 0 — SVG layering handles collisions without explicit spacing
7. No special title-aware routing exists — generic boundary expansion + clipping handles it
8. **For ASCII, we need a structural solution** since we can't rely on z-ordering or separate text elements

## Open Questions

- Could we replicate Mermaid's "expanded boundary + edge clipping" in ASCII by adding a post-routing pass that clips edge segments at subgraph borders?
- Mermaid's default margin is 0 — does this mean they accept visual overlap and rely on SVG layering? If so, we definitely need a different approach.
- How does the half-margin vs full-margin distinction work for nested subgraphs?
