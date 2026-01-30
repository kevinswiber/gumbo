# Issue 10: TD edge label has ambiguous pairing with target node

**Severity:** Medium
**Category:** Label placement
**Status:** Fixed (commit 995a6ef)
**Affected fixtures:** `decision`, `labeled_edges`, `complex`, `http_request`, `label_spacing`

## Description

In TD layouts with labeled edges, labels are placed at the junction between the
source exit and the horizontal routing segment. When multiple labeled edges
diverge from the same node, labels appear closer to the target node than the
source node, making it ambiguous which edge a label belongs to.

## Reproduction

### decision.mmd

```
cargo run -q -- tests/fixtures/decision.mmd
```

**mmdflux output (relevant portion):**
```
      │    │               │
      │    │               │
      └──┐ └──────────────┐│
         │ Yes            ││No
         ▼                ▼└┐
    ┌────────┐         ┌───────┐
    │ Great! │         │ Debug │
    └────────┘         └───────┘
```

The "No" label appears directly above the Debug node column. It reads as if
"No" labels the Debug→Start backward edge rather than the "Is it working?"→Debug
forward edge. The "Yes" label has the same issue to a lesser degree — it appears
at the junction rather than along the edge path from "Is it working?".

### labeled_edges.mmd

```
cargo run -q -- tests/fixtures/labeled_edges.mmd
```

**mmdflux output (relevant portion):**
```
    ┌────────┐             │
    < Valid? >           retry
    └────────┘             │
       │ │                 │
       │ │                 │
       └─┼─────────────────┤
         │ yes             │ no
         ▼                 ▼───┐
    ┌─────────┐       ┌──────────────┐
    │ Execute │       │ Handle Error │
    └─────────┘       └──────────────┘
```

The "no" label appears at the junction just above Handle Error. Combined with
the "retry" backward edge label on the right, it is unclear whether "no" labels
the Valid?→Handle Error forward edge or is associated with the backward edge
from Handle Error. Similarly "yes" sits at the junction above Execute rather
than along the edge from Valid?.

## Expected behavior

Labels should be placed along the edge path in a position that makes the
source-target relationship unambiguous. Mermaid places labels along the middle
of the edge segment, roughly equidistant from source and target. For TD layouts
with diverging edges, labels should appear along the vertical segment below the
source or along the horizontal routing segment, not at the junction immediately
above the target.

## Root cause hypothesis

The label placement algorithm positions labels at or near the junction point
where horizontal routing meets the vertical descent to the target. For edges
that route horizontally before descending, this places the label at the corner
closest to the target node. A better heuristic would place the label along the
longest segment of the edge path, or anchor it closer to the source node's exit
point.

This issue compounds with Issue 08 (attachment overlap) in `labeled_edges` where
overlapping forward and backward edges at Handle Error make the label ambiguity
worse.

## Resolution

Fixed in commit 995a6ef. Short forward TD/BT edges now place labels on
the horizontal jog segment (overlapping edge drawing characters) when
the segment is wide enough, or on a source-near vertical segment as
fallback. The `on_h_seg` flag skips edge collision checks to allow
intentional overlap on the jog line.

## Cross-references

- Related to Issue 05 (LR label placement, fixed in Plan 0020 Phase 4)
- Compounds with Issue 08 (attachment overlap) in `labeled_edges`
- Research: research/0014-remaining-visual-issues/q4-td-label-placement.md
