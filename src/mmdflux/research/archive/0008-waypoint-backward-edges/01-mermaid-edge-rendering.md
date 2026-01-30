# 01: How Mermaid/dagre-d3 Renders Backward Edge Paths

## Edge Points Data Structure After Dagre Layout

**File:** `~/src/dagre/lib/layout.js` (lines 84-93)

After dagre completes layout, edge paths are stored as `edge.points` — an array of `{x, y}` objects:

```javascript
inputGraph.edges().forEach(e => {
  let inputLabel = inputGraph.edge(e);
  let layoutLabel = layoutGraph.edge(e);
  inputLabel.points = layoutLabel.points;  // Array of {x, y} coordinates
  if (Object.hasOwn(layoutLabel, "x")) {
    inputLabel.x = layoutLabel.x;
    inputLabel.y = layoutLabel.y;
  }
});
```

Each edge has:
- `edge.points`: Array of `{x, y}` waypoints (dummy node positions + boundary intersections)
- `edge.x`, `edge.y`: Optional label position coordinates
- `edge.reversed`: Boolean flag for backward edges
- `edge.forwardName`: Original edge name before reversal

## Backward Edge Pipeline

The complete pipeline for a backward edge:

1. **Acyclic phase** (`acyclic.js:11-27`): Identifies feedback edges, reverses them (edge `v→w` becomes `w→v`), marks `label.reversed = true`
2. **Rank assignment**: Assigns ranks respecting reversed edge directions — all edges now point "forward" in rank
3. **Normalization** (`normalize.js:31-67`): Long edges get dummy nodes inserted at intermediate ranks. `edgeLabel.points = []` initialized
4. **Ordering**: Crossing minimization positions nodes (including dummies) within each rank
5. **Position** (`position/index.js`): x,y coordinates assigned to all nodes including dummies
6. **Denormalization** (`normalize.js:69-89`): Walks dummy chains, pushes `{x: node.x, y: node.y}` to `origLabel.points`
7. **Node intersects** (`layout.js:266-283`): Adds start/end boundary intersection points via `unshift`/`push`
8. **Point reversal** (`layout.js:300-306`): For reversed edges, `edge.points.reverse()` — flips waypoint order back to original direction
9. **Acyclic undo** (`acyclic.js:55-67`): Restores original edge direction in graph structure

## SVG Path Generation in Mermaid

**File:** `~/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/edges.js` (lines 507-785)

Mermaid converts dagre's edge points into SVG paths using D3 curve interpolation:

- Lines 566-607: Supports `curveLinear`, `curveBasis`, `curveCardinal`, `curveBumpX/Y`, `curveCatmullRom`
- Default: `curveLinear` (straight segments between waypoints)
- Lines 614-647: `const lineFunction = line().x(x).y(y).curve(curve);`

Before SVG generation, node boundary clipping occurs (lines 531-543):
```javascript
if (head.intersect && tail.intersect && !skipIntersect) {
  points = points.slice(1, edge.points.length - 1);
  points.unshift(tail.intersect(points[0]));
  points.push(head.intersect(points[points.length - 1]));
}
```

## Flowchart Integration

**File:** `~/src/mermaid/packages/mermaid/src/rendering-util/layout-algorithms/dagre/index.js` (lines 248-258)

After dagre layout, Mermaid iterates edges and calls `insertEdge()`:
```javascript
graph.edges().forEach(function (e) {
  const edge = graph.edge(e);
  edge.points.forEach((point) => (point.y += subGraphTitleTotalMargin / 2));
  const paths = insertEdge(edgePaths, edge, clusterDb, diagramType, startNode, endNode, id);
  positionEdgeLabel(edge, paths);
});
```

## Key Insight for mmdflux

Dagre produces edge waypoints as the **positions of dummy nodes** inserted during normalization. For backward edges, these dummy nodes are positioned by the same crossing-minimization and coordinate-assignment algorithms as regular nodes. The points are then reversed to match original edge direction.

This means backward edge waypoints naturally route **through the layout area** — they follow the same inter-rank spacing as forward edges. The "corridor" approach in mmdflux is an ASCII-specific workaround that doesn't exist in dagre/Mermaid.
