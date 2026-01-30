# Visual Comparison Fixes Implementation Plan

## Status: 🚧 IN PROGRESS

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Addresses 9 visual comparison issues grouped into 5 root cause categories identified in research/0013. Fixes are ordered by impact and dependency: LR routing first (highest impact), then centering jog (quick win), attachment ordering (benefits from LR fix), label placement (localized), and BK stagger (most architecturally significant).

## Current State

The `compute_layout_direct` pipeline is the default renderer. Visual comparison with Mermaid's reference output revealed 9 issues across 5 root causes:

| Category | Root Cause | Issues |
|----------|-----------|--------|
| A: LR routing | `resolve_attachment_points()` uses per-node `center_y()` | 1, 4, 6 |
| B: BK stagger | Missing block graph in horizontal compaction | 2, 9 |
| C: Attachment ordering | Face classification vs sorting divergence | 7, 8 |
| D: Centering jog | Integer division in `center_x()` | 3 |
| E: Label placement | Fallback midpoint in empty space | 5 |

## Implementation Approach

Five phases, each addressing one root cause category:

1. **Phase 1: LR/RL Attachment Point Alignment** — Compute consensus y-coordinate for same-rank LR/RL edges so attachment points align horizontally
2. **Phase 2: Centering Jog Fix** — Store dagre-derived integer centers in `NodeBounds` to avoid re-derivation via integer division
3. **Phase 3: Attachment Point Ordering** — Sort face groups by approach point cross-axis coordinate; protect arrows from overwrite
4. **Phase 4: LR Label Placement** — Anchor fallback label position to source exit point instead of averaged midpoint
5. **Phase 5: BK Block Graph Stagger** — Add post-BK nudge pass to separate skip-edge dummy chains from adjacent real nodes

## Files to Modify/Create

| File | Phases | Changes |
|------|--------|---------|
| `src/render/router.rs` | 1, 3 | Consensus y in `resolve_attachment_points()`; consistent sort key in `sort_face_group()` |
| `src/render/shape.rs` | 2 | Add `dagre_center_x/y` fields to `NodeBounds`; update `center_x()`/`center_y()` |
| `src/render/layout.rs` | 2 | Populate `dagre_center_x/y` when constructing `NodeBounds` |
| `src/render/edge.rs` | 3, 4 | Arrow overwrite protection; label placement fallback fix |
| `src/dagre/bk.rs` | 5 | Post-BK nudge pass for skip-edge stagger |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Consensus-y unit tests for `resolve_attachment_points` | [tasks/1.1-consensus-y-tests.md](./tasks/1.1-consensus-y-tests.md) |
| 1.2 | Implement consensus-y in `resolve_attachment_points` | [tasks/1.2-consensus-y-impl.md](./tasks/1.2-consensus-y-impl.md) |
| 1.3 | Integration tests for LR forward edge horizontal segments | [tasks/1.3-lr-forward-integration.md](./tasks/1.3-lr-forward-integration.md) |
| 1.4 | Integration tests for LR backward edge routing | [tasks/1.4-lr-backward-integration.md](./tasks/1.4-lr-backward-integration.md) |
| 2.1 | Add `dagre_center` fields to `NodeBounds` | [tasks/2.1-dagre-center-fields.md](./tasks/2.1-dagre-center-fields.md) |
| 2.2 | Populate `dagre_center` in layout pipelines | [tasks/2.2-populate-dagre-center.md](./tasks/2.2-populate-dagre-center.md) |
| 2.3 | Update all `NodeBounds` construction sites | [tasks/2.3-update-construction-sites.md](./tasks/2.3-update-construction-sites.md) |
| 3.1 | Consistent sort key in `sort_face_group` | [tasks/3.1-consistent-sort-key.md](./tasks/3.1-consistent-sort-key.md) |
| 3.2 | Arrow overwrite protection | [tasks/3.2-arrow-overwrite-protection.md](./tasks/3.2-arrow-overwrite-protection.md) |
| 3.3 | Integration test for fan attachment ordering | [tasks/3.3-fan-attachment-integration.md](./tasks/3.3-fan-attachment-integration.md) |
| 4.1 | Relax `select_label_segment_horizontal` filtering | [tasks/4.1-relax-label-segment.md](./tasks/4.1-relax-label-segment.md) |
| 4.2 | Fix LR fallback to use anchor Y | [tasks/4.2-lr-label-anchor.md](./tasks/4.2-lr-label-anchor.md) |
| 5.1 | Research dagre.js block graph implementation | [tasks/5.1-research-block-graph.md](./tasks/5.1-research-block-graph.md) |
| 5.2 | Identify skip-edge stagger test cases | [tasks/5.2-stagger-test-cases.md](./tasks/5.2-stagger-test-cases.md) |
| 5.3 | Implement post-BK nudge pass | [tasks/5.3-post-bk-nudge.md](./tasks/5.3-post-bk-nudge.md) |
| 5.4 | Integration test for stagger visibility | [tasks/5.4-stagger-integration.md](./tasks/5.4-stagger-integration.md) |

## Research References

- [synthesis.md](../../research/0013-visual-comparison-fixes/synthesis.md) — Overall synthesis of all 5 categories
- [q1-lr-edge-routing.md](../../research/0013-visual-comparison-fixes/q1-lr-edge-routing.md) — LR routing root cause analysis
- [q2-bk-stagger-mechanism.md](../../research/0013-visual-comparison-fixes/q2-bk-stagger-mechanism.md) — BK stagger analysis
- [q3-attachment-point-ordering.md](../../research/0013-visual-comparison-fixes/q3-attachment-point-ordering.md) — Attachment ordering analysis
- [q4-centering-jog-analysis.md](../../research/0013-visual-comparison-fixes/q4-centering-jog-analysis.md) — Centering jog analysis
- [q5-lr-label-placement.md](../../research/0013-visual-comparison-fixes/q5-lr-label-placement.md) — Label placement analysis

## Testing Strategy

All tasks follow strict TDD (Red/Green/Refactor). Each phase has:
- **Primary fixtures:** Diagrams that exhibit the specific issue
- **Regression fixtures:** Diagrams that should not change behavior

| Phase | Primary Fixtures | Regression Fixtures |
|-------|-----------------|-------------------|
| 1 | `left_right.mmd`, `fan_in_lr.mmd`, `ci_pipeline.mmd` | `simple.mmd`, `chain.mmd`, `fan_in.mmd` |
| 2 | `simple.mmd`, `bottom_top.mmd` | `left_right.mmd`, `fan_in.mmd` |
| 3 | `fan_in.mmd`, `multiple_cycles.mmd`, `five_fan_in.mmd` | `simple.mmd`, `chain.mmd` |
| 4 | `ci_pipeline.mmd`, `git_workflow.mmd` | `labeled_edges.mmd`, `label_spacing.mmd` |
| 5 | `double_skip.mmd`, `skip_edge_collision.mmd` | `complex.mmd`, `http_request.mmd` |

## Commit Policy

**Commit after every phase.** This plan has 5 phases touching different parts of the codebase. To avoid losing work, create a git commit at the end of each phase with message `feat(plan-0020): Phase N - <description>`. Do not batch phases together.

## Sequencing and Dependencies

```
Phase 1 (LR routing) ──┐
                        ├──> Phase 3 (Attachment ordering)
Phase 2 (Centering)  ───┘         │
                                  ├──> Phase 4 (Label placement)
                                  │
Phase 5 (BK stagger) ────────────────> (independent)
```
