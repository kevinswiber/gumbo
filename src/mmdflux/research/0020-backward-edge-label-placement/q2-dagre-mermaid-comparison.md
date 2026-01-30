# Q2: How do dagre and mermaid handle edge label positioning for backward edges?

## Summary

Dagre computes label positions from abstract layout-space coordinates of a label dummy node, with no backward-edge-specific handling. Mermaid compensates by recomputing label positions from the actual rendered SVG path using `calcLabelPosition()`, which traverses the path to find the geometric midpoint. This path-aware approach works universally for forward and backward edges because it depends on the concrete rendered path rather than dagre's theoretical position. mmdflux currently follows dagre's approach (direct coordinates via `transform_label_positions_direct()`), which fails for backward edges whose routed paths diverge from the layout-space position.

## Where

**Sources consulted:**
- `~/src/dagre/lib/normalize.js` — label dummy creation during normalization
- `~/src/dagre/lib/layout.js` — layout orchestration and label position extraction
- `~/src/dagre/lib/acyclic.js` — cycle removal, edge reversal marking
- `~/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/edges.js` — mermaid's edge label positioning
- `~/src/mermaid/packages/mermaid/src/utils.ts` — `calcLabelPosition()` utility

## What

### Dagre's Label Dummy Lifecycle

1. **Creation (normalize.js)**: During normalization, a special dummy node is created for each labeled edge at a specific rank (`labelRank`), marked with `dummy: "edge-label"`. The dummy has the label's width/height dimensions.

2. **Layout**: The dummy is treated like a real node and laid out by the Sugiyama algorithm — it participates in crossing reduction and coordinate assignment just like any other node.

3. **Denormalization**: After layout, the dummy's `(x, y)` coordinates are extracted and used as the label position. These coordinates come from the abstract layout graph.

4. **Backward edge handling**: Edges are reversed in the acyclic phase and marked `reversed: true`, but label positions are NOT recomputed for backward edges — they use the theoretical coordinates from the layout graph. Dagre has no backward-edge-specific label logic.

**Critical insight**: Dagre's label coordinates are computed in **abstract layout space**, not accounting for how edges are actually routed after rendering.

### Mermaid's Path-Aware Recomputation

1. **`calcLabelPosition()`** traverses the actual rendered SVG path to compute the total length
2. **`calculatePoint()`** finds the point at 50% of the path length (geometric midpoint)
3. **`positionEdgeLabel()`** uses this recalculated position instead of dagre's coordinates when a rendered path exists
4. **Universal approach**: Works identically for forward and backward edges because it depends on the actual path, not dagre's theoretical position

Code pattern:
```javascript
if (path) {
  const pos = utils.calcLabelPosition(path);  // Recalculate from ACTUAL path
  x = pos.x;
  y = pos.y;
}
```

### Comparison Table

| Aspect | Dagre | Mermaid | mmdflux (current) |
|--------|-------|---------|-------------------|
| Label source | Dummy node coords (abstract) | Rendered path (concrete) | Dummy node coords (abstract) |
| Backward edge aware | No | Implicitly yes (any path) | No |
| Recomputation | Never | Always (when path exists) | Never |
| Robustness | Theory-dependent | Practice-dependent | Theory-dependent |

## How

### Dagre's Process (No Recomputation)

```
normalize() → create label dummy at labelRank
  ↓
layout phases (rank, order, position) → assign x,y to dummy
  ↓
denormalize() → extract dummy's x,y as label position
  ↓
Return label position = dummy's layout-space coordinate
```

The label dummy participates in the full Sugiyama pipeline. Its coordinates reflect where the algorithm placed it to minimize crossings and respect constraints. For forward edges, this position is usually reasonable because the edge path passes through (or near) the dummy's position. For backward edges, the edge may route via a completely different path after reversal.

### Mermaid's Process (Path-Aware)

```
dagre.layout(graph) → get initial label x,y from dummy
  ↓
render edge as SVG path (potentially different from dagre's abstract route)
  ↓
calcLabelPosition(path) → walk rendered path, find 50% length point
  ↓
positionEdgeLabel() → place label at path midpoint
```

Mermaid essentially ignores dagre's label coordinates for positioning (when a path exists) and recomputes from the rendered geometry. This is why mermaid's backward edge labels always appear near their edges — the position is derived from the actual visual path, not from the layout graph.

## Why

### Why Dagre Doesn't Handle This

Dagre is a layout engine, not a rendering engine. It computes abstract coordinates and assumes the rendering layer will use them directly. The concept of "synthetic backward routing" (routing backward edges around the perimeter) doesn't exist in dagre's model — it expects the rendering to follow the layout graph's structure.

### Why Mermaid Recomputes

Mermaid recognized that the actual rendered edge path can differ significantly from dagre's abstract layout, especially for:
- Backward edges (routed differently by the SVG renderer)
- Edges with curvature (Bézier curves vs. straight layout)
- Edges that are rerouted to avoid overlaps

By recomputing from the rendered path, mermaid achieves robustness regardless of how the edge was routed.

### Why mmdflux Has This Problem

mmdflux follows dagre's approach (abstract coordinates) but has its own backward edge routing (`generate_backward_waypoints()`) that creates synthetic paths at different cross-axis positions. The label position is still computed from dagre's dummy node, which doesn't know about the synthetic routing. This creates the cross-axis mismatch described in issues 0004-01 through 0004-03.

## Key Takeaways

- **Dagre provides no backward-edge-specific label handling** — it treats all edges uniformly in layout space
- **Mermaid's `calcLabelPosition()` is the key innovation** — recomputing from the rendered path makes it robust to any routing strategy
- **mmdflux currently mirrors dagre's approach**, which is only correct when the routed edge path matches the layout-space position (true for forward edges, false for backward edges with synthetic routing)
- **The fix doesn't require porting mermaid's exact algorithm** — mmdflux already has segment-based label placement heuristics that achieve the same goal (placing labels near the actual routed edge) and can be used for backward edges

## Open Questions

- Does mermaid's `calcLabelPosition()` handle all edge types (self-loops, multi-edges) or just standard edges?
- Does dagre-d3 (the dagre rendering layer) do any label recomputation, or is this purely a mermaid innovation?
- For mmdflux's ASCII grid, is geometric midpoint the right heuristic, or would the existing segment-based approach (pick the longest inner segment) produce better visual results?
