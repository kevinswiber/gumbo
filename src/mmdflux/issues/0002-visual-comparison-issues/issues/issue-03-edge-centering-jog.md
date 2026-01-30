# Issue 03: Edge centering jog for different-width nodes

**Severity:** Medium
**Category:** Edge routing / coordinate mapping
**Status:** Fixed (Plan 0020, Phase 2)
**Affected fixtures:** `simple`, `bottom_top`, `simple_cycle`

## Description

When connected nodes have different widths but share the same dagre x-center,
edges produce unnecessary right-angle jogs (`┌┘` or `└┐`) instead of straight
vertical lines. Mermaid draws perfectly straight edges by centering both
attachment points at the shared x-center.

## Reproduction

### simple.mmd

```
cargo run -q -- tests/fixtures/simple.mmd
```

**mmdflux output:**
```
┌───────┐
│ Start │
└───────┘
   ┌┘
   ▼
┌─────┐
│ End │
└─────┘
```

The `┌┘` indicates the edge exits Start, jogs left, then enters End. This
should be a perfectly straight vertical line from Start's bottom center to
End's top center.

### bottom_top.mmd

```
cargo run -q -- tests/fixtures/bottom_top.mmd
```

**mmdflux output:**
```
┌──────┐
│ Roof │
└──────┘
     ▲
     │
┌───────────┐
│ Structure │
└───────────┘
      ▲
      └┐
       │
┌────────────┐
│ Foundation │
└────────────┘
```

The `└┐` between Foundation and Structure shows a jog. All three nodes share
x-center in Mermaid (x=78.0) and should have straight vertical edges.

## Expected behavior

Straight vertical edges between center-aligned nodes, with no right-angle jogs.

## Root cause hypothesis

The ASCII attachment point calculation maps dagre float centers to discrete
character columns. When source and target have different widths (different
character counts), the center columns differ by 1 cell, producing a jog. The
offset is approximately `(source_width - target_width) / 2` cells at the
ASCII level. The fix likely requires rounding attachment points to match when
the dagre coordinates indicate aligned centers.
