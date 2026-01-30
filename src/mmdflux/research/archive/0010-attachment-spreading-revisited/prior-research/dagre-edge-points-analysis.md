# Dagre Edge Points Analysis: How Multiple Edges Get Different Attachment Points

## Executive Summary

Dagre does NOT use explicit "ports" on nodes. Instead, it relies on a three-stage mechanism to ensure multiple edges from the same node get different waypoints and attachment points:

1. **Normalization** -- Long edges are split into chains of dummy nodes (one per rank gap). Each edge becomes its own independent chain with its own dummy nodes.
2. **Ordering** -- The order phase assigns each node (including dummy nodes) a unique ordinal position within its rank. Multiple dummy nodes from the same source get **different order values** via barycenter sorting.
3. **Positioning** -- The Brandes-Kopf algorithm assigns x-coordinates based on order, with separation enforced by `edgesep`. Dummy nodes at different orders get different x-coordinates, creating distinct waypoints. Final attachment points are computed via rectangle-line intersection from the first/last waypoint to the source/target node center.

The critical insight: **each edge gets its own chain of dummy nodes, and those dummy nodes compete for position within each rank independently**. The ordering phase naturally spreads them apart.

---

## Pipeline Overview

From `layout.js:30-58`, the full pipeline is:

```
makeSpaceForEdgeLabels  -- doubles minlen, halves ranksep for label placement
removeSelfEdges         -- temporarily removes self-edges
acyclic.run             -- reverses back-edges to make DAG
nestingGraph.run        -- handles compound graph nesting
rank                    -- assigns rank (layer) to each node
injectEdgeLabelProxies  -- dummy nodes for edge label positions
removeEmptyRanks        -- compacts empty rank layers
normalizeRanks          -- shifts ranks so minimum is 0
assignRankMinMax        -- records min/max ranks for subgraphs
removeEdgeLabelProxies  -- clean up label proxy nodes
normalize.run           -- *** SPLIT LONG EDGES INTO DUMMY CHAINS ***
parentDummyChains       -- assign dummy nodes to correct compound parents
addBorderSegments       -- border nodes for subgraphs
order                   -- *** ASSIGN ORDER (horizontal position) TO ALL NODES ***
insertSelfEdges         -- re-insert self-edges as dummy nodes
adjustCoordinateSystem  -- swap width/height for LR/RL
position                -- *** ASSIGN X,Y COORDINATES ***
positionSelfEdges       -- compute self-edge point arrays
removeBorderNodes       -- clean up border dummy nodes
normalize.undo          -- *** COLLECT DUMMY NODE POSITIONS INTO edge.points ***
fixupEdgeLabelCoords    -- adjust label coordinates for offset
undoCoordinateSystem    -- undo LR/RL coordinate swaps
translateGraph          -- shift everything so min coords are at margin
assignNodeIntersects    -- *** COMPUTE EDGE ENDPOINTS ON NODE BORDERS ***
reversePoints           -- reverse points for reversed (back) edges
acyclic.undo            -- restore original edge directions
```

---

## Stage 1: Normalization -- Creating Dummy Node Chains

**File:** `normalize.js:26-67`

When an edge spans more than one rank (i.e., `wRank !== vRank + 1`), Dagre removes the original edge and creates a chain of dummy nodes, one per intermediate rank:

```javascript
// normalize.js:31-67
function normalizeEdge(g, e) {
  let v = e.v;
  let vRank = g.node(v).rank;
  let w = e.w;
  let wRank = g.node(w).rank;
  let name = e.name;
  let edgeLabel = g.edge(e);
  let labelRank = edgeLabel.labelRank;

  if (wRank === vRank + 1) return;  // Already spans exactly 1 rank, no split needed

  g.removeEdge(e);

  let dummy, attrs, i;
  for (i = 0, ++vRank; vRank < wRank; ++i, ++vRank) {
    edgeLabel.points = [];            // Reset points array
    attrs = {
      width: 0, height: 0,           // Dummy nodes have ZERO width/height
      edgeLabel: edgeLabel,
      edgeObj: e,                     // Preserves original edge identity
      rank: vRank
    };
    dummy = util.addDummyNode(g, "edge", attrs, "_d");
    // ...
    g.setEdge(v, dummy, { weight: edgeLabel.weight }, name);
    if (i === 0) {
      g.graph().dummyChains.push(dummy);  // Track first dummy for undo
    }
    v = dummy;
  }
  g.setEdge(v, w, { weight: edgeLabel.weight }, name);
}
```

