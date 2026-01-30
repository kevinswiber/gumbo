# Mermaid's Edge Label Approach

## Summary

Mermaid converts edges with labels into **three-node chains**, making labels actual graph nodes that Dagre positions automatically.

## Implementation Details

From `packages/mermaid/src/rendering-util/createGraph.ts`:

```typescript
// When an edge has a label:
if (edge.label && edge.label?.length > 0) {
  // Create a label node for the edge
  const labelNodeId = `edge-label-${edge.start}-${edge.end}-${edge.id}`;
  const labelNode = {
    id: labelNodeId,
    label: edge.label,
    shape: 'labelRect',
    isEdgeLabel: true,
    isDummy: true,
    // ...
  };

  // Insert the label node into the DOM
  const labelNodeEl = await insertNode(nodesGroup, labelNode, { config, dir: edge.dir });

  // Create two edges to replace the original one
  const edgeToLabel = { ...edge, end: labelNodeId, arrowTypeEnd: 'none' };
  const edgeFromLabel = { ...edge, start: labelNodeId, arrowTypeEnd: 'arrow_point' };
}
```

## Visual Transformation

```
Original:  A --label--> B
Becomes:   A → [labelNode] → B
```

- First edge: A → labelNode (no arrow)
- Second edge: labelNode → B (with arrow)

## Benefits

1. **No collision possible** - Labels are nodes; Dagre spaces them automatically
2. **Consistent positioning** - Labels participate in crossing reduction
3. **Proper routing** - Edges route to/from label nodes naturally

## Trade-offs

1. **Graph modification** - Increases node/edge count
2. **Complexity** - Must track dummy nodes through layout pipeline
3. **Rendering** - Must handle label nodes specially during render

## Why mmdflux Uses a Different Approach

For ASCII output:
- Simpler post-hoc label placement is sufficient
- Don't need sub-pixel positioning precision
- Fewer nodes = simpler rendering pipeline
- Label collision detection + shifting works well enough

Our approach: Place labels at edge midpoints (forward) or on corridor segments (backward), with collision detection to shift overlapping labels.
