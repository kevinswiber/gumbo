# How Dagre and Mermaid Compute Edge Attachment Points

## Executive Summary

Dagre does **not** have an explicit "port" or "edge spreading" mechanism. Instead, it
relies on an **indirect** approach: each multi-rank edge is broken into a chain of
dummy nodes (one per rank), those dummy nodes participate in the ordering phase and
get distinct x-coordinates, and the final intersection calculation uses the **angle
from the first/last waypoint** to determine where the edge meets the node boundary.
Multiple edges naturally fan out because their dummy-node chains receive different
horizontal positions during ordering, producing different angles of approach.

Mermaid's rendering layer then replaces Dagre's simple `intersectRect` with
shape-aware intersection functions (polygon, circle, ellipse) but the fundamental
mechanism is identical: shoot a ray from the nearest waypoint toward the node center
and find where it crosses the boundary.

---

## 1. Dagre's Edge Endpoint Computation: `assignNodeIntersects`

**File:** `$HOME/src/dagre/lib/layout.js`, lines 266-283

This is the **final step** before output. It runs after all positioning is complete.

```javascript
function assignNodeIntersects(g) {
  g.edges().forEach(e => {
    let edge = g.edge(e);
    let nodeV = g.node(e.v);
    let nodeW = g.node(e.w);
    let p1, p2;
    if (!edge.points) {
      edge.points = [];
      p1 = nodeW;
      p2 = nodeV;
    } else {
      p1 = edge.points[0];          // first waypoint
      p2 = edge.points[edge.points.length - 1];  // last waypoint
    }
    edge.points.unshift(util.intersectRect(nodeV, p1));  // source attachment
    edge.points.push(util.intersectRect(nodeW, p2));      // target attachment
  });
}
```

**Key insight:** The attachment point is determined by the **angle between the node
center and the nearest waypoint**. The `intersectRect` function (see below) computes
where a ray from the node center toward that waypoint crosses the rectangular
boundary.

- For the **source node** (`nodeV`): the ray goes from `nodeV`'s center toward
  `edge.points[0]` (the first interior waypoint).
- For the **target node** (`nodeW`): the ray goes from `nodeW`'s center toward
  `edge.points[last]` (the last interior waypoint).

If there are no interior points (adjacent nodes), the ray goes from each node center
toward the **other node's center**, meaning the edge is a straight line.

---

## 2. The `intersectRect` Function

**File:** `$HOME/src/dagre/lib/util.js`, lines 101-134

```javascript
function intersectRect(rect, point) {
  let x = rect.x;
  let y = rect.y;

  let dx = point.x - x;
  let dy = point.y - y;
  let w = rect.width / 2;
  let h = rect.height / 2;

  if (!dx && !dy) {
    throw new Error("Not possible to find intersection inside of the rectangle");
  }

  let sx, sy;
  if (Math.abs(dy) * w > Math.abs(dx) * h) {
    // Intersection is top or bottom of rect.
    if (dy < 0) { h = -h; }
    sx = h * dx / dy;
    sy = h;
  } else {
    // Intersection is left or right of rect.
    if (dx < 0) { w = -w; }
    sx = w;
    sy = w * dy / dx;
  }

  return { x: x + sx, y: y + sy };
}
```

**Algorithm:** Given a rectangle centered at `(rect.x, rect.y)` with half-dimensions
`w` and `h`, and an external point, compute where the ray from center to point
crosses the boundary.

The comparison `|dy| * w > |dx| * h` determines whether the ray hits a horizontal
edge (top/bottom) or a vertical edge (left/right). Then it uses similar triangles to
find the exact crossing point.

**Critical property for spreading:** The intersection point is a **continuous
function** of the waypoint position. Two edges approaching from slightly different
angles will produce slightly different attachment points along the same face. There
is no snapping, no port system, and no quantization.

---

## 3. How Dummy Nodes Create Different Waypoints (The Spreading Mechanism)

### 3a. Edge Normalization

**File:** `$HOME/src/dagre/lib/normalize.js`, lines 26-67

