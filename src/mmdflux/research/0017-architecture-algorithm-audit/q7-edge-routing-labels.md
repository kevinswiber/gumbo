# Q7: Edge Routing and Label Positioning

## Summary

Edge routing across all three codebases shares the same core algorithmic pattern: Dagre produces waypoints (dummy node positions from normalization), endpoint intersection is computed against node boundaries, and the rendering layer converts these abstract points into visual output. The key architectural difference is that Dagre.js produces floating-point waypoints consumed by SVG curve interpolation (d3 curveBasis), while mmdflux must orthogonalize waypoints into axis-aligned segments for character-grid rendering. Label positioning in Dagre.js is handled algorithmically during layout (edge labels become dummy nodes with width/height), while mmdflux must do post-hoc heuristic placement since the character grid imposes collision constraints Dagre never encounters.

## Where

**mmdflux (Rust):**
- `/Users/kevin/src/mmdflux/src/render/router.rs` — edge routing: waypoint handling, orthogonalization, backward edge synthesis, attachment plan
- `/Users/kevin/src/mmdflux/src/render/edge.rs` — edge rendering: segment drawing, arrow glyphs, label placement heuristics
- `/Users/kevin/src/mmdflux/src/render/intersect.rs` — node boundary intersection: rect, diamond, face classification, spread points

**Dagre.js:**
- `/Users/kevin/src/dagre/lib/layout.js` — `assignNodeIntersects()`, `positionSelfEdges()`, `fixupEdgeLabelCoords()`, `makeSpaceForEdgeLabels()`, `injectEdgeLabelProxies()`
- `/Users/kevin/src/dagre/lib/util.js` — `intersectRect()` (the core rectangle intersection algorithm)
- `/Users/kevin/src/dagre/lib/normalize.js` — dummy node chain creation for long edges, edge label proxy nodes

**Mermaid.js:**
- `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/edges.js` — SVG edge insertion, path clipping, corner rounding, d3 curve selection
- `/Users/kevin/src/mermaid/packages/mermaid/src/dagre-wrapper/edges.js` — legacy dagre-wrapper edge insertion
- `/Users/kevin/src/mermaid/packages/mermaid/src/rendering-util/rendering-elements/intersect/` — shape-specific intersect functions (rect, polygon, ellipse, circle, line)
- `/Users/kevin/src/mermaid/packages/mermaid/src/utils.ts` — `calcLabelPosition()`, `traverseEdge()`, `calcTerminalLabelPosition()`

## What

### 1. Waypoint Generation (Algorithmic — Shared)

All three codebases share the same waypoint generation algorithm inherited from the Sugiyama/Dagre framework:

**Dagre normalization** (`normalize.js`): Long edges (spanning multiple ranks) are split into chains of dummy nodes. Each dummy node occupies one rank. During coordinate assignment (Brandes-Kopf), these dummy nodes get x/y positions. When normalization is undone, the dummy node positions become the edge's `points` array — these are the waypoints.

**Edge label as dummy node**: If an edge has a label, Dagre creates a special dummy node at the label's target rank (midpoint of the edge). This dummy has the label's width and height, so the layout algorithm naturally makes space for it. When normalization is undone, the dummy's position becomes `edge.x` and `edge.y` — the label's center coordinate.

**mmdflux replication**: mmdflux replicates this in its own dagre module. Waypoints come from dummy node positions and are stored in `layout.edge_waypoints`. However, mmdflux does not yet implement edge-label-as-dummy-node; labels are positioned post-hoc.

### 2. Node Intersection Calculation (Algorithmic — Shared with Shape Variations)

