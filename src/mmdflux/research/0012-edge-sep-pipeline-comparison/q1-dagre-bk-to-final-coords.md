# Q1: How does dagre.js translate BK output to final coordinates?

## Summary

dagre.js preserves `edgesep` through the entire pipeline without neutralization. The `sep()` function embeds the dummy/real node distinction into block graph edge weights during `horizontalCompaction()`, these weights are directly added/subtracted during coordinate assignment, and all subsequent transformations (alignment, coordinate system undo, graph translation) are uniform operations that preserve relative spacing.

## Where

- `/Users/kevin/src/dagre/lib/position/bk.js` — `sep()`, `buildBlockGraph()`, `horizontalCompaction()`, `positionX()`
- `/Users/kevin/src/dagre/lib/position/index.js` — `position()`, `positionY()`
- `/Users/kevin/src/dagre/lib/coordinate-system.js` — `undo()`, `swapXY()`, `reverseY()`
- `/Users/kevin/src/dagre/lib/layout.js` — `translateGraph()`, `updateInputGraph()`, `runLayout()`

## What

### 1. sep() Function: Where edgesep Enters (bk.js, lines 389-425)

```javascript
function sep(nodeSep, edgeSep, reverseSep) {
  return (g, v, w) => {
    let vLabel = g.node(v);
    let wLabel = g.node(w);
    let sum = 0;

    sum += vLabel.width / 2;
    // ... label positioning adjustments ...

    // LINE 408-409: THE KEY DECISION POINT
    sum += (vLabel.dummy ? edgeSep : nodeSep) / 2;
    sum += (wLabel.dummy ? edgeSep : nodeSep) / 2;

    sum += wLabel.width / 2;
    // ... more label adjustments ...
    return sum;
  };
}
```

**Critical distinction:**
- If a node has `dummy: true` (edge dummy), use `edgeSep / 2`
- If a node is real, use `nodeSep / 2`
- This distinction is **not** lost — it's fundamental to the separation calculation

### 2. buildBlockGraph(): Where edgesep Propagates (bk.js, lines 267-287)

```javascript
function buildBlockGraph(g, layering, root, reverseSep) {
  let blockGraph = new Graph(),
    graphLabel = g.graph(),
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

- The closure captures `graphLabel.edgesep` and `graphLabel.nodesep`
- For each adjacent pair of nodes in a layer, `sepFn()` calculates separation
- If either node is dummy, it uses `edgesep`; otherwise `nodesep`
- This separation becomes an edge weight in the block graph

### 3. horizontalCompaction(): Where Separation Weights Are Applied (bk.js, lines 206-264)

```javascript
function pass1(elem) {
  xs[elem] = blockG.inEdges(elem).reduce((acc, e) => {
    return Math.max(acc, xs[e.v] + blockG.edge(e));  // ADD the edge weight
  }, 0);
}

