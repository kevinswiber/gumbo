# Dagre Source Code Analysis

This document provides a detailed analysis of the Dagre JavaScript library source code, based on exploration of ~/src/dagre.

## Overview

Dagre is a JavaScript graph layout library that implements the Sugiyama/Gansner algorithm for hierarchical graph drawing. The algorithm transforms a directed graph into a layered layout with minimal edge crossings.

**Main Pipeline (in `lib/layout.js`):**
1. **Acyclic Transformation** - Handle cycles
2. **Ranking (Layering)** - Assign nodes to horizontal layers
3. **Ordering** - Minimize edge crossings within layers
4. **Positioning** - Calculate exact x,y coordinates

## File Structure

```
lib/
├── acyclic.js                 # Cycle detection and reversal
├── greedy-fas.js              # Greedy feedback arc set algorithm
├── rank/
│   ├── index.js              # Entry point, selects ranker
│   ├── network-simplex.js    # Primary ranking algorithm
│   ├── feasible-tree.js      # Tight tree construction
│   └── util.js               # longestPath, slack calculations
├── order/
│   ├── index.js              # Entry point, edge crossing minimization
│   ├── init-order.js         # Initial ordering via DFS
│   ├── barycenter.js         # Barycenter heuristic
│   ├── sort.js               # Sorting with conflict resolution
│   ├── cross-count.js        # Bilayer edge crossing count
│   ├── build-layer-graph.js  # Build subgraph for a rank
│   ├── sort-subgraph.js      # Recursive subgraph sorting
│   └── resolve-conflicts.js  # Constraint-based conflict resolution
├── position/
│   ├── index.js              # positionY (trivial), calls positionX
│   └── bk.js                 # Brandes-Köpf horizontal positioning
├── normalize.js              # Break long edges into unit-length segments
├── nesting-graph.js          # Handle compound/subgraph nodes
├── coordinate-system.js      # Handle rankdir transformations
└── util.js                   # Utilities: slack, simplify, buildLayerMatrix
```

---

## Phase 1: Acyclic Transformation

**File:** `lib/acyclic.js`

**Purpose:** Remove cycles to ensure DAG property required by layout algorithm.

### Algorithm Options

**1. DFS-based FAS (DEFAULT):**
- Tracks visited nodes and current recursion stack
- Back edges (edges to nodes in stack) form the feedback arc set
- Simple and fast
- **This is what Mermaid.js uses** (no `acyclicer` option set)

**2. Greedy FAS (Optional):**
- Only used when `acyclicer: "greedy"` is explicitly set
- Implements Eades, Lin, Smyth 1993 heuristic
- Mermaid does NOT use this (the option is commented out in their code)

### Key Functions

- `dfsFAS(g)` - Lines 30-53: DFS traversal detecting back edges
- `run(g)` - Lines 11-28: Reverses FAS edges and marks them as reversed
- `undo(g)` - Lines 55-67: Restores reversed edges to original direction

### Data Structures

- `visited`: Track processed nodes
- `stack`: Track nodes in current DFS path (detects back edges)
- `fas`: Array of edges to reverse

---

## Phase 2: Ranking (Layering)

**Files:** `lib/rank/`

**Purpose:** Assign each node a rank (layer) respecting `minlen` constraints on edges.

### Three Ranking Strategies

#### 2a. Longest Path Ranker (Simple)

**File:** `lib/rank/util.js` - `longestPath()` function

```javascript
// For each node: rank = min(successor.rank - edge.minlen)
// Sink nodes get rank 0
// Source nodes get highest ranks
```

**Complexity:** O(V+E)
**Pros:** Fast
**Cons:** Creates wide bottom ranks

#### 2b. Feasible Tree Ranker (Medium Quality)

**Files:** `feasible-tree.js`, `util.js`

Two-stage algorithm:
1. Apply longestPath for initial ranks
2. Construct tight spanning tree and adjust ranks

Key concept: `slack = rank_w - rank_v - minlen` (difference between actual and minimum edge length)

#### 2c. Network Simplex Ranker (Optimal) - DEFAULT

**File:** `lib/rank/network-simplex.js`

Most complex and best quality ranking, based on Gansner et al. paper.

**Algorithm Phases:**
1. **Initialization:** Apply longestPath, build feasible tree, assign low/lim values
2. **Optimization Loop:**
   ```javascript
   while (e = leaveEdge(t)) {  // Find edge with negative cut value
       f = enterEdge(t, g, e)   // Find replacement edge
       exchangeEdges(t, g, e, f)// Swap edges, update ranks
   }
   ```

