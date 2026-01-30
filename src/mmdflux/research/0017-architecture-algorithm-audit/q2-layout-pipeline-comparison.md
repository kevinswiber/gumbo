# Q2: Layout Pipeline Comparison

## Summary

Dagre.js executes 27 pipeline steps in its `runLayout()` function; mmdflux implements 6 of these (the core Sugiyama phases) and omits 21. The missing steps fall into three categories: (1) compound graph support (nesting graph, parent dummy chains, border segments, rank min/max assignment, border node removal), (2) edge label positioning infrastructure (makeSpaceForEdgeLabels, edge label proxies, fixupEdgeLabelCoords), and (3) post-layout fixups (self-edge handling, coordinate system transformations, graph translation, node intersection computation, reverse-points-for-reversed-edges). Most missing steps are either compound-graph-specific (not needed until subgraph support is added) or handled differently by mmdflux's rendering layer rather than the layout engine.

## Where

Sources consulted:

- **Dagre.js pipeline**: `/Users/kevin/src/dagre/lib/layout.js` (lines 30-58, the `runLayout()` function)
- **Dagre.js nesting graph**: `/Users/kevin/src/dagre/lib/nesting-graph.js`
- **Dagre.js parent dummy chains**: `/Users/kevin/src/dagre/lib/parent-dummy-chains.js`
- **Dagre.js border segments**: `/Users/kevin/src/dagre/lib/add-border-segments.js`
- **Dagre.js coordinate system**: `/Users/kevin/src/dagre/lib/coordinate-system.js`
- **Dagre.js normalize**: `/Users/kevin/src/dagre/lib/normalize.js`
- **Dagre.js util** (normalizeRanks, removeEmptyRanks): `/Users/kevin/src/dagre/lib/util.js` (lines 156-197)
- **mmdflux pipeline**: `/Users/kevin/src/mmdflux/src/dagre/mod.rs` (lines 64-240, the `layout_with_labels()` function)
- **mmdflux acyclic**: `/Users/kevin/src/mmdflux/src/dagre/acyclic.rs`
- **mmdflux rank**: `/Users/kevin/src/mmdflux/src/dagre/rank.rs`
- **mmdflux normalize**: `/Users/kevin/src/mmdflux/src/dagre/normalize.rs`
- **mmdflux order**: `/Users/kevin/src/mmdflux/src/dagre/order.rs`
- **mmdflux position**: `/Users/kevin/src/mmdflux/src/dagre/position.rs`
- **mmdflux types**: `/Users/kevin/src/mmdflux/src/dagre/types.rs`

## What

### Step-by-Step Pipeline Mapping

