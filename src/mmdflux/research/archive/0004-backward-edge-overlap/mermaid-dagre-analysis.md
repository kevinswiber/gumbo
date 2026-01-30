# Mermaid/Dagre Backward Edge Routing Analysis

## Key Finding: Edge Reversal During Cycle Removal

The fundamental difference is that **Dagre reverses backward edges in the graph representation**, not just the visual rendering.

### Dagre's Acyclic Phase (`acyclic.js`)

```javascript
function run(g) {
  // KEY: Dagre supports two algorithms, but defaults to DFS
  var fas = g.graph().acyclicer === 'greedy' ? greedyFAS(g, weightFn(g)) : dfsFAS(g);
  fas.forEach(e => {
    let label = g.edge(e);
    g.removeEdge(e);
    label.forwardName = e.name;
    label.reversed = true;
    g.setEdge(e.w, e.v, label, uniqueId('rev'));  // REVERSE: (v,w) becomes (w,v)
  });
}
```

**Important**: Dagre defaults to `dfsFAS(g)` (DFS-based Feedback Arc Set), NOT greedy FAS. The greedy algorithm is only used when `acyclicer` is explicitly set to `'greedy'`.
```

**For simple_cycle.mmd:**
- Original edges: Start→Process, Process→End, End→Start
- After acyclic phase: Start→Process, Process→End, **Start→End** (reversed!)
- The graph is now a DAG (directed acyclic graph)

### Layout on Acyclic Graph

With the edge reversed, the layout algorithm treats it as:
- Start→End (a normal forward edge going from rank 0 to rank 2)

This means:
1. **Different waypoints**: Goes through intermediate ranks normally
2. **Different attachment points**: Exits bottom of Start, enters top of End
3. **No overlap**: Different path than Process→End

### Point Reversal (`layout.js` line 56)

After layout completes, waypoints are cosmetically reversed:

```javascript
function reversePointsForReversedEdges(g) {
  g.edges().forEach(e => {
    let edge = g.edge(e);
    if (edge.reversed) {
      edge.points.reverse();  // Flip the array order
    }
  });
}
```

**Result**: Visually, the edge appears to go End→Start, but it was laid out as Start→End.

## DFS-Based Feedback Arc Set (What Mermaid Actually Uses)

Mermaid uses Dagre's default DFS-based cycle detection. From `acyclic.js`:

```javascript
function dfsFAS(g) {
  var fas = [];
  var stack = {};
  var visited = {};

  function dfs(v) {
    if (Object.prototype.hasOwnProperty.call(visited, v)) {
      return;
    }
    visited[v] = true;
    stack[v] = true;
    _.forEach(g.outEdges(v), function (e) {
      if (Object.prototype.hasOwnProperty.call(stack, e.w)) {
        fas.push(e);  // Back edge found - cycle detected
      } else {
        dfs(e.w);     // Continue DFS
      }
    });
    delete stack[v];
  }

  _.forEach(g.nodes(), dfs);
  return fas;
}
```

The algorithm:
1. Performs depth-first search from each unvisited node
2. Maintains a "stack" of nodes in the current DFS path
3. If an edge points to a node already in the stack, it's a back edge (cycle)
4. Back edges are collected and later reversed

**Key insight**: DFS naturally identifies back edges that create cycles. The order edges are discovered depends on node iteration order, not edge weights.

## Greedy Feedback Arc Set (NOT Used by Mermaid)

Dagre includes a greedy FAS algorithm in `greedy-fas.js`, but **Mermaid never enables it**. In Mermaid's Dagre configuration:

```javascript
// From packages/mermaid/src/rendering-util/layout-algorithms/dagre/index.js
const graph = new graphlib.Graph({ multigraph: true, compound: true })
  .setGraph({
    rankdir: data4Layout.direction,
    nodesep: ...,
    ranksep: ...,
    marginx: 8,
    marginy: 8,
  });  // Note: NO acyclicer option set
