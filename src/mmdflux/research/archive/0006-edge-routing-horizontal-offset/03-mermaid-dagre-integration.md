# Mermaid.js and Dagre Edge Routing Integration

## Overview

Mermaid.js does NOT rely solely on Dagre for edge routing. It employs a sophisticated multi-layered approach with significant post-processing.

## Key Finding: Mermaid Uses Layered Post-Processing

### 1. Dagre Layout Phase (Core Layout)

**Location**: `packages/mermaid/src/rendering-util/layout-algorithms/dagre/index.js`

Dagre provides:
- Node positions using rank-based layout
- Initial edge waypoints (points array)
- Control points defining general edge path structure

### 2. Point-Based Edge Path System

**Location**: `packages/mermaid/src/rendering-util/rendering-elements/edges.js`

Mermaid stores edge paths as arrays of control points (`edge.points`), not SVG path strings:

```typescript
// In types.ts:
interface Edge {
  points?: Point[];  // Array of control points
}

// In edges.js:
let points = edge.points;  // Get waypoints from dagre
let lineData = points.filter((p) => !Number.isNaN(p.y));
lineData = fixCorners(lineData);  // Post-process for visual clarity
```

### 3. Post-Processing Passes

#### A. Corner Detection and Smoothing

```typescript
function extractCornerPoints(points) {
  const cornerPoints = [];
  for (let i = 1; i < points.length - 1; i++) {
    const prev = points[i - 1];
    const curr = points[i];
    const next = points[i + 1];

    // Detect right-angle corners
    if (prev.x === curr.x && curr.y === next.y) {
      cornerPoints.push(curr);
    } else if (prev.y === curr.y && curr.x === next.x) {
      cornerPoints.push(curr);
    }
  }
  return cornerPoints;
}
```

#### B. Corner Radius Adjustment

- Rounds sharp corners with adjustable radius (default 5)
- Creates intermediate points to smooth transitions
- Improves visual clarity at intersections

#### C. Curve Interpolation

Mermaid supports multiple interpolation strategies:
- `linear` - Direct line segments (default for flowcharts)
- `basis` - B-spline curves
- `cardinal` - Cardinal spline curves
- `catmullRom` - Catmull-Rom splines
- And others

```typescript
const lineFunction = line().x(x).y(y).curve(curve);
let linePath = lineFunction(lineData);  // Generate SVG path
```

### 4. Cluster Boundary Handling

Unique to Mermaid - post-processing removes portions of edge paths that intersect cluster boundaries:

```typescript
if (edge.toCluster) {
  points = cutPathAtIntersect(edge.points, clusterDb.get(edge.toCluster).node);
}

if (edge.fromCluster) {
  points = cutPathAtIntersect(points.reverse(), clusterDb.get(edge.fromCluster).node).reverse();
}
```

## How Mermaid Handles Large Horizontal Offsets

### Solution: Waypoint Positioning

1. **Dagre computes waypoints** that route around intermediate nodes
2. **Post-processing refines waypoints**:
   - Corner detection and smoothing
   - Curve interpolation
   - Cluster intersection handling
3. **Waypoints are dynamic** per edge, allowing natural accommodation of offsets

### No "Side Preference" Heuristics

Mermaid does NOT have explicit side preferences. Instead:
- Edge routing determined by Dagre's layer assignment
- Waypoints computed based on node positions
- Visual clarity from corner smoothing, not path logic

## Comparison with mmdflux Z-Path

| Aspect | mmdflux | Mermaid |
|--------|---------|---------|
| **Routing Core** | Explicit segment-based | Dagre waypoint-based |
| **Path Shape** | Rectilinear (fixed angles) | Arbitrary (curved or linear) |
| **Horizontal Offset** | Z-path with mid-y | Waypoint positioning |
| **Corner Handling** | Built into routing | Post-processing refinement |
| **Curve Support** | No (ASCII limitation) | Yes (SVG target) |

## Does Mermaid Make Routing Decisions Independent of Dagre?

### Answer: Partially

**What Dagre decides**:
- Node rank assignment
- Initial edge layering
- Waypoint placement
- Self-loop handling

**What Mermaid refines (independent)**:
- Edge waypoint post-processing
- Corner smoothing
- Curve interpolation
- Cluster boundary cleanup
- Label positioning

**What Mermaid does NOT override**:
- Node positions
- Rank ordering
- Layer assignment

Independence is **limited to rendering refinement**, not core routing decisions.

## Key Takeaways for mmdflux

### 1. Waypoint Post-Processing vs Pre-Processing

Mermaid doesn't decide routing early:
- Dagre provides base waypoints
- Mermaid refines for visual clarity
- Allows flexibility for large horizontal offsets

### 2. No Explicit Side Preference in Modern Mermaid

Current Mermaid:
- Relies entirely on Dagre's layer assignment
- Uses geometric refinement only
- Simplified architecture

### 3. Z-Path Doesn't Map to SVG

mmdflux's Z-path is sensible for ASCII but:
- Mermaid doesn't use pre-defined path shapes
- Waypoints dynamically computed
- More adaptable to varying offsets

### 4. Architectural Tradeoffs

| Approach | Benefit | Cost |
|----------|---------|------|
| **mmdflux Z-path** | Predictable ASCII output | Less flexible |
| **Mermaid waypoints** | Flexible routing | Requires post-processing |
| **Dagre core** | Proven algorithm | Not optimized for ASCII |

### 5. Recommendations for mmdflux

**Option A: Enhance Z-path**
- Add corridor reservation per rank
- Allow edges to use reserved corridor space

**Option B: Adopt waypoint approach**
- Extract waypoints from dagre
- Simplify for ASCII grid

**Option C: Hybrid**
- Z-path for simple edges
- Waypoint-based for complex cases
