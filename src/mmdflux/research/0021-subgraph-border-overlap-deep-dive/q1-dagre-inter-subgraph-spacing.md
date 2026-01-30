# Q1: How does dagre.js guarantee inter-subgraph spacing?

## Summary

Dagre.js guarantees inter-subgraph spacing through a multi-layered approach: **(1) border nodes** create explicit boundaries for each compound node at every rank level, **(2) nesting edges** constrain minimum rank separations between border nodes, and **(3) horizontal coordinate assignment** uses these border nodes in the Brandes-Köpf algorithm to enforce spacing as part of the block graph construction. The sibling subgraph ordering is maintained implicitly through the border node architecture rather than explicit ordering constraints.

## Where

**Files read:**
- `/Users/kevin/src/dagre/lib/nesting-graph.js` (lines 1-127) — Border node creation and nesting edges
- `/Users/kevin/src/dagre/lib/add-border-segments.js` (lines 1-38) — Per-rank border segments
- `/Users/kevin/src/dagre/lib/order/add-subgraph-constraints.js` (lines 1-51) — Subgraph ordering constraints
- `/Users/kevin/src/dagre/lib/layout.js` (lines 309-330: `removeBorderNodes()`, lines 30-58: `runLayout()`)
- `/Users/kevin/src/dagre/lib/position/bk.js` (lines 206-287: `horizontalCompaction()`, lines 389-425: `sep()`)
- `/Users/kevin/src/dagre/lib/coordinate-system.js` (lines 1-71) — No compound-specific logic
- `/Users/kevin/src/dagre/lib/rank/index.js` (lines 1-54) — Ranking ignores compound structure
- `/Users/kevin/src/dagre/lib/order/index.js` (lines 28-116) — Order algorithm
- `/Users/kevin/src/dagre/lib/order/build-layer-graph.js` (lines 38-79) — Border node inclusion in ordering
- `/Users/kevin/src/dagre/lib/order/sort-subgraph.js` (lines 1-74) — Recursive subgraph sorting
- `/Users/kevin/src/dagre/lib/parent-dummy-chains.js` (lines 1-84) — Path assignment for edges crossing compounds
- `/Users/kevin/src/dagre/lib/util.js` (lines 199-209: `addBorderNode()`, lines 62-73: `asNonCompoundGraph()`)

## What

### 1. Border Node Creation (Nesting Graph Phase)

**nesting-graph.js:**
- For each compound node `v` with children, two special border nodes are created:
  - `borderTop` — dummy node placed at the minimum rank of the compound
  - `borderBottom` — dummy node placed at the maximum rank of the compound
- These border nodes become **children** of the compound node in the graph hierarchy
- All real children must have ranks between `borderTop.rank` and `borderBottom.rank`
- The weight formula for nesting edges (line 78):
  ```javascript
  thisWeight = childNode.borderTop ? weight : 2 * weight
  ```
  where `weight = sumWeights(g) + 1` (line 44)
  - If child is itself a compound: weight = `weight` (lighter)
  - If child is a leaf node: weight = `2 * weight` (heavier)
- Minlen formula for nesting edges (line 79):
  ```javascript
  minlen = childTop !== childBottom ? 1 : height - depths[v] + 1
  ```
  This ensures proper vertical spacing based on nesting depth

### 2. Per-Rank Border Segments

**add-border-segments.js:**
- After ranking assigns minRank/maxRank to each compound node, border segments are created
- For each rank from `minRank` to `maxRank`, **two dummy border nodes** are created per compound:
  - `borderLeft[rank]` — left boundary for that rank
  - `borderRight[rank]` — right boundary for that rank
- These form vertical chains (line 35): consecutive border nodes at the same compound have edges with weight 1
- Border nodes have zero width/height (line 29): `{ width: 0, height: 0, rank: rank, borderType: prop }`

### 3. Rank Constraints

**layout.js - assignRankMinMax() (lines 192-203):**
- For each compound node, minRank and maxRank are derived from the border nodes:
  ```javascript
  node.minRank = g.node(node.borderTop).rank
  node.maxRank = g.node(node.borderBottom).rank
  ```
