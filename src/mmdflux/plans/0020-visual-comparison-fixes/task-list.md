# Visual Comparison Fixes Task List

## Status: ✅ COMPLETE

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: LR/RL Attachment Point Alignment (Category A — Issues 1, 4, 6)

- [x] **1.1** Add consensus-y unit tests for `resolve_attachment_points`
  → [tasks/1.1-consensus-y-tests.md](./tasks/1.1-consensus-y-tests.md)

- [x] **1.2** Implement consensus-y in `resolve_attachment_points`
  → [tasks/1.2-consensus-y-impl.md](./tasks/1.2-consensus-y-impl.md)

- [x] **1.3** Integration tests for LR forward edge horizontal segments
  → [tasks/1.3-lr-forward-integration.md](./tasks/1.3-lr-forward-integration.md)

- [x] **1.4** Integration tests for LR backward edge routing
  → [tasks/1.4-lr-backward-integration.md](./tasks/1.4-lr-backward-integration.md)

## Phase 2: Centering Jog Fix (Category D — Issue 3)

- [x] **2.1** Add `dagre_center` fields to `NodeBounds`
  → [tasks/2.1-dagre-center-fields.md](./tasks/2.1-dagre-center-fields.md)

- [x] **2.2** Populate `dagre_center` in layout pipelines
  → [tasks/2.2-populate-dagre-center.md](./tasks/2.2-populate-dagre-center.md)

- [x] **2.3** Update all `NodeBounds` construction sites
  → [tasks/2.3-update-construction-sites.md](./tasks/2.3-update-construction-sites.md)

## Phase 3: Attachment Point Ordering (Category C — Issues 7, 8)

- [x] **3.1** Consistent sort key in `sort_face_group`
  → [tasks/3.1-consistent-sort-key.md](./tasks/3.1-consistent-sort-key.md)

- [x] **3.2** Arrow overwrite protection
  → [tasks/3.2-arrow-overwrite-protection.md](./tasks/3.2-arrow-overwrite-protection.md)

- [x] **3.3** Integration test for fan attachment ordering
  → [tasks/3.3-fan-attachment-integration.md](./tasks/3.3-fan-attachment-integration.md)

## Phase 4: LR Label Placement Fix (Category E — Issue 5)

- [x] **4.1** Relax `select_label_segment_horizontal` filtering
  *(Already handled — or_else fallback already searches all segments)*

- [x] **4.2** Fix LR fallback to use anchor Y
  → [tasks/4.2-lr-label-anchor.md](./tasks/4.2-lr-label-anchor.md)

## Phase 5: BK Block Graph Stagger (Category B — Issues 2, 9)

- [x] **5.1** Research dagre.js block graph implementation
  → [tasks/5.1-research-block-graph.md](./tasks/5.1-research-block-graph.md)
  *(Research found root cause: overhang offset missing from waypoint/label transforms)*

- [x] **5.2** Identify skip-edge stagger test cases
  → [tasks/5.2-stagger-test-cases.md](./tasks/5.2-stagger-test-cases.md)
  *(TDD red: skip_edge_separation tests for double_skip.mmd and skip_edge_collision.mmd)*

- [x] **5.3** Fix waypoint overhang offset
  *(Replaced post-BK nudge — applied overhang_x/overhang_y to transform_waypoints_direct and transform_label_positions_direct)*

- [x] **5.4** Integration test for stagger visibility
  → [tasks/5.4-stagger-integration.md](./tasks/5.4-stagger-integration.md)
  *(All 57 tests pass including new separation tests)*

## Commit Policy

**Commit after every phase.** Do not batch phases. Each phase commit uses: `feat(plan-0020): Phase N - <description>`

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - LR/RL Routing | Complete | Consensus-y, zero-gap fix, rank gap repair |
| 2 - Centering Jog | Complete | Overhang offset fix, dagre centers stored |
| 3 - Attachment Ordering | Complete | Approach-based sort, arrow protection |
| 4 - Label Placement | Complete | Anchor y to source exit, fallback already correct |
| 5 - BK Stagger | Complete | Overhang offset fix for waypoint/label transforms |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Synthesis | [synthesis.md](../../research/0013-visual-comparison-fixes/synthesis.md) |
| Research: LR Routing | [q1-lr-edge-routing.md](../../research/0013-visual-comparison-fixes/q1-lr-edge-routing.md) |
| Research: BK Stagger | [q2-bk-stagger-mechanism.md](../../research/0013-visual-comparison-fixes/q2-bk-stagger-mechanism.md) |
| Research: Attachment Ordering | [q3-attachment-point-ordering.md](../../research/0013-visual-comparison-fixes/q3-attachment-point-ordering.md) |
| Research: Centering Jog | [q4-centering-jog-analysis.md](../../research/0013-visual-comparison-fixes/q4-centering-jog-analysis.md) |
| Research: Label Placement | [q5-lr-label-placement.md](../../research/0013-visual-comparison-fixes/q5-lr-label-placement.md) |
