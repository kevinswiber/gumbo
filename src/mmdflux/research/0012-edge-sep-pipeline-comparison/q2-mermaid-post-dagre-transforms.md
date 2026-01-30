# Q2: Does Mermaid add any coordinate transformations beyond dagre?

## Summary

Mermaid applies **minimal post-dagre transformations**, primarily **subgraph title margin offsets** for node and edge coordinates. It does **not use edgesep** in flowchart rendering (only in ER diagrams), and there is **no grid snapping, proportional scaling, or stagger mapping**.

## Where

- `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/layout-algorithms/dagre/index.js` — Main dagre wrapper and `recursiveRender()` function
- `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/nodes.ts` — `positionNode()` SVG transform logic
- `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/edges.js` — Edge waypoint and label positioning
- `/Users/kevin/src/mermaid/packages/mermaid/src/utils/subGraphTitleMargins.ts` — Subgraph title margin retrieval
- `/Users/kevin/src/mermaid/node_modules/.pnpm/dagre-d3-es@7.0.13/node_modules/dagre-d3-es/src/dagre/layout.js` — Dagre parameter definitions

## What

### 1. Dagre Parameters Passed via setGraph()

Mermaid passes the following parameters to dagre via `setGraph()` in `/index.js` lines 276-288:

```javascript
.setGraph({
  rankdir: data4Layout.direction,
  nodesep: data4Layout.config?.nodeSpacing ||
           data4Layout.config?.flowchart?.nodeSpacing ||
           data4Layout.nodeSpacing,
  ranksep: data4Layout.config?.rankSpacing ||
           data4Layout.config?.flowchart?.rankSpacing ||
           data4Layout.rankSpacing,
  marginx: 8,
  marginy: 8,
})
```

- `rankdir` — rank direction (TB, LR, RL, BT)
- `nodesep` — node spacing (default 50 from flowRenderer-v3-unified.ts line 49)
- `ranksep` — rank spacing (default 50 from flowRenderer-v3-unified.ts line 50)
- `marginx`, `marginy` — fixed margins (8 pixels each)
- **NO `edgesep`** — Mermaid flowchart rendering does not pass `edgesep` (only ER diagrams do, with `edgesep: 100` in erRenderer.js line 615)

The dagre library defines default parameters (layout.js line 93):
```javascript
var graphDefaults = { ranksep: 50, edgesep: 20, nodesep: 50, rankdir: 'tb' };
```

### 2. Post-Dagre Coordinate Transformations

After dagre completes layout (`dagreLayout(graph)` at line 165), Mermaid applies **two transformations**:

**A. Subgraph Title Margin Offset** (lines 170-184 and 249-258):
- Retrieves `subGraphTitleTotalMargin` from `getSubGraphTitleMargins(siteConfig)`
- For **nodes**: `node.y += subGraphTitleTotalMargin` (for cluster nodes) or `node.y += subGraphTitleTotalMargin / 2` (for regular nodes) (lines 184, 224)
- For **edge waypoints**: `edge.points.forEach((point) => (point.y += subGraphTitleTotalMargin / 2))` (line 253)
- This is a **vertical offset only**, applied to compensate for subgraph title heights (default 0 if not configured)

**B. SVG Transform Generation** (nodes.ts lines 73-96):
- For **cluster nodes**:
  ```javascript
  el.attr('transform', 'translate(' +
    (node.x + diff - node.width / 2) + ', ' +
    (node.y - node.height / 2 - padding) + ')')
  ```
  Centers the node by subtracting half-width and half-height, applies `diff` offset

- For **regular nodes**:
  ```javascript
  el.attr('transform', 'translate(' + node.x + ', ' + node.y + ')')
  ```
  Uses dagre coordinates directly without centering

- No rounding, no snapping, no proportional scaling

### 3. Edge Waypoint Consumption (edges.js lines 507-785)

Edge waypoints from dagre are consumed **directly**:
- Line 518: `let points = edge.points` (dagre's waypoints)
- Lines 531-543: Intersect calculation with start/end nodes
- Line 564: Filter out NaN values: `let lineData = points.filter((p) => !Number.isNaN(p.y))`
- Lines 566-607: D3 curve selection (curveLinear default, other curves available)
- Lines 613-614: Line function created and applied to lineData
- **No transformation, snapping, or stagger mapping applied to waypoints**

### 4. Edge Label Positioning (edges.js lines 213-291)

For edge labels, coordinates are determined by:
- `pos = utils.calcLabelPosition(path)` — calculates label position from path
- Applied Y offset: `el.attr('transform', translate(${x}, ${y + subGraphTitleTotalMargin / 2}))`
- Terminal labels positioned via `utils.calcTerminalLabelPosition()` with fixed offsets based on arrow types

### 5. No Grid Snapping or Proportional Scaling

- No `Math.round()` or rounding operations applied to coordinates
- No modulo operations or grid alignment
- No layer-grouping or stagger mapping visible in the codebase
- Coordinates are used as floating-point values throughout

## How

**Data Flow:**
1. `render()` in flowRenderer-v3-unified.ts (line 55) → calls `render(data4Layout, svg)` from rendering-util/render.ts
2. `render()` calls layout algorithm's `render()` method (render.ts line 65)
3. Dagre layout algorithm (dagre/index.js):
   - `recursiveRender()` inserts nodes (insertNode) and edge labels (insertEdgeLabel) **before** layout
   - `dagreLayout(graph)` runs dagre algorithm (line 165)
   - `positionNode()` applies SVG transforms to nodes (line 197, 242)
   - Edge waypoints are adjusted for subgraph margins (line 253)
   - `insertEdge()` renders edges using transformed waypoints (line 256)
   - `positionEdgeLabel()` positions labels (line 257)

**No intermediate transforms** between dagre output and final positioning.

## Why

1. **Subgraph Margin Offset** — Required for proper layout when subgraphs have title margins (optional feature, defaults to 0)
2. **No edgesep in flowcharts** — Mermaid relies on `nodesep` and `ranksep` for spacing; ER diagrams use `edgesep` for entity relationship specific layout
3. **Direct waypoint usage** — Dagre's edge routing already produces high-quality paths; no need for post-processing
4. **No grid snapping** — Floating-point coordinates allow for smooth, continuous layouts without aliasing effects
5. **SVG transform centering** — Required because SVG elements are positioned by their top-left corner, while dagre provides center coordinates for nodes

## Key Takeaways

- **Mermaid does NOT pass `edgesep` to dagre for flowchart diagrams** — uses only `nodesep` and `ranksep`
- **Minimal post-dagre transformations** — only Y-axis offsets for subgraph title margins and SVG transform generation
- **No coordinate snapping or scaling** — uses floating-point coordinates directly
- **Dagre defaults apply** — `edgesep` defaults to 20 in dagre if needed, but Mermaid doesn't configure it
- **Different for ER diagrams** — ER renderer explicitly sets `edgesep: 100` (erRenderer.js line 615)

## Open Questions

- Why does Mermaid not use `edgesep` for flowcharts? (Appears to be deliberate design choice)
- What are the effects of the `diff` offset applied to cluster nodes? (Appears related to subgraph layout, could deserve deeper investigation)
- How does the padding calculation (`node.height / 2 - padding`) in node positioning relate to actual node rendering? (Appears to be cluster-specific adjustment)
