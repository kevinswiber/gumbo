# Attachment Spreading & Single-Rank Backward Routing Implementation Plan

## Status: 🚧 IN PROGRESS

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Implement the three remaining actionable items from research 0014 (remaining visual comparison issues). Q1 (LR/RL backward routing) and Q4 (TD label placement) were already fixed. This plan addresses:

1. **Spread formula improvement** — switch from centering to endpoint-maximizing
2. **Minimum gap enforcement** — prevent arrow collisions on narrow faces
3. **Single-rank backward edge routing** — synthetic waypoints to route around nodes

Q2 (BK block graph) is explicitly deferred to a separate plan due to large scope and aesthetic-only impact.

## Current State

- `spread_points_on_face()` in `src/render/intersect.rs` uses a centering formula `((i+1) * range) / (count+1)` that wastes edge space. It already has an `use_endpoints` branch for `range < count` that uses the endpoint formula.
- No minimum gap enforcement exists — arrow characters can visually collide when many edges converge on a narrow face.
- Single-rank-span backward edges (no dagre waypoints) route straight through the inter-rank gap via `route_edge_direct()`. Mermaid wraps these around the side of nodes.

## Implementation Approach

Three phases, with Phases 1 and 3 independent (Phase 2 depends on Phase 1):

- **Phase 1:** Replace the centering formula with the endpoint-maximizing formula for all `count >= 2` cases
- **Phase 2:** Add `MIN_ATTACHMENT_GAP` enforcement to prevent arrow collisions on narrow faces
- **Phase 3:** Generate synthetic waypoints for single-rank-span backward edges to route around nodes

## Files to Modify/Create

| File | Phases | Description |
|------|--------|-------------|
| `src/render/intersect.rs` | 1, 2 | Spread formula change + gap enforcement |
| `src/render/router.rs` | 3 | `generate_backward_waypoints()` + call from `route_edge()` |
| `src/render/layout.rs` | 3 | Backward-edge canvas margin |
| `tests/fixtures/very_narrow_fan_in.mmd` | 2 | New fixture for gap enforcement testing |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Replace centering formula with endpoint-maximizing | [tasks/1.1-endpoint-spread-formula.md](./tasks/1.1-endpoint-spread-formula.md) |
| 1.2 | Update unit tests for new formula | [tasks/1.2-update-spread-unit-tests.md](./tasks/1.2-update-spread-unit-tests.md) |
| 1.3 | Update snapshot baselines | *(Covered in 1.2 — run integration tests and update snapshots)* |
| 2.1 | Add MIN_ATTACHMENT_GAP constant and enforcement | [tasks/2.1-min-gap-enforcement.md](./tasks/2.1-min-gap-enforcement.md) |
| 2.2 | Add narrow fan-in test fixture | *(Covered in 2.1)* |
| 3.1 | Implement generate_backward_waypoints() | [tasks/3.1-synthetic-backward-waypoints.md](./tasks/3.1-synthetic-backward-waypoints.md) |
| 3.2 | Wire into route_edge() and add canvas margin | [tasks/3.2-wire-backward-routing.md](./tasks/3.2-wire-backward-routing.md) |
| 3.3 | Update cycle fixture snapshots | *(Covered in 3.2)* |

## Research References

- [research/0014-remaining-visual-issues/synthesis.md](../../research/0014-remaining-visual-issues/synthesis.md) — full synthesis with recommendations
- [research/0014-remaining-visual-issues/q3-attachment-overlap.md](../../research/0014-remaining-visual-issues/q3-attachment-overlap.md) — Q3 attachment overlap analysis
- [research/0014-remaining-visual-issues/q1-lr-multirank-routing.md](../../research/0014-remaining-visual-issues/q1-lr-multirank-routing.md) — Q1 findings including spread formula and single-rank backward edge observations

## Testing Strategy

All tasks follow TDD (Red/Green/Refactor):

- **Phase 1:** Unit tests for `spread_points_on_face()` asserting endpoint positions. Integration tests via existing fan-in fixtures.
- **Phase 2:** Unit tests with narrow ranges asserting MIN_GAP enforcement. New `very_narrow_fan_in.mmd` fixture.
- **Phase 3:** Unit tests for `generate_backward_waypoints()`. Integration tests via `simple_cycle.mmd` and `multiple_cycles.mmd` fixtures — backward edges should have >= 4 path segments.
