# Q2: How does Mermaid handle subgraph titles and edge-title collisions?

## Summary

Mermaid positions subgraph titles **above the border rect** using `subGraphTitleTopMargin`, not inside it. After dagre computes layout, Mermaid adjusts all node and edge coordinates **downward** by `subGraphTitleTotalMargin` to reserve vertical space for titles. Additionally, cluster borders are expanded **upward** during rendering (the rect height increases), and edge paths are clipped at cluster boundaries via `cutPathAtIntersect()`, which naturally prevents edges from passing through title regions since titles exist outside the border geometry.

## Where

### Key Files
1. **`/Users/kevin/src/mermaid/packages/mermaid/src/utils/subGraphTitleMargins.ts`** - Title margin configuration
2. **`/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/layout-algorithms/dagre/index.js`** - Layout post-processing (lines 170-258)
3. **`/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/clusters.js`** (lines 13-122) - Cluster rendering and title positioning
4. **`/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/edges.js`** (lines 368-401, 507-561) - Edge path clipping at cluster boundaries
5. **`/Users/kevin/src/mermaid/packages/mermaid/src/dagre-wrapper/clusters.js`** (lines 10-90) - Legacy dagre-wrapper cluster rendering

## What

### 1. Title Positioning (Outside the Border)

In **clusters.js** (rendering-util version, lines 95-100):

```javascript
const { subGraphTitleTopMargin } = getSubGraphTitleMargins(siteConfig);
labelEl.attr(
  'transform',
  // This puts the label on top of the box instead of inside it
  `translate(${node.x - bbox.width / 2}, ${node.y - node.height / 2 + subGraphTitleTopMargin})`
);
```

- The title is positioned at `y = node.y - node.height / 2 + subGraphTitleTopMargin`
- This places the title **above** the cluster border (which is at `y = node.y - node.height / 2`)
- The comment explicitly confirms: "This puts the label on top of the box instead of inside it"

### 2. Title Margin and offsetY

In **clusters.js** (rendering-util, line 115):

```javascript
// Used by layout engine to position subgraph in parent
node.offsetY = bbox.height - node.padding / 2;
```

- `offsetY` records the label height to inform parent layout algorithm
- This allows nested subgraphs to account for title space

### 3. Dagre Post-Processing for Title Space

In **rendering-util/layout-algorithms/dagre/index.js** (lines 170-246):

```javascript
// Line 170: Get total title margin from config
let { subGraphTitleTotalMargin } = getSubGraphTitleMargins(siteConfig);

// Line 184: For recursive cluster nodes
node.y += subGraphTitleTotalMargin;

// Line 211: For non-recursive clusters, expand height
node.height += subGraphTitleTotalMargin;

// Line 224: For regular nodes, offset by half margin
node.y += subGraphTitleTotalMargin / 2;
```

The algorithm treats three node types differently:
1. **Recursive clusters** (clusterNode=true): Shift down by full margin
2. **Non-recursive clusters**: Increase height by full margin (no shift)
3. **Regular nodes**: Shift down by half margin

This ensures nodes don't overlap with subgraph titles above them.

### 4. Edge Point Adjustment

In **rendering-util/layout-algorithms/dagre/index.js** (line 253):

```javascript
edge.points.forEach((point) => (point.y += subGraphTitleTotalMargin / 2));
```

All edge waypoints are adjusted downward by half the title margin, shifting edges to avoid the reserved title space.

### 5. Edge-Title Collision Avoidance

The avoidance happens through two mechanisms:

#### A. Cluster Boundary Clipping (Primary)

In **rendering-util/rendering-elements/edges.js** (lines 368-401, 507-561):

```javascript
const cutPathAtIntersect = (_points, boundaryNode) => {
  let points = [];
  let lastPointOutside = _points[0];
  let isInside = false;
  _points.forEach((point) => {
    if (!outsideNode(boundaryNode, point) && !isInside) {
      const inter = intersection(boundaryNode, lastPointOutside, point);
      points.push(inter);
      isInside = true;
    } else {
      lastPointOutside = point;
      if (!isInside) {
        points.push(point);
      }
    }
  });
  return points;
};

export const insertEdge = function (elem, edge, clusterDb, ...) {
  if (edge.toCluster) {
    points = cutPathAtIntersect(edge.points, clusterDb.get(edge.toCluster).node);
    pointsHasChanged = true;
  }
  if (edge.fromCluster) {
    points = cutPathAtIntersect(points.reverse(), clusterDb.get(edge.fromCluster).node).reverse();
    pointsHasChanged = true;
  }
};
```