function pass2(elem) {
  let min = blockG.outEdges(elem).reduce((acc, e) => {
    return Math.min(acc, xs[e.w] - blockG.edge(e));  // SUBTRACT the edge weight
  }, Number.POSITIVE_INFINITY);
  // ...
  xs[elem] = Math.max(xs[elem], min);
}
```

- Pass 1: minimum x-coordinate = max(predecessor_x + edge_weight)
- Pass 2: adjust to greatest valid x-coordinate by checking constraints
- Edge weights (containing edgesep values) are **directly added/subtracted**, not interpolated
- All aligned nodes get their root's x-coordinate: `xs[v] = xs[root[v]]`

### 4. positionX(): Combines Four Alignments (bk.js, lines 355-387)

- Computes 4 alignment variants: UL, UR, DL, DR
- Each uses same `sep()` function, preserving edgesep/nodesep distinction
- `alignCoordinates()` adds uniform deltas to shift solutions (preserves relative spacing)
- `balance()` takes median of 4 coordinates per node (preserves spacing info)

### 5. position(): Assigns X and Y Coordinates (position/index.js, lines 8-13)

```javascript
function position(g) {
  g = util.asNonCompoundGraph(g);
  positionY(g);
  Object.entries(positionX(g)).forEach(([v, x]) => g.node(v).x = x);
}
```

- `positionX(g)` returns `{ nodeId: xCoordinate, ... }`
- Each coordinate is directly assigned to `g.node(v).x`
- **No scaling, rounding, or snapping** — exact floating-point values

### 6. coordinateSystem.undo(): Swaps and Reverses (coordinate-system.js, lines 15-25)

```javascript
function undo(g) {
  let rankDir = g.graph().rankdir.toLowerCase();
  if (rankDir === "bt" || rankDir === "rl") {
    reverseY(g);     // Flip y-coordinates
  }
  if (rankDir === "lr" || rankDir === "rl") {
    swapXY(g);        // For horizontal layouts: swap x ↔ y
    swapWidthHeight(g);
  }
}
```

- **Geometric transformation only** — ratios and separations preserved
- edgesep values are rotated with the diagram, not lost

### 7. translateGraph(): Shifts to Origin (layout.js, lines 215-264)

```javascript
g.nodes().forEach(v => {
  let node = g.node(v);
  node.x -= minX;
  node.y -= minY;
});
```

- **Uniform translation**: subtract same `minX` from all nodes
- All relative distances preserved — edgesep spacing unchanged
- No rescaling, snapping, or loss of precision

## How

**The Complete Transformation Chain:**

```
edgesep value (e.g., 20)
         ↓
sep() function captures edgesep/nodesep
         ↓
buildBlockGraph() creates block graph with edges weighted by sep() results
         ↓
horizontalCompaction() adds/subtracts edge weights to compute x-coordinates
         ↓
positionX() combines 4 alignments, all using sep()
         ↓
balance() takes median, preserving all separation constraints
         ↓
position() assigns xs[v] directly to node.x
         ↓
coordinateSystem.undo() applies geometric transformations (swapXY, reverseY)
         ↓
translateGraph() applies uniform translation (preserves relative distances)
         ↓
updateInputGraph() copies final x/y to output
         ↓
Final node.x / node.y: Contains edgesep spacing, unmultiplied, unscaled
```

**Worked example from BK tests:**
```
g.graph().edgesep = 20;
g.setNode("a", { width: 100, dummy: true });
g.setNode("b", { width: 200, dummy: true });

xs = horizontalCompaction(...);
// xs.a = 0
// xs.b = 100/2 + 20 + 200/2 = 50 + 20 + 100 = 170
// The 20 is edgesep, directly in the result
```

## Why

- **Tighter spacing for dummy nodes** (edgesep=20) vs real nodes (nodesep=50) allows edge segments to nestle closer together
- This is computed during block construction and never "undone"
- The design maintains separation guarantees as algebraic constraints throughout the pipeline
- No step applies proportional scaling or grid snapping that could neutralize these constraints

## Key Takeaways

- **edgesep IS preserved throughout the dagre.js pipeline.** The dummy/real node distinction in `sep()` (lines 408-409) flows through block graph edge weights → compaction → 4 alignments → median → final coordinates without any lossy transformation.

- **No neutralization step exists in dagre.js.** No proportional scaling, no grid snapping, no interpolation that averages out separations, no constant time step applied uniformly.

- **All post-BK transformations are uniform.** `alignCoordinates()` adds deltas uniformly, `coordinateSystem.undo()` applies geometric transformations, `translateGraph()` applies uniform translation — all preserve relative distances.

- **dagre.js defaults** are `nodesep: 50, edgesep: 20, ranksep: 50` (layout.js line 100), meaning dummy nodes are 2.5x closer together by default.

## Open Questions

- How does mmdflux's Rust BK implementation differ in handling edgesep through its BK variant?
- What edge cases might cause edgesep to be effectively neutralized (e.g., border nodes with special handling)?
- Does the final edge routing in the render phase respect these separations, or could they be violated by subsequent path computations?