| # | Dagre.js Step | Function | mmdflux Equivalent | Status |
|---|--------------|----------|-------------------|--------|
| 0 | Build layout graph | `buildLayoutGraph(g)` | `LayoutGraph::from_digraph()` | **Implemented** (simpler: no compound graph, no attribute canonicalization) |
| 1 | Make space for edge labels | `makeSpaceForEdgeLabels(g)` | None | **Missing** |
| 2 | Remove self-edges | `removeSelfEdges(g)` | None | **Missing** |
| 3 | Make acyclic | `acyclic.run(g)` | `acyclic::run(&mut lg)` | **Implemented** |
| 4 | Build nesting graph | `nestingGraph.run(g)` | None | **Missing** |
| 5 | Rank assignment | `rank(asNonCompoundGraph(g))` | `rank::run(&mut lg)` | **Implemented** (longest-path vs network simplex) |
| 6 | Inject edge label proxies | `injectEdgeLabelProxies(g)` | None | **Missing** |
| 7 | Remove empty ranks | `removeEmptyRanks(g)` | None | **Missing** |
| 8 | Cleanup nesting graph | `nestingGraph.cleanup(g)` | None | **Missing** (paired with step 4) |
| 9 | Normalize ranks | `normalizeRanks(g)` | `rank::normalize(&mut lg)` | **Implemented** |
| 10 | Assign rank min/max | `assignRankMinMax(g)` | None | **Missing** |
| 11 | Remove edge label proxies | `removeEdgeLabelProxies(g)` | None | **Missing** (paired with step 6) |
| 12 | Normalize long edges | `normalize.run(g)` | `normalize::run(&mut lg, edge_labels)` | **Implemented** |
| 13 | Parent dummy chains | `parentDummyChains(g)` | None | **Missing** |
| 14 | Add border segments | `addBorderSegments(g)` | None | **Missing** |
| 15 | Crossing reduction | `order(g)` | `order::run(&mut lg)` | **Implemented** |
| 16 | Insert self-edges | `insertSelfEdges(g)` | None | **Missing** (paired with step 2) |
| 17 | Adjust coordinate system | `coordinateSystem.adjust(g)` | None (handled differently) | **Missing** |
| 18 | Position assignment | `position(g)` | `position::run(&mut lg, config)` | **Implemented** |
| 19 | Position self-edges | `positionSelfEdges(g)` | None | **Missing** (paired with step 2) |
| 20 | Remove border nodes | `removeBorderNodes(g)` | None | **Missing** (paired with step 14) |
| 21 | Denormalize | `normalize.undo(g)` | `normalize::denormalize(&lg)` | **Implemented** (extracts waypoints) |
| 22 | Fix edge label coords | `fixupEdgeLabelCoords(g)` | None | **Missing** |
| 23 | Undo coordinate system | `coordinateSystem.undo(g)` | None (handled differently) | **Missing** |
| 24 | Translate graph | `translateGraph(g)` | Built into `position::assign_vertical/assign_horizontal` | **Implemented differently** |
| 25 | Assign node intersects | `assignNodeIntersects(g)` | Handled in render layer (`router.rs`) | **Implemented differently** |
| 26 | Reverse points for reversed edges | `reversePointsForReversedEdges(g)` | Handled in render layer | **Implemented differently** |
| 27 | Undo acyclic | `acyclic.undo(g)` | Not needed (reversed_edges tracked, not mutated back) | **Implemented differently** |
| 28 | Update input graph | `updateInputGraph(g, layoutGraph)` | Not needed (result built directly) | **Implemented differently** |

### Summary Counts

- **Core steps implemented**: 8 (build graph, acyclic, rank, normalize ranks, normalize edges, order, position, denormalize)
- **Implemented differently**: 4 (translate, node intersects, reverse points, acyclic undo)
- **Compound-graph-only steps missing**: 6 (nesting graph run/cleanup, parent dummy chains, border segments, rank min/max, border node removal)
- **Self-edge steps missing**: 3 (remove, insert, position self-edges)
- **Edge label infrastructure missing**: 4 (make space, inject/remove proxies, fixup coords)
- **Coordinate system steps missing**: 2 (adjust/undo)
- **Other missing**: 1 (remove empty ranks)

## How

### What Each Missing Step Does

#### Compound Graph Steps (6 steps)

**1. nestingGraph.run (step 4)**: Creates a "nesting graph" that encodes subgraph containment as edges. It adds border dummy nodes (`_bt` top and `_bb` bottom) for each compound node, connects them with high-weight edges to enforce that children stay between their parent's borders, and adds a root node connected to all top-level nodes to guarantee graph connectivity. It scales all `minlen` values by `nodeSep` (2 * tree_height + 1) to reserve rank space for border nodes. Based on Sander's "Layout of Compound Directed Graphs."

**2. nestingGraph.cleanup (step 8)**: Removes the temporary root node and all nesting edges added in step 4, after ranking is complete. The rank information has been captured and the nesting constraints are no longer needed.

**3. assignRankMinMax (step 10)**: For compound nodes with border top/bottom dummies, records `minRank` and `maxRank` properties. These are used by `parentDummyChains` and `addBorderSegments` to know the rank span of each compound node.

**4. parentDummyChains (step 13)**: Assigns parent compound nodes to dummy nodes in normalized edge chains. When a long edge passes through a compound node, its dummies need to be children of the correct compound node in the hierarchy. Uses LCA (lowest common ancestor) to find the path between source and target through the compound hierarchy.

**5. addBorderSegments (step 14)**: For each compound node, creates left and right border dummy nodes at every rank the compound spans. These border nodes are connected with edges (forming vertical "walls") and participate in crossing reduction to ensure the compound node's visual boundary is maintained. Each border node has zero width/height and type `"border"`.

**6. removeBorderNodes (step 20)**: After positioning, computes the compound node's final dimensions from its border nodes (width = right.x - left.x, height = bottom.y - top.y), sets the compound node's center position, then removes all border dummy nodes.

#### Self-Edge Steps (3 steps)