The core intersection algorithm is identical across all three codebases. All use the same `intersectRect` formula from [math.stackexchange.com/questions/108113](https://math.stackexchange.com/questions/108113):

```
Given rectangle center (x,y) with half-width w and half-height h, and external point p:
  dx = p.x - x, dy = p.y - y
  if |dy| * w > |dx| * h:
    // steep: intersect top or bottom
    sx = h * dx / dy, sy = h (or -h if dy < 0)
  else:
    // shallow: intersect left or right
    sx = w (or -w if dx < 0), sy = w * dy / dx
  intersection = (x + sx, y + sy)
```

**Dagre.js** (`util.intersectRect`): Only supports rectangle intersection. Called in `assignNodeIntersects()` to clip edge endpoints to node boundaries. Uses first/last waypoint as the approach direction; falls back to the opposite node's center if no waypoints exist.

**Mermaid.js**: Extends with multiple shape intersectors:
- `intersect-rect.js` — identical formula to Dagre
- `intersect-ellipse.js` — parametric ellipse-line intersection
- `intersect-circle.js` — delegates to ellipse with rx = ry
- `intersect-polygon.js` — tests against each polygon edge, returns nearest intersection
- `intersect-node.js` — dispatches to shape-specific `node.intersect(point)` method

Mermaid also has a separate `intersection()` function in `edges.js` that computes line-rectangle intersection from an `outsidePoint`/`insidePoint` pair (used for cluster boundary clipping via `cutPathAtIntersect`).

**mmdflux** (`intersect.rs`): Supports rect and diamond intersection:
- `intersect_rect()` — same formula as Dagre, using `FloatPoint` for intermediate math
- `intersect_diamond()` — rhombus intersection via `|dx|/w + |dy|/h = 1` boundary equation
- `intersect_node()` — dispatches by `Shape` enum (Rectangle/Round use rect, Diamond uses diamond)
- `classify_face()` — determines which face (Top/Bottom/Left/Right) an approach angle hits, using the same slope comparison
- `calculate_attachment_points()` — computes both source and target intersections given waypoints

### 3. Self-Edge Handling (Algorithmic)

**Dagre.js**: Self-edges (v == w) are removed before layout, stored on the node. After layout, `insertSelfEdges()` creates a dummy node adjacent to the self-referencing node. `positionSelfEdges()` generates 5 hardcoded waypoints forming a loop to the right of the node:
```javascript
points = [
  { x: x + 2*dx/3, y: y - dy },  // upper approach
  { x: x + 5*dx/6, y: y - dy },  // upper middle
  { x: x + dx,     y: y },        // rightmost point
  { x: x + 5*dx/6, y: y + dy },  // lower middle
  { x: x + 2*dx/3, y: y + dy }   // lower approach
]
```

**mmdflux**: No self-edge handling currently implemented.

**Mermaid.js**: Inherits Dagre's self-edge points and renders them as SVG curves.

### 4. Backward Edge Routing (mmdflux-Specific)

mmdflux has unique backward edge routing that doesn't exist in Dagre.js or Mermaid.js (because SVG renderers don't need special backward routing — curves handle it naturally):

- **Detection**: `is_backward_edge()` checks if an edge goes against the layout direction
- **Synthetic waypoints**: `generate_backward_waypoints()` creates 2 waypoints routing around the right side (TD/BT) or bottom side (LR/RL) of both nodes
- **Face classification**: `backward_routing_faces()` forces both source and target to attach on the same face (Right for TD/BT, Bottom for LR/RL)

This is necessary because ASCII rendering requires orthogonal paths — you can't draw a smooth curve that gracefully reverses direction.

### 5. Attachment Point Spreading (mmdflux-Specific)

mmdflux has a sophisticated attachment plan system that Dagre.js lacks entirely:

- **`compute_attachment_plan()`**: Groups edges by (node_id, face), then for faces with >1 edge, computes evenly-spaced attachment points using `spread_points_on_face()`
- **Endpoint-maximizing**: N edges on a face are spread to the full extent of the face for maximum visual separation, with a minimum gap of 2 cells
- **Cross-axis sorting**: Edges are sorted by their approach point's cross-axis coordinate to minimize visual crossings

Dagre.js doesn't need this because SVG edges can overlap at the same pixel and curves naturally fan out. In ASCII, overlapping attachment points would produce garbled characters.

### 6. Orthogonalization (mmdflux-Specific, Rendering-Target)

mmdflux converts all edge paths to axis-aligned segments:

- **`orthogonalize_segment()`**: Converts a diagonal between two points into an L-shaped pair of segments (vertical-then-horizontal or horizontal-then-vertical depending on layout direction)
- **Z-shaped paths**: `build_orthogonal_path_for_direction()` produces V-H-V paths for TD/BT and H-V-H paths for LR/RL, ensuring the final segment matches the layout's canonical entry direction for correct arrow glyph selection
- **Direction-aware final segment**: The last segment's orientation determines the arrow character (down-arrow for vertical final segment going down, right-arrow for horizontal going right, etc.)

Neither Dagre.js nor Mermaid.js has any orthogonalization — they pass waypoints directly to d3's curve interpolation.

### 7. Edge Label Positioning

**Dagre.js (algorithmic, layout-time)**:
1. `makeSpaceForEdgeLabels()`: Halves `ranksep` and doubles edge `minlen`, creating space for label dummy nodes
2. `injectEdgeLabelProxies()`: Creates temporary proxy nodes at the midpoint rank of labeled edges
3. During normalization, the label dummy node gets the edge's `width`/`height` so layout reserves space
4. `normalize.undo()`: Sets `edge.x` and `edge.y` from the label dummy's final position
5. `fixupEdgeLabelCoords()`: Adjusts x coordinate based on `labelpos` ("l", "r", or "c") and `labeloffset`

The label position supports three modes: center (default), left offset, or right offset relative to the edge midpoint.

