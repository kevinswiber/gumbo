# Mermaid-Dagre Integration Analysis

This document analyzes how Mermaid.js integrates with Dagre for flowchart layout.

## High-Level Architecture

```
Flowchart Text → Parser → FlowDB → getData() → LayoutData
  → Layout Algorithm (Dagre) → Positioned Graph → Rendering
```

**Key Location:** `packages/mermaid/src/rendering-util/layout-algorithms/dagre/`

---

## How Mermaid Invokes Dagre

### Entry Point: `flowRenderer-v3-unified.ts`

1. Renderer calls `diag.db.getData()` to extract parsed flowchart
2. Sets `layoutAlgorithm` property to 'dagre'
3. Calls `render(data4Layout, svg)` which loads Dagre module

### Dagre Layout Invocation: `layout-algorithms/dagre/index.js`

```javascript
const graph = new graphlib.Graph({
  multigraph: true,
  compound: true,
})
  .setGraph({
    rankdir: data4Layout.direction,
    nodesep: data4Layout.nodeSpacing || 50,
    ranksep: data4Layout.rankSpacing || 50,
    marginx: 8,
    marginy: 8,
  });

// After graph construction:
dagreLayout(graph);  // The actual layout call
```

---

## Configuration Options Passed to Dagre

### Graph-Level Configuration

| Config | Source | Default | Purpose |
|--------|--------|---------|---------|
| `rankdir` | `data4Layout.direction` | 'TB' | Layout direction |
| `nodesep` | `data4Layout.nodeSpacing` | 50 | Node separation |
| `ranksep` | `data4Layout.rankSpacing` | 50 | Rank separation |
| `marginx` | Hardcoded | 8 | X margin |
| `marginy` | Hardcoded | 8 | Y margin |

**Note:** Mermaid does NOT set `acyclicer: "greedy"`. This means Dagre uses its default DFS-based cycle removal algorithm. The `acyclicer: 'greedy'` option appears in Mermaid's state renderer code but is commented out.

### Edge-Level Properties

| Property | Purpose |
|----------|---------|
| `minlen` | Minimum edge length (Dagre constraint) |
| `weight` | Edge weight for layout |
| `label` | Edge label text |
| `arrowTypeStart/End` | Arrow rendering |
| `thickness` | Visual thickness |
| `pattern` | Solid/dotted/invisible |

### Node-Level Properties

| Property | Purpose |
|----------|---------|
| `width`, `height` | Set after DOM insertion via `getBBox()` |
| `padding` | Node internal padding (8px default) |
| `parentId` | For compound graphs (subgraphs) |
| `label` | Node text |

---

## Data Flow: Parsing to Layout

### Step 1: Parse Flowchart (FlowDB)

Grammar parses Mermaid syntax into:
- `vertices` - Node definitions
- `edges` - Connections
- `subGraphs` - Clusters

### Step 2: Convert to LayoutData (`getData()`)

```typescript
public getData() {
  // 1. Build subgraph nodes (clusters)
  for (let i = subGraphs.length - 1; i >= 0; i--) {
    nodes.push({
      id: subGraph.id,
      isGroup: true,
      parentId: parentDB.get(subGraph.id),
    });
  }

  // 2. Build regular nodes
  n.forEach((vertex) => {
    this.addNodeFromVertex(vertex, nodes, ...);
  });

  // 3. Build edges
  e.forEach((rawEdge, index) => {
    edges.push({
      start: rawEdge.start,
      end: rawEdge.end,
      minlen: rawEdge.length,
      ...
    });
  });

  return { nodes, edges, config };
}
```

### Step 3: Build Graphlib Graph

```javascript
// Create graph with compound=true for subgraph support
const graph = new graphlib.Graph({
  multigraph: true,
  compound: true,
}).setGraph({ rankdir, nodesep, ranksep, ... });

// Add nodes with parentId for clustering
data4Layout.nodes.forEach((node) => {
  graph.setNode(node.id, { ...node });
  if (node.parentId) {
    graph.setParent(node.id, node.parentId);
  }
});
```

### Step 4: Call Dagre Layout

```javascript
dagreLayout(graph);  // Modifies graph in-place with x, y coordinates
```

### Step 5: Update Node Positions

Dagre writes x, y coordinates back to graph nodes.

---

## Pre-Processing for Dagre

### Edge Label Handling (`createGraph.ts`)

Mermaid converts edges with labels into three-node chains:

```
Original:  A --label--> B
Becomes:   A → labelNode → B
```

Creates intermediate invisible dummy node for label positioning.

### Self-Loop Handling (`index.js`)

Detects A→A edges (self-loops) and creates 3 intermediate dummy nodes around the source to prevent visual overlap.

### Cluster Extraction (`mermaid-graphlib.js`)

- Recursively processes nested subgraphs
- Replaces cluster-to-external edges with boundary node edges
- Sets `externalConnections` flag

---

## Post-Processing After Layout

### Position Adjustment

- Applies `subGraphTitleTotalMargin` offset to Y coordinates
- Accounts for subgraph title height
- Positions clusters and regular nodes

### Edge Routing

```javascript
graph.edges().forEach((e) => {
  const edge = graph.edge(e);
  // Dagre provides edge.points array
  const paths = insertEdge(edgePaths, edge, ...);
  positionEdgeLabel(edge, paths);
});
```

### Recursive Rendering for Nested Clusters

If a cluster has `clusterNode: true`, recursively layout its sub-graph with separate Dagre layout.

---

## Key Integration Insights for mmdflux

1. **Graphlib Model** - Mermaid uses graphlib (Dagre's graph data structure)

2. **Two-Phase Nodes** - Edge labels are separate dummy nodes

3. **Self-Loops** - Special handling with intermediate nodes

4. **Compound Graphs** - Recursive layout for nested subgraphs

5. **Post-Processing** - Significant coordinate adjustment after Dagre

6. **Minlen Constraints** - Mermaid respects `minlen` from edge length specs

7. **Cluster Extraction** - Complex algorithm for external edges crossing cluster boundaries

8. **Rendering Decoupling** - Layout (x, y, points) is separate from visual rendering

---

## Dagre Library Details

**Package:** `dagre-d3-es@7.0.13` (ES module version)

**Import Path:**
```javascript
import { layout as dagreLayout } from 'dagre-d3-es/src/dagre/index.js';
import * as graphlib from 'dagre-d3-es/src/graphlib/index.js';
```

**Layout Algorithm Steps (from `layout.js`):**
1. `acyclic.run()` - Break cycles
2. `nestingGraph.run()` - Handle compound structure
3. `rank()` - Assign ranks
4. `order()` - Determine node order
5. `position()` - Calculate coordinates
6. `normalize.run/undo()` - Insert/remove dummy nodes
7. `fixupEdgeLabelCoords()` - Adjust label positions
