# Option 4B: Synthetic Waypoints for Large Horizontal Offset

## Status: 🚧 IN PROGRESS

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Generate synthetic waypoints for forward edges with large horizontal offset that don't receive waypoints from dagre normalization. This provides ~80% of Dagre's edge routing quality at ~20% of the implementation cost.

## Problem Statement

In `complex.mmd`, the edge E→F ("More Data?" → "Output") labeled "no":
- Source E is on the **right side** of the diagram
- Target F is **centered**
- Current routing goes **left through the middle** (crowded area)
- No waypoints exist because it's a "short" edge (adjacent ranks)

## Solution

Generate synthetic waypoints for edges that:
1. Have large horizontal offset (> threshold)
2. Don't already have waypoints from dagre normalization
3. Would benefit from non-standard routing

## Architecture

```
route_edge()
    ↓
[Check backward edge]
    ↓
[Check existing waypoints from dagre]
    ↓
NEW → generate_synthetic_waypoints()
    ↓
    ├─ analyze_edge() → EdgeAnalysis
    │   ├─ horizontal_offset
    │   ├─ source_position (Left/Center/Right)
    │   └─ needs_synthetic_waypoints
    │
    └─ If needs waypoints:
        ├─ generate_source_side_waypoints() [most common]
        └─ route_edge_with_waypoints() [existing infrastructure]
```

## Key Design Decisions

1. **Integration point:** Router phase (not layout phase)
   - All required context available (bounds, shapes, layout)
   - Follows existing pattern (similar to backward edge check)

2. **Single waypoint strategy:** Keep source X, drop to near target Y
   - Forces vertical-first routing on source side
   - Avoids crowded middle

3. **Threshold-based:** Only affects edges with large offset
   - Small offset edges use existing mid-y routing
   - Minimizes visual changes to existing diagrams

## Files Changed

| File | Change |
|------|--------|
| `src/render/router.rs` | Add `generate_synthetic_waypoints()`, `analyze_edge()`, integrate into `route_edge()` |
| `tests/integration.rs` | Update expected output for `complex.mmd` |
| New: `tests/fixtures/horizontal_offset.mmd` | New test fixture |

## Task Details

See [task-list.md](./task-list.md) for the full task breakdown. Key tasks:

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | EdgeAnalysis struct | [tasks/1.1-edge-analysis.md](./tasks/1.1-edge-analysis.md) |
| 1.2 | generate_synthetic_waypoints() | [tasks/1.2-generate-waypoints.md](./tasks/1.2-generate-waypoints.md) |
| 1.3 | Integration into route_edge() | [tasks/1.3-integrate-route-edge.md](./tasks/1.3-integrate-route-edge.md) |
| 1.4 | Unit tests | [tasks/1.4-unit-tests.md](./tasks/1.4-unit-tests.md) |

## Research References

- [01-current-mmdflux-behavior.md](../../research/archive/0006-edge-routing-horizontal-offset/01-current-mmdflux-behavior.md) - Current mid-y routing analysis
- [04-synthesis-and-options.md](../../research/archive/0006-edge-routing-horizontal-offset/04-synthesis-and-options.md) - Options comparison
- [option4-waypoints/01-existing-waypoint-code.md](../../research/archive/0006-edge-routing-horizontal-offset/option4-waypoints/01-existing-waypoint-code.md) - Existing infrastructure analysis
- [option4-waypoints/04-option4-implementation-plan.md](../../research/archive/0006-edge-routing-horizontal-offset/option4-waypoints/04-option4-implementation-plan.md) - Detailed implementation plan
- [05-full-dagre-parity-analysis.md](../../research/archive/0006-edge-routing-horizontal-offset/05-full-dagre-parity-analysis.md) - Full parity analysis

## Success Criteria

1. E→F "no" edge in `complex.mmd` routes via right side, not through middle
2. All existing tests pass (may need output updates)
3. No visual regressions in simple diagrams
