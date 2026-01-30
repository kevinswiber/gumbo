# Mermaid.js Edge Label Positioning

## Summary

Mermaid.js uses a **midpoint-based positioning approach** for edge labels:
- Labels are positioned at the **geometric center of the edge path**
- Positioning happens in two stages: (1) label centering at insertion time, (2) position finalization after layout
- No built-in collision avoidance with edge segments

## Label Positioning Logic

### Core Algorithm: Midpoint Calculation

**Location:** `/packages/mermaid/src/utils.ts:305-327`

```typescript
function traverseEdge(points: Point[]): Point {
  let prevPoint: Point | undefined;
  let totalDistance = 0;

  // Calculate total path distance
  points.forEach((point) => {
    totalDistance += distance(point, prevPoint);
    prevPoint = point;
  });

  // Traverse HALF of total distance to find midpoint
  const remainingDistance = totalDistance / 2;
  return calculatePoint(points, remainingDistance);
}
```

Labels are placed at the geometric center of the edge path - no buffer/margin is applied.

### Label Centering at Creation Time

**Location:** `/packages/mermaid/src/rendering-util/rendering-elements/edges.js:52-89`

```javascript
// Calculate label bounding box
let bbox = labelElement.getBBox();

// Center the label by translating to negative half dimensions
label.attr('transform', 'translate(' + -bbox.width / 2 + ', ' + -bbox.height / 2 + ')');

// Store dimensions for later positioning
edge.width = bbox.width;
edge.height = bbox.height;
```

Labels are pre-centered as a transform, then positioned with `translate(x, y)` at the midpoint.

### Main Label Position Finalization

**Location:** `/packages/mermaid/src/rendering-util/rendering-elements/edges.js:213-241`

```javascript
export const positionEdgeLabel = (edge, paths) => {
  let path = paths.updatedPath ? paths.updatedPath : paths.originalPath;

  if (edge.label) {
    const el = edgeLabels.get(edge.id);
    let x = edge.x;  // From dagre layout
    let y = edge.y;  // From dagre layout

    if (path) {
      // Recalculate from actual path if available
      const pos = utils.calcLabelPosition(path);
      x = pos.x;
      y = pos.y;
    }

    // Apply subgraph title margin
    el.attr('transform', `translate(${x}, ${y + subGraphTitleTotalMargin / 2})`);
  }
}
```

Two-step positioning:
1. Dagre provides edge coordinates (`edge.x`, `edge.y`)
2. If edge path available, recalculate from actual geometry
3. Apply any subgraph margins

## Terminal Labels - Different Strategy

**Location:** `/packages/mermaid/src/utils.ts:399-427`

Terminal labels (at edge endpoints) use perpendicular offsets:

```typescript
function calcTerminalLabelPosition(
  terminalMarkerSize: number,
  position: 'start_left' | 'start_right' | 'end_left' | 'end_right',
  _points: Point[]
): Point {
  // Traverse 25 pixels + half marker size from the start
  const distanceToCardinalityPoint = 25 + terminalMarkerSize;
  const center = calculatePoint(points, distanceToCardinalityPoint);

  // Offset perpendicular to edge by (10 + marker*0.5) pixels
  const d = 10 + terminalMarkerSize * 0.5;
  const angle = Math.atan2(points[0].y - center.y, points[0].x - center.x);

  // Apply perpendicular offset
  cardinalityPosition.x = Math.sin(angle) * d + (points[0].x + center.x) / 2;
  cardinalityPosition.y = -Math.cos(angle) * d + (points[0].y + center.y) / 2;
}
```

**Hardcoded values:**
- **25 pixels**: Distance from start/end to find the label position point
- **10 pixels**: Perpendicular offset from the edge

Note: Main edge labels do NOT get this perpendicular offset treatment.

## Configuration/Options

### Layout Spacing Defaults

**Location:** `/packages/mermaid/src/diagrams/flowchart/flowRenderer-v3-unified.ts:49-50`

```typescript
data4Layout.nodeSpacing = conf?.nodeSpacing || 50;  // Default: 50 pixels
data4Layout.rankSpacing = conf?.rankSpacing || 50;  // Default: 50 pixels
```

These get passed to dagre as `nodesep` and `ranksep`.

### Edge Path Configuration

**Location:** `/packages/mermaid/src/rendering-util/layout-algorithms/dagre/index.js:249-258`

```javascript
graph.edges().forEach(function (e) {
  const edge = graph.edge(e);

  // Adjust y for subgraph margins
  edge.points.forEach((point) => (point.y += subGraphTitleTotalMargin / 2));

  const startNode = graph.node(e.v);
  const endNode = graph.node(e.w);

  // Insert the visual edge
  const paths = insertEdge(edgePaths, edge, clusterDb, diagramType, startNode, endNode, id);

  // Position label based on final edge path
  positionEdgeLabel(edge, paths);
});
```

## Code References

| File | Lines | Purpose |
|------|-------|---------|
| `utils.ts` | 305-327 | `traverseEdge()` - midpoint calculation |
| `utils.ts` | 322 | `calcLabelPosition()` - wrapper for path positioning |
| `utils.ts` | 399-427 | `calcTerminalLabelPosition()` - endpoint labels |
| `edges.js` | 52-89 | `insertEdgeLabel()` - initial label creation |
| `edges.js` | 213-241 | `positionEdgeLabel()` - final positioning |
| `dagre/index.js` | 249-258 | Edge path + label integration |
| `flowRenderer-v3-unified.ts` | 49-50 | Default spacing values |

## Key Insights

1. **Pure midpoint positioning** - No built-in padding/margin between label and edge path

2. **Terminal labels are special** - Only endpoint labels get perpendicular offsets (25+10 pixels), main labels don't

3. **Label dimensions stored but not used for collision** - `edge.width` and `edge.height` exist but only for SVG centering

4. **No collision avoidance** - If label overlaps an edge point, Mermaid renders it that way

5. **Path geometry matters** - Curved edges naturally give more space than orthogonal routes

6. **SVG assumptions** - Works well because:
   - Sub-pixel positioning possible
   - Text can overlap lines and remain readable
   - Anti-aliasing smooths edges
   - Dynamic rotation/scaling available

## Why This Doesn't Translate to ASCII

In ASCII rendering with a discrete character grid:
1. Midpoint calculation gives float coords; converting to char grid can place label ON edge
2. No perpendicular offset means labels can touch edge characters
3. Character width/height differ; label dimensions in chars ≠ SVG dimensions
4. Fixed font size - can't dynamically size labels
5. No overlap tolerance - characters either overwrite or don't
