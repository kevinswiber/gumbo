# Dagre Ordering Algorithm Analysis

This document analyzes Dagre's node ordering algorithm, which determines the left-to-right order of nodes within each layer to minimize edge crossings.

## What: Purpose and Goals

### The Problem

In layered graph layout, after nodes are assigned to layers (ranks), we need to determine their horizontal order within each layer. Poor ordering leads to many edge crossings, making the diagram hard to read.

**Example:** Given a graph with layers:
```
Layer 1:  A  B
Layer 2:  C  D  E
```

If A connects to D and E, and B connects to C, bad ordering might cause edges to cross. Good ordering minimizes these crossings.

### Goals

1. **Minimize edge crossings** - The primary objective
2. **Maintain stability** - Similar inputs should produce similar outputs
3. **Handle compound graphs** - Support subgraphs/clusters with border constraints
4. **Be efficient** - Work well on real-world graph sizes

### Key Invariants

From `lib/order/index.js` preconditions:
- Graph must be a DAG (directed acyclic graph)
- Nodes must have a `rank` attribute
- Edges must have a `weight` attribute

Post-condition: Each node receives an `order` attribute indicating its position within its layer.

## Where: Key Functions and Their Roles

### File Structure

```
lib/order/
  index.js              -- Main entry point (order function)
  init-order.js         -- Initial ordering via DFS
  barycenter.js         -- Calculate node barycenters
  sort-subgraph.js      -- Sort nodes within subgraphs
  resolve-conflicts.js  -- Handle constraint conflicts
  sort.js               -- Final sort with bias parameter
  cross-count.js        -- Count edge crossings (quality metric)
  build-layer-graph.js  -- Build per-layer graphs for sorting
  add-subgraph-constraints.js -- Handle compound graph constraints
```

### Main Entry Point: `order(g, opts)`

**File:** `$HOME/src/dagre/lib/order/index.js`

```javascript
function order(g, opts = {}) {
  if (typeof opts.customOrder === 'function') {
    opts.customOrder(g, order);
    return;
  }

  let maxRank = util.maxRank(g),
    downLayerGraphs = buildLayerGraphs(g, util.range(1, maxRank + 1), "inEdges"),
    upLayerGraphs = buildLayerGraphs(g, util.range(maxRank - 1, -1, -1), "outEdges");

  let layering = initOrder(g);
  assignOrder(g, layering);

  if (opts.disableOptimalOrderHeuristic) {
    return;
  }

  let bestCC = Number.POSITIVE_INFINITY,
    best;

  const constraints = opts.constraints || [];
  for (let i = 0, lastBest = 0; lastBest < 4; ++i, ++lastBest) {
    sweepLayerGraphs(i % 2 ? downLayerGraphs : upLayerGraphs, i % 4 >= 2, constraints);

    layering = util.buildLayerMatrix(g);
    let cc = crossCount(g, layering);
    if (cc < bestCC) {
      lastBest = 0;
      best = Object.assign({}, layering);
      bestCC = cc;
    } else if (cc === bestCC) {
      best = structuredClone(layering);
    }
  }

  assignOrder(g, best);
}
```

### Helper Functions

#### `initOrder(g)` - Initial Ordering

**File:** `$HOME/src/dagre/lib/order/init-order.js`

Creates initial node ordering using depth-first search from top-ranked nodes.

```javascript
function initOrder(g) {
  let visited = {};
  let simpleNodes = g.nodes().filter(v => !g.children(v).length);
  let simpleNodesRanks = simpleNodes.map(v => g.node(v).rank);
  let maxRank = util.applyWithChunking(Math.max, simpleNodesRanks);
  let layers = util.range(maxRank + 1).map(() => []);

  function dfs(v) {
    if (visited[v]) return;
    visited[v] = true;
    let node = g.node(v);
    layers[node.rank].push(v);
    g.successors(v).forEach(dfs);
  }

  let orderedVs = simpleNodes.sort((a, b) => g.node(a).rank - g.node(b).rank);
  orderedVs.forEach(dfs);

  return layers;
}
```