```

The state diagram renderer even has it commented out:

```javascript
// From packages/mermaid/src/diagrams/state/stateRenderer.js
graph.setGraph({
  rankdir: 'LR',
  // acyclicer: 'greedy',  // <-- COMMENTED OUT
  ranker: 'tight-tree',
  ...
});
```

The greedy algorithm would use edge weights to prefer reversing "less important" edges, but since Mermaid uses DFS, the cycle-breaking is determined by traversal order instead.

## Intersection Calculation

From Dagre's `util.js`:

```javascript
function intersectRect(rect, point) {
  let x = rect.x;
  let y = rect.y;
  let dx = point.x - x;
  let dy = point.y - y;
  let w = rect.width / 2;
  let h = rect.height / 2;

  let sx, sy;
  if (Math.abs(dy) * w > Math.abs(dx) * h) {
    // Intersection is top or bottom of rect
    if (dy < 0) { h = -h; }
    sx = h * dx / dy;
    sy = h;
  } else {
    // Intersection is left or right of rect
    if (dx < 0) { w = -w; }
    sx = w;
    sy = w * dy / dx;
  }
  return { x: x + sx, y: y + sy };
}
```

This calculates the **exact point** where an edge line intersects a node's boundary, based on the approach angle. Different edges get different intersection points even on the same side.

## Mermaid's Integration

From `rendering-util/rendering-elements/edges.js`:

```javascript
export const intersection = (node, outsidePoint, insidePoint) => {
  // Uses ray-casting to find where edge intersects node boundary
  // Each edge gets its own intersection point based on its angle of approach
};
```

From `layout-algorithms/dagre/index.js`:

```javascript
if (head.intersect && tail.intersect && !skipIntersect) {
  points = points.slice(1, edge.points.length - 1);
  points.unshift(tail.intersect(points[0]));
  points.push(head.intersect(points[points.length - 1]));
}
```

**Mermaid's pipeline:**
1. Dagre layouts the graph (with reversed edges)
2. Mermaid gets waypoints for each edge
3. For each edge, calculates intersection with source and target nodes
4. Uses SVG path to render with curves

## Why This Prevents Overlap

### Scenario: simple_cycle.mmd

**Dagre (after reversal):**
```
Graph edges: Start→Process, Process→End, Start→End (was End→Start)

Layout result:
- Start at rank 0
- Process at rank 1
- End at rank 2

Start→End waypoints: different x-coordinates than Process→End
because they're both forward edges with different source positions
```

**After reversePoints:**
```
End→Start waypoints (reversed): still different coordinates
Visual path goes from End, curves around, to Start
No overlap with Process→End because waypoints were calculated independently
```

## Comparison with mmdflux

| Aspect | mmdflux | Dagre/Mermaid |
|--------|---------|---------------|
| Cycle handling | Post-layout routing | Pre-layout reversal |
| Backward edge representation | Special routing function | Reversed in graph |
| Attachment points | Fixed center per side | Dynamic intersection |
| Coordinate system | Integer grid | Floating-point |
| Path style | Orthogonal only | Bezier curves |

## Implications for mmdflux

To match Mermaid's approach, mmdflux could:

### Option A: Full Edge Reversal
1. During layout, reverse backward edges in the diagram
2. Compute layout treating them as forward edges
3. After layout, reverse the waypoints cosmetically
4. Route using reversed waypoints

**Pros**: Mathematically identical to Dagre
**Cons**: Major refactor of layout phase

### Option B: Intersection-Based Attachment
1. Keep current routing structure
2. Calculate intersection points based on approach angle
3. Round to integer grid

**Pros**: Less invasive change
**Cons**: Integer rounding may still cause collisions

### Option C: Side Differentiation
1. Keep current routing structure
2. Use different exit side for backward edges
3. Avoids overlap without math changes

**Pros**: Simple, targeted fix
**Cons**: Doesn't handle all collision cases

## Conclusion

The key architectural difference is that Dagre reverses backward edges **before layout**, making them indistinguishable from forward edges during coordinate calculation. mmdflux routes backward edges **after layout**, which requires them to navigate around already-placed forward edges.

For a complete solution, consider implementing the edge reversal approach during the cycle removal phase of layout computation.