**Key details:**
- Each dummy node has `width: 0` and `height: 0` -- it's a dimensionless point
- Each dummy node gets `dummy: "edge"` type marker
- The `edgeObj` preserves the original edge identity (source, target, name)
- The first dummy in each chain is recorded in `g.graph().dummyChains` for later undo
- Each edge gets its OWN chain of dummy nodes -- two edges from the same source to different targets spanning 3 ranks will produce 2 independent chains of 2 dummy nodes each

**Example:** If node A (rank 0) has edges to B (rank 3) and C (rank 3):
```
Before normalization:
  Rank 0: A
  Rank 3: B, C

After normalization:
  Rank 0: A
  Rank 1: _d1 (for A->B), _d3 (for A->C)
  Rank 2: _d2 (for A->B), _d4 (for A->C)
  Rank 3: B, C

  Edges: A->_d1, _d1->_d2, _d2->B, A->_d3, _d3->_d4, _d4->C
```

Now there are **four dummy nodes** that need to be positioned. The spreading happens in the next phase.

---

## Stage 2: Ordering -- Spreading Dummy Nodes Horizontally

**File:** `order/index.js`

The ordering phase assigns each node an `order` attribute (integer position within its rank). This is the phase that determines the **relative left-to-right arrangement** of all nodes, including dummy nodes.

### 2a. Initial Order (`order/init-order.js:18-37`)

```javascript
function initOrder(g) {
  let visited = {};
  let layers = util.range(maxRank + 1).map(() => []);

  function dfs(v) {
    if (visited[v]) return;
    visited[v] = true;
    let node = g.node(v);
    layers[node.rank].push(v);
    g.successors(v).forEach(dfs);
  }

  let orderedVs = simpleNodes.sort((a, b) => g.node(a).rank - g.node(b).rank);
  orderedVs.forEach(dfs);
  return layers;
}
```

The DFS traversal naturally places dummy nodes from different edges at different positions because:
- When visiting node A, it traverses A's successors (including dummy nodes _d1 and _d3)
- _d1 is visited first, then its successors (_d2, then B)
- Then _d3 is visited, then its successors (_d4, then C)
- Result at rank 1: [_d1, _d3] -- they already have different ordinal positions

### 2b. Barycenter Ordering (`order/barycenter.js:3-25`)

The main ordering loop (`order/index.js:49-61`) repeatedly sweeps up and down, using **barycenter heuristic** to minimize edge crossings:

```javascript
// barycenter.js:3-25
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

**This is where spreading happens for adjacent-rank edges.** Each node's barycenter is the weighted average of its neighbors' order values. Consider rank 1 containing dummy nodes _d1 (for A->B) and _d3 (for A->C):

- Both _d1 and _d3 have A as their only predecessor, so they both get `barycenter = A.order`
- They have the **same barycenter value**

When barycenters are equal, the sort function breaks ties:

```javascript
// sort.js:46-55
function compareWithBias(bias) {
  return (entryV, entryW) => {
    if (entryV.barycenter < entryW.barycenter) {
      return -1;
    } else if (entryV.barycenter > entryW.barycenter) {
      return 1;
    }
    return !bias ? entryV.i - entryW.i : entryW.i - entryV.i;
  };
}
```

When barycenters are equal, the tiebreaker uses index `i` (the original position in the entries list). The `biasRight` parameter alternates between sweeps (`i % 4 >= 2` in `order/index.js:50`), helping explore different orderings.

**The net effect:** Even when multiple edges originate from the same node, their dummy nodes get **distinct order values** within each rank. They may be adjacent, but they are distinct positions.

### 2c. Layer Graph Construction (`order/build-layer-graph.js:38-73`)

The layer graph used for ordering aggregates multi-edges into single weighted edges:

```javascript
// build-layer-graph.js:56-61
g[relationship](v).forEach(e => {
  let u = e.v === v ? e.w : e.v,
    edge = result.edge(u, v),
    weight = edge !== undefined ? edge.weight : 0;
  result.setEdge(u, v, { weight: g.edge(e).weight + weight });
});
```

This means that if A has two edges to the same rank, the layer graph sees each individual connection (A->_d1 and A->_d3 are separate edges in the layer graph because _d1 and _d3 are different nodes). Each dummy node is an independent entity in the ordering.

---

## Stage 3: Positioning -- Assigning X-Coordinates

**File:** `position/index.js` and `position/bk.js`

### 3a. Y-Coordinate Assignment (`position/index.js:15-41`)

Y-coordinates are straightforward -- each rank gets a y based on the tallest node in that rank plus `ranksep`:

```javascript
function positionY(g) {
  let layering = util.buildLayerMatrix(g);
  let rankSep = g.graph().ranksep;
  let prevY = 0;
  layering.forEach(layer => {
    const maxHeight = layer.reduce((acc, v) => Math.max(acc, g.node(v).height), 0);
    layer.forEach(v => {
      g.node(v).y = prevY + maxHeight / 2;  // (for center alignment)
    });
    prevY += maxHeight + rankSep;
  });
}
```

### 3b. X-Coordinate Assignment -- Brandes-Kopf Algorithm (`position/bk.js`)

This is the most complex part. The algorithm runs **4 times** with different bias directions (up-left, up-right, down-left, down-right) and takes the median result.

```javascript
// bk.js:355-387
function positionX(g) {
  let layering = util.buildLayerMatrix(g);
  let conflicts = Object.assign(
    findType1Conflicts(g, layering),
    findType2Conflicts(g, layering));

  let xss = {};
  ["u", "d"].forEach(vert => {
    ["l", "r"].forEach(horiz => {
      let neighborFn = (vert === "u" ? g.predecessors : g.successors).bind(g);
      let align = verticalAlignment(g, adjustedLayering, conflicts, neighborFn);
      let xs = horizontalCompaction(g, adjustedLayering, align.root, align.align, horiz === "r");
      xss[vert + horiz] = xs;
    });
  });

  let smallestWidth = findSmallestWidthAlignment(g, xss);
  alignCoordinates(xss, smallestWidth);
  return balance(xss, g.graph().align);
}
```

**The balance function** (`bk.js:344-353`) takes the median of the 4 alignment results:

```javascript
function balance(xss, align) {
  return util.mapValues(xss.ul, (num, v) => {
    if (align) {
      return xss[align.toLowerCase()][v];
    } else {
      let xs = Object.values(xss).map(xs => xs[v]).sort((a, b) => a - b);
      return (xs[1] + xs[2]) / 2;  // median of 4 values
    }
  });
}
```

### 3c. The Separation Function -- `edgesep` Parameter (`bk.js:389-425`)

**This is the key spacing mechanism for edges.** The `sep` function computes the minimum horizontal distance between two adjacent nodes in the same rank:

```javascript
// bk.js:389-425
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
    // ... labelpos adjustments ...

    return sum;
  };
}
```

**Critical behavior:** When computing the separation between two nodes:
- If a node is a **dummy node** (`vLabel.dummy` is truthy), it uses `edgeSep / 2`
- If a node is a **real node**, it uses `nodeSep / 2`
- The total separation between two dummy nodes = `edgeSep` (since both contribute `edgeSep / 2`)
- The total separation between a dummy and a real node = `(edgeSep + nodeSep) / 2`

**Default values** from `layout.js:100`:
```javascript
let graphDefaults = { ranksep: 50, edgesep: 20, nodesep: 50 };
```

So two adjacent edge dummy nodes get a minimum separation of **20 pixels** between their x-coordinates. This is the fundamental mechanism that spreads edges apart.

### 3d. Block Graph Construction (`bk.js:267-287`)

The `buildBlockGraph` function encodes separation constraints between adjacent nodes:

```javascript
function buildBlockGraph(g, layering, root, reverseSep) {
  let blockGraph = new Graph(),
    sepFn = sep(graphLabel.nodesep, graphLabel.edgesep, reverseSep);

  layering.forEach(layer => {
    let u;
    layer.forEach(v => {
      let vRoot = root[v];
      blockGraph.setNode(vRoot);
      if (u) {
        var uRoot = root[u],
          prevMax = blockGraph.edge(uRoot, vRoot);
        blockGraph.setEdge(uRoot, vRoot, Math.max(sepFn(g, v, u), prevMax || 0));
      }
      u = v;
    });
  });

  return blockGraph;
}
```

For each pair of adjacent nodes in a rank, it creates a constraint edge in the block graph with weight = minimum separation distance. When `v` and `u` are both dummy nodes, the constraint is `edgesep` pixels apart.

### 3e. Vertical Alignment (`bk.js:166-204`)

The vertical alignment groups nodes into "blocks" that should share the same x-coordinate. Each node tries to align with its **median neighbor** from the adjacent rank:

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
  return { root, align };
}
```

For dummy nodes in a chain (e.g., _d1 -> _d2), each dummy aligns with its predecessor dummy. This creates a vertical "block" -- the entire chain wants the same x-coordinate. **But different chains (different edges) form different blocks** with different x-coordinates, because their dummy nodes have different order values.