**Algorithm:** Sort nodes by rank, then DFS from each, adding nodes to their layer as first visited. This creates a reasonable initial ordering that respects graph structure.

**Reference:** From Gansner, et al., "A Technique for Drawing Directed Graphs."

#### `barycenter(g, movable)` - Calculate Barycenters

**File:** `$HOME/src/dagre/lib/order/barycenter.js`

Computes the weighted average position of predecessors for each node.

```javascript
function barycenter(g, movable = []) {
  return movable.map(v => {
    let inV = g.inEdges(v);
    if (!inV.length) {
      return { v: v };
    } else {
      let result = inV.reduce((acc, e) => {
        let edge = g.edge(e),
          nodeU = g.node(e.v);
        return {
          sum: acc.sum + (edge.weight * nodeU.order),
          weight: acc.weight + edge.weight
        };
      }, { sum: 0, weight: 0 });

      return {
        v: v,
        barycenter: result.sum / result.weight,
        weight: result.weight
      };
    }
  });
}
```

**Formula:** `barycenter = sum(predecessor.order * edge.weight) / sum(edge.weight)`

Nodes without predecessors get no barycenter (undefined), making them "unsortable."

#### `sortSubgraph(g, v, cg, biasRight)` - Sort Subgraph Nodes

**File:** `$HOME/src/dagre/lib/order/sort-subgraph.js`

Recursively sorts nodes within a subgraph, handling compound graph hierarchy.

```javascript
function sortSubgraph(g, v, cg, biasRight) {
  let movable = g.children(v);
  let node = g.node(v);
  let bl = node ? node.borderLeft : undefined;
  let br = node ? node.borderRight: undefined;
  let subgraphs = {};

  if (bl) {
    movable = movable.filter(w => w !== bl && w !== br);
  }

  let barycenters = barycenter(g, movable);
  barycenters.forEach(entry => {
    if (g.children(entry.v).length) {
      let subgraphResult = sortSubgraph(g, entry.v, cg, biasRight);
      subgraphs[entry.v] = subgraphResult;
      if (Object.hasOwn(subgraphResult, "barycenter")) {
        mergeBarycenters(entry, subgraphResult);
      }
    }
  });

  let entries = resolveConflicts(barycenters, cg);
  expandSubgraphs(entries, subgraphs);

  let result = sort(entries, biasRight);

  if (bl) {
    result.vs = [bl, result.vs, br].flat(true);
    // ... handle border node barycenters
  }

  return result;
}
```

**Key steps:**
1. Get movable children (excluding border nodes)
2. Calculate barycenters
3. Recursively sort nested subgraphs
4. Resolve constraint conflicts
5. Expand subgraph placeholders
6. Final sort with bias
7. Add border nodes back at edges

#### `resolveConflicts(entries, cg)` - Handle Constraint Violations

**File:** `$HOME/src/dagre/lib/order/resolve-conflicts.js`

Resolves conflicts between barycenter-based ordering and constraint graph requirements.

```javascript
function resolveConflicts(entries, cg) {
  let mappedEntries = {};
  entries.forEach((entry, i) => {
    let tmp = mappedEntries[entry.v] = {
      indegree: 0,
      "in": [],
      out: [],
      vs: [entry.v],
      i: i
    };
    if (entry.barycenter !== undefined) {
      tmp.barycenter = entry.barycenter;
      tmp.weight = entry.weight;
    }
  });

  cg.edges().forEach(e => {
    let entryV = mappedEntries[e.v];
    let entryW = mappedEntries[e.w];
    if (entryV !== undefined && entryW !== undefined) {
      entryW.indegree++;
      entryV.out.push(mappedEntries[e.w]);
    }
  });

  let sourceSet = Object.values(mappedEntries).filter(entry => !entry.indegree);
  return doResolveConflicts(sourceSet);
}
```

**Reference:** Based on Forster, "A Fast and Simple Heuristic for Constrained Two-Level Crossing Reduction."

When barycenter ordering would violate a constraint (A must be left of B), nodes are coalesced into a single entry with aggregated barycenter.

#### `sort(entries, biasRight)` - Final Sort with Bias

