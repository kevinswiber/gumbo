# Issue 08: Attachment point overlap causes missing arrows and edge collisions

**Severity:** High
**Category:** Attachment point overlap / edge rendering
**Status:** Fixed — Plan 0021 (endpoint spread formula + MIN_GAP + synthetic waypoints)
**Affected fixtures:** `http_request`, `labeled_edges`

## Description

When multiple edges converge on the same node face, attachment points overlap
or are placed too close together, causing:
1. Arrow characters to be overwritten by edge-drawing characters
2. Edge paths to visually merge or collide
3. Backward edges to pass behind node boxes

## Reproduction

### http_request.mmd

```
cargo run -q -- tests/fixtures/http_request.mmd
```

**mmdflux output (relevant portion):**
```
┌─────────────────┐       ┌──────────────────┐─┐
│ Process Request │       │ 401 Unauthorized │ │
└─────────────────┘       └──────────────────┘ │
            │                     │            │
            │                     │            │
            └──────────┐      ┌───┘            │
                       │      │                │
                       ▼   ┌──┴────────────────┘
                   ┌───────────────┐
                   │ Send Response │
                   └───────────────┘
```

Two problems visible:
1. The `┌──┴─` at Send Response shows the incoming edge from 401 Unauthorized
   colliding with the backward edge (HTTP Response → Client). The `┴` indicates
   two edges sharing the same column, and the arrow for one edge is missing.
2. The `─┐` at 401 Unauthorized's right side (`┐─┐`) shows the backward edge
   (HTTP Response) passing behind the 401 box, merging with the node border.

### labeled_edges.mmd

```
cargo run -q -- tests/fixtures/labeled_edges.mmd
```

**mmdflux output (relevant portion):**
```
    ┌────────┐          │
    < Valid? >        retry
    └────────┘          │
       │ │              │
       │ │              │
       └─┼──────────────┼──┐
         │ yes          │  │ no
         ▼              └──┴───┐
    ┌─────────┐       ┌──────────────┐
    │ Execute │       │ Handle Error │
    └─────────┘       └──────────────┘
```

The `└──┴───┐` shows the "no" edge from Valid? and the "retry" backward edge
from Handle Error colliding at the same point. The attachment points overlap,
making it unclear which edge connects where.

## Expected behavior

- Each edge arriving at a node face should have its own distinct attachment
  point with a visible arrow
- Backward edges should route around nodes, not behind them
- When multiple edges share a face, attachment points should be spread with
  sufficient separation

## Root cause hypothesis

Two compounding issues:
1. Attachment point spreading allocates insufficient space when edges include
   both forward and backward edges on the same face
2. Edge rendering does not check for character collisions — later-drawn edges
   overwrite arrow characters from earlier edges

## Additional observations (post Plan 0020)

In `labeled_edges`, the forward "no" edge from Valid? and the "retry" backward
edge from Handle Error both arrive at Handle Error's top face. The overlapping
paths create ambiguity about which label belongs to which edge — "no" appears
to label the backward edge rather than the forward edge from Valid?. This
compounds with the label ambiguity issue (Issue 10) since overlapping edges
make label pairing harder to read.

In `http_request`, after Phase 5 fixes the overlap at Send Response is reduced
but the `▼   ▼  ┌` pattern shows forward edges from Process Request and 401
Unauthorized arriving very close together at Send Response's top face, with
the backward edge routing through the gap between them.

## Resolution (Plan 0021)

Three changes in Plan 0021 eliminated the overlap:
1. **Endpoint-maximizing spread formula** (Phase 1, commit `b6cc0e2`): Replaced
   centering formula with `(i * range) / (count - 1)`, placing edges at face
   extremes for maximum separation.
2. **MIN_ATTACHMENT_GAP enforcement** (Phase 2, commit `45f8c5f`): Added minimum
   2-cell separation between adjacent attachment points as a safety net.
3. **Synthetic backward waypoints** (Phase 3, commit `95cf793`): Backward edges
   now route around nodes (right side for TD/BT, bottom for LR/RL) instead of
   through the gap, eliminating forward/backward collisions on shared faces.

Both `http_request` and `labeled_edges` now render cleanly with distinct
attachment points and no arrow overwrites.
