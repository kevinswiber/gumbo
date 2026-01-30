# Fix Forward Edge Label Overlap in LR Layouts

## Status: ✅ COMPLETE

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Fix forward edge labels ("git add", "git commit", "git push") overlapping with adjacent node boxes in LR layouts, and eliminate the stray routing segment artifact (`─┴─────┘`). Both defects share a single root cause in the `layer_starts` midpoint interpolation formula.

**Worktree:** `~/src/mmdflux-label-dummy` (branch `label-dummy-experiment`)

## Current State

In `git_workflow.mmd` (LR layout), the `layer_starts` odd-rank interpolation computes label positions using left-edge-to-left-edge midpoints:

```
label_x = (left_edge_of_source_layer + left_edge_of_target_layer) / 2
```

For Staging → Local: (30 + 60) / 2 = 45, which is inside the Staging Area node (extends to x=46). The centering adjustment in `draw_label_at_position()` compounds the overlap. The same coordinate also triggers `nudge_colliding_waypoints()` to push the label dummy waypoint to y=5, creating a U-shaped routing detour.

## Implementation Approach

Three-phase fix:

1. **Phase 1 (Core Fix):** Compute `layer_ends_raw` (max right edge per layer) alongside `layer_starts_raw`, then use right-edge-to-left-edge midpoint for odd ranks.
2. **Phase 2 (Safety Net):** Route precomputed label positions through `find_safe_label_position()` so rounding errors or edge cases are caught.
3. **Phase 3 (Verification):** Strengthen `git_workflow_renders` test to assert full label visibility and absence of stray segments.

## Files to Modify/Create

| File | Change |
|------|--------|
| `src/render/layout.rs` | Add `layer_ends_raw` computation; fix odd-rank interpolation formula |
| `src/render/edge.rs` | Add `find_safe_label_position()` call for precomputed labels |
| `tests/integration.rs` | Strengthen `git_workflow_renders` test assertions |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Fix `layer_starts` odd-rank interpolation using layer right edges | [tasks/1.1-fix-layer-starts-midpoint.md](./tasks/1.1-fix-layer-starts-midpoint.md) |
| 2.1 | Add collision avoidance safety net for precomputed labels | [tasks/2.1-precomputed-label-collision-avoidance.md](./tasks/2.1-precomputed-label-collision-avoidance.md) |
| 3.1 | Strengthen git_workflow integration test and verify no regressions | [tasks/3.1-strengthen-integration-tests.md](./tasks/3.1-strengthen-integration-tests.md) |

## Research References

- [Research 0022 Synthesis](../../research/0022-lr-forward-label-overlap/synthesis.md) — Root cause analysis
- [Q1: Label Position Trace](../../research/0022-lr-forward-label-overlap/q1-label-position-trace.md) — Exact coordinates at each pipeline stage
- [Q2: Node Boundary Analysis](../../research/0022-lr-forward-label-overlap/q2-node-boundary-analysis.md) — Why positions land inside nodes
- [Q3: Collision Avoidance Analysis](../../research/0022-lr-forward-label-overlap/q3-collision-avoidance-analysis.md) — Design rationale for skipping collision avoidance
- [Q4: Stray Segment Investigation](../../research/0022-lr-forward-label-overlap/q4-stray-segment-investigation.md) — Root cause of routing artifact

## Testing Strategy

All tasks follow TDD (Red/Green/Refactor). Key test coverage:
- `git_workflow.mmd` — primary fixture for the fix (LR layout with labeled forward and backward edges)
- `labeled_edges.mmd`, `label_spacing.mmd` — TD layout label fixtures to verify no regression
- `left_right.mmd`, `right_left.mmd` — LR/RL layout fixtures
- Full `cargo test` suite to catch any unexpected regressions
