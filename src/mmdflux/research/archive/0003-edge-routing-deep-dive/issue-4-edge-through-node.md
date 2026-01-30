# Issue 4: Edge Routing Through/Alongside Node

**Problem:** The "no" edge from "More Data?" to "Output" visually passes through or alongside the "Cleanup" node, creating visual confusion: `└───────no───│ Cleanup │`

## Current Output

```
        │            ┌─────────┐
        └───────no───│ Cleanup │
                     └─────────┘
                          │
                          │
                          ▼
                     ┌────────┐
                     │ Output │
                     └────────┘
```

The edge from "More Data?" (left side) goes horizontally right through the row where "Cleanup" sits, drawing the label "no" alongside the Cleanup node border.

---

## Mermaid.js Approach

### How Mermaid.js Handles This

Mermaid.js delegates layout and edge routing to **dagre** for the flowchart diagram type. The key insight is that Mermaid does NOT do its own edge path finding - it relies entirely on dagre's output.

Looking at `$HOME/src/mermaid/packages/mermaid/src/diagrams/flowchart/flowRenderer-v3-unified.ts`:

```typescript
// The getData method provided in all supported diagrams is used to extract the data
// into the Layout data format
const data4Layout = diag.db.getData() as LayoutData;

data4Layout.layoutAlgorithm = getRegisteredLayoutAlgorithm(layout);
// ...
await render(data4Layout, svg);
```

The actual edge routing is handled by dagre, and Mermaid simply draws SVG paths along the points dagre provides.

### Why It Works in Mermaid/Dagre

In SVG rendering, dagre computes edge paths that:

1. **Use floating-point coordinates** - Not constrained to a grid
2. **Apply cubic bezier curves** - Can curve around obstacles smoothly
3. **Place intermediate control points** - `edge.points` contains waypoints for the spline

The critical function is in `lib/layout.js`:

```javascript
function assignNodeIntersects(g) {
  g.edges().forEach(e => {
    let edge = g.edge(e);
    let p1 = edge.points[0];
    let p2 = edge.points[edge.points.length - 1];
    edge.points.unshift(util.intersectRect(nodeV, p1));
    edge.points.push(util.intersectRect(nodeW, p2));
  });
}
```

Dagre calculates intersection points where edges meet node boundaries, then the renderer draws splines through all the intermediate points.

### Key Files in Dagre

- `lib/normalize.js` - Splits long edges spanning multiple ranks into segments with **dummy nodes**
- `lib/position/bk.js` - Brandes-Kopf algorithm for coordinate assignment
- `lib/util.js` - `intersectRect()` computes where edge intersects node boundary

### Dummy Node Strategy

The critical mechanism for edge routing in dagre is **dummy nodes**. From `lib/normalize.js`:

```javascript
/*
 * Breaks any long edges in the graph into short segments that span 1 layer
 * each. This operation is undoable with the denormalize function.
 *
 * Post-condition:
 *    1. All edges in the graph have a length of 1.
 *    2. Dummy nodes are added where edges have been split into segments.
 */
function normalizeEdge(g, e) {
  let v = e.v;
  let vRank = g.node(v).rank;
  let w = e.w;
  let wRank = g.node(w).rank;

  if (wRank === vRank + 1) return; // Edge spans only 1 rank, no splitting needed

  g.removeEdge(e);

  // Add dummy nodes for each intermediate rank
  for (i = 0, ++vRank; vRank < wRank; ++i, ++vRank) {
    attrs = { width: 0, height: 0, edgeLabel: edgeLabel, rank: vRank };
    dummy = util.addDummyNode(g, "edge", attrs, "_d");
    g.setEdge(v, dummy, { weight: edgeLabel.weight }, name);
    v = dummy;
  }
  g.setEdge(v, w, { weight: edgeLabel.weight }, name);
}
```

These dummy nodes:
1. Participate in the **ordering phase** (crossing reduction)
2. Get **positioned** like real nodes (but with zero width/height)
3. The edge path goes through their positions
4. After layout, the dummy nodes are removed and their positions become the `edge.points` array