**File:** `$HOME/src/dagre/lib/order/sort.js`

```javascript
function sort(entries, biasRight) {
  let parts = util.partition(entries, entry => {
    return Object.hasOwn(entry, "barycenter");
  });
  let sortable = parts.lhs,
    unsortable = parts.rhs.sort((a, b) => b.i - a.i),
    vs = [],
    sum = 0,
    weight = 0,
    vsIndex = 0;

  sortable.sort(compareWithBias(!!biasRight));

  vsIndex = consumeUnsortable(vs, unsortable, vsIndex);

  sortable.forEach(entry => {
    vsIndex += entry.vs.length;
    vs.push(entry.vs);
    sum += entry.barycenter * entry.weight;
    weight += entry.weight;
    vsIndex = consumeUnsortable(vs, unsortable, vsIndex);
  });

  let result = { vs: vs.flat(true) };
  if (weight) {
    result.barycenter = sum / weight;
    result.weight = weight;
  }
  return result;
}

function compareWithBias(bias) {
  return (entryV, entryW) => {
    if (entryV.barycenter < entryW.barycenter) {
      return -1;
    } else if (entryV.barycenter > entryW.barycenter) {
      return 1;
    }
    return !bias ? entryV.i - entryW.i : entryW.i - entryV.i;
  };
}
```

**Key behaviors:**
- Partitions entries into sortable (have barycenter) and unsortable
- Sorts by barycenter, with **bias as tiebreaker**
- Interleaves unsortable entries at their original positions

#### `crossCount(g, layering)` - Count Edge Crossings

**File:** `$HOME/src/dagre/lib/order/cross-count.js`

Counts weighted crossings using the Barth et al. accumulator tree algorithm.

```javascript
function crossCount(g, layering) {
  let cc = 0;
  for (let i = 1; i < layering.length; ++i) {
    cc += twoLayerCrossCount(g, layering[i-1], layering[i]);
  }
  return cc;
}

function twoLayerCrossCount(g, northLayer, southLayer) {
  let southPos = zipObject(southLayer, southLayer.map((v, i) => i));
  let southEntries = northLayer.flatMap(v => {
    return g.outEdges(v).map(e => {
      return { pos: southPos[e.w], weight: g.edge(e).weight };
    }).sort((a, b) => a.pos - b.pos);
  });

  // Build accumulator tree
  let firstIndex = 1;
  while (firstIndex < southLayer.length) firstIndex <<= 1;
  let treeSize = 2 * firstIndex - 1;
  firstIndex -= 1;
  let tree = new Array(treeSize).fill(0);

  // Calculate weighted crossings
  let cc = 0;
  southEntries.forEach(entry => {
    let index = entry.pos + firstIndex;
    tree[index] += entry.weight;
    let weightSum = 0;
    while (index > 0) {
      if (index % 2) {
        weightSum += tree[index + 1];
      }
      index = (index - 1) >> 1;
      tree[index] += entry.weight;
    }
    cc += entry.weight * weightSum;
  });

  return cc;
}
```

**Reference:** Barth, et al., "Simple and Efficient Bilayer Cross Counting" - O(|E| log |V|) algorithm.

## How: The Algorithm Steps

### Overview

1. **Initialize** ordering via DFS
2. **Build layer graphs** for up and down sweeps
3. **Iterate** with alternating sweeps and bias until no improvement
4. **Track best** ordering by crossing count
5. **Apply** best ordering to graph

### Step 1: Initial Ordering

```javascript
let layering = initOrder(g);
assignOrder(g, layering);
```

DFS from top-ranked nodes establishes initial order. This gives a reasonable starting point that tends to keep connected nodes close together.

### Step 2: Build Layer Graphs

```javascript
let downLayerGraphs = buildLayerGraphs(g, util.range(1, maxRank + 1), "inEdges");
let upLayerGraphs = buildLayerGraphs(g, util.range(maxRank - 1, -1, -1), "outEdges");
```

Creates two sets of graphs:
- **Down sweeps**: ranks 1 to max, using incoming edges (predecessors are fixed)
- **Up sweeps**: ranks max-1 to 0, using outgoing edges (successors are fixed)