Long edges (spanning multiple ranks) are split into chains of single-rank segments
by inserting **dummy nodes**:

```javascript
function normalizeEdge(g, e) {
  let v = e.v;
  let vRank = g.node(v).rank;
  let w = e.w;
  let wRank = g.node(w).rank;
  // ...
  if (wRank === vRank + 1) return;  // already single-rank, skip

  g.removeEdge(e);

  let dummy, attrs, i;
  for (i = 0, ++vRank; vRank < wRank; ++i, ++vRank) {
    edgeLabel.points = [];
    attrs = {
      width: 0, height: 0,
      edgeLabel: edgeLabel, edgeObj: e,
      rank: vRank
    };
    dummy = util.addDummyNode(g, "edge", attrs, "_d");
    // ...
    g.setEdge(v, dummy, { weight: edgeLabel.weight }, name);
    if (i === 0) {
      g.graph().dummyChains.push(dummy);
    }
    v = dummy;
  }
  g.setEdge(v, w, { weight: edgeLabel.weight }, name);
}
```

Each dummy node has `width: 0, height: 0` and represents one bend-point of the
original long edge. These dummy nodes are **real nodes in the graph** during
ordering and positioning.

### 3b. Denormalization: Collecting Waypoints

**File:** `$HOME/src/dagre/lib/normalize.js`, lines 69-89

After positioning, dummy chains are collapsed back into edge points:

```javascript
function undo(g) {
  g.graph().dummyChains.forEach(v => {
    let node = g.node(v);
    let origLabel = node.edgeLabel;
    let w;
    g.setEdge(node.edgeObj, origLabel);
    while (node.dummy) {
      w = g.successors(v)[0];
      g.removeNode(v);
      origLabel.points.push({ x: node.x, y: node.y });  // <-- waypoint from dummy position
      // ...
      v = w;
      node = g.node(v);
    }
  });
}
```

Each dummy node's final `(x, y)` position becomes a waypoint in `edge.points`. The
x-coordinate of each dummy was determined by the Brandes-Kopf horizontal positioning
algorithm, which respects the **order** established by the crossing-minimization
phase.

---

## 4. The Ordering Phase: How Edges Get Different Positions

### 4a. Overview

**File:** `$HOME/src/dagre/lib/order/index.js`, lines 28-64

The ordering phase assigns each node (including dummy nodes) an `order` value within
its rank (layer). It minimizes edge crossings using a layer-by-layer sweep with
barycenter heuristics.

```javascript
function order(g, opts = {}) {
  let maxRank = util.maxRank(g),
    downLayerGraphs = buildLayerGraphs(g, util.range(1, maxRank + 1), "inEdges"),
    upLayerGraphs   = buildLayerGraphs(g, util.range(maxRank - 1, -1, -1), "outEdges");

  let layering = initOrder(g);
  assignOrder(g, layering);

  let bestCC = Number.POSITIVE_INFINITY, best;
  for (let i = 0, lastBest = 0; lastBest < 4; ++i, ++lastBest) {
    sweepLayerGraphs(i % 2 ? downLayerGraphs : upLayerGraphs, i % 4 >= 2);
    layering = util.buildLayerMatrix(g);
    let cc = crossCount(g, layering);
    if (cc < bestCC) {
      lastBest = 0;
      best = Object.assign({}, layering);
      bestCC = cc;
    }
  }
  assignOrder(g, best);
}
```

### 4b. Barycenter Ordering

**File:** `$HOME/src/dagre/lib/order/barycenter.js`, lines 1-26

```javascript
function barycenter(g, movable = []) {
  return movable.map(v => {
    let inV = g.inEdges(v);
    if (!inV.length) {
      return { v: v };
    } else {
      let result = inV.reduce((acc, e) => {
        let edge = g.edge(e),
          nodeU = g.node(e.v);
        return {
          sum: acc.sum + (edge.weight * nodeU.order),
          weight: acc.weight + edge.weight
        };
      }, { sum: 0, weight: 0 });
      return {
        v: v,
        barycenter: result.sum / result.weight,
        weight: result.weight
      };
    }
  });
}
```

