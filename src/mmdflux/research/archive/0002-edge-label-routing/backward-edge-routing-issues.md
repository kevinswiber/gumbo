# Backward Edge Routing Issues

## Current Implementation

Backward edges (cycles) are routed around the diagram perimeter:

**Vertical layouts (TD/BT):**
1. Exit from right side of source
2. Horizontal segment to right-side corridor
3. Vertical segment in corridor (up for TD, down for BT)
4. Horizontal segment to right side of target

**Horizontal layouts (LR/RL):**
1. Exit from bottom side of source
2. Vertical segment to bottom corridor
3. Horizontal segment in corridor
4. Vertical segment to bottom of target

## Problem: Visual Ambiguity

In `complex.mmd`, the backward edge from "More Data?" to "Input" creates visual confusion:

```
 < More Data? >────│ Log Error │────│ Notify Admin │──┘
```

The horizontal line appears to connect ALL three nodes to the vertical corridor, making it unclear that only "More Data?" has the backward edge to "Input".

### Root Cause

When the source node isn't the rightmost node on its row, the horizontal segment to the corridor passes through (or appears to connect) intervening nodes.

## Potential Fixes

### Option 1: Exit from Top (for TD layouts)

Instead of exiting from the right side, backward edges could exit from the top:

```
Current:                         Proposed:
                                      │
< More Data? >──────────────┐    < More Data? >
                            │         │
                            │         └──────────────┐
                            ▼                        ▼
```

**Pros:**
- Clear visual origin of the edge
- No ambiguity with sibling nodes

**Cons:**
- May conflict with incoming forward edges
- Needs special handling when source is at top of diagram

### Option 2: Separate Corridor Lanes per Source Row

Assign different horizontal lanes based on which row the backward edge originates from:

```
Row 0 backward edges: corridor at y = height + 2
Row 1 backward edges: corridor at y = height + 4
...
```

**Pros:**
- Clear separation between edges from different sources

**Cons:**
- Increases diagram height
- Complex lane assignment logic

### Option 3: Route Around Left Side

When source isn't rightmost, route backward edge around the LEFT side instead:

```
┌──────────────────────────────< More Data? >
│
▼
Input
```

**Pros:**
- Avoids crossing other nodes on the same row

**Cons:**
- Need to track which side is "clearer"
- May conflict with other left-side elements

### Option 4: Exit from Top-Right Corner

Diagonal exit using corner characters:

```
                                 ┐
< More Data? >────...────...────┘
```

**Pros:**
- Shows the edge clearly starts from rightmost point of node

**Cons:**
- ASCII corner characters don't represent "edge from this node" well

## Dagre's Approach

Dagre handles this differently:

1. **Dummy nodes for long edges** - Edges spanning multiple ranks get dummy nodes at each intermediate layer
2. **Dummy nodes participate in ordering** - Crossing reduction ensures edges don't visually cross nodes
3. **Control points** - SVG paths can curve around obstacles with bezier curves

For mmdflux (ASCII), we can't do bezier curves, but we could:
- Insert "virtual routing points" that affect corridor placement
- Use smarter heuristics for which side to exit from
- Add visual indicators (different line style, annotation) to clarify origin

## Recommendation

Start with **Option 1 (exit from top)** for TD layouts as it's the simplest fix with clearest visual improvement. The "yes" edge from "More Data?" would exit upward, making it obvious the edge originates there rather than from "Log Error" or "Notify Admin".

Implementation location: `src/render/router.rs` in `route_backward_edge_vertical()`