### Step 3: Sweep Mechanism

```javascript
for (let i = 0, lastBest = 0; lastBest < 4; ++i, ++lastBest) {
  sweepLayerGraphs(i % 2 ? downLayerGraphs : upLayerGraphs, i % 4 >= 2, constraints);
  // ...
}
```

#### Sweep Direction Alternation: `i % 2`

| i | i % 2 | Direction |
|---|-------|-----------|
| 0 | 0 | Up (upLayerGraphs) |
| 1 | 1 | Down (downLayerGraphs) |
| 2 | 0 | Up |
| 3 | 1 | Down |
| 4 | 0 | Up |
| ... | ... | ... |

Alternates between:
- **Up sweep**: Process layers from bottom to top, using successors' positions
- **Down sweep**: Process layers from top to bottom, using predecessors' positions

#### Bias Pattern: `i % 4 >= 2`

| i | i % 4 | i % 4 >= 2 | biasRight |
|---|-------|------------|-----------|
| 0 | 0 | false | false (bias left) |
| 1 | 1 | false | false (bias left) |
| 2 | 2 | true | true (bias right) |
| 3 | 3 | true | true (bias right) |
| 4 | 0 | false | false (bias left) |
| ... | ... | ... | ... |

**Pattern:** false, false, true, true (repeating)

### Step 4: The Bias Parameter

When two nodes have **equal barycenters**, the bias determines which comes first:

```javascript
function compareWithBias(bias) {
  return (entryV, entryW) => {
    if (entryV.barycenter < entryW.barycenter) {
      return -1;
    } else if (entryV.barycenter > entryW.barycenter) {
      return 1;
    }
    // Tiebreaker when barycenters are equal:
    return !bias ? entryV.i - entryW.i : entryW.i - entryV.i;
  };
}
```

- **biasRight = false**: Sort by original index ascending (keep original left-to-right order)
- **biasRight = true**: Sort by original index descending (reverse original order)

This helps escape local minima where equal barycenters mask potential improvements.

### Step 5: Iteration and Termination

```javascript
for (let i = 0, lastBest = 0; lastBest < 4; ++i, ++lastBest) {
  // ... sweep ...

  let cc = crossCount(g, layering);
  if (cc < bestCC) {
    lastBest = 0;  // Reset counter on improvement
    best = Object.assign({}, layering);
    bestCC = cc;
  } else if (cc === bestCC) {
    best = structuredClone(layering);
  }
}
```

**Termination condition:** Stop when 4 consecutive iterations fail to improve crossing count.

This ensures:
- At least 4 iterations (one full cycle of bias patterns)
- Continues as long as improvements are found
- Eventually terminates when stuck

### Step 6: Apply Best Ordering

```javascript
assignOrder(g, best);
```

Sets `order` attribute on each node based on best-found layering.

## Why: Design Choices

### Why Alternating Up/Down Sweeps?

1. **Bi-directional influence**: Down sweeps let parents influence children; up sweeps let children influence parents
2. **Propagation**: Changes in one layer propagate through the graph
3. **Balance**: Avoids bias toward either direction

From the academic literature (Gansner et al.): alternating sweeps is a standard technique in the barycenter heuristic, as single-direction sweeps can get stuck in local optima.

### Why the Bias Pattern (false, false, true, true)?

The pattern ensures exploration of different orderings:

1. **Two iterations with each bias**: Gives the current direction time to stabilize
2. **Alternating bias pairs**: Helps escape local minima

When nodes have equal barycenters, different tie-breaking can lead to different crossing counts. By trying both, the algorithm explores more of the solution space.

**From test file comments:**
```javascript
it("biases to the left by default", () => {
  // With equal barycenters, original order preserved
});

it("biases to the right if biasRight = true", () => {
  // With equal barycenters, original order reversed
});
```

### Why Track "Best" Ordering?

The heuristic doesn't guarantee monotonic improvement. Tracking the best:
1. **Prevents regression**: Later iterations might increase crossings
2. **Allows exploration**: Can try different configurations without losing progress
3. **Handles oscillation**: Algorithm might oscillate between configurations