**Mermaid.js (rendering-time)**:
1. `insertEdgeLabel()`: Creates SVG `<g>` elements with the label text, measures bbox
2. `positionEdgeLabel()`: Positions the label `<g>` at `(edge.x, edge.y)` from Dagre output, or recalculates using `calcLabelPosition()` if the path was modified
3. `calcLabelPosition()` / `traverseEdge()`: Walks along the edge's point array to find the midpoint by accumulated distance (not simply the middle waypoint index — it's the geometric midpoint along the path's total length)
4. `calcTerminalLabelPosition()`: Places start/end terminal labels 25px along the path from the respective endpoint, with angular offset for left/right positioning

**mmdflux (rendering-time, heuristic)**:
1. `draw_edge_label_with_tracking()`: Post-hoc label placement with direction-aware heuristics
2. **TD/BT with Z-paths (3+ segments)**: First tries centering on the widest horizontal segment (requires `label_len + 2` padding); falls back to placing beside the longest vertical segment
3. **LR/RL**: `label_on_horizontal_segment()` places labels above the widest horizontal segment
4. **Straight paths**: Places label beside the edge line
5. **Collision avoidance**: `find_safe_label_position()` tries the base position, then shifts by fixed offsets (up to +/-3 cells) to avoid node and edge cell collisions
6. **Side selection**: For vertical-segment labels, checks if placing on the right side would sandwich the label between two edges, and flips to the left if so

### 8. SVG Path Generation (Mermaid-Specific, Rendering-Target)

Mermaid's rendering layer adds significant SVG-specific processing:
- **Curve interpolation**: Supports 12+ d3 curve types (basis, linear, cardinal, bumpX/Y, catmullRom, monotone, natural, step, etc.)
- **Corner rounding**: `fixCorners()` / `extractCornerPoints()` identifies sharp corners and inserts adjacent points 5px away for smoother transitions
- **Cluster boundary clipping**: `cutPathAtIntersect()` truncates edge paths at cluster (subgraph) boundaries
- **Marker offsets**: `getLineFunctionsWithOffset()` adjusts path endpoints to account for arrowhead marker sizes
- **Dash arrays**: `generateDashArray()` computes SVG stroke-dasharray patterns
- **Hand-drawn mode**: Uses roughjs to render edges with a sketchy appearance

## How

### Dagre.js Edge Processing Pipeline

```
1. makeSpaceForEdgeLabels()     — halve ranksep, double minlen
2. removeSelfEdges()            — stash self-edges on nodes
3. injectEdgeLabelProxies()     — proxy nodes for label rank
4. normalize.run()              — split long edges into dummy chains
5. order()                      — crossing minimization (positions dummies)
6. position()                   — coordinate assignment (x,y for all nodes)
7. positionSelfEdges()          — generate 5-point self-edge loops
8. normalize.undo()             — collect dummy positions as edge.points; set edge.x/y for labels
9. fixupEdgeLabelCoords()       — adjust label position by labelpos/labeloffset
10. assignNodeIntersects()       — clip edge endpoints to node boundaries via intersectRect
11. reversePointsForReversedEdges() — flip point order for reversed (back) edges
```

Output: Each edge has `points` (array of {x,y}), optionally `x`/`y` (label center), `width`/`height` (label dimensions).

### mmdflux Edge Processing Pipeline

```
1. dagre::layout()              — produces waypoints (dummy node positions) + node positions
2. compute_layout()             — converts dagre output to draw coordinates, stores edge_waypoints
3. compute_attachment_plan()    — groups edges by face, computes spread positions
4. route_all_edges()            — for each edge:
   a. Check for dagre waypoints → route_edge_with_waypoints()
   b. Check for backward edge → generate_backward_waypoints() → route_backward_with_synthetic_waypoints()
   c. Otherwise → route_edge_direct()
5. Each routing path:
   a. resolve_attachment_points() — use override or intersect calculation
   b. clamp_to_boundary() — ensure point is on node boundary cell
   c. offset_for_face() — move 1 cell outward from boundary
   d. build_orthogonal_path_with_waypoints() or build_orthogonal_path_for_direction() — orthogonalize
6. render_all_edges()           — two passes: segments+arrows first, then labels
7. Label placement              — heuristic positioning with collision avoidance
```

### Mermaid.js Edge Processing Pipeline

```
1. Dagre layout (via dagre-wrapper or ELK) → edge.points, edge.x/y
2. insertEdgeLabel()            — create SVG label elements, measure bbox
3. insertEdge():
   a. Shape-specific node.intersect() to clip endpoints
   b. cutPathAtIntersect() for cluster boundaries
   c. fixCorners() to smooth sharp turns (newer renderer)
   d. d3 line().curve() to generate SVG path string
   e. Apply stroke classes (thickness, pattern)
   f. addEdgeMarkers() for arrowheads
4. positionEdgeLabel()          — place label at edge.x/y or recalculate via calcLabelPosition()
```