This means an edge from "More Data?" to "Output" that skips "Cleanup" would have dummy nodes placed in intermediate ranks, and those dummies would be ordered to avoid crossing "Cleanup" during the crossing reduction phase.

---

## Dagre Approach

### Edge Routing Philosophy

Dagre does NOT have explicit "node avoidance" in its edge routing. Instead, it achieves clean routing through:

1. **Layered assignment (ranking)** - Nodes are assigned to discrete layers/ranks
2. **Dummy nodes for long edges** - Edges spanning multiple layers get dummy nodes inserted
3. **Crossing reduction** - The barycenter/median heuristic orders nodes within layers to minimize edge crossings
4. **Coordinate assignment** - Brandes-Kopf algorithm positions nodes, respecting the computed order

The key insight: **Node avoidance is implicit in the ordering algorithm, not explicit in path finding.**

### Crossing Reduction (`lib/order/index.js`)

```javascript
/*
 * Applies heuristics to minimize edge crossings in the graph and sets the best
 * order solution as an order attribute on each node.
 */
function order(g, opts = {}) {
  // Build layer graphs for up/down sweeps
  let downLayerGraphs = buildLayerGraphs(g, util.range(1, maxRank + 1), "inEdges");
  let upLayerGraphs = buildLayerGraphs(g, util.range(maxRank - 1, -1, -1), "outEdges");

  let layering = initOrder(g);
  assignOrder(g, layering);

  // Iteratively sweep and improve ordering
  for (let i = 0, lastBest = 0; lastBest < 4; ++i, ++lastBest) {
    sweepLayerGraphs(i % 2 ? downLayerGraphs : upLayerGraphs, i % 4 >= 2);
    // ...
    let cc = crossCount(g, layering);
    if (cc < bestCC) {
      best = layering;
      bestCC = cc;
    }
  }
}
```

The `crossCount()` function measures how many edges would visually cross given an ordering. By minimizing this, dummy nodes (representing long edge segments) get positioned away from other nodes they'd cross.

### Position Assignment (`lib/position/bk.js`)

The Brandes-Kopf algorithm assigns X coordinates while:
1. Keeping nodes aligned with their median predecessors/successors
2. Respecting minimum separation (`nodesep`, `edgesep`)
3. Avoiding conflicts where alignments would cause crossings

This ensures that even though edge routing is just "connect the dots through dummy nodes," the dots are positioned to create clean paths.

---

## mmdflux Current Implementation

### Layout (`src/render/layout.rs`)

mmdflux has two layout algorithms:

1. **Built-in topological sort** (`compute_layout()`)
2. **Dagre-based** (`compute_layout_dagre()`)

The built-in algorithm does NOT create dummy nodes for long edges. It simply:
1. Assigns nodes to layers via topological sort
2. Places nodes within layers based on order in the layer list
3. Calculates pixel coordinates

### Router (`src/render/router.rs`)

The `route_edge()` function handles edge path computation:

```rust
pub fn route_edge(
    edge: &Edge,
    layout: &Layout,
    diagram_direction: Direction,
) -> Option<RoutedEdge> {
    let from_bounds = layout.get_bounds(&edge.from)?;
    let to_bounds = layout.get_bounds(&edge.to)?;

    // Check if this is a backward edge
    if is_backward_edge(from_bounds, to_bounds, diagram_direction) {
        return route_backward_edge(edge, from_bounds, to_bounds, layout, diagram_direction);
    }

    let (out_dir, in_dir) = attachment_directions(diagram_direction);
    let start = attachment_point(from_bounds, out_dir);
    let end = attachment_point(to_bounds, in_dir);

    // Route based on the relative positions
    let segments = compute_path(start, end, diagram_direction);
    // ...
}
```

For **forward edges**, `compute_path()` simply draws:
- Vertical segment from start toward midpoint
- Horizontal segment at midpoint
- Vertical segment to end

