# 04: Dagre Edge Points Output Format

## Edge Data After Layout

After `dagre.layout(g)` completes, each edge in the graph has:

```javascript
{
  points: [{x, y}, ...],  // Waypoints from source to target
  x: number,              // Label X position (optional)
  y: number,              // Label Y position (optional)
  width: number,          // Label width (if labeled)
  height: number,         // Label height (if labeled)
  reversed: boolean,      // True if edge was reversed for cycle breaking
  weight: number,         // Edge weight
  minlen: number,         // Minimum rank span
}
```

## How edge.points Are Computed

### Step 1: Normalization Creates Dummy Chains

**`normalize.js:31-67`**: Long edges broken into unit-length segments with dummy nodes:

```javascript
function normalizeEdge(g, e) {
  // ...
  for (i = 0, ++vRank; vRank < wRank; ++i, ++vRank) {
    edgeLabel.points = [];  // Initialize empty
    attrs = { width: 0, height: 0, edgeLabel: edgeLabel, edgeObj: e, rank: vRank };
    dummy = util.addDummyNode(g, "edge", attrs, "_d");
    g.setEdge(v, dummy, { weight: edgeLabel.weight }, name);
    if (i === 0) g.graph().dummyChains.push(dummy);  // Track chain head
    v = dummy;
  }
  g.setEdge(v, w, { weight: edgeLabel.weight }, name);
}
```

Key: All dummy nodes in a chain reference the **same `edgeLabel` object** via the first dummy's `edgeLabel` property. `edgeLabel.points` is shared.

### Step 2: Position Assignment

**`position/index.js`**: Assigns x,y coordinates to all nodes:

- **Y-coordinates**: By rank — `y = prevY + maxHeight/2` (center alignment by default)
- **X-coordinates**: Brandes-Kopf algorithm (`position/bk.js`) — horizontal compaction with 4-pass median alignment

Dummy nodes (width=0, height=0) get positioned at the exact center of their rank layer.

### Step 3: Denormalization Extracts Points

**`normalize.js:69-89`**: Walks dummy chains, collecting positions:

```javascript
function undo(g) {
  g.graph().dummyChains.forEach(v => {
    let node = g.node(v);
    let origLabel = node.edgeLabel;
    g.setEdge(node.edgeObj, origLabel);
    while (node.dummy) {
      w = g.successors(v)[0];
      g.removeNode(v);
      origLabel.points.push({ x: node.x, y: node.y });  // Collect position
      if (node.dummy === "edge-label") {
        origLabel.x = node.x;  // Label position
        origLabel.y = node.y;
      }
      v = w;
      node = g.node(v);
    }
  });
}
```

Points are pushed in chain order (source-side dummy to target-side dummy).

### Step 4: Node Boundary Intersections

**`layout.js:266-283`**: Adds start/end points at node boundaries:

```javascript
function assignNodeIntersects(g) {
  g.edges().forEach(e => {
    let edge = g.edge(e);
    let nodeV = g.node(e.v), nodeW = g.node(e.w);
    if (!edge.points) {
      edge.points = [];
      p1 = nodeW; p2 = nodeV;  // Unit-length: direct connection
    } else {
      p1 = edge.points[0];
      p2 = edge.points[edge.points.length - 1];
    }
    edge.points.unshift(util.intersectRect(nodeV, p1));  // Start intersection
    edge.points.push(util.intersectRect(nodeW, p2));     // End intersection
  });
}
```

`intersectRect` (`util.js:101-134`) computes where a line from rectangle center to a point crosses the rectangle boundary.

### Step 5: Reverse Points for Backward Edges

**`layout.js:300-306`**:

```javascript
function reversePointsForReversedEdges(g) {
  g.edges().forEach(e => {
    let edge = g.edge(e);
    if (edge.reversed) {
      edge.points.reverse();
    }
  });
}
```

## Execution Order (Critical)

From `layout.js` `runLayout()`:
```
normalize.run()           → Insert dummy nodes
order()                   → Crossing minimization
position()                → Assign x,y coordinates
normalize.undo()          → Extract points from dummies
coordinateSystem.adjust() → Transform for rankdir
translateGraph()          → Normalize to (0,0) origin
assignNodeIntersects()    → Add boundary start/end points
reversePointsForReversedEdges() → Flip backward edge points
acyclic.undo()            → Restore original edge directions
```

## Final Points Structure

**Unit-length edge** (adjacent ranks, no dummies):
```
[source_boundary_point, target_boundary_point]
```

**Long forward edge** (multiple ranks, with dummies):
```
[source_boundary, dummy1_pos, dummy2_pos, ..., target_boundary]
```

**Backward/reversed edge** (after reversal):
```
[target_boundary, ..., dummyN_pos, ..., dummy1_pos, source_boundary]
// Points reversed: now flows in original (pre-reversal) direction
```

## Coordinate Transformations by Direction

**`coordinate-system.js`**:
- TB: No transform (native coordinate system)
- BT: `reverseY(g)` — flips Y coordinates
- LR: `swapXY(g)` + `swapWidthHeight(g)` — transposes axes
- RL: `reverseY(g)` + `swapXY(g)` + `swapWidthHeight(g)`

All transformations apply to `edge.points` entries.

## Key Insight for mmdflux

Dagre's edge points are fundamentally **dummy node center positions** plus **node boundary intersections**. The points form a piecewise-linear path through the layout. For backward edges, the points are simply reversed in order — the spatial positions are identical to what forward-direction dummies would produce, just traversed in the opposite direction.

This means mmdflux's existing `edge_waypoints` data already contains the correct intermediate positions for backward edges. The missing piece is using those waypoints to generate ASCII routing segments instead of routing through corridors.
