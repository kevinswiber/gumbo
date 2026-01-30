# Q2: What does the borderType guard in Pass 2 actually do?

## Summary

The `borderType` guard in Pass 2 of dagre.js's `horizontalCompaction` is exclusively for compound graphs (graphs with subgraphs). It prevents border nodes marking the left/right edges of subgraph clusters from being pulled past their intended boundaries. Simple flowcharts without subgraphs never have `borderType` set on any node, so Pass 2 is a complete no-op for all graphs mmdflux handles.

## Where

- `/Users/kevin/src/dagre/lib/position/bk.js` — Lines 214, 252 (Pass 2 guard condition)
- `/Users/kevin/src/dagre/lib/add-border-segments.js` — Lines 5-37 (where borderType is set)
- `/Users/kevin/src/dagre/lib/layout.js` — Lines 19-54 (layout pipeline, compound graph initialization)
- `/Users/kevin/src/dagre/lib/util.js` — `asNonCompoundGraph()` function

## What

### What is borderType?

`borderType` is a string property with exactly two possible values: `"borderLeft"` or `"borderRight"`. It is set **only** by `addBorderSegments()` in `add-border-segments.js`, which labels whether a border node marks the left or right edge of a subgraph cluster.

### When is borderType set?

`addBorderSegments()` only processes nodes with `minRank` and `maxRank` properties (line 13: `if (Object.hasOwn(node, "minRank"))`). These properties are assigned only to subgraph nodes by `assignRankMinMax()` (layout.js lines 192-203). For each rank in a subgraph's range, two border nodes are created:

```javascript
addBorderNode(g, "borderLeft", "_bl", v, node, rank);   // borderType: "borderLeft"
addBorderNode(g, "borderRight", "_br", v, node, rank);  // borderType: "borderRight"
```

### Can simple flowcharts have borderType?

**No.** Simple flowcharts have only regular nodes — no subgraphs. Regular nodes never get `minRank`/`maxRank` attributes, so `addBorderSegments()` creates zero border nodes, and no node ever receives a `borderType` property.

### The Pass 2 guard in context

```javascript
// Line 214: Set borderType based on alignment direction
borderType = reverseSep ? "borderLeft" : "borderRight";

// Lines 251-254: Pass 2 guard
let min = blockG.outEdges(elem).reduce((acc, e) => {
  return Math.min(acc, xs[e.w] - blockG.edge(e));
}, Number.POSITIVE_INFINITY);

let node = g.node(elem);
if (min !== Number.POSITIVE_INFINITY && node.borderType !== borderType) {
  xs[elem] = Math.max(xs[elem], min);
}
```

For simple graphs: `node.borderType` is `undefined`, so the condition `undefined !== "borderRight"` is always `true`. Pull-right proceeds normally for all nodes — but since Pass 1 already placed blocks optimally for DAGs, Pull-right has no effect anyway.

## How

1. **Compound graph initialization:** Layout creates a compound graph with subgraph hierarchy
2. **Subgraph processing:** Subgraph nodes get `minRank`/`maxRank` assigned
3. **Border node creation:** `addBorderSegments()` creates left/right border nodes per subgraph rank
4. **Position calculation:** `position()` converts to non-compound graph (keeping border nodes as regular nodes with their `borderType` properties)
5. **Pass 2 execution:** Guard prevents border nodes from being pulled past their intended side during right-pull
6. **Border removal:** After positioning, border nodes are removed (`removeBorderNodes`, layout.js line 50)

## Why

The guard prevents border nodes from crossing their intended boundaries during Pull-right. For compound graphs, borderLeft nodes should stay on the left side of their cluster, and borderRight nodes on the right. The guard ensures alignment-direction-specific constraints are maintained.

For simple graphs, this is entirely irrelevant — no border nodes exist, so the guard condition is vacuously satisfied and Pull-right runs normally (but produces no changes for DAGs since Pass 1 already computed the optimal placement).

## Key Takeaways

- `borderType` is 100% compound-graph-only — set only by `addBorderSegments()` for subgraph nodes
- Simple flowcharts never have borderType nodes — Pass 2's guard is irrelevant for all mmdflux inputs
- Pass 2 is a complete no-op for simple graphs — confirmed both by the guard analysis and by Plan 0022's proof that Pass 1 produces optimal placement for DAGs
- mmdflux does not need to implement this guard since it doesn't support compound graphs

## Open Questions

- If mmdflux ever adds compound graph (subgraph) support, it would need to implement border nodes and this guard
- Pass 2 could potentially matter for graphs with cycles (after cycle removal, the block graph might not be a pure DAG) — but this seems unlikely given that cycle removal happens much earlier in the pipeline
