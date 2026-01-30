# Dagre Edge Routing with Horizontal Offset

## Overview

Dagre's approach to edge routing with significant horizontal offset is based on **dummy nodes and layered ordering with crossing minimization**. Rather than explicitly deciding "left vs. right" routing, dagre uses emergent behavior from multiple competing algorithms.

## Core Pipeline

```
Input Graph
    ↓
1. NORMALIZE: Break long edges into unit-length segments (dummy nodes)
    ↓
2. ORDER: Minimize crossings via iterative sweep heuristics
    ↓
3. POSITION: Assign X coordinates using Brandes-Kopf algorithm
    ↓
4. RENDER: Draw edges through waypoints (dummy node positions)
```

## Phase 1: Normalization (Breaking Long Edges)

**File**: `$HOME/src/dagre/lib/normalize.js`

For an edge from rank `r₁` to rank `r₂` where `r₂ ≠ r₁ + 1`:
- Remove the original edge
- Create dummy nodes at each intermediate rank
- Link source → dummy₁ → dummy₂ → ... → target

```javascript
function normalizeEdge(g, e) {
  let v = e.v;              // source
  let vRank = g.node(v).rank;
  let w = e.w;              // target
  let wRank = g.node(w).rank;

  if (wRank === vRank + 1) return;  // Already unit-length

  g.removeEdge(e);

  // Insert dummy nodes for each intermediate rank
  for (i = 0, ++vRank; vRank < wRank; ++i, ++vRank) {
    attrs = {
      width: 0, height: 0,
      edgeLabel: edgeLabel,
      edgeObj: e,
      rank: vRank
    };
    dummy = util.addDummyNode(g, "edge", attrs, "_d");
    g.setEdge(v, dummy, { weight: edgeLabel.weight }, name);
    v = dummy;
  }

  g.setEdge(v, w, { weight: edgeLabel.weight }, name);
}
```

**Why This Matters**: A long diagonal edge (source.x >> target.x) gets broken into multiple segments. Each segment is a "unit" that participates in ordering and crossing minimization. The intermediate dummy nodes become decision points for routing.

## Phase 2: Crossing Reduction (Order Phase)

**File**: `$HOME/src/dagre/lib/order/index.js`

### Iterative Sweep Heuristic

```javascript
function order(g, opts = {}) {
  let layering = initOrder(g);
  assignOrder(g, layering);

  let bestCC = Number.POSITIVE_INFINITY;
  let best;

  for (let i = 0, lastBest = 0; lastBest < 4; ++i, ++lastBest) {
    // Alternate between down and up sweeps
    sweepLayerGraphs(
      i % 2 ? downLayerGraphs : upLayerGraphs,
      i % 4 >= 2,  // biasRight: true for iterations 2,3
    );

    layering = util.buildLayerMatrix(g);
    let cc = crossCount(g, layering);

    if (cc < bestCC) {
      lastBest = 0;
      best = Object.assign({}, layering);
      bestCC = cc;
    }
  }

  assignOrder(g, best);
}
```

**Key Points**:
- **Four iterations** with resets when improvement stops
- **Alternates up/down**: Sweeps from rank 1→max, then max→1
- **Biasing**: `i % 4 >= 2` means iterations 2,3 bias right
- **biasRight parameter** affects tie-breaking in node ordering

### Barth Bilayer Crossing Count

**File**: `$HOME/src/dagre/lib/order/cross-count.js`

```javascript
function crossCount(g, layering) {
  let cc = 0;
  for (let i = 1; i < layering.length; ++i) {
    cc += twoLayerCrossCount(g, layering[i-1], layering[i]);
  }
  return cc;
}
```

Each dummy node has `weight: edgeLabel.weight`. Long edges contribute their weight to crossings across multiple layers.

## Phase 3: Horizontal Positioning (Brandes-Kopf)

**File**: `$HOME/src/dagre/lib/position/bk.js`

### Four Alignments Strategy

This is the **key algorithm for deciding routing sides**:

```javascript
function positionX(g) {
  let layering = util.buildLayerMatrix(g);
  let conflicts = Object.assign(
    findType1Conflicts(g, layering),
    findType2Conflicts(g, layering));

  let xss = {};

  // FOUR ALIGNMENTS: ul, ur, dl, dr
  // u/d = up/down sweep direction
  // l/r = left/right bias
  ["u", "d"].forEach(vert => {
    ["l", "r"].forEach(horiz => {
      // Compute alignment with this bias
      let align = verticalAlignment(g, adjustedLayering, conflicts, neighborFn);
      let xs = horizontalCompaction(g, adjustedLayering, align.root, align.align);
      xss[vert + horiz] = xs;
    });
  });

  // Select the alignment with smallest total width
  let smallestWidth = findSmallestWidthAlignment(g, xss);

  // Balance: return median of all four
  return balance(xss, g.graph().align);
}
```

| Alignment | Direction | Bias | Purpose |
|-----------|-----------|------|---------|
| **ul** | Up → Down | Left | Left-aligned layout from top |
| **ur** | Up → Down | Right | Right-aligned layout from top |
| **dl** | Down → Up | Left | Left-aligned layout from bottom |
| **dr** | Down → Up | Right | Right-aligned layout from bottom |

### Conflict Detection

**Type-1 Conflicts**: When a non-inner segment crosses an inner segment
**Type-2 Conflicts**: Between dummy nodes from parallel long edges

These create hard constraints preventing certain orderings.

### Vertical Alignment (Block Creation)

```javascript
function verticalAlignment(g, layering, conflicts, neighborFn) {
  let root = {}, align = {};

  layering.forEach(layer => {
    layer.forEach((v, order) => {
      root[v] = v;
      align[v] = v;
    });
  });

  // Greedily form blocks by aligning with median neighbor
  layering.forEach(layer => {
    layer.forEach(v => {
      let ws = neighborFn(v);  // predecessors or successors
      if (ws.length) {
        ws = ws.sort((a, b) => pos[a] - pos[b]);
        let mp = (ws.length - 1) / 2;
        // Align with median neighbor if no conflict
        // ...
      }
    });
  });

  return { root, align };
}
```

### Horizontal Compaction

Two-pass algorithm:
- **Pass 1**: Push blocks as far left as possible given constraints
- **Pass 2**: Pull them as far right as possible
- Result: Balanced position respecting edge constraints

## How Dagre "Decides" Left vs. Right Routing

**There is no explicit "left-routing" vs. "right-routing" choice.**

Instead:
1. Four alignments (ul, ur, dl, dr) computed in parallel
2. Each uses different tie-breaking and direction preferences
3. **Smallest-width alignment wins**
4. All four alignments aligned to winner's bounds
5. **Balanced average** returned from all four

### What Drives Left vs. Right Emergence

For edges with significant horizontal offset (source.x >> target.x):

1. **Crossing Minimization**: Dummy nodes ordered to reduce crossings
2. **Constraint Propagation**: Type-1/Type-2 conflicts create hard constraints
3. **Width Optimization**: Smallest-width alignment chosen
4. **Four-Way Voting**: Median of all four alignments used

## Key Differences from mmdflux

| Aspect | Dagre | mmdflux |
|--------|-------|---------|
| **Routing Decision** | Emergent from four competing algorithms | Explicit mid-y calculation |
| **Constraint Handling** | Type-1/Type-2 conflicts | None |
| **Width Optimization** | Automatic smallest width | Not considered |
| **Crossing Minimization** | Iterative sweeps | Not implemented |
| **Dummy Node Usage** | Central to ordering | Optional waypoints |

## Applicable Insights for mmdflux

### What mmdflux Could Adopt

1. **Local crossing counts**: Count crossings if routing left vs. right
   - For edge with source.x >> target.x:
   - Count crossings if routing via left approach
   - Count crossings if routing via right approach
   - Choose side with fewer crossings

2. **Simple width heuristic**: If source is on right side of diagram:
   - Prefer routing through right corridor (less congestion)
   - Avoid crossing through the crowded middle

3. **Conflict detection**: Check if horizontal segment would cross existing edges
   - If so, shift to avoid or use alternative routing

### Minimal Implementation Path

```
1. Identify large-offset edges: abs(source.x - target.x) > threshold
2. For each such edge:
   a. Check if source is on right half of diagram
   b. If yes, consider routing via right corridor
   c. If no, use current mid-y approach
3. If tie: use direction bias (prefer left for TD)
```

This captures the essence of dagre's approach without full complexity.