The `outsideNode()` function checks if a point is outside cluster bounds:

```javascript
const outsideNode = (node, point) => {
  const x = node.x;
  const y = node.y;
  const dx = Math.abs(point.x - x);
  const dy = Math.abs(point.y - y);
  const w = node.width / 2;
  const h = node.height / 2;
  return dx >= w || dy >= h;
};
```

**Key insight**: This clipping uses the **cluster's expanded height** (which includes `subGraphTitleTotalMargin`), so edges are clipped to never cross the space where the title exists.

#### B. Node Positioning Offset

By shifting all node coordinates downward by `subGraphTitleTotalMargin / 2`, dagre naturally routes edges further away from the top of clusters, providing additional buffer.

### 6. Cluster Rect Height Adjustment

In **clusters.js** (rendering-util, lines 84-93):

```javascript
rect
  .attr('style', nodeStyles)
  .attr('rx', node.rx)
  .attr('ry', node.ry)
  .attr('x', x)
  .attr('y', y)
  .attr('width', width)
  .attr('height', height);
```

The rect SVG element uses `node.height`, which was increased by `subGraphTitleTotalMargin` in line 211 of the layout algorithm. This visually expands the border to accommodate space above the title.

## How

### Step-by-Step: Rendering Pipeline

1. **Parse & Build Graph** — Flowchart parsed, converted to abstract graph

2. **Pre-Layout** — Each subgraph node marked with `clusterNode: true`, title text measured

3. **Dagre Layout** — Computes X/Y positions for all nodes (titles not considered)

4. **Post-Layout Adjustment** (lines 170-246)
   - Read `subGraphTitleTotalMargin` from config
   - Recursive clusters: `node.y += subGraphTitleTotalMargin`
   - Non-recursive clusters: `node.height += subGraphTitleTotalMargin`
   - Regular nodes: `node.y += subGraphTitleTotalMargin / 2`
   - Edge points: `point.y += subGraphTitleTotalMargin / 2`

5. **Cluster Rendering** (clusters.js, lines 13-122)
   - Create SVG `<rect>` with adjusted height
   - Position title at `y = node.y - node.height / 2 + subGraphTitleTopMargin`
   - Title sits **above** the border in reserved space

6. **Edge Rendering** (edges.js, lines 507-561)
   - For edges to/from clusters: call `cutPathAtIntersect()` with expanded boundary
   - Since rect is expanded for title space, edges naturally avoid the title

## Why

1. **Title Above Border, Not Inside** — Clearer visual hierarchy, not obscured by content
2. **Post-Layout Adjustment** — Keeps dagre algorithm unchanged, single adjustment pass
3. **Cluster Boundary Expansion** — Satisfies both visual rendering and edge routing
4. **Edge Clipping at Boundaries** — Generic solution, no special title-aware routing needed
5. **Configurable Margins** — `subGraphTitleMargin` allows per-diagram tuning

## Key Takeaways

- **Titles are positioned OUTSIDE clusters** using `subGraphTitleTopMargin`, placed above the rect
- **Space is reserved POST-layout** by adjusting node and edge Y-coordinates downward
- **Cluster borders expand UPWARD** in height (via `node.height += subGraphTitleTotalMargin`) to include title space
- **Edges naturally avoid titles** because `cutPathAtIntersect()` clips them at the expanded cluster boundary
- **No special title-aware routing** is needed — the boundary expansion handles it implicitly
- **offsetY property** on cluster nodes tracks label height for nested cluster layout

## Open Questions

- How is `subGraphTitleMargin` calculated in default config? The spec files show it comes from `flowchart.subGraphTitleMargin.{top, bottom}`, but what are the defaults?
- Why is `subGraphTitleTotalMargin / 2` applied to regular nodes instead of the full margin?
- Does `node.offsetY` get used by parent clusters in nested hierarchies?
- How does the implementation handle very large titles that exceed the configured margin?