### 3f. Type-1 Conflict Detection (`bk.js:41-81`)

Type-1 conflicts occur when a non-inner-segment edge crosses an inner segment (an edge between two dummy nodes). The algorithm marks these conflicts to prevent alignment across inner segments, which preserves the straightness of long edge chains:

```javascript
function findType1Conflicts(g, layering) {
  // ... scans each layer pair for edges that cross inner segments ...
  // Marks conflicting (v, w) pairs so verticalAlignment won't align them
}
```

This protects dummy chains from being disrupted. An inner segment (dummy-to-dummy edge) gets priority for vertical alignment, ensuring that long edges remain straight where possible. This means a long edge's dummy chain tends to form a single vertical block, while other edges that would cross it are forced to different x-positions.

---

## Stage 4: Denormalization -- Collecting Waypoints

**File:** `normalize.js:69-89`

After positioning, the `undo` function walks each dummy chain and collects the (x, y) coordinates of dummy nodes as the edge's `points` array:

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
      origLabel.points.push({ x: node.x, y: node.y });  // <-- Collect waypoint!
      if (node.dummy === "edge-label") {
        origLabel.x = node.x;
        origLabel.y = node.y;
        origLabel.width = node.width;
        origLabel.height = node.height;
      }
      v = w;
      node = g.node(v);
    }
  });
}
```

**Key:** Each dummy node's `(x, y)` becomes a point in the edge's `points` array. Since different dummy chains have different x-coordinates (determined by their order values and the `edgesep` constraint), the resulting `points` arrays differ between edges.

---

## Stage 5: Endpoint Computation -- Node Border Intersection

**File:** `layout.js:266-283`

After denormalization, the edge `points` arrays contain only the intermediate waypoints (dummy node positions). The final step adds the actual start and end points on the node borders:

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
      p1 = edge.points[0];          // First waypoint
      p2 = edge.points[edge.points.length - 1];  // Last waypoint
    }
    edge.points.unshift(util.intersectRect(nodeV, p1));  // Start point on source border
    edge.points.push(util.intersectRect(nodeW, p2));     // End point on target border
  });
}
```

The `intersectRect` function (`util.js:101-134`) computes where a line from the node center to a target point crosses the node's rectangular border:

```javascript
function intersectRect(rect, point) {
  let dx = point.x - rect.x;
  let dy = point.y - rect.y;
  let w = rect.width / 2;
  let h = rect.height / 2;

  let sx, sy;
  if (Math.abs(dy) * w > Math.abs(dx) * h) {
    // Intersection is top or bottom
    if (dy < 0) { h = -h; }
    sx = h * dx / dy;
    sy = h;
  } else {
    // Intersection is left or right
    if (dx < 0) { w = -w; }
    sx = w;
    sy = w * dy / dx;
  }

  return { x: rect.x + sx, y: rect.y + sy };
}
```

**This is how different edges get different attachment points on the same node.** Since each edge's first waypoint (the first dummy node's position) is at a different x-coordinate, the `intersectRect` computation produces a different intersection point on the node's border.

Example: If node A is at (100, 0) with width 60, height 40:
- Edge A->B has first waypoint at (90, 50): intersectRect gives approximately (96, 20) -- left of center on bottom edge
- Edge A->C has first waypoint at (110, 50): intersectRect gives approximately (104, 20) -- right of center on bottom edge

The edges fan out from different points on A's border.

---

## Complete Walkthrough: A -> B and A -> C (both spanning 3 ranks)

### Initial state:
```
Rank 0: A
Rank 3: B, C
Edges: A->B, A->C
```

### After normalize.run:
```
Rank 0: A
Rank 1: _d1 (A->B chain), _d3 (A->C chain)
Rank 2: _d2 (A->B chain), _d4 (A->C chain)
Rank 3: B, C

Edges: A->_d1, _d1->_d2, _d2->B, A->_d3, _d3->_d4, _d4->C
Chains: [_d1, _d2], [_d3, _d4]
```

### After order:
```
Rank 0: [A]          orders: A=0
Rank 1: [_d1, _d3]   orders: _d1=0, _d3=1
Rank 2: [_d2, _d4]   orders: _d2=0, _d4=1
Rank 3: [B, C]       orders: B=0, C=1
```

The barycenter heuristic places _d1 and _d3 side by side because they share the same predecessor (A). Their relative order is determined by tie-breaking on initial index.