**7. removeSelfEdges (step 2)**: Removes edges where source == target and stashes them on the node as `selfEdges` array. Self-edges would confuse the acyclic and ranking phases since they create trivial cycles. Dagre saves them for later re-insertion.

**8. insertSelfEdges (step 16)**: After crossing reduction, creates dummy nodes adjacent to each node with self-edges. The dummy gets the same rank as the node but a higher order value, effectively placing it next to the node in the layer.

**9. positionSelfEdges (step 19)**: After positioning, computes a 5-point curved path for each self-edge using the dummy's x-position to determine the loop width. The path goes up-right-down from the node, creating a visual self-loop.

**mmdflux behavior**: Self-edges (A -> A) are currently treated as back-edges by the acyclic phase. They get reversed and handled as normal edges, which may produce unexpected visual results but does not crash.

#### Edge Label Infrastructure (4 steps)

**10. makeSpaceForEdgeLabels (step 1)**: Doubles all edge `minlen` values and halves `ranksep`. This creates an extra "half-rank" between every pair of ranks where edge labels can be placed. For non-center labels (left/right position), it also pads the edge width/height by `labeloffset` to push the label away from the edge line.

**11. injectEdgeLabelProxies (step 6)**: For edges with non-zero label dimensions, creates temporary dummy nodes at the label's target rank. These proxies protect the label's rank position during `removeEmptyRanks` -- without them, the empty rank reserved for the label might be removed.

**12. removeEdgeLabelProxies (step 11)**: Removes the proxy dummies added in step 6, transferring the `labelRank` property to the edge. The rank position has been preserved through the empty-rank-removal phase.

**13. fixupEdgeLabelCoords (step 22)**: After positioning, adjusts edge label coordinates based on `labelpos` (left/center/right). For left labels, shifts x left by `width/2 + labeloffset`; for right labels, shifts right. Also removes the labeloffset padding added in step 1.

**mmdflux behavior**: Label positioning is handled through `EdgeLabelInfo` in `normalize.rs`. Labels are placed at the midpoint rank during normalization, with label dummies getting the label's actual dimensions. The rendering layer in `render/layout.rs` computes final label positions. This is simpler but only supports center-positioned labels.

#### Coordinate System Steps (2 steps)

**14. coordinateSystem.adjust (step 17)**: For LR/RL layouts, swaps width and height on all nodes and edges. This allows the position algorithm to always work in "top-to-bottom" mode -- horizontal layouts are treated as vertical after transposition.

**15. coordinateSystem.undo (step 23)**: Reverses the coordinate system adjustment. For BT/RL, negates y-coordinates. For LR/RL, swaps x/y back and swaps width/height back.

**mmdflux behavior**: Direction is handled in `position.rs` with separate `assign_vertical()` and `assign_horizontal()` functions. The BK algorithm receives a `direction` field in its config. After positioning, `reverse_positions()` handles BT/RL reversal. This is functionally equivalent but uses separate code paths rather than a transform/un-transform pattern.

#### Other Steps