```rust
fn compute_vertical_first_path(start: Point, end: Point) -> Vec<Segment> {
    let mid_y = if start.y < end.y {
        start.y + (end.y - start.y) / 2
    } else {
        end.y + (start.y - end.y) / 2
    };

    // Vertical segment from start to midpoint
    segments.push(Segment::Vertical { x: start.x, y_start: start.y, y_end: mid_y });
    // Horizontal segment at midpoint
    segments.push(Segment::Horizontal { y: mid_y, x_start: start.x, x_end: end.x });
    // Vertical segment from midpoint to end
    segments.push(Segment::Vertical { x: end.x, y_start: mid_y, y_end: end.y });
}
```

**There is NO node avoidance logic.** The path is computed purely geometrically without considering what nodes exist in between.

---

## Root Cause Analysis

### Is This a Layout Issue or a Routing Issue?

**It's BOTH, but primarily a LAYOUT issue.**

#### Layout Problem

In the complex.mmd diagram:
- "More Data?" is positioned on the **left side** of the diagram
- "Cleanup" is positioned in the **center**
- "Output" is positioned in the **center** (below Cleanup)

When we draw an edge from "More Data?" (left) to "Output" (center-bottom), any horizontal path at an intermediate Y level will pass through the space where "Cleanup" resides.

The layout doesn't account for the edge from E->F needing vertical clearance around I (Cleanup).

#### Routing Problem

Even with the current layout, the router could potentially:
1. Detect that the horizontal segment would pass through a node
2. Route around it (up or down, then horizontal, then down or up)

But no such logic exists. The `compute_path()` function is purely geometric.

### Comparison with Dagre

In dagre's approach, the edge E->F would have a **dummy node** in the same rank as I (Cleanup). The crossing reduction algorithm would position that dummy node to the **left or right** of Cleanup, not overlapping it. The edge would naturally route through that dummy's position, avoiding Cleanup.

---

## ASCII Constraints for Node Avoidance

### The Challenge

ASCII rendering has fundamental constraints:
1. **Integer grid** - Can only place elements at discrete character positions
2. **Limited resolution** - Each cell is one character wide
3. **No curves** - Only orthogonal (Manhattan) routing
4. **Character overlap** - Two elements cannot share a cell

### What Other ASCII Tools Do

**AsciiFlow** (analyzed in `$HOME/src/mmdflux/research/archive/0000-initial-research/asciiflow-analysis.md`):
- Manual drawing tool, no automatic routing
- Users draw around obstacles manually

**Mermaid-ASCII** (from research):
- Simplified layouts, typically doesn't handle complex edge-skipping scenarios
- Often produces suboptimal output for complex graphs

### Viable ASCII Strategies

1. **Corridor-based routing (for backward edges)** - Already implemented for cycles
   - Reserve space on diagram perimeter for edge corridors
   - Route edges through corridors to avoid nodes
   - Works well but increases diagram size

2. **Vertical offset routing** - Route edges above or below obstacle nodes
   - Requires knowing where obstacles are
   - May need to insert extra vertical space in layout

3. **Dummy node emulation** - Add placeholder positions in layout for long edge segments
   - Mimics dagre's approach
   - Requires more sophisticated layout algorithm

4. **Post-hoc avoidance** - Compute path, detect collisions, reroute
   - Check if horizontal/vertical segments intersect node bounds
   - If so, route around (add bends)
   - Simpler to implement but may produce suboptimal paths

---

## Recommended Solutions

### Option 1: Layout-Based (Best Long-Term Solution)

**Approach:** Implement dummy nodes for long edges in layout computation.

When computing layout:
1. Identify edges that span more than one layer
2. Create virtual "edge segment" placeholders in intermediate layers
3. Include these in layer ordering (crossing reduction)
4. Position actual nodes considering edge segment positions
5. Route edges through the computed segment positions

**Pros:**
- Matches dagre's proven approach
- Produces optimal-quality layouts
- Handles complex graphs well

