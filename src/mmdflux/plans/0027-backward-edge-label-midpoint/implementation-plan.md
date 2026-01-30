# Backward Edge Label Placement via Path-Midpoint

## Status: 🚧 IN PROGRESS

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Backward edge labels in mmdflux render at wrong cross-axis positions because label positions are computed from dagre's abstract layout-space coordinates, while backward edges are routed synthetically via `generate_backward_waypoints()` at completely different cross-axis positions. This plan implements a mermaid-style path-midpoint algorithm that computes backward edge label positions from the actual routed segments, bypassing dagre's precomputed positions entirely for backward edges.

## Current State

- Dagre computes label positions via label dummy nodes in abstract layout space
- `transform_label_positions_direct()` converts these to ASCII coordinates using rank-based snapping (primary axis) and uniform scaling (cross axis)
- Backward edges are routed synthetically by `generate_backward_waypoints()` at completely different cross-axis positions
- The precomputed label position from dagre does not match the synthetic route
- Existing heuristics in `draw_edge_label_with_tracking()` use a brittle 6-segment threshold and direction-specific branching
- Research 0020 recommends a path-midpoint algorithm mirroring mermaid's `calcLabelPosition()`

## Implementation Approach

Add a `calc_label_position()` function that walks orthogonal segments by Manhattan distance to find the 50% mark of the total path length. For backward edges, use this instead of dagre's precomputed label position. Offset the label by a small amount so it sits beside the edge line, not on it.

### Phases

1. **Segment Helper Methods** — Add `length()`, `point_at_offset()`, `start_point()`, `end_point()` to `Segment`
2. **Path-Midpoint Function** — Implement `calc_label_position(&[Segment]) -> Option<Point>`
3. **RoutedEdge `is_backward` Field** — Cache backward classification in the routing result
4. **Rendering Integration** — Wire up path-midpoint for backward edges in `render_all_edges_with_labels()`
5. **Integration Tests** — Verify backward edge labels across all four layout directions

## Files to Modify/Create

| File | Change |
|------|--------|
| `src/render/router.rs` | Add Segment methods, is_backward field on RoutedEdge |
| `src/render/edge.rs` | Add calc_label_position(), offset_label_from_path(), modify render_all_edges_with_labels() |
| `src/render/layout.rs` | Strip precomputed label positions for backward edges |
| `tests/integration.rs` | Add backward edge label position tests for all directions |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Add Segment helper methods | [tasks/1.1-segment-helpers.md](./tasks/1.1-segment-helpers.md) |
| 2.1 | Implement calc_label_position() | [tasks/2.1-calc-label-position.md](./tasks/2.1-calc-label-position.md) |
| 3.1 | Add is_backward field to RoutedEdge | [tasks/3.1-is-backward-field.md](./tasks/3.1-is-backward-field.md) |
| 4.1 | Wire up path-midpoint for backward edge labels | [tasks/4.1-rendering-integration.md](./tasks/4.1-rendering-integration.md) |
| 5.1 | Integration tests for all directions | [tasks/5.1-integration-tests.md](./tasks/5.1-integration-tests.md) |

## Research References

- [Research 0020: Backward Edge Label Placement](../../research/0020-backward-edge-label-placement/synthesis.md)
- [Q1: mmdflux current pipeline](../../research/0020-backward-edge-label-placement/q1-mmdflux-current-pipeline.md)
- [Q2: dagre/mermaid comparison](../../research/0020-backward-edge-label-placement/q2-dagre-mermaid-comparison.md)
- [Q3: Fix strategy](../../research/0020-backward-edge-label-placement/q3-fix-strategy.md)

## Testing Strategy

All tasks follow TDD Red/Green/Refactor:
- **Phase 1-2**: Unit tests for Segment helpers and calc_label_position() with constructed segment lists
- **Phase 3**: Unit tests verifying is_backward is set correctly for forward/backward edges
- **Phase 4**: Unit/integration tests verifying backward edge labels appear near the routed path
- **Phase 5**: Cross-direction integration tests (TD, BT, LR, RL) verifying label positioning
