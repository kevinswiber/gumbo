# Dagre Label Positioning Capabilities

## Summary

Dagre provides sophisticated label positioning through a **proxy node system** that treats labels as nodes during layout. Key capabilities:

1. **Label Positioning Options**: Three horizontal positions via `labelpos` property: left ("l"), center ("c"), right ("r")
2. **Label Spacing Management**: Labels affect edge routing through `labeloffset` property (default: 10 pixels)
3. **Label Dimensions**: Edges have `width` and `height` properties representing label dimensions
4. **Automatic Positioning**: Labels placed at rank midpoints between source and target nodes

## Label Positioning API

### Edge Properties for Labels

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `labelpos` | string | "c" | Horizontal position: "l" (left), "c" (center), "r" (right) |
| `labeloffset` | number | 10 | Pixel offset pushing label away from edge |
| `width` | number | 0 | Label width in pixels |
| `height` | number | 0 | Label height in pixels |
| `minlen` | number | 1 | Minimum edge length (affects label vertical distance) |

### Graph Layout Properties

| Property | Default | Description |
|----------|---------|-------------|
| `ranksep` | 50 | Vertical separation between ranks. **Halved when labels exist** |
| `edgesep` | 20 | Horizontal separation between edges |
| `nodesep` | 50 | Horizontal separation between nodes |

## Implementation Details

### Label Placement Pipeline

The label positioning happens in several phases within `layout.js`:

#### 1. makeSpaceForEdgeLabels() (lines 158-172)

Prepares graph for label insertion:
- Halves `ranksep` to create space for label placement
- Doubles `minlen` for edges with labels
- Adds `labeloffset` to edge width/height for "l" and "r" positions
- For center position ("c"), no offset is added

```javascript
function makeSpaceForEdgeLabels(g) {
  var graph = g.graph();
  graph.ranksep /= 2;  // Make room for labels

  g.edges().forEach(function(e) {
    var edge = g.edge(e);
    edge.minlen *= 2;  // Double minlen for label space

    if (edge.labelpos.toLowerCase() !== "c") {
      // Add offset for non-center labels
      if (graph.rankdir === "TB" || graph.rankdir === "BT") {
        edge.width += edge.labeloffset;
      } else {
        edge.height += edge.labeloffset;
      }
    }
  });
}
```

#### 2. injectEdgeLabelProxies() (lines 180-190)

Creates temporary dummy nodes at label positions:

```javascript
function injectEdgeLabelProxies(g) {
  g.edges().forEach(function(e) {
    var edge = g.edge(e);
    if (edge.width && edge.height) {
      var v = g.node(e.v);
      var w = g.node(e.w);
      // Label rank = midpoint between source and target
      var labelRank = (w.rank - v.rank) / 2 + v.rank;
      // Create dummy node with label dimensions
      addDummyNode(g, "edge-proxy", { rank: labelRank, e: e, ... });
    }
  });
}
```

#### 3. normalize.run() (normalize.js:26-67)

Breaks long edges into unit-length segments:
- At `labelRank`, dummy node gets label dimensions and `labelpos` property
- This allows positioning module to handle labels as nodes

```javascript
// From normalize.js:53-58
if (edge.labelRank === rank) {
  attrs.width = edge.width;
  attrs.height = edge.height;
  attrs.dummy = "edge-label";
  attrs.labelpos = edge.labelpos;
}
```

#### 4. position() - Coordinate Assignment

**positionY()**: Places nodes/labels vertically at rank-based coordinates

**positionX()**: Uses Brandes & Köpf algorithm with label awareness (bk.js:389-425):

```javascript
// The sep() function considers labelpos when calculating spacing
function sep(nodeSep, edgeSep, reverse) {
  return function(g, v, w) {
    var vLabel = g.node(v);
    var wLabel = g.node(w);
    var sum = 0;

    // Account for node widths
    sum += vLabel.width / 2;

    // Handle label positioning offset
    if (vLabel.labelpos) {
      switch (vLabel.labelpos.toLowerCase()) {
        case "l": sum -= vLabel.width / 2; break;
        case "r": sum += vLabel.width / 2; break;
      }
    }

    sum += (vLabel.dummy ? edgeSep : nodeSep) / 2;
    // ... similar for wLabel
    return sum;
  };
}
```

#### 5. fixupEdgeLabelCoords() (lines 285-298)

Final adjustment based on `labelpos`:

```javascript
function fixupEdgeLabelCoords(g) {
  g.edges().forEach(function(e) {
    var edge = g.edge(e);
    if (edge.hasOwnProperty("x")) {
      if (edge.labelpos === "l" || edge.labelpos === "r") {
        edge.width -= edge.labeloffset;
      }
      switch (edge.labelpos) {
        case "l": edge.x -= edge.width / 2 + edge.labeloffset; break;
        case "r": edge.x += edge.width / 2 + edge.labeloffset; break;
      }
    }
  });
}
```

## How Labels Interact with Layouts

### TB/BT (Top-to-Bottom, Bottom-to-Top)

- Labels positioned horizontally (left/center/right of vertical edge)
- `labeloffset` adds to edge width
- Rank separation halved to fit labels between ranks

### LR/RL (Left-to-Right, Right-to-Left)

- Labels positioned vertically (above/center/below horizontal edge)
- `labeloffset` adds to edge height
- Same rank separation halving applies

## Code References

| File | Lines | Purpose |
|------|-------|---------|
| `lib/layout.js` | 31-57 | Main layout pipeline |
| `lib/layout.js` | 105-108 | Edge defaults (`minlen: 1`, `weight: 1`) |
| `lib/layout.js` | 158-172 | `makeSpaceForEdgeLabels()` |
| `lib/layout.js` | 180-190 | `injectEdgeLabelProxies()` |
| `lib/layout.js` | 285-298 | `fixupEdgeLabelCoords()` |
| `lib/normalize.js` | 53-58 | Label property preservation during normalization |
| `lib/position/bk.js` | 389-425 | `sep()` - separation calculation with labelpos |

## Key Insights

1. **Space Trading**: Dagre trades horizontal/vertical space for label placement by halving rank separation and doubling edge minlen. This maintains balance.

2. **Dummy Node Strategy**: Labels are treated as dummy nodes during layout, making them subject to same positioning algorithms as regular nodes. This ensures they don't collide with other graph elements.

3. **Label Rank Calculation**: The midpoint formula `(w.rank - v.rank) / 2 + v.rank` guarantees labels appear at visual center between connected nodes.

4. **Horizontal Offset Handling**: `labeloffset` creates consistent spacing, but only for "l" and "r" positions. Center labels use their width for spacing.

5. **No Edge Routing Around Labels**: Dagre doesn't route edges to avoid labels. Instead, it reserves space during layout by:
   - Creating label "zones" at midpoint ranks
   - Accounting for label dimensions in edge width/height
   - Using dimensions in separation calculation

6. **Post-Processing Adjustment**: `fixupEdgeLabelCoords()` is a final adjustment step - the actual positioning happens during the main layout pass via dummy nodes.

## Relevance for mmdflux

Dagre's approach is designed for continuous 2D coordinate spaces where:
- Coordinates can be any floating-point value
- Labels can be positioned with sub-pixel precision
- The rendering layer (D3.js typically) handles actual display

For ASCII rendering, we need to:
- Convert floating-point positions to discrete character cells
- Account for character-level collisions
- Consider that label characters directly overwrite edge characters
- Handle the discrete nature of ASCII art spacing
