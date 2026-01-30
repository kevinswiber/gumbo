# Q2: dagre.js Compound Graph Layout Pipeline

## Summary

dagre.js implements compound graph (subgraph) support through a sophisticated pipeline that transforms a flat graph into a hierarchically constrained structure, applies positional constraints based on compound membership, and cleans up temporary border nodes. The pipeline integrates with the Sugiyama algorithm by inserting compound-specific phases at strategic points: after acyclic treatment (nesting graph initialization), after rank assignment (border segment creation), and after position calculation (border node removal with bounding box extraction).

## Where

- `/Users/kevin/src/dagre/lib/layout.js` -- main layout orchestration (lines 19-58)
- `/Users/kevin/src/dagre/lib/nesting-graph.js` -- nesting hierarchy construction (lines 31-126)
- `/Users/kevin/src/dagre/lib/add-border-segments.js` -- border node generation (lines 5-37)
- `/Users/kevin/src/dagre/lib/parent-dummy-chains.js` -- dummy chain parenting (lines 3-84)
- `/Users/kevin/src/dagre/lib/rank/util.js` -- rank constraint implementation (lines 31-67)
- `/Users/kevin/src/dagre/lib/order/index.js` -- compound-aware ordering orchestration (lines 28-64)
- `/Users/kevin/src/dagre/lib/order/add-subgraph-constraints.js` -- ordering constraints (lines 3-51)
- `/Users/kevin/src/dagre/lib/order/sort-subgraph.js` -- recursive subgraph sorting (lines 7-73)
- `/Users/kevin/src/dagre/lib/order/build-layer-graph.js` -- layer graph construction preserving hierarchy (lines 38-79)
- `/Users/kevin/src/dagre/lib/util.js` -- utility functions including `asNonCompoundGraph()` (lines 62-73)
- Prior research: `/Users/kevin/src/mmdflux/research/0015-bk-block-graph-divergence/q2-border-type-guard.md`

## What

### Core Data Structures

**Graphlib Compound Representation:**
- Graphs created with `{ multigraph: true, compound: true }` flag
- Parent-child relationships via `g.setParent(v, parent_id)` and `g.parent(v)`, `g.children(v)`
- Nodes can have `minRank` and `maxRank` properties indicating rank span
- Border nodes have `borderType` property: `"borderLeft"` or `"borderRight"`

### The Compound Pipeline (within runLayout, layout.js lines 30-58)

**Phase 1: Nesting Graph Setup** -- `nestingGraph.run()`
- Creates root dummy node (`_root`) connecting to all top-level nodes
- For each subgraph, creates `borderTop` and `borderBottom` dummy nodes
- Recursively processes nesting tree depth-first
- For each child of a subgraph, adds weighted nesting edges:
  - `borderTop -> childTop` with `nestingEdge: true`
  - `childBottom -> borderBottom` with `nestingEdge: true`
- Multiplies all edge minlen by `nodeSep = 2*height + 1` to ensure nodes don't share ranks with borders
- Saves `nodeRankFactor = nodeSep` for later empty rank removal

**Phase 2: Ranking** -- `rank(util.asNonCompoundGraph(g))`
- `asNonCompoundGraph()` filters to only leaf nodes (no children)
- Ranks only simple nodes; subgraph ranks are derived from children's border positions
- Nesting edges bias ranking to group children together

**Phase 3: Nesting Cleanup** -- `nestingGraph.cleanup()`
- Removes root dummy node
- Removes all edges marked with `nestingEdge: true`
- Cleans up graph metadata

**Phase 4: Rank Constraints** -- `assignRankMinMax()`
- For each node with `borderTop`: reads `minRank = rank(borderTop)`, `maxRank = rank(borderBottom)`
- Stores `maxRank` on graph for later reference
- Defines vertical span of each subgraph

**Phase 5: Normalize + Parent Dummy Chains** -- `normalize.run()` then `parentDummyChains()`
- normalize splits long edges into unit-length edges with dummy nodes
- parentDummyChains assigns dummy nodes to correct compound parent:
  - Computes path from source to target through lowest common ancestor (LCA)
  - Uses postorder tree traversal for efficient LCA computation
  - Climbing phase: moves up from source toward LCA
  - Descending phase: moves down from LCA toward target

**Phase 6: Border Segments** -- `addBorderSegments()`
- For each compound node with minRank/maxRank:
  - Creates left and right border nodes for each rank in [minRank, maxRank]
  - Stores in `node.borderLeft[rank]` and `node.borderRight[rank]`
  - Each border node has `dummy: "border"` and `borderType: "borderLeft"` or `"borderRight"`
  - Links consecutive border nodes vertically with weight-1 edges

**Phase 7: Compound-Aware Ordering** -- `order()`
- `buildLayerGraph()` preserves compound hierarchy when building layer-local graphs
- `sortSubgraph()` recursively sorts subgraph children, then non-subgraph siblings
  - Computes barycenter for each node based on incident edges
  - Filters out border nodes from movable nodes
  - Restores border nodes to final ordering