## Why

### Algorithmic (Diagram-Type-Agnostic) Components

These components work for any diagram type and any rendering target:

1. **Waypoint generation via normalization**: The dummy-node-chain approach works for any hierarchical layout. Class diagram associations, state transitions, and sequence diagram vertical lifelines all benefit from the same long-edge normalization.

2. **Node intersection calculation**: The `intersectRect` formula is purely geometric. It works for any shape that has a well-defined center and boundary. The polygon and ellipse extensions in Mermaid show how the same pattern extends to arbitrary shapes.

3. **Edge label as layout participant**: Dagre's approach of injecting label dimensions into the layout graph is the correct algorithmic solution. It ensures labels never overlap with nodes because the layout engine treats them as first-class spatial objects. This is diagram-type-agnostic.

4. **Self-edge routing**: The 5-waypoint loop pattern is algorithmically general — it works for any node shape and any rendering target.

### Rendering-Target-Specific Components

1. **Orthogonalization** (mmdflux only): Required because character grids can only draw horizontal and vertical lines. SVG renderers never need this.

2. **Attachment point spreading** (mmdflux only): Required because overlapping characters produce unreadable output. SVG renderers handle this implicitly via anti-aliasing and sub-pixel positioning.

3. **SVG curve interpolation** (Mermaid only): The d3 curve library is entirely rendering-target-specific. The algorithmic equivalent in ASCII is the Z-path orthogonalization.

4. **Corner rounding** (Mermaid only): `fixCorners()` smooths sharp turns for visual polish — purely an SVG rendering concern.

5. **Collision-avoidance label placement** (mmdflux only): The heuristic shifting in `find_safe_label_position()` is necessitated by the discrete character grid. SVG labels can be placed at arbitrary sub-pixel positions.

6. **Face-aware arrow selection** (mmdflux only): The final segment orientation determining the arrow glyph is unique to text rendering. SVG uses rotatable marker elements.

## Key Takeaways

- **The intersectRect algorithm is universal**: All three codebases use the identical formula. mmdflux's version in `intersect.rs` is a faithful port. The math.stackexchange origin is referenced in both Dagre.js and Mermaid.js source comments.

- **Dagre's label-as-dummy-node is the algorithmically correct approach**: By giving labels width and height during layout, Dagre ensures collision-free label placement without post-hoc heuristics. mmdflux's current heuristic label placement (`draw_edge_label_with_tracking`) is a workaround for not yet participating labels in layout.

- **mmdflux's attachment plan is an ASCII-specific innovation**: The `compute_attachment_plan()` / `spread_points_on_face()` system solves a problem that doesn't exist in SVG rendering. This is novel and well-designed for the character grid constraint.

- **Backward edge routing is an ASCII-specific concern**: Dagre.js simply reverses the points array for reversed edges. SVG curves naturally handle this. mmdflux needs explicit synthetic waypoints and orthogonal routing because ASCII lines can't gracefully reverse direction.

- **Mermaid's shape-specific intersection library is the model for extensibility**: The `intersect-polygon.js` function handles arbitrary polygonal shapes (hexagons, trapezoids, etc.) by testing against each edge. mmdflux currently handles rect and diamond; extending to new shapes would follow Mermaid's dispatch pattern.

- **Edge routing is mostly diagram-type-agnostic**: The waypoint-generation, intersection, and label-positioning algorithms work unchanged across flowcharts, class diagrams, state diagrams, etc. Only the rendering layer (SVG curves vs. ASCII segments) is target-specific. This means mmdflux's router.rs and intersect.rs would need minimal changes to support non-flowchart edge types.

## Open Questions

- **Should mmdflux adopt label-as-dummy-node?** This would eliminate the heuristic label placement entirely and produce layout-guaranteed collision-free labels. The tradeoff is increased layout complexity and slightly wider inter-rank spacing.

- **How would self-edges render in ASCII?** Dagre's 5-point loop renders beautifully as an SVG curve but would need orthogonalization for ASCII. A small rectangular loop (3-4 segments) attached to the right side of a node might work.

- **Can mmdflux support non-rectangular intersection shapes?** The diamond intersector is already implemented. Adding ellipse and polygon intersectors (following Mermaid's pattern) would enable stadium shapes, hexagons, etc.

- **How does Mermaid's `calcLabelPosition()` (geometric midpoint along path length) compare to mmdflux's segment-based heuristic?** The distance-walking approach is more principled and could be adapted for orthogonal paths by measuring total segment length.

- **Would the attachment spread algorithm need modification for non-flowchart diagrams?** Class diagrams have cardinality labels at both endpoints (like Mermaid's `startLabelLeft`/`endLabelRight`), which would need a different placement strategy than the current midpoint-focused approach.