**Key Functions:**
- `initLowLimValues(tree, root)` - DFS assigns subtree boundaries
- `initCutValues(t, g)` - Compute cut value for each tree edge
- `calcCutValue(t, g, child)` - Recursive cut value calculation
- `leaveEdge(tree)` - Find tree edge with negative cut value
- `enterEdge(t, g, edge)` - Find replacement non-tree edge with minimum slack
- `exchangeEdges(t, g, e, f)` - Swap edges, recompute values
- `updateRanks(t, g)` - Adjust ranks via preorder traversal

---

## Phase 3: Ordering (Minimize Edge Crossings)

**Files:** `lib/order/`

**Purpose:** Arrange nodes within each rank to minimize edge crossings.

### Main Algorithm (`order/index.js`)

1. **Initial Ordering:** DFS from source nodes assigns initial order
2. **Iterative Sweep Optimization:**
   - Build layer graphs (for up/down directions)
   - 4 iterations with alternate sweeping
   - Apply barycenter heuristic for each direction
   - Track best ordering by lowest cross count

### Key Components

#### Barycenter Heuristic (`barycenter.js`)

```javascript
// For each movable node:
// barycenter = sum(predecessor_order × edge_weight) / sum(edge_weights)
```

#### Edge Crossing Count (`cross-count.js`)

```javascript
// Efficient O(E log V) algorithm using binary tree accumulator
twoLayerCrossCount(g, northLayer, southLayer)
```

#### Sorting & Conflict Resolution

- `sort.js` - Partition, sort by barycenter, interleave unsortables
- `resolve-conflicts.js` - Apply constraint graph to merge conflicts

---

## Phase 4: Positioning

**Files:** `lib/position/`

**Purpose:** Calculate exact x,y coordinates for each node.

### Y Positioning (`position/index.js`)

Simple: For each layer, calculate max height and assign y based on `ranksep`.

### X Positioning - Brandes-Köpf (`position/bk.js`)

Most complex positioning algorithm with 4 passes:

1. Find Type-1 and Type-2 conflicts (edge crossing patterns)
2. For 4 combinations (up/down × left/right):
   - Compute vertical alignment of nodes into "blocks"
   - Run horizontal compaction
3. Select alignment with smallest width
4. Balance coordinates

**Key Functions:**
- `findType1Conflicts()`, `findType2Conflicts()` - Detect crossing patterns
- `verticalAlignment()` - Group nodes into blocks
- `horizontalCompaction()` - Assign x-coordinates with separation constraints
- `findSmallestWidthAlignment()` - Compare 4 alignments
- `balance()` - Final coordinate assignment

**Complexity:** O(V+E) - linear

---

## Supporting Structures

### Edge Normalization (`normalize.js`)

- `run()` - Break long edges into unit-length segments with dummy nodes
- `undo()` - Restore original edges, convert dummy coordinates to bend points

### Nesting/Compounds (`nesting-graph.js`)

- Handle subgraph boundaries with dummy border nodes
- Ensure nodes stay within subgraph ranks

### Coordinate Transformations (`coordinate-system.js`)

- `adjust()` - Swap width/height for LR/RL directions
- `undo()` - Reverse transformations, swap X/Y for different directions

---

## Data Flow Summary

```
Input Graph
  → acyclic.run() → DAG
  → rank() → Graph with rank assignments
  → order() → Graph with order assignments
  → position() → Graph with x,y coordinates
  → normalize.undo() → Edge bend points
  → updateInputGraph() → Output
```

---

## Key Algorithms & Complexity

| Phase | Algorithm | Complexity |
|-------|-----------|------------|
| Acyclic | DFS FAS | O(V+E) |
| Ranking | Network Simplex | O(V³) average |
| Ordering | Barycenter Heuristic | O(E × iterations) |
| Crossing Count | Bilayer Tree | O(E log V) |
| Positioning | Brandes-Köpf | O(V+E) |

---

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `rankdir` | `TB` | Layout direction: TB, BT, LR, RL |
| `nodesep` | 50 | Horizontal separation between nodes |
| `ranksep` | 50 | Vertical separation between ranks |
| `edgesep` | 10 | Horizontal separation between edges |
| `ranker` | `network-simplex` | Algorithm: `network-simplex`, `tight-tree`, `longest-path` |
| `acyclicer` | `undefined` (DFS) | Cycle removal: DFS (default) or `"greedy"` (optional) |
