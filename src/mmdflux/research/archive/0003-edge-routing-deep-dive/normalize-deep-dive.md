# Deep Dive: dagre's lib/normalize.js

## Overview

The normalize module is responsible for breaking long edges (spanning multiple ranks) into chains of short edges (spanning exactly 1 rank each) by inserting dummy nodes. This is a critical step in the Sugiyama framework that enables proper edge routing.

**Source:** https://github.com/dagrejs/dagre/blob/master/lib/normalize.js

---

## The Complete Algorithm

### run(g) - Entry Point

```javascript
function run(g) {
  g.graph().dummyChains = [];
  g.edges().forEach(edge => normalizeEdge(g, edge));
}
```

**What it does:**
1. Initializes an empty `dummyChains` array on the graph object
2. Processes every edge through `normalizeEdge()`

**Key insight:** The `dummyChains` array stores the *first* dummy node of each chain. This is the only reference needed because chains can be traversed via successor relationships.

---

### normalizeEdge(g, e) - The Core Algorithm

```javascript
function normalizeEdge(g, e) {
  let v = e.v;                           // Source node ID
  let vRank = g.node(v).rank;            // Source rank
  let w = e.w;                           // Target node ID
  let wRank = g.node(w).rank;            // Target rank
  let name = e.name;                     // Edge name (for multigraphs)
  let edgeLabel = g.edge(e);             // Edge label object
  let labelRank = edgeLabel.labelRank;   // Which rank the label belongs at

  // Short edges (span 1 rank) are kept as-is
  if (wRank === vRank + 1) return;

  // Remove the original long edge
  g.removeEdge(e);

  let dummy, attrs, i;
  // Iterate through intermediate ranks
  for (i = 0, ++vRank; vRank < wRank; ++i, ++vRank) {
    edgeLabel.points = [];  // Initialize waypoint array

    // Create dummy node attributes
    attrs = {
      width: 0, height: 0,           // Zero size by default
      edgeLabel: edgeLabel,          // Reference to original edge label
      edgeObj: e,                    // Reference to original edge
      rank: vRank                    // Dummy's rank
    };

    // Create the dummy node with unique ID
    dummy = util.addDummyNode(g, "edge", attrs, "_d");

    // Special handling for label rank
    if (vRank === labelRank) {
      attrs.width = edgeLabel.width;     // Label's width
      attrs.height = edgeLabel.height;   // Label's height
      attrs.dummy = "edge-label";        // Mark as label dummy
      attrs.labelpos = edgeLabel.labelpos; // "l", "r", or "c"
    }

    // Create edge from previous node to this dummy
    g.setEdge(v, dummy, { weight: edgeLabel.weight }, name);

    // Track first dummy in chain
    if (i === 0) {
      g.graph().dummyChains.push(dummy);
    }

    v = dummy;  // Move to next position in chain
  }

  // Create final edge from last dummy to target
  g.setEdge(v, w, { weight: edgeLabel.weight }, name);
}
```

**Algorithm breakdown:**

1. **Early exit for short edges:** If the edge spans exactly 1 rank (`wRank === vRank + 1`), do nothing.

2. **Remove original edge:** The long edge is deleted; it will be replaced by a chain.

3. **Create dummy chain:** For each intermediate rank between source and target:
   - Create a dummy node with zero width/height
   - Store references to the original edge (`edgeObj`) and label (`edgeLabel`)
   - Create an edge from the previous node (or source) to this dummy

4. **Handle label placement:** When the current rank equals `labelRank`:
   - The dummy gets the label's actual dimensions (width, height)
   - Marked with `dummy: "edge-label"` for later identification
   - `labelpos` preserved for left/right/center positioning

5. **Track chain start:** Only the first dummy is stored in `dummyChains`

6. **Final connection:** Create edge from last dummy to target node

---

### undo(g) - Denormalization

```javascript
function undo(g) {
  g.graph().dummyChains.forEach(v => {
    let node = g.node(v);
    let origLabel = node.edgeLabel;      // Get original edge label
    let w;

    // Restore the original edge
    g.setEdge(node.edgeObj, origLabel);

    // Walk the dummy chain
    while (node.dummy) {
      w = g.successors(v)[0];            // Next node in chain
      g.removeNode(v);                    // Remove dummy

      // Record dummy position as waypoint
      origLabel.points.push({ x: node.x, y: node.y });

      // Special handling for label dummy
      if (node.dummy === "edge-label") {
        origLabel.x = node.x;
        origLabel.y = node.y;
        origLabel.width = node.width;
        origLabel.height = node.height;
      }

      v = w;
      node = g.node(v);
    }
  });
}
```

**Algorithm breakdown:**

1. **Iterate through chain starts:** For each first-dummy in `dummyChains`

2. **Restore original edge:** Re-create the original edge with its label data