### Why DFS for Initial Order?

From `init-order.js` comments:
> "This approach comes from Gansner, et al., 'A Technique for Drawing Directed Graphs.'"

DFS naturally places connected nodes close together, providing a good starting point that the optimization refines.

### Why Coalesce Conflicting Nodes?

From `resolve-conflicts.js` comments:
> "This implementation is based on the description in Forster, 'A Fast and Simple Heuristic for Constrained Two-Level Crossing Reduction.'"

When constraints conflict with barycenter ordering, merging nodes:
1. **Respects constraints**: Merged nodes move together
2. **Averages barycenters**: Combined position is weighted average
3. **Maintains tractability**: Doesn't need to solve constraint satisfaction

### Why the Accumulator Tree for Cross Counting?

From `cross-count.js` comments:
> "This algorithm is derived from Barth, et al., 'Bilayer Cross Counting.'"

The tree provides O(|E| log |V|) counting vs naive O(|E|^2), crucial since cross counting happens every iteration.

## Summary: Data Flow

```
                                   +-----------------+
                                   |   Input Graph   |
                                   |  (with ranks)   |
                                   +-----------------+
                                           |
                                           v
                                   +-----------------+
                                   |   initOrder()   |
                                   |   (DFS-based)   |
                                   +-----------------+
                                           |
                                           v
                                   +-----------------+
                                   | buildLayerGraphs|
                                   | (up + down)     |
                                   +-----------------+
                                           |
                                           v
                         +----------------------------------+
                         |          Main Loop              |
                         |  for each iteration until       |
                         |  4 consecutive non-improvements |
                         +----------------------------------+
                                           |
                    +----------------------+----------------------+
                    |                                             |
                    v                                             v
           +-----------------+                           +-----------------+
           |  Up Sweep       |                           |  Down Sweep     |
           |  (i % 2 == 0)   |                           |  (i % 2 == 1)   |
           +-----------------+                           +-----------------+
                    |                                             |
                    +----------------------+----------------------+
                                           |
                                           v
                                   +-----------------+
                                   | sweepLayerGraphs|
                                   +-----------------+
                                           |
                         +-----------------)------------------+
                         |                 |                  |
                         v                 v                  v
                   +-----------+    +-------------+    +-----------+
                   | barycenter|    |resolveConfl.|    |   sort    |
                   +-----------+    +-------------+    +-----------+
                                           |
                                           v
                                   +-----------------+
                                   |  crossCount()   |
                                   +-----------------+
                                           |
                                           v
                                   +-----------------+
                                   |  Track best if  |
                                   |  cc < bestCC    |
                                   +-----------------+
                                           |
                                           v
                                   +-----------------+
                                   |  assignOrder()  |
                                   |  (apply best)   |
                                   +-----------------+
```

## Academic References

1. **Gansner, Koutsofios, North, Vo** - "A Technique for Drawing Directed Graphs" (1993)
   - Overall framework for layered graph drawing
   - DFS-based initial ordering

2. **Junger and Mutzel** - "2-Layer Straightline Crossing Minimization: Performance of Exact and Heuristic Algorithms" (1997)
   - Comparison of crossing minimization approaches
   - Barycenter heuristic analysis

3. **Barth, Junger, Mutzel** - "Simple and Efficient Bilayer Cross Counting" (2002)
   - O(|E| log |V|) cross counting algorithm
   - Accumulator tree data structure

4. **Forster** - "A Fast and Simple Heuristic for Constrained Two-Level Crossing Reduction" (2002)
   - Constraint handling in crossing minimization
   - Node coalescing approach

## Key Takeaways for mmdflux Implementation

1. **Initial ordering matters** - DFS provides good starting point
2. **Iterate with alternating sweeps** - Both up and down directions needed
3. **Use bias parameter** - Helps escape local minima
4. **Track best solution** - Don't assume monotonic improvement
5. **Efficient cross counting** - Use tree-based algorithm if performance matters
6. **Barycenter formula** - Weighted average of connected nodes' positions
