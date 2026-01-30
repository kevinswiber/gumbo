# Q5: Mermaid subgraph box and label post-processing

## Summary

Mermaid renders subgraph boxes and labels through a two-phase post-processing pipeline: first, it calculates subgraph bounds by calling `updateNodeBounds()` on the recursive render output, accounting for label height and internal padding; second, it positions title labels outside the box boundary using `subGraphTitleMargins` config (default 0), and applies CSS styling for colors/borders from theme variables. The SVG viewBox is then computed from the final bounding box with additional padding to ensure all content is visible.

## Where

Sources consulted:
- `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/clusters.js` — Cluster box rendering
- `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/layout-algorithms/dagre/index.js` (lines 169-246) — Post-dagre adjustments
- `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/shapes/util.ts:133-141` — `updateNodeBounds()`
- `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/layout-algorithms/dagre/mermaid-graphlib.js` — Boundary-crossing edge handling
- `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/setupViewPortForSVG.ts` — SVG viewBox calculation
- `/Users/kevin/src/mermaid/packages/mermaid/src/diagrams/flowchart/styles.ts:126-141` — CSS styling

## What

**Cluster Box Rendering** (clusters.js):
- Creates a `<g class="cluster">` wrapper with an ID
- Inserts a `<rect>` element with width/height computed from node dimensions
- Box width is dynamic: `width = node.width <= bbox.width + padding ? bbox.width + padding : node.width`
- Boxes are centered: `x = node.x - width/2`, `y = node.y - node.height/2`
- Two shapes: basic `rect` and compound `roundedWithTitle` (for styled subgraphs with title bars)

**Label Positioning**:
- Labels are positioned **outside/on top of the box**, not inside
- Translation formula: `translate(${node.x - bbox.width / 2}, ${node.y - node.height / 2 + subGraphTitleTopMargin})`
- Horizontally centered relative to box center
- Vertically placed at top of box with configurable margin offset
- Rendered as separate `<g class="cluster-label">` containing SVG `<text>` or HTML `<div>`

**Post-Dagre Adjustments** (dagre/index.js, lines 169-246):
- After dagre layout, cluster nodes have `node.y += subGraphTitleTotalMargin`
- Child nodes inside clusters: `node.y += subGraphTitleTotalMargin / 2`
- Edge waypoints also adjusted: `point.y += subGraphTitleTotalMargin / 2`
- `subGraphTitleMargins` is configurable from `flowchart.subGraphTitleMargin.top/bottom` config

**Bounds Calculation** (shapes/util.ts:133-141):
- `updateNodeBounds()` reads actual SVG bounding box: `element.node().getBBox()`
- Updates node dimensions: `node.width = bbox.width`, `node.height = bbox.height`
- Called for recursive cluster renders to capture visual dimensions

**Cluster Height Includes Label**:
- For compound shapes: `node.offsetY = bbox.height - node.padding / 2`
- Communicates to layout engine that visual box is larger than content alone

**Handling Boundary-Crossing Edges** (mermaid-graphlib.js):
- `adjustClustersAndEdges()` identifies clusters with `externalConnections`
- Replaces cluster node IDs with anchor node IDs (first non-cluster child) in edges
- Stores metadata: `edge.fromCluster` and `edge.toCluster`
- Prevents dagre from trying to route edges through cluster containers

**SVG ViewBox** (setupViewPortForSVG.ts):
- Calculated AFTER all rendering completes
- Gets complete bounding box: `svg.node().getBBox()`
- Creates viewBox with padding: `${x - padding} ${y - padding} ${width} ${height}`
- Default padding is 8px for flowcharts
- Ensures all content (nodes, edges, labels, cluster boxes) is visible

**CSS Styling** (flowchart/styles.ts:126-141):
```css
.cluster rect {
  fill: ${options.clusterBkg};      /* Theme-based fill */
  stroke: ${options.clusterBorder}; /* Theme-based border */
  stroke-width: 1px;
}
.cluster text { fill: ${options.titleColor}; }
.cluster span { color: ${options.titleColor}; }
.cluster-label span p { background-color: transparent; }
```

## How

Complete pipeline:

1. **Preparation**: Convert LayoutData to graphlib compound graph, analyze cluster boundaries
2. **Recursive Insertion**: Depth-first insertion of nodes/edges with label sizing
3. **Dagre Layout**: Hierarchical positioning of all nodes
4. **Post-Layout**: Call shape functions (`rect`/`roundedWithTitle`), render boxes and labels
5. **Coordinate Adjustment**: Apply title margins, update bounds
6. **ViewBox Calculation**: Final SVG viewport to include all content + padding

Key mechanisms:
- **Title Outside Box**: Avoids text overlapping with content, simplifies centering, reduces interior space conflicts
- **Recursive Rendering**: Supports arbitrary nesting depth, allows independent layout per level
- **updateNodeBounds() After SVG Rendering**: More reliable than pre-calculation, accounts for font metrics and HTML label rendering variability
- **Configurable Margins**: Different diagram types can control spacing without code changes

## Why

**Design rationale:**

- Labels outside box = cleaner but can overlap if positioned close together
- Cluster boundaries are approximate: edges use anchor nodes, not visual cluster geometry
- Recursive layouts may be inefficient if child graphs differ greatly in size from parent
- Edge routing may not perfectly align with visual cluster boundaries

The key insight for mmdflux is that **padding/margin adjustments happen after layout, not before**, and labels are positioned independently of box sizing. Mermaid's approach is pragmatic: it separates layout computation (dagre) from visual rendering (SVG shape functions), with post-processing adjustments to account for labels and subgraph visual boundaries.

## Key Takeaways

- **Post-layout adjustment**: Mermaid shifts cluster nodes and their children by `subGraphTitleTotalMargin` after dagre layout completes — title space is not baked into dagre's input
- **Anchor node replacement**: Edges targeting clusters are redirected to an internal anchor node, avoiding direct cluster-to-cluster routing
- **Dynamic bounds**: `updateNodeBounds()` measures actual SVG bbox rather than pre-computing dimensions, giving accurate results after rendering
- **Configurable title margins**: `flowchart.subGraphTitleMargin.top/bottom` controls title spacing, unlike mmdflux's hardcoded constants
- **ViewBox as safety net**: Final SVG viewBox calculation with padding ensures nothing is clipped, regardless of post-layout adjustments

## Open Questions

- How does Mermaid handle deeply nested subgraphs (3+ levels)? Does the recursive rendering create compounding margin issues?
- What happens when two adjacent subgraphs have labels that would overlap horizontally?
- Does the anchor node replacement approach cause edge routing artifacts (edges not connecting to visual cluster boundary)?
- How does the `roundedWithTitle` shape differ from basic `rect` in terms of padding/margin handling?