The barycenter of a node is the **weighted average position** of its neighbors in the
adjacent layer. For dummy nodes in the same layer that represent different edges from
the same source, their barycenters will differ if their targets are at different
positions, causing them to receive different order values.

### 4c. Impact on Attachment Points

Consider a diamond node D with two outgoing edges to nodes A and B, where A is
to the left of B in the next layer:

```
    D (diamond)
   / \
  A   B
```

After normalization (if ranks differ by 1, no dummies are needed), the edges go
directly from D to A and D to B. In `assignNodeIntersects`:

- Edge D->A: waypoint is A's position (left of D), so the ray from D's center
  goes left-downward, hitting D's boundary at a left-of-center point on the bottom
  face.
- Edge D->B: waypoint is B's position (right of D), so the ray goes right-downward,
  hitting D's boundary at a right-of-center point on the bottom face.

**The edges naturally spread across the bottom face of D** because A and B have
different x-coordinates, creating different approach angles.

For longer edges (spanning multiple ranks), each edge gets its own chain of dummy
nodes. The ordering phase places these dummy chains at different horizontal positions
(determined by where their ultimate targets are), so the first dummy node of each
chain has a different x-coordinate, producing different approach angles from the
source node.

---

## 5. Horizontal Positioning: The Brandes-Kopf Algorithm

**File:** `$HOME/src/dagre/lib/position/bk.js`

### 5a. positionX (main entry)

Lines 355-387: Runs four alignment passes (up-left, up-right, down-left, down-right)
and balances them:

```javascript
function positionX(g) {
  let layering = util.buildLayerMatrix(g);
  let conflicts = Object.assign(
    findType1Conflicts(g, layering),
    findType2Conflicts(g, layering));

  let xss = {};
  let adjustedLayering;
  ["u", "d"].forEach(vert => {
    adjustedLayering = vert === "u" ? layering : Object.values(layering).reverse();
    ["l", "r"].forEach(horiz => {
      // ... reverse layers for right bias ...
      let neighborFn = (vert === "u" ? g.predecessors : g.successors).bind(g);
      let align = verticalAlignment(g, adjustedLayering, conflicts, neighborFn);
      let xs = horizontalCompaction(g, adjustedLayering, align.root, align.align, horiz === "r");
      if (horiz === "r") { xs = util.mapValues(xs, x => -x); }
      xss[vert + horiz] = xs;
    });
  });

  let smallestWidth = findSmallestWidthAlignment(g, xss);
  alignCoordinates(xss, smallestWidth);
  return balance(xss, g.graph().align);
}
```

### 5b. Vertical Alignment

Lines 166-204: Tries to align each node with its **median neighbor** in the adjacent
layer, forming vertical "blocks":

```javascript
function verticalAlignment(g, layering, conflicts, neighborFn) {
  // ...
  layering.forEach(layer => {
    let prevIdx = -1;
    layer.forEach(v => {
      let ws = neighborFn(v);
      if (ws.length) {
        ws = ws.sort((a, b) => pos[a] - pos[b]);
        let mp = (ws.length - 1) / 2;
        for (let i = Math.floor(mp), il = Math.ceil(mp); i <= il; ++i) {
          let w = ws[i];
          if (align[v] === v && prevIdx < pos[w] && !hasConflict(conflicts, v, w)) {
            align[w] = v;
            align[v] = root[v] = root[w];
            prevIdx = pos[w];
          }
        }
      }
    });
  });
  // ...
}
```

This is where dummy nodes for different edges get different x-coordinates. Each
dummy aligns with its median neighbor, and since the ordering phase has already
separated the dummies based on their targets' positions, the horizontal compaction
assigns them distinct x values.

### 5c. The `sep` Function: Minimum Separation

Lines 389-425: Computes minimum separation between adjacent nodes:

```javascript
function sep(nodeSep, edgeSep, reverseSep) {
  return (g, v, w) => {
    let vLabel = g.node(v);
    let wLabel = g.node(w);
    let sum = 0;

    sum += vLabel.width / 2;
    // ... labelpos adjustments ...
    sum += (vLabel.dummy ? edgeSep : nodeSep) / 2;
    sum += (wLabel.dummy ? edgeSep : nodeSep) / 2;
    sum += wLabel.width / 2;
    // ...
    return sum;
  };
}
```

**Important:** Dummy nodes use `edgeSep` (default 20) while real nodes use `nodeSep`
(default 50). This means edges passing through the same layer are separated by at
least `edgeSep` pixels, which is the **minimum spreading distance** between parallel
edges in the same rank.

### 5d. Y-Positioning

**File:** `$HOME/src/dagre/lib/position/index.js`, lines 15-41

Y-coordinates are assigned per-layer based on the maximum node height in each layer,
plus `rankSep`:

```javascript
function positionY(g) {
  let layering = util.buildLayerMatrix(g);
  let rankSep = g.graph().ranksep;
  let prevY = 0;
  layering.forEach(layer => {
    const maxHeight = layer.reduce((acc, v) => {
      return Math.max(acc, g.node(v).height);
    }, 0);
    layer.forEach(v => {
      g.node(v).y = prevY + maxHeight / 2;  // center alignment (default)
    });
    prevY += maxHeight + rankSep;
  });
}
```

All nodes (and dummy nodes) in the same layer share the same y-coordinate.

---

## 6. Mermaid's Intersection Functions

### 6a. Rectangle Intersection (rendering-util)

**File:** `$HOME/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/intersect/intersect-rect.js`

Identical algorithm to Dagre's `intersectRect`:

```javascript
const intersectRect = (node, point) => {
  var dx = point.x - node.x;
  var dy = point.y - node.y;
  var w = node.width / 2;
  var h = node.height / 2;

  var sx, sy;
  if (Math.abs(dy) * w > Math.abs(dx) * h) {
    if (dy < 0) { h = -h; }
    sx = dy === 0 ? 0 : (h * dx) / dy;
    sy = h;
  } else {
    if (dx < 0) { w = -w; }
    sx = w;
    sy = dx === 0 ? 0 : (w * dy) / dx;
  }
  return { x: node.x + sx, y: node.y + sy };
};
```

### 6b. Polygon Intersection (for diamonds, hexagons, etc.)

**File:** `$HOME/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/intersect/intersect-polygon.js`

Tests the ray (node-center -> point) against each polygon edge and returns the
nearest intersection:

```javascript
function intersectPolygon(node, polyPoints, point) {
  let intersections = [];
  // ...
  for (let i = 0; i < polyPoints.length; i++) {
    let p1 = polyPoints[i];
    let p2 = polyPoints[i < polyPoints.length - 1 ? i + 1 : 0];
    let intersect = intersectLine(node, point, /* polygon edge p1->p2 */);
    if (intersect) { intersections.push(intersect); }
  }
  // Return closest intersection to the external point
  if (intersections.length > 1) {
    intersections.sort(/* by distance to point */);
  }
  return intersections[0];
}
```

### 6c. How Shapes Register Their Intersect

**File (example):** `$HOME/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/shapes/drawRect.ts`, lines 66-72

```typescript
node.calcIntersect = function (bounds: Bounds, point: Point) {
  return intersect.rect(bounds, point);
};
node.intersect = function (point) {
  return intersect.rect(node, point);
};
```

**File (diamond):** `$HOME/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/shapes/question.ts`, lines 64-84

```typescript
node.calcIntersect = function (bounds: Bounds, point: Point) {
  const s = bounds.width;
  const points = [
    { x: s / 2, y: 0 },
    { x: s, y: -s / 2 },
    { x: s / 2, y: -s },
    { x: 0, y: -s / 2 },
  ];
  const res = intersect.polygon(bounds, points, point);
  return { x: res.x - 0.5, y: res.y - 0.5 };
};
```

