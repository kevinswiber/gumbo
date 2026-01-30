# Q4: Mermaid Reference Implementation for Nested Subgraphs

## Summary

Mermaid.js handles nested subgraphs through a two-phase approach: the parser/DB layer stores subgraphs as a flat list with implicit nesting (each subgraph's `nodes` array can contain other subgraph IDs), while the rendering layer converts this into a parent-child tree using graphlib's `compound: true` graph with `setParent()` calls. For the dagre layout backend, Mermaid uses a complex "extractor" algorithm that recursively splits nested compound clusters into separate sub-graphs, each laid out independently via `recursiveRender()`. The ELK backend instead passes the full hierarchy to ELK natively via its `INCLUDE_CHILDREN` hierarchy handling.

## Where

Sources consulted (all within the local clone at `/Users/kevin/src/mermaid`):

- **Parser DB**: `packages/mermaid/src/diagrams/flowchart/flowDb.ts` -- `addSubGraph()`, `makeUniq()`, `getData()`, `indexNodes2()`
- **Types**: `packages/mermaid/src/diagrams/flowchart/types.ts` -- `FlowSubGraph` interface
- **JISON grammar**: `packages/mermaid/src/diagrams/flowchart/parser/flow.jison` -- subgraph production rules
- **Dagre layout**: `packages/mermaid/src/rendering-util/layout-algorithms/dagre/index.js` -- `render()`, `recursiveRender()`
- **Cluster handling**: `packages/mermaid/src/rendering-util/layout-algorithms/dagre/mermaid-graphlib.js` -- `adjustClustersAndEdges()`, `extractor()`, `extractDescendants()`, `copy()`
- **ELK layout**: `packages/mermaid-layout-elk/src/render.ts` -- `addVertices()`, `addSubGraphs()`, `setIncludeChildrenPolicy()`
- **Common ancestor**: `packages/mermaid-layout-elk/src/find-common-ancestor.ts`
- **Rendering types**: `packages/mermaid/src/rendering-util/types.ts` -- `Node` base interface with `parentId`, `isGroup`
- **Parser tests**: `packages/mermaid/src/diagrams/flowchart/parser/subgraph.spec.js`, `flow-direction.spec.js`
- **DB tests**: `packages/mermaid/src/diagrams/flowchart/flowDb.spec.ts`

## What

### Data Structures

**FlowSubGraph** (parser level):
```typescript
interface FlowSubGraph {
  classes: string[];
  dir?: string;        // per-subgraph direction (e.g., "LR", "BT")
  id: string;          // subgraph identifier
  labelType: string;
  nodes: string[];     // list of node IDs AND child subgraph IDs
  title: string;
}
```

Key: The `nodes` array is a flat list that can contain both regular node IDs and subgraph IDs. This is how nesting is represented at the parser level -- a subgraph A that contains subgraph B will have B's ID in A's `nodes` array.

**Node** (rendering level):
```typescript
interface Node {
  id: string;
  parentId?: string;    // ID of containing subgraph
  isGroup: boolean;     // true for subgraphs, false for regular nodes
  dir?: string;         // layout direction for subgraph contents
  shape: string;        // 'rect' for subgraphs
  // ... other rendering properties
}
```

### Parser Storage Model

1. **Flat list, bottom-up order**: `FlowDB.subGraphs` is a flat array. Inner subgraphs are added first (JISON parses depth-first, so nested `subgraph...end` blocks resolve inner-first). The outermost subgraph is last in the array.

2. **Uniqueness enforcement via `makeUniq()`**: When `addSubGraph()` is called, it removes any node IDs from the new subgraph's `nodes` list that already exist in a previously-added subgraph. This ensures each node belongs to exactly one subgraph. Since inner subgraphs are added first, their nodes are claimed first, and the outer subgraph retains only nodes not already claimed by inner subgraphs. The outer subgraph's `nodes` array will however contain the inner subgraph's ID.

3. **Subgraph-as-node**: A subgraph ID is treated as a node. When subgraph A contains subgraph B, then B's ID appears in A's `nodes` array. This means B is both a subgraph in the `subGraphs` list AND a node-member of A.

4. **Direction inheritance**: Each subgraph can have its own `dir` property (e.g., `direction LR` inside a subgraph). If not specified and `flowchart.inheritDir` is true, it inherits the graph-level direction.

### Conversion to Layout (getData())

The `getData()` method converts the flat subgraph list into a parent-child tree:

```typescript
// Build parentDB: maps each node/subgraph ID to its containing subgraph ID
for (let i = subGraphs.length - 1; i >= 0; i--) {
  const subGraph = subGraphs[i];
  for (const id of subGraph.nodes) {
    parentDB.set(id, subGraph.id);
  }
}

// Emit subgraphs as group nodes with parentId
for (let i = subGraphs.length - 1; i >= 0; i--) {
  nodes.push({
    id: subGraph.id,
    parentId: parentDB.get(subGraph.id),  // may be undefined (root level)
    isGroup: true,
    shape: 'rect',
    dir: subGraph.dir,
    // ...
  });
}

// Emit regular vertices with parentId
n.forEach((vertex) => {
  // parentId comes from parentDB lookup
});
```

This iteration order (reverse) ensures parent subgraphs are processed after children, which means the `parentDB` correctly maps inner subgraph IDs to their containing outer subgraph.

## How

### Dagre Backend: Recursive Extraction

The dagre backend cannot natively handle compound/nested graphs. Mermaid works around this with a multi-step process:

**Step 1: Build compound graphlib graph**
```javascript
const graph = new graphlib.Graph({ multigraph: true, compound: true });
data4Layout.nodes.forEach((node) => {
  graph.setNode(node.id, { ...node });
  if (node.parentId) {
    graph.setParent(node.id, node.parentId);
  }
});
```

**Step 2: Adjust clusters and edges (`adjustClustersAndEdges`)**

This is the most complex part. It:
1. Identifies all clusters (nodes with children) and builds a `descendants` map via `extractDescendants()` -- recursively collecting all descendants of each cluster.
2. Detects "external connections" -- edges where one endpoint is inside a cluster and the other is outside. Clusters with external connections cannot be extracted into separate sub-graphs.
3. Rewires edges: When an edge targets a cluster node (subgraph), it gets redirected to a non-cluster child node within that cluster via `findNonClusterChild()`. This is necessary because dagre cannot have edges to/from compound nodes.
4. Calls `extractor()` to recursively split the graph.

**Step 3: Extraction (`extractor`)**

For clusters WITHOUT external connections:
- Creates a new `graphlib.Graph` for the cluster's contents
- Copies child nodes and internal edges into the new sub-graph via `copy()`
- Replaces the cluster node in the parent graph with a `clusterNode: true` marker that contains the sub-graph
- The sub-graph can have its own `rankdir` (from subgraph `dir` property)
- Recursively extracts nested sub-graphs within

For clusters WITH external connections:
- Leaves them in the parent graph (dagre handles them as compound nodes with `setParent`)
- These get rendered as visual cluster boxes but not as separate layout sub-graphs

**Step 4: Recursive Render**

```javascript
const recursiveRender = async (_elem, graph, ...) => {
  // For each node in the graph:
  graph.nodes().map(async (v) => {
    const node = graph.node(v);
    if (node?.clusterNode) {
      // Recursively render the sub-graph
      const o = await recursiveRender(nodes, node.graph, ...);
      updateNodeBounds(node, newEl);  // Set node size from rendered sub-graph
    } else {
      await insertNode(nodes, node, ...);
    }
  });

  // Run dagre layout on this level
  dagreLayout(graph);

  // Position nodes and edges
};
```

Each nesting level gets its own dagre layout call. The inner sub-graph is laid out first, its bounding box becomes the size of the cluster node in the parent graph, and then the parent graph is laid out.

**Depth limit**: The extractor has a `depth > 10` guard to prevent infinite recursion.

### ELK Backend: Native Hierarchy

The ELK backend takes a fundamentally different approach:

1. **Tree-structured graph**: Builds the ELK graph as a tree where subgraphs are parent nodes containing their children:
```javascript
const addVertices = async (nodeEl, nodeArr, graph, parentId) => {
  const siblings = nodeArr.filter((node) => node?.parentId === parentId);
  for (const node of siblings) {
    if (node.isGroup) {
      const child = { ...node, children: [] };
      graph.children.push(child);
      await addVertices(nodeEl, nodeArr, child, node.id);  // recurse
    } else {
      graph.children.push(child);
    }
  }
};
```

2. **Hierarchy handling**: Sets `elk.hierarchyHandling: 'INCLUDE_CHILDREN'` globally, and for subgraphs with their own direction, sets `elk.hierarchyHandling: 'SEPARATE_CHILDREN'` to get independent layout.

3. **Cross-boundary edges**: For edges crossing subgraph boundaries, uses `findCommonAncestor()` to find the lowest common ancestor and sets `INCLUDE_CHILDREN` policy up the ancestor chain:
```javascript
elkGraph.edges.forEach((edge) => {
  if (nodeDb[source].parentId !== nodeDb[target].parentId) {
    const ancestorId = findCommonAncestor(source, target, parentLookupDb);
    setIncludeChildrenPolicy(source, ancestorId);
    setIncludeChildrenPolicy(target, ancestorId);
  }
});
```

4. **Position calculation**: After ELK layout, positions are computed relative to parent subgraphs, accumulated through recursive `drawNodes(relX + node.x, relY + node.y, node.children, ...)`.

### Edge Cases Observed

**Deeply nested subgraphs (3+ levels)**:
- Parser supports arbitrary nesting via recursive JISON grammar (`document` production can contain `subgraph ... document ... end`)
- Dagre backend: limited by `depth > 10` guard in extractor, but practically works for reasonable depths
- ELK backend: native tree structure, no practical depth limit

**Edges crossing subgraph boundaries**:
- Dagre: `adjustClustersAndEdges` detects external connections, marks clusters, and rewires edges to point to non-cluster children. Clusters with external connections are NOT extracted into sub-graphs; they remain in the parent graph as compound nodes.
- ELK: `findCommonAncestor` + `setIncludeChildrenPolicy` ensures the hierarchy handling is correctly configured for cross-boundary edges.

**Nodes in multiple subgraphs**:
- `makeUniq()` explicitly prevents this. Each node can only belong to one subgraph (the first one that claims it, which is the innermost due to bottom-up parsing order).

**Empty nested subgraphs**:
- `subGraphDB` only marks a subgraph as a group if `subGraph.nodes.length > 0`. Empty subgraphs (no nodes, no child subgraphs) would not be marked as groups and would be treated as regular nodes.

**Backward/cycle edges within nested subgraphs**:
- The dagre backend's `extractor` only separates clusters without external connections. If a backward edge exists purely within a cluster, it stays within the sub-graph and dagre handles cycle-breaking normally at that sub-graph level.
- Self-loops on subgraphs are handled with special dummy nodes (`specialId1`, `specialId2`) created in the dagre `render()` function.

**Subgraph-to-subgraph edges**:
- When an edge connects to a subgraph (rather than a regular node), `findNonClusterChild()` finds a representative leaf node within that subgraph to serve as the actual edge endpoint. This function prefers children without common edges to avoid routing conflicts.

## Why

### Design Rationale

1. **Flat list with implicit nesting**: Simpler parser implementation. JISON naturally handles recursion, and the bottom-up subgraph addition order makes `makeUniq()` correctly assign nodes to their innermost subgraph. The downside is that the tree structure must be reconstructed in `getData()`.

2. **Two layout backends with different strategies**: Dagre-d3 does not natively support compound/hierarchical graphs well. The `extractor` + `recursiveRender` approach works around this by treating each cluster as an independent layout problem. ELK natively supports hierarchical graphs, making the implementation much cleaner.

3. **External connection detection**: A key insight. Clusters with edges crossing their boundary cannot be extracted into independent sub-graphs because the edge endpoints need to participate in the same layout. These clusters must remain in the parent graph as compound nodes with children.

4. **Edge rewiring to non-cluster children**: Dagre cannot route edges to compound nodes. The `findNonClusterChild()` + `getAnchorId()` pattern redirects edges to actual leaf nodes, with metadata (`fromCluster`, `toCluster`) preserved for correct visual rendering.

### Tradeoffs

- **Dagre approach complexity**: The extractor/recursiveRender pattern is complex (300+ lines of graph manipulation code) and has edge cases (the depth limit, the external connections heuristic). However, it enables per-subgraph layout directions.
- **Single-parent constraint**: `makeUniq()` enforces that each node belongs to exactly one subgraph. This simplifies layout but means a node cannot visually appear in multiple groups.
- **Subgraph direction**: When a subgraph has its own `direction`, the dagre backend creates a sub-graph with a different `rankdir`. The ELK backend uses `SEPARATE_CHILDREN`. Both approaches allow mixed layout directions within nested subgraphs.

## Key Takeaways

- **Flat subgraph list, tree reconstruction**: Mermaid stores subgraphs as a flat array at parse time, then reconstructs the parent-child tree for layout via `parentDB` mapping. This is a practical approach we can follow.
- **Each node belongs to exactly one subgraph**: Enforced by `makeUniq()` at parse time. Inner subgraphs claim nodes first (bottom-up parsing order).
- **Subgraphs become nodes**: A subgraph ID is treated as a node in its parent subgraph's `nodes` list. At layout time, subgraphs become `isGroup: true` nodes with `parentId`.
- **The dagre compound graph approach is complex**: The `extractor` pattern (splitting clusters without external connections into separate sub-graphs for independent layout) is ~300 lines of intricate code. This is the hardest part to replicate.
- **External connections are the key distinction**: Clusters with edges crossing their boundary stay in the parent graph; clusters without external connections get extracted for independent layout.
- **Edge rewiring is necessary**: Edges to/from subgraph nodes must be redirected to actual leaf nodes within those subgraphs for dagre to handle them.
- **Per-subgraph direction is supported**: Each subgraph can have its own layout direction, laid out independently and then composed.
- **Self-loops on subgraphs use dummy nodes**: Mermaid handles self-referencing subgraph edges by creating intermediate dummy nodes.
- **Depth guards exist**: The extractor limits recursion to depth 10 and the `indexNodes2` method has a counter limit of 2000 to prevent runaway recursion.
- **For mmdflux**: Since we use our own dagre implementation (not graphlib + dagre-d3), we have more control. We could either: (a) follow the recursive extraction approach (complex but proven), or (b) extend our dagre to natively handle compound nodes (cleaner but novel work). The simpler option for ASCII rendering may be to lay out each cluster independently and composite the results, similar to the dagre backend's approach.

## Open Questions

- How does mmdflux's internal dagre implementation compare to graphlib's compound graph support? Does it already support `setParent`/`children` semantics?
- For ASCII rendering, is the recursive extraction approach (layout each cluster independently, use bounding box as node size in parent) sufficient, or do we need full compound graph support?
- How should cross-boundary edges be handled in ASCII rendering? The visual "edge rewiring to representative child" approach may produce different-looking results than expected.
- What happens with per-subgraph directions in mmdflux? Our dagre already supports different `rankdir` values, but can it handle different directions at different nesting levels?
- How should empty subgraphs be rendered in ASCII? Mermaid effectively ignores them (treats as non-group nodes).