- `addSubgraphConstraints()` records ordering constraints between compound siblings

**Phase 8: Position with borderType Guard** -- `position()`
- BK algorithm Pass 2 includes borderType guard preventing border nodes from crossing their intended side
- Border nodes marked as "left" stay on left, "right" stay on right

**Phase 9: Border Node Removal** -- `removeBorderNodes()`
- Reads position of borderTop/borderBottom for height, borderLeft/borderRight for width
- Sets compound node dimensions and center from border positions
- Removes all border dummy nodes from graph

## How

### Step-by-Step Data Flow for a Compound Graph

**Input:** Graph with nodes A, B, C and compound node S containing children D, E. Edges: A->D, C->E, D->E.

1. **buildLayoutGraph()** -- Preserves `setParent(v, parent_id)` relationships
2. **acyclic.run()** -- Marks reversed edges if any
3. **nestingGraph.run()** -- Creates root, S.borderTop, S.borderBottom; adds weighted nesting edges
4. **rank()** with asNonCompoundGraph -- Assigns ranks to A, B, C, D, E only (not S or its borders)
5. **nestingGraph.cleanup()** -- Removes nesting edges
6. **assignRankMinMax()** -- Computes S.minRank and S.maxRank from border node ranks
7. **normalize.run()** -- Creates dummies for multi-rank edges (e.g., A->D spanning 2 ranks)
8. **parentDummyChains()** -- Reparents dummies into S if they cross S's rank range
9. **addBorderSegments()** -- Creates S.borderLeft[rank] and S.borderRight[rank] for each rank
10. **order()** -- Sorts D and E within S, ensuring they stay between borders
11. **position()** -- BK algorithm with borderType guard
12. **removeBorderNodes()** -- Uses border positions to compute S's final width/height/center
13. **updateInputGraph()** -- Copies S's dimensions back to input graph

### Data Structure Transformations

```
Initial graph: Compound structure with parent-child relationships
  |
After nestingGraph: Flat graph with structural nesting edges and borderTop/borderBottom markers
  |
After rank (non-compound): Leaf nodes have ranks; compound nodes marked with minRank/maxRank
  |
After normalize + parentDummyChains: Dummy chains reparented to correct ancestors
  |
After addBorderSegments: Border dummy nodes added for each compound node's rank range
  |
After order: All nodes (including borders) have order properties within their ranks
  |
After position: All nodes have x, y coordinates
  |
After removeBorderNodes: Border dummies removed; compound nodes inherit bounding boxes
```

## Why

### Design Rationale

1. **Nesting graph (Phase 1):** High-weight nesting edges dominate rank assignment, pulling all children into a contiguous block. More elegant than explicit constraints because it leverages the existing rank algorithm.

2. **Rank on non-compound subgraph:** Keeps rank assignment focused on leaf nodes; compound node ranks are derived from children's border positions. Avoids ambiguity about how to rank a node spanning many ranks.

3. **Border segments as invisible nodes:** Efficient (reuses ordering machinery) but adds overhead (O(ranks x compounds) dummy nodes). Alternative would be special-case constraint handling in ordering.

4. **Parent dummy chains via LCA:** Efficient for moderate nesting depth (O(depth) per chain); ensures edge paths respect hierarchy.

5. **Border node cleanup:** After positioning, borders serve as the "outline" of compound nodes; their positions define the bounding box. Removal keeps the final output graph clean.

### Tradeoffs

- **Nesting edges vs. explicit constraints:** Nesting approach is implicit (harder to debug) but doesn't require separate constraint propagation logic
- **Border segments as invisible nodes:** Efficient (reuses ordering) but adds O(ranks x compounds) dummy nodes
- **Parent dummy chains via LCA:** Efficient for moderate nesting but would be slow for very deep hierarchies (rare in practice)

## Key Takeaways

- dagre.js implements compound graphs through phases strategically interspersed in the Sugiyama pipeline
- **Nesting graph** establishes hierarchy constraints before ranking via weighted dummy edges
- **Ranking operates on non-compound subgraph** (leaf nodes only); compound ranks are derived
- **Border segments** are invisible left/right boundary nodes per rank, connected vertically
- **Parent dummy chains** reparent edge dummies to correct compound ancestors using LCA
- **Compound-aware ordering** sorts nodes hierarchically while respecting compound structure
- **Border removal** extracts bounding boxes from border positions, removes temporary nodes
- Border nodes have explicit `borderType` properties used in BK Pass 2 alignment
- The pipeline is fully integrated: each phase's output feeds the next
- Simple graphs (no compound nodes) skip all compound phases with no overhead

## Open Questions

- How does the pipeline handle edges between sibling subgraphs (not parent-child, but crossing boundaries)?
- What happens if a compound node has no children -- does it still get minRank/maxRank?
- Does the order phase's subgraph constraint graph persist across iterations or get rebuilt?
- Performance of LCA computation in parentDummyChains for very deep nesting (100+ levels)?
- What happens if a compound node's minRank/maxRank span has gaps in ranks?