### After position:
Suppose A is at x=100, and edgesep=20:
```
A:   x=100, y=0
_d1: x=90,  y=50    (one edgesep unit left of center)
_d3: x=110, y=50    (one edgesep unit right of center)
_d2: x=90,  y=100
_d4: x=110, y=100
B:   x=90,  y=150
C:   x=110, y=150
```

The separation between _d1 and _d3 is enforced by the block graph constraint of `edgesep=20`.

### After normalize.undo:
```
Edge A->B: points = [{x:90, y:50}, {x:90, y:100}]
Edge A->C: points = [{x:110, y:50}, {x:110, y:100}]
```

### After assignNodeIntersects:
```
Edge A->B: points = [intersectRect(A, {90,50}), {x:90, y:50}, {x:90, y:100}, intersectRect(B, {90,100})]
                   = [{x:96, y:20}, {x:90, y:50}, {x:90, y:100}, {x:90, y:130}]

Edge A->C: points = [intersectRect(A, {110,50}), {x:110, y:50}, {x:110, y:100}, intersectRect(C, {110,100})]
                   = [{x:104, y:20}, {x:110, y:50}, {x:110, y:100}, {x:110, y:130}]
```

The edges leave node A from different points (x=96 vs x=104) on its bottom border, because the first waypoints are at different x-coordinates.

---

## What About Short Edges (Spanning Exactly 1 Rank)?

For edges that span exactly one rank (`wRank === vRank + 1`), normalization does NOT create dummy nodes (line `normalize.js:40`). These edges get **no intermediate waypoints**.

In `assignNodeIntersects` (`layout.js:271-278`), when `edge.points` is empty/undefined:
```javascript
if (!edge.points) {
  edge.points = [];
  p1 = nodeW;     // Use target node center as reference
  p2 = nodeV;     // Use source node center as reference
}
edge.points.unshift(util.intersectRect(nodeV, p1));
edge.points.push(util.intersectRect(nodeW, p2));
```

For short edges, the start point is computed as the intersection of the source node's rectangle with a line toward the target node's center, and vice versa. **Two short edges from the same source to different targets will have different attachment points** because their targets are at different positions (the `p1` parameter differs).

However, **two short edges from the same source to the same target** (multi-edges) get the **exact same attachment points** since both compute `intersectRect` toward the same target center. Dagre handles multi-edges via graphlib's multigraph support, but the positioning does not inherently spread them. They would overlap.

---

## Summary of Separation Parameters

| Parameter | Default | Controls |
|-----------|---------|----------|
| `nodesep` | 50 | Minimum horizontal pixels between real nodes in the same rank |
| `edgesep` | 20 | Minimum horizontal pixels between edge dummy nodes (or between a dummy and a real node) |
| `ranksep` | 50 | Vertical pixels between ranks (halved internally for label placement) |

From `bk.js:408-409`:
```javascript
sum += (vLabel.dummy ? edgeSep : nodeSep) / 2;
sum += (wLabel.dummy ? edgeSep : nodeSep) / 2;
```

The separation between two adjacent dummy nodes is exactly `edgesep`. Between a dummy and a real node it's `(edgesep + nodesep) / 2`.

---

## Key Takeaways for Implementation

1. **No explicit ports.** Dagre relies entirely on dummy node positioning to spread edges. The "port" effect emerges from the `intersectRect` computation using different first/last waypoints.

2. **One dummy chain per edge.** Each edge that spans >1 rank gets its own chain. Multiple edges from the same node produce multiple independent chains. Their dummy nodes compete for position within each rank during ordering.

3. **Ordering determines relative position.** The barycenter heuristic + tie-breaking gives dummy nodes from different edges distinct order values. Equal barycenters are broken by insertion index.

4. **`edgesep` enforces minimum spacing.** The block graph in horizontal compaction uses `edgesep` as the minimum x-distance between adjacent dummy nodes. This guarantees visible separation between edge waypoints.

5. **`intersectRect` creates the fan-out.** Because different edges' first waypoints have different x-coordinates, the line-rectangle intersection produces different departure points on the source node's border. The edges visually "fan out" from the node.

6. **Short edges (1 rank span) don't get waypoints.** They connect directly from source border to target border. Multiple short edges from the same source fan out only if their targets are at different positions. True multi-edges between the same pair of nodes will overlap.

7. **The Brandes-Kopf algorithm runs 4 times.** Up-left, up-right, down-left, down-right alignments are computed and the median x-coordinate is chosen for each node. This produces a balanced result but means edge positions are influenced by the full graph structure, not just local neighbors.
