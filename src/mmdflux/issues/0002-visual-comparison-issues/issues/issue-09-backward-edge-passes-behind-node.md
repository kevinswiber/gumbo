# Issue 09: Backward edge passes behind intermediate nodes

**Severity:** High
**Category:** Backward edge routing
**Status:** Fixed (Plan 0020, Phases 2+5) — resolved as consequence of Issue 2 fix
**Affected fixtures:** `http_request`, `skip_edge_collision`, `stacked_fan_in`

## Description

Backward edges and skip edges visually pass behind or merge with intermediate
node box borders instead of routing around them with clear visual separation.
The edge line characters merge with the node box-drawing characters, making the
edge path invisible or ambiguous.

## Reproduction

### http_request.mmd

The HTTP Response backward edge from Send Response to Client routes upward
along the right side of the diagram. At the 401 Unauthorized node, the edge
path merges with the node's right border:

```
┌──────────────────┐─┐
│ 401 Unauthorized │ │
└──────────────────┘ │
```

The `─┐` followed by `│` shows the backward edge touching/overlapping the
node border. The edge should route with clear separation from the node.

### skip_edge_collision.mmd

The Start→End skip edge passes directly along the right border of Step 1 and
Step 2 boxes:

```
┌────────┐│
│ Step 1 ││
└────────┘│
     │    │
     │    │
     ▼    │
┌────────┐│
│ Step 2 ││
└────────┘┘
```

The `┐│` and `┘┘` show the skip edge touching the node borders with zero
separation.

### stacked_fan_in.mmd

```
┌─────┐ │
│ Mid │ │
└─────┘─┘
```

The Top→Bot skip edge merges with Mid's right and bottom borders (`─┘`).

## Expected behavior

Edges should route with at least 1 character of visual separation from nodes
they pass by. Mermaid achieves this through node stagger (Issue 02) and by
routing edges through the open space created by the stagger.

## Root cause hypothesis

This is closely related to Issue 02 (skip-edge stagger missing). Without
x-axis stagger, skip edges are forced to route in the narrow space immediately
adjacent to intermediate nodes. The edge routing algorithm in
`src/render/router.rs` uses waypoints from dagre's dummy nodes, which are
positioned too close to real nodes when stagger is absent.

Additionally, the edge rendering in `src/render/edge.rs` does not enforce a
minimum clearance distance from node bounding boxes.

## Plan 0020 Progress

**Phase 5** fixed the waypoint overhang offset bug that caused zero separation
between skip-edge waypoints and intermediate node bounds. Waypoints now include
the same `max_overhang_x`/`max_overhang_y` offset applied to node positions.

**Residual:** Skip edges now clear node borders (no more merging with box-drawing
characters), but the routing still runs immediately adjacent to intermediate
nodes. Wider stagger from a BK block graph (Issue 02) would give edges more
space. The `http_request` fixture still shows the backward edge running close to
the 401 Unauthorized node, though it no longer overlaps.
