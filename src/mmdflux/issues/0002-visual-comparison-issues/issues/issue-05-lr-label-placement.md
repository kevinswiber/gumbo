# Issue 05: ci_pipeline LR label placement at edges

**Severity:** Low
**Category:** Label placement
**Status:** Fixed (Plan 0020, Phase 4)
**Affected fixtures:** `ci_pipeline`

## Description

In the ci_pipeline LR layout, edge labels ("staging", "production") appear at
the far edges of the diagram rather than centered on their respective edges.

## Root cause hypothesis

LR label placement uses a naive midpoint formula as fallback when
`select_label_segment_horizontal()` returns None for complex waypoint paths.
The midpoint Y doesn't correspond to any actual edge segment for backward
edges, so labels float in empty space.

## Cross-references

- Related to 0001 Issues 5 and 6 (label detachment)
- Plan 0018 Phase 4 partially addressed LR/RL label placement