### 6d. How Mermaid Uses Dagre's Points + Node Intersect

**File:** `$HOME/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/edges.js`, lines 507-544

```javascript
export const insertEdge = function (elem, edge, clusterDb, diagramType,
                                     startNode, endNode, id, skipIntersect = false) {
  let points = edge.points;
  const tail = startNode;
  var head = endNode;

  if (head.intersect && tail.intersect && !skipIntersect) {
    points = points.slice(1, edge.points.length - 1);  // strip dagre's rect intersections
    points.unshift(tail.intersect(points[0]));           // recompute with shape-aware intersect
    points.push(head.intersect(points[points.length - 1]));
  }
  // ...
};
```

**This is the critical bridge:** Mermaid takes Dagre's output points (which include
rectangular intersection endpoints), **strips them off** (the `slice(1, -1)`), and
**recomputes** the first and last points using the shape-specific `intersect()`
method. The interior waypoints from Dagre (the dummy node positions) are preserved
as-is.

This means the **angle of approach** is still determined by the first/last interior
waypoint from Dagre's layout, but the actual boundary point is computed using the
correct shape geometry (diamond, circle, etc.) rather than Dagre's rectangle
approximation.

---

## 7. The Complete Pipeline for Edge Attachment

Here is the complete sequence for how an edge gets its attachment points:

### Step 1: Normalization (normalize.run)
Long edges are split into dummy node chains. Each dummy node is a zero-size node
at an intermediate rank.

### Step 2: Ordering (order)
Barycenter heuristics assign each node (including dummies) an `order` value within
its rank. Dummies for different edges from the same source get different orders
because they connect to different targets.

### Step 3: Position X (position -> bk.positionX)
The Brandes-Kopf algorithm assigns x-coordinates. Dummies in the same rank are
separated by at least `edgeSep` (20px default). Each dummy aligns vertically with
its median neighbor.

### Step 4: Position Y (position -> positionY)
All nodes in a rank get the same y-coordinate.

### Step 5: Coordinate System Undo (coordinateSystem.undo)
For LR/RL layouts, x and y are swapped. For BT/RL, y is negated.

### Step 6: Denormalization (normalize.undo)
Dummy chains are collapsed back into edge point arrays. Each dummy's (x, y) becomes
a waypoint.

### Step 7: Translation (translateGraph)
All coordinates are shifted so the graph starts at (marginX, marginY).

### Step 8: Node Intersection (assignNodeIntersects)
For each edge, the first waypoint determines the source attachment angle, and the
last waypoint determines the target attachment angle. `intersectRect` computes where
the ray crosses the node boundary.

### Step 9: Reverse Points (reversePointsForReversedEdges)
Edges that were reversed for acyclicity have their points reversed to match the
original direction.

### Step 10 (Mermaid only): Shape-Aware Intersection
Mermaid strips Dagre's rectangular intersections and recomputes using
shape-specific geometry (polygon, circle, ellipse, etc.).

---

## 8. Does Dagre Have Ports? No.

Dagre has **no concept of ports**. There is no mechanism to specify that an edge
should attach to a specific point on a node. The attachment point is entirely
determined by the approach angle, which is itself determined by the waypoint
positions, which come from the ordering and positioning of dummy nodes.

This means:

1. **Fan-out from a diamond:** If a diamond has two outgoing edges to nodes A (left)
   and B (right), the edges will attach at different points on the diamond's bottom
   face because A and B have different x-coordinates, creating different approach
   angles. The polygon intersection in Mermaid will correctly compute where the ray
   crosses the diamond's slanted edge.

2. **Multiple edges same direction:** If two edges go from node X to nodes in the
   same rank, their dummy chains (or direct connections if adjacent ranks) will have
   different x-positions from ordering, giving different attachment points.

3. **Edges to same target:** Two edges arriving at the same node from different
   sources will have different last-waypoints and thus different attachment points
   on the target's boundary.

---

## 9. The Ordering Phase's Effect on Attachment Points

The ordering phase (`order/index.js`) is the **primary driver** of attachment point
differentiation. Here's why:

### Initial Order (`init-order.js`)
DFS from rank-0 nodes assigns initial positions. The DFS traversal order determines
which dummy chains end up next to each other.

### Barycenter Heuristic (`barycenter.js`)
Each node's position is pulled toward the weighted average of its neighbors. For
two dummy nodes D1 and D2 in the same rank, if D1's predecessor is to the left and
D2's predecessor is to the right, D1 gets a lower barycenter and ends up to the
left.

### Cross-Count Minimization (`cross-count.js`)
The sweep iterates until edge crossings stop decreasing (or 4 iterations without
improvement). This separates dummy chains that would cause crossings.

### Result
After ordering, dummy nodes for different edges from the same source are spatially
separated. The `edgeSep` parameter (default 20px) guarantees minimum separation
between adjacent dummy nodes. This separation directly translates to different
approach angles and thus different attachment points.

---

## 10. The Coordinate System Transform for LR/RL

**File:** `$HOME/src/dagre/lib/coordinate-system.js`

For horizontal layouts (LR/RL):

1. **Before layout:** `adjust()` swaps width and height of all nodes, so the layout
   algorithm works in the "TB" orientation internally.
2. **After layout:** `undo()` swaps x/y coordinates and dimensions back:
   - For BT/RL: also negates y-coordinates
   - For LR/RL: swaps x/y on nodes, edge points, and edge labels; swaps width/height

This means the same dummy-node spreading mechanism works for all four directions.
The intersection calculation in `assignNodeIntersects` happens **after**
`coordinateSystem.undo`, so it operates on the final coordinate space.

---

## 11. Summary Table

| Mechanism | File | Purpose |
|-----------|------|---------|
| Edge normalization | `normalize.js:run` | Split long edges into dummy chains |
| Edge denormalization | `normalize.js:undo` | Collect dummy positions as waypoints |
| Ordering | `order/index.js` | Assign horizontal order to nodes+dummies |
| Barycenter | `order/barycenter.js` | Pull nodes toward neighbor average |
| X positioning | `position/bk.js` | Assign x-coords respecting order+separation |
| Y positioning | `position/index.js` | Assign y-coords per rank |
| Coord transform | `coordinate-system.js` | Handle LR/RL/BT directions |
| Node intersect (dagre) | `layout.js:assignNodeIntersects` | Compute rect boundary crossing |
| `intersectRect` (dagre) | `util.js:intersectRect` | Ray-rectangle intersection |
| Shape intersect (mermaid) | `edges.js:insertEdge` | Replace rect with shape-aware intersection |
| `intersect-rect` (mermaid) | `intersect/intersect-rect.js` | Same algorithm as dagre |
| `intersect-polygon` (mermaid) | `intersect/intersect-polygon.js` | Ray-polygon intersection for diamonds etc. |

---

## 12. Key Implications for mmdflux

1. **No port system needed.** Spreading happens naturally from waypoint positions.

2. **The critical requirement** is that edges from the same node going to different
   targets must have their first waypoint at different x-coordinates. In dagre this
   comes from dummy node ordering; in mmdflux's grid-based layout, this would need
   an analogous mechanism.

3. **For adjacent-rank edges** (no dummies), the waypoint IS the target node's
   center. So two edges from a node to two children in the next rank will attach at
   different points on the parent as long as the children have different
   x-coordinates.

4. **For multi-rank edges**, the dummy node chain's positions determine the
   waypoints. The first dummy's x-coordinate determines the source attachment angle;
   the last dummy's x-coordinate determines the target attachment angle.

5. **The `edgeSep` parameter** (default 20px) controls minimum distance between
   parallel edge segments in the same rank. In a character-grid system, the analogous
   value would be 1 or 2 character cells.

6. **Diamond nodes** in Mermaid use polygon intersection, not rect intersection.
   The ray-polygon test checks all four edges of the diamond and returns the nearest
   crossing point. This means the attachment point slides continuously along the
   diamond's slanted faces as the approach angle changes.
