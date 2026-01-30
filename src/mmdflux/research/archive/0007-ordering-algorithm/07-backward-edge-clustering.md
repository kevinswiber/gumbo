# 07: Backward Edge Clustering — Why Mermaid Has Two Node Clusters

## Observation

When rendering `complex.mmd`, Mermaid produces a layout with two distinct visual clusters:
- **Left cluster**: Input → Validate → Process → More Data?
- **Right cluster**: Error Handler → Log Error / Notify Admin → Cleanup

The backward edge (More Data? → Input, labeled "yes") runs as a curved spline up the left side of the left cluster. In contrast, mmdflux renders all nodes in a more centered layout with the backward edge routed through a dedicated corridor on the far right.

## Root Cause: Dagre Treats Reversed Edges as Normal Long Edges

The two-cluster layout is NOT an explicit backward-edge feature. It's a natural consequence of how dagre normalizes and renders ALL long edges, including reversed ones.

### Dagre's Pipeline for the Reversed Edge E→A

1. **Acyclic phase**: Reverses E→A to create effective direction A→E
2. **Rank assignment**: A gets rank 0, E gets rank 6 (dagre uses even-only ranks for real nodes)
3. **Normalization**: Creates dummy nodes at ranks 1, 3, 5 (odd ranks between A and E)
4. **Crossing reduction**: Dummies participate in ordering alongside real nodes. The dummies for A→E get placed near A's column (left side) because they connect to A and E.
5. **BK coordinate assignment**: Vertically aligns connected nodes into "blocks". The A→E dummy chain forms a vertical spine connecting Input (top-left) to More Data? (bottom-left).
6. **Rendering**: Mermaid's d3 SVG renderer draws the backward edge as a **curved spline passing through the dummy node positions** — just like any other long edge.

### The Clustering Effect

The dummy chain for the backward edge acts as gravitational pull. The BK algorithm aligns:
- A → dummies(ranks 1,3,5) → E into a vertical column on the left
- Error Handler → Log Error / Notify Admin → Cleanup into a separate column on the right

Dagre's final x-coordinates confirm this:
```
Input:         x=235   (left cluster)
Validate:      x=265   (left cluster)
Process:       x=265   (left cluster)
More Data?:    x=235   (left cluster)
Error Handler: x=75    (right cluster)
Notify Admin:  x=25    (right cluster)
Log Error:     x=125   (right cluster)
Cleanup:       x=75    (right cluster)
Output:        x=135   (between clusters)
```

## How mmdflux Diverges

mmdflux follows the same structural pipeline — we create dummy nodes for the reversed edge, they participate in ordering and BK alignment. The divergence happens at **rendering**:

- **Mermaid/dagre**: Routes the backward edge through dummy waypoints as a curved spline. The dummy positions directly determine the edge path.
- **mmdflux**: Routes the backward edge through a **corridor** — a dedicated vertical lane on the right side of the diagram, drawn with orthogonal box-drawing characters.

This means in mmdflux:
1. The backward edge's dummy nodes still influence node ordering and coordinate assignment
2. But the rendered edge path is completely disconnected from the dummy positions
3. The corridor doesn't create the same visual clustering because it's spatially separated from the node layout

## Key Insight

The corridor approach was likely chosen because ASCII art can't render curved splines. But it has a significant side effect: it breaks the visual connection between the backward edge path and the node positions that dagre's algorithm produces. The result is a more centered layout without the distinctive cluster separation that Mermaid shows.

## Options for Matching Mermaid's Layout

To reproduce Mermaid's two-cluster visual effect, we would need to:

1. **Route backward edges through dummy waypoints** instead of corridors — render the backward edge as an orthogonal path that passes through the dummy node positions (going upward through the same column of nodes)
2. **Alternatively, preserve the corridor but adjust node positioning** — use the dummy chain's influence on BK to push clusters apart, even though the edge itself routes through a corridor

Option 1 is the more faithful reproduction but requires creative ASCII routing of upward-flowing edges through the node layout area rather than around it.