**16. removeEmptyRanks (step 7)**: After ranking and nesting graph cleanup, some ranks may have no nodes (this happens when the nesting graph's scaled `minlen` values create gaps). This step compacts ranks by removing empty layers, but only those that don't fall on compound-node boundaries (`i % nodeRankFactor !== 0`).

**17. translateGraph (step 24)**: Translates all node and edge positions so the minimum x and y are at the margin. Computes bounding box width and height. In mmdflux, this is integrated into the position assignment -- `assign_vertical` shifts x by `x_shift = config.margin - min_x` and starts y at `config.margin`.

**18. assignNodeIntersects (step 25)**: Computes where edge paths intersect node boundaries using `intersectRect()`. Adds intersection points at the start and end of each edge's points array. In mmdflux, this is handled by the rendering layer in `router.rs` which computes edge attachment points.

**19. reversePointsForReversedEdges (step 26)**: For edges that were reversed during the acyclic phase, reverses the order of their edge points so they flow in the original direction. In mmdflux, the rendering layer tracks `reversed_edges` and handles routing differently for backward edges via `route_backward_edge()`.

**20. acyclic.undo (step 27)**: In Dagre.js, this re-reverses edges that were reversed for acyclicity, restoring the original edge direction in the graph data structure. In mmdflux, edges are never physically reversed -- the `reversed_edges` set tracks which edges are logically reversed, and `effective_edges()` returns the effective direction.

## Why

### Which Missing Steps Matter

#### Critical for compound graphs (needed when subgraph support is added)
- **nestingGraph run/cleanup** -- Without this, compound nodes cannot constrain their children's rank positions. Essential for `subgraph` support.
- **parentDummyChains** -- Without this, long edges passing through compound nodes won't be properly parented, leading to incorrect rendering of compound boundaries.
- **addBorderSegments / removeBorderNodes** -- Without these, compound nodes have no visual boundaries in the layout. Border segments define the left/right/top/bottom walls.
- **assignRankMinMax** -- Supports the above steps.

#### Important for edge labels (partial support exists)
- **makeSpaceForEdgeLabels** -- mmdflux doesn't create half-ranks for labels. Instead, labels are placed at the midpoint of normalized edges. This works for center-positioned labels but does not support left/right label positioning or labels on single-rank edges.
- **injectEdgeLabelProxies / removeEdgeLabelProxies** -- Only needed when `removeEmptyRanks` is implemented. Currently a non-issue since mmdflux doesn't remove empty ranks.
- **fixupEdgeLabelCoords** -- Only needed for left/right positioned labels. mmdflux currently only supports center positioning.

#### Nice to have for correctness
- **Self-edge handling (3 steps)** -- Self-loops in Mermaid diagrams (e.g., `A --> A`) are uncommon but valid. Currently handled as back-edges in mmdflux, which may produce odd visual results. Proper handling would require removing them before layout and rendering a loop shape afterward.
- **removeEmptyRanks** -- Only matters when nesting graph creates rank gaps. Not needed without compound graph support.

#### Already handled differently (no action needed)
- **coordinateSystem adjust/undo** -- mmdflux uses separate code paths per direction. Functionally equivalent.
- **translateGraph** -- Integrated into position assignment.
- **assignNodeIntersects** -- Handled by the rendering layer.
- **reversePointsForReversedEdges** -- Handled by the rendering layer's backward edge routing.
- **acyclic.undo** -- Not needed since mmdflux uses logical reversal tracking.

## Key Takeaways

- **mmdflux implements the 6 core Sugiyama phases** (acyclic, rank, normalize-ranks, normalize-edges, order, position) plus denormalization, which covers the fundamental layout algorithm.
- **12 missing steps are compound-graph-specific**. These will all be needed when subgraph/cluster support is added. They form a coherent group: nesting graph creates the rank constraints, border segments create the visual boundaries, parent dummy chains assign ownership, and cleanup removes the scaffolding.
- **Self-edge handling is the most notable gap for current functionality**. Mermaid supports `A --> A` self-loops, and the current treatment as a back-edge is incorrect. This requires 3 coordinated steps: remove before layout, create positioned dummy after ordering, and generate a loop path after positioning.
- **Edge label positioning is partially implemented** but only supports center-positioned labels. Left/right label positioning would require the makeSpaceForEdgeLabels half-rank strategy and fixupEdgeLabelCoords adjustment.
- **The coordinate system transform pattern (adjust/undo)** is an elegant architectural choice in Dagre.js that lets the position algorithm be direction-agnostic. mmdflux's approach of separate code paths works but may diverge as features are added. The transform approach is more maintainable for a single position algorithm.
- **mmdflux's "logical reversal" approach** (tracking reversed edges in a set rather than physically reversing them) is arguably cleaner than Dagre.js's mutate-and-undo pattern, but requires careful handling throughout the pipeline.

## Open Questions

- **Should mmdflux adopt the transform/un-transform pattern for directions?** The current separate-code-paths approach works but means any position algorithm changes must be duplicated across vertical and horizontal paths. A single-axis transform would be more maintainable.
- **What is the priority for self-edge support?** Is `A --> A` a common pattern in Mermaid diagrams that users encounter?
- **When compound graph support is added, should the nesting graph approach be used, or is there a simpler alternative?** The Sander approach used by Dagre.js is well-studied but adds significant complexity (6+ pipeline steps). An alternative might be a two-pass approach: layout each subgraph independently, then compose.
- **Is the longest-path ranking algorithm sufficient, or will network simplex be needed?** Dagre.js uses network simplex by default. Longest-path can produce suboptimal (too many) ranks for certain graph shapes, leading to taller layouts. This is a separate concern from the pipeline comparison but related to overall layout quality.
- **Should mmdflux support left/right edge label positioning?** This would require the half-rank strategy from makeSpaceForEdgeLabels, which is a significant architectural change to the ranking step.
