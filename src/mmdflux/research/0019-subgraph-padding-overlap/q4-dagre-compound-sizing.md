# Q4: dagre.js compound node sizing and padding

## Summary

dagre.js handles compound node sizing using **border nodes** (dummy nodes marked with `dummy: "border"`) that are created for each layer of the subgraph's minRank to maxRank range. The final compound dimensions are calculated from the coordinates of these border nodes: the compound width and height are computed as the absolute distance between the rightmost/leftmost border nodes (for width) and top/bottom border nodes (for height). The `marginx` and `marginy` graph config options are applied as global padding around the entire graph, not per-compound.

## Where

Sources consulted:
- `/Users/kevin/src/dagre/lib/add-border-segments.js` (lines 5-37): Border node creation
- `/Users/kevin/src/dagre/lib/nesting-graph.js` (lines 31-96): Nesting graph structure and compound boundaries
- `/Users/kevin/src/dagre/lib/layout.js` (lines 99-100, 192-203, 309-330): Graph config, rank assignment, dimension calculation
- `/Users/kevin/src/dagre/lib/position/index.js` (lines 15-41): Y-coordinate assignment
- `/Users/kevin/src/dagre/lib/util.js` (lines 199-209): Border node creation helper

## What

**Border Node Creation:**
- Border nodes are created in `addBorderSegments()` for every compound (subgraph) that has a `minRank` and `maxRank` property
- For each rank between minRank and maxRank (inclusive), two border nodes are created: `borderLeft` and `borderRight`
- These border nodes have properties: `width: 0, height: 0, rank: rank, borderType: "borderLeft" | "borderRight"`
- Border nodes are stored in arrays on the compound node: `node.borderLeft[]` and `node.borderRight[]`
- Border nodes are parented to the compound, making them part of the compound's internal graph structure

**Dimension Assignment:**
- Border nodes start with `width: 0, height: 0` and maintain these dimensions throughout layout
- During position calculation, they receive x and y coordinates through the normal position algorithm
- The actual compound dimensions are calculated AFTER position assignment in `removeBorderNodes()` (layout.js, lines 309-330):
  - Get the rightmost border node from borderRight array: `r = g.node(node.borderRight[node.borderRight.length - 1])`
  - Get the leftmost border node from borderLeft array: `l = g.node(node.borderLeft[node.borderLeft.length - 1])`
  - Get the bottom border node from borderBottom: `b = g.node(node.borderBottom)`
  - Get the top border node from borderTop: `t = g.node(node.borderTop)`
  - Calculate: `node.width = Math.abs(r.x - l.x)`
  - Calculate: `node.height = Math.abs(b.y - t.y)`
  - Position compound center: `node.x = l.x + node.width / 2` and `node.y = t.y + node.height / 2`

**Margin Handling:**
- Graph config defines `marginx` and `marginy` (layout.js, line 99)
- These are applied globally in `translateGraph()` (lines 215-264) AFTER all node positioning:
  - Calculate minX, maxX, minY, maxY by examining all nodes' extremes
  - Subtract marginX from minX and marginY from minY
  - Shift all node coordinates by minX and minY to translate the graph
  - Final canvas size: `width = maxX - minX + marginX` and `height = maxY - minY + marginY`
- **Critical**: marginx/marginy are GLOBAL padding, not per-compound padding

**Ranking and Nesting:**
- Compounds get `minRank` and `maxRank` assigned in `assignRankMinMax()` (lines 192-203) based on their border nodes' ranks
- The nesting graph (nesting-graph.js) creates top and bottom border nodes for each compound and uses minlen constraints to prevent child nodes from sharing ranks with border nodes

## How

dagre.js compound sizing works in this sequence:

1. **Parse Input**: Identify all compounds (subgraphs) in the graph
2. **Create Nesting Structure**: nesting-graph.js creates top and bottom border nodes for each compound, ensuring compounds maintain vertical separation
3. **Layout Passes**: Run standard Sugiyama layout (rank, order, position) on the graph including border nodes
4. **Assign Border Nodes**: addBorderSegments.js creates left/right border nodes for every rank span of each compound
5. **Position All Nodes**: The position algorithm places all nodes (including border nodes with width:0, height:0) at x,y coordinates
6. **Calculate Compound Dimensions**: removeBorderNodes() reads the positioned border node coordinates and computes compound width/height as the span between border nodes
7. **Remove Border Nodes**: Delete all border nodes (they were only placeholders for positioning)
8. **Apply Global Margins**: translateGraph() applies marginx/marginy as global padding around the entire diagram
9. **Return Result**: The input graph is updated with final x, y, width, height for all nodes (including compounds)

## Why

This approach provides several benefits:

- **Border nodes as constraints**: By creating dummy nodes at compound boundaries, the layout algorithm naturally respects compound extents without special handling
- **Width determination from layout**: Rather than computing compound width from child sizes (which could be recursive and complex), dagre lets the layout algorithm position everything, then measures the actual span
- **Flexible compounds**: Compounds can have complex nested structures and the algorithm doesn't need to understand them deeply
- **Global margin simplicity**: One marginx/marginy value handles padding for the entire diagram rather than per-compound padding which would be harder to implement
- **Separation guarantees**: The border node approach ensures children don't overlap their parent's boundary

## Key Takeaways

- **Border nodes are transient**: They're created during layout specifically to guide positioning, then removed. They don't appear in the final output.
- **Zero-size border nodes**: Border nodes have `width: 0, height: 0` and act as invisible anchors, not as visual elements with thickness
- **Compound size is derived, not specified**: Unlike input nodes (which have explicit width/height), compound dimensions are calculated from border node positions
- **No per-compound padding**: dagre doesn't support margin/padding per compound. Only global marginx/marginy exists.
- **Border nodes in every layer**: For a compound spanning ranks [2, 5], left and right border nodes exist at ranks 2, 3, 4, 5 — one pair per layer
- **updateInputGraph copies dimensions**: After layout, only compound nodes' width and height are copied back to the input graph (layout.js lines 77-80)

## Open Questions

- How does dagre handle deeply nested compounds (compounds within compounds)? Does the nesting graph handle this recursively?
- Are there any special considerations for compounds in LR/RL modes vs TB/BT modes, or does the algorithm work uniformly?
- When border nodes participate in edge routing/rendering, how are they handled since they're supposed to be invisible?
- What's the exact coordinate assignment order for border nodes — are they treated like regular dummy nodes in the position algorithm?
- How does the algorithm handle compounds with very few children, or single-child compounds?