**Cons:**
- Significant implementation effort
- Requires reworking layout algorithm
- May already be partially available with `compute_layout_dagre()`

### Option 2: Routing-Based (Practical Near-Term Fix)

**Approach:** Add node avoidance to the routing algorithm.

In `route_edge()`:
1. Compute the basic geometric path (current behavior)
2. Check each segment for intersection with any node bounds
3. If a segment intersects a node, reroute:
   - For horizontal segments through nodes: route above or below the node
   - For vertical segments through nodes: route left or right of the node
4. Add extra segments to navigate around obstacles

```rust
fn compute_path_with_avoidance(
    start: Point,
    end: Point,
    layout: &Layout,
    direction: Direction
) -> Vec<Segment> {
    let basic_path = compute_path(start, end, direction);

    // Check each segment for node collisions
    for segment in &basic_path {
        for (_, bounds) in &layout.node_bounds {
            if segment_intersects_bounds(segment, bounds) {
                // Reroute around this node
                return compute_avoidance_path(start, end, bounds, layout, direction);
            }
        }
    }

    basic_path
}
```

**Pros:**
- Fixes the immediate visual problem
- Relatively simple to implement
- Works with existing layout

**Cons:**
- May produce suboptimal paths (more bends than necessary)
- Doesn't address root cause (layout quality)
- Could get complex with multiple obstacles

### Option 3: Hybrid Approach (Recommended)

**Approach:** Use the dagre layout algorithm (already partially implemented) and enhance routing.

1. **Use `compute_layout_dagre()`** - Already integrates with dagre for crossing reduction
2. **Verify dummy node handling** - Ensure reversed_edges are properly processed
3. **Add basic collision detection** - As a safety net for edge cases
4. **Reserve corridor space** - For edges that need to go around nodes

This leverages existing work while providing a fallback safety mechanism.

---

## Tradeoffs Summary

| Solution | Implementation Effort | Quality | Diagram Size Impact |
|----------|----------------------|---------|---------------------|
| Full dummy nodes | High | Excellent | Minimal |
| Routing avoidance | Medium | Good | Moderate (extra bends) |
| Hybrid (dagre + routing) | Low-Medium | Good | Moderate |
| Do nothing | None | Poor | None |

---

## Specific Fix for complex.mmd

For the immediate issue with "More Data?" -> "Output" crossing "Cleanup":

The edge E->F ("no") should NOT be routed with a horizontal segment at the same Y-level as node I (Cleanup).

**Quick Fix Options:**

1. **Route below Cleanup:** The horizontal segment should be at or below the bottom of Cleanup
2. **Use corridor routing:** Treat this like a backward edge and route around the perimeter
3. **Vertical-only routing:** If source and target have similar X coordinates, go straight vertical

Looking at the diagram structure:
```
E{More Data?} -- layer 4 (same as G, H, I)
F[Output]     -- layer 6
I[Cleanup]    -- layer 5
```

The edge E->F spans layers 4 to 6, passing through layer 5 where I sits. The fix should ensure the horizontal segment is either above layer 5 (avoiding I) or goes around.

Since F is centered and I is also roughly centered, the cleanest routing would be:
- Vertical down from E to below I
- Horizontal to align with F
- Vertical down to F

This requires knowing where I is and avoiding its Y-range.

---

## Implementation Recommendation

**Phase 1 (Immediate):**
- Add collision detection to `compute_path()`
- If horizontal segment would cross a node, shift it below that node's bottom boundary
- Simple O(n) check for each segment against all nodes

**Phase 2 (Medium-term):**
- Ensure `compute_layout_dagre()` fully handles the complex.mmd case
- Verify dummy nodes are creating proper routing positions
- Add integration tests for edge-skipping scenarios

**Phase 3 (Long-term):**
- Implement full dummy node support in the built-in layout algorithm
- Optimize for ASCII grid constraints
- Add sophisticated crossing reduction heuristics