- These constraints ensure no real node gets placed outside the compound's bounds

### 4. Subgraph Ordering Constraints

**add-subgraph-constraints.js (lines 1-51):**
- The implementation is **minimal** — it only handles ordering of **nested** subgraphs (parent-child relationships)
- Algorithm (lines 7-26):
  - Iterates through ordered vertices `vs`
  - For each vertex, walks up the hierarchy to find parent relationships
  - When a different sibling has been seen before at the same parent level, adds an ordering edge in the constraint graph `cg`
  - Returns early after first constraint added
- **Critical observation**: Sibling subgraph ordering is **NOT** explicitly constrained at the same parent level. The algorithm only adds edges for ancestor-level subgraphs.
- Commented-out code (lines 29-50) shows a previous implementation that **did** explicitly sort siblings

### 5. Order and Horizontal Positioning

**order/index.js (lines 66-112):**
- `buildLayerGraphs()` includes compound nodes in each layer where they have `minRank <= rank <= maxRank`
- `buildLayerGraph()` in `build-layer-graph.js` (lines 51-68):
  - For each compound node in the layer, includes its `borderLeft[rank]` and `borderRight[rank]` nodes
  - These border nodes are part of the ordering layer graph
  - When sorting happens, borders naturally position themselves and their children inside

**sort-subgraph.js (lines 1-74):**
- Recursively sorts subgraphs by:
  1. Calculating barycenter of children (line 18)
  2. Resolving conflicts (line 29)
  3. Sorting (line 32)
  4. For compounds with borders, wraps result with `[bl, ...content, br]` (line 35)
  5. Merges barycenter of borders with barycenter of content (lines 43-45)

### 6. Horizontal Compaction (Brandes-Köpf)

**position/bk.js - horizontalCompaction() (lines 206-287):**
- Converts node ordering into actual X coordinates
- Creates a **block graph** where nodes are grouped into alignment blocks
- For each adjacent pair in a layer, calculates the minimum separation using `sep()` function (line 270):
  ```javascript
  sepFn = sep(graphLabel.nodesep, graphLabel.edgesep, reverseSep)
  ```

**sep() function (lines 389-425):**
- Calculates required separation between two adjacent nodes `v` and `w`:
  ```javascript
  sum = vLabel.width / 2
  sum += (vLabel.dummy ? edgeSep : nodeSep) / 2
  sum += (wLabel.dummy ? edgeSep : nodeSep) / 2
  sum += wLabel.width / 2
  ```
- **Key insight**: Border nodes have `width: 0`, so they contribute 0 to separation
- Real nodes contribute `nodeSep / 2` on each side (default 50 in layout.js line 100: `nodesep: 50`)
- The separation is calculated between border nodes and actual nodes
- Example for `subgraph1 [border_right] <-> [border_left] subgraph2`:
  - `border_right.width / 2 = 0`
  - `edgeSep / 2` (default 20, line 100) — between border and next layer
  - `edgeSep / 2` — between previous layer and border
  - `border_left.width / 2 = 0`
  - Total minimum separation = `20` (edgeSep default)

### 7. Border Node Removal and Final Bounds

**layout.js - removeBorderNodes() (lines 309-330):**
- After positioning all nodes, border nodes are removed
- The compound node's bounding box is derived from border node positions:
  ```javascript
  node.width = Math.abs(r.x - l.x)   // Distance from rightmost to leftmost border
  node.height = Math.abs(b.y - t.y)  // Distance from bottom to top border
  node.x = l.x + node.width / 2      // Center between left and right
  node.y = t.y + node.height / 2     // Center between top and bottom
  ```
- This formula naturally expands the compound to fully contain all children

### 8. Coordinate System Adjustments

**coordinate-system.js:**
- Handles orientation swaps (LR → TB, BT → RL)
- No special compound node handling — all coordinate transforms apply uniformly

## How

### Step-by-Step Spacing Guarantee