3. **Walk the chain:** Follow successor edges from dummy to dummy:
   - Each dummy's (x, y) position is added to `origLabel.points`
   - Dummy nodes are removed from the graph
   - Continue until reaching a non-dummy node (the target)

4. **Extract label position:** When encountering an "edge-label" dummy:
   - Copy its final position (x, y) to the label
   - Copy its dimensions (width, height) to the label

---

## Key Data Structures

### Dummy Node Attributes

```javascript
{
  width: 0 | labelWidth,      // Zero for regular dummies, label width for edge-label
  height: 0 | labelHeight,    // Zero for regular dummies, label height for edge-label
  edgeLabel: Object,          // Reference to original edge's label object
  edgeObj: { v, w, name },    // Original edge identifier
  rank: Number,               // The rank this dummy occupies
  dummy: "edge" | "edge-label", // Type identifier
  labelpos: "l" | "r" | "c"   // Only for edge-label dummies
}
```

### Edge Label Object (mutated during process)

```javascript
{
  // Input properties
  width: Number,              // Label width in pixels
  height: Number,             // Label height in pixels
  weight: Number,             // Edge weight (affects crossing reduction)
  labelRank: Number,          // Which rank the label should appear at
  labelpos: "l" | "r" | "c",  // Label position relative to edge

  // Output properties (set by undo())
  points: [{x, y}, ...],      // Waypoints from dummy positions
  x: Number,                  // Label center x (if edge-label dummy existed)
  y: Number,                  // Label center y
}
```

### Graph-Level Data

```javascript
g.graph().dummyChains = [dummyId1, dummyId2, ...]  // First dummy of each chain
```

---

## How Label Rank is Determined

The `labelRank` is calculated *before* normalization, typically as:

```javascript
labelRank = Math.floor((sourceRank + targetRank) / 2)
```

This places the label at the midpoint rank of the edge. For an edge from rank 0 to rank 4:
- labelRank = 2
- Dummies created at ranks 1, 2, 3
- The rank-2 dummy gets the label dimensions

---

## Implications for mmdflux

### 1. Pre-calculate Label Dimensions

Before calling normalize, we need:
- Label text measurement (character width × label length)
- Store as `edgeLabel.width` and `edgeLabel.height`
- Calculate `edgeLabel.labelRank` as midpoint

### 2. Dummy Node Storage

mmdflux should track:
```rust
struct DummyNode {
    edge_index: usize,        // Which original edge
    rank: i32,                // Which rank
    is_label: bool,           // Is this the edge-label dummy?
    label_pos: Option<LabelPos>, // "l", "r", "c" for label dummies
}
```

### 3. Waypoint Generation

After coordinate assignment:
```rust
fn denormalize(graph: &LayoutGraph) -> HashMap<EdgeId, Vec<Point>> {
    // For each dummy chain:
    // 1. Walk from first dummy to target
    // 2. Collect (x, y) positions
    // 3. Return as waypoints for the original edge
}
```

### 4. ASCII Constraints

Unlike dagre's floating-point coordinates:
- Dummy positions will be on integer grid
- May need minimum spacing between dummies on same rank
- Label dummies need enough width for text (measured in characters)

---

## Open Questions Answered

### Q: How does dagre's normalize.js handle edge labels with labelpos options?

**A:** The `labelpos` attribute is:
1. Stored on the edge label object (`edgeLabel.labelpos`)
2. Copied to the edge-label dummy node's attributes during normalization
3. Used later by rendering code to offset the label left/right/center from the dummy's position

The normalize module doesn't interpret labelpos—it just preserves it for the rendering phase.

### Q: How are dummy nodes removed during denormalize?

**A:** The `undo()` function:
1. Walks the dummy chain via successor relationships
2. Calls `g.removeNode(v)` on each dummy
3. Records their positions before removal
4. Stops when reaching a non-dummy node (the original target)

### Q: What data structure tracks the mapping from dummies back to original edges?

**A:** Two mechanisms:
1. **dummyChains array:** Stores the first dummy ID of each chain
2. **edgeObj attribute:** Each dummy stores a reference to the original edge object `{v, w, name}`

The chain is traversed via `g.successors(v)[0]` since each dummy has exactly one outgoing edge.

---

## Summary

The normalize module is elegant and efficient:
- **Input:** Graph with long edges (spanning multiple ranks)
- **Output:** Graph where all edges span exactly 1 rank

Key implementation details:
1. Only first dummy of each chain is stored (traverse via successors)
2. Label dummies have non-zero dimensions and special marking
3. Original edge data preserved on dummy nodes for reconstruction
4. Waypoints extracted from dummy positions during denormalization

This design allows crossing reduction and coordinate assignment to treat dummies like regular nodes, while the final denormalization step converts their positions back into edge waypoints.