1. **Build nesting graph** (nesting-graph.js)
   - Create `borderTop` and `borderBottom` for each compound
   - Connect children to borders with weighted nesting edges
   - Higher weight = stronger preference to keep structure compact

2. **Ranking** (rank/index.js)
   - Runs on the **entire** graph including border nodes
   - Minlen constraints force minimum rank separations
   - Compound's minRank and maxRank are determined by its border nodes' ranks

3. **Normalize and add border segments** (normalize.js, add-border-segments.js)
   - Split long edges into dummy chains
   - For each rank in `[minRank, maxRank]`, add `borderLeft[rank]` and `borderRight[rank]`
   - Chain them vertically with weight-1 edges to maintain vertical alignment

4. **Order** (order/index.js)
   - For each layer, include nodes + their border segments
   - Build layer graphs that preserve hierarchy
   - Sort to minimize edge crossings
   - Border nodes naturally position themselves as children are ordered

5. **Position X-coordinates** (position/bk.js)
   - Apply Brandes-Köpf algorithm
   - Calculate separations between adjacent nodes using `sep()`
   - Border nodes (width=0) don't consume space themselves
   - The `edgeSep` parameter (default 20) becomes the inter-subgraph gap

6. **Position Y-coordinates** (position/index.js)
   - Apply `rankSep` (default 50) uniformly across all ranks
   - Border nodes are positioned at their assigned ranks

7. **Remove borders** (layout.js)
   - Calculate compound's bounding box from positioned border nodes
   - Formula: `width = right.x - left.x`, center = `left.x + width/2`
   - This box now contains all children

### Spacing Formula

For sibling subgraphs at the same layer:
```
gap = edgeSep  (default 20)
     = distance from rightmost border_right.x to leftmost border_left.x
     = sum of sep() calculations between adjacent order positions
```

For subgraphs at different ranks:
```
gap = rankSep  (default 50)
     = vertical spacing between layers
```

## Why

1. **Generality**: The border node architecture works for arbitrarily nested compounds
2. **Consistency**: Uses the same ranking and ordering machinery as regular nodes
3. **Efficiency**: Border nodes have zero width, so they don't add layout complexity
4. **Separation parameter flexibility**: `edgeSep` and `nodeSep` control gaps without special compound logic
5. **Implicit ordering**: Sibling ordering emerges naturally from the hierarchy preservation in the order phase

**Trade-off**: The current `add-subgraph-constraints.js` implementation (lines 7-26) is **minimal**. The commented-out code suggests earlier versions tried to explicitly order siblings, but this was replaced with a simpler hierarchy-based approach that relies on the order algorithm's barycenter heuristic.

## Key Takeaways

- **Border nodes are the mechanism**: Every compound node has explicit `borderTop`, `borderBottom`, `borderLeft[rank]`, and `borderRight[rank]` nodes that define its boundaries
- **Zero width is critical**: Because border nodes have width 0, they don't consume space in the block graph, allowing the `sep()` function to create tight coupling
- **Spacing comes from `edgeSep`**: The gap between sibling subgraphs is the `edgeSep` parameter (default 20), applied in the Brandes-Köpf block graph calculation
- **Ranking prevents overlap vertically**: Nesting edges ensure children can't escape above/below their parent's bounds
- **Ordering preserves hierarchy**: The order algorithm includes border nodes in layer graphs, ensuring children stay grouped
- **Final bounds are derived**: Compound node width/height are calculated post-positioning from border node coordinates
- **Subgraph constraints are minimal**: Current implementation doesn't explicitly order siblings; ordering emerges from barycenter-based heuristics

## Open Questions

- Why was the explicit sibling ordering constraint (commented-out code in add-subgraph-constraints.js) removed? Was it causing issues with the optimal order heuristic?
- How does the algorithm handle edge cases like overlapping `borderLeft` and `borderRight` nodes when compounds are too narrow?
- What happens if `edgeSep` is set to 0 or negative? Would subgraphs overlap?
- How do self-edges interact with the border node system?
