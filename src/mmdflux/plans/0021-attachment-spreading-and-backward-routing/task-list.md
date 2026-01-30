# Attachment Spreading & Single-Rank Backward Routing Task List

## Status: ✅ COMPLETE

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Spread Formula Improvement

- [x] **1.1** Replace centering formula with endpoint-maximizing formula
  → [tasks/1.1-endpoint-spread-formula.md](./tasks/1.1-endpoint-spread-formula.md)

- [x] **1.2** Update unit tests and snapshot baselines for new formula
  → [tasks/1.2-update-spread-unit-tests.md](./tasks/1.2-update-spread-unit-tests.md)

## Phase 2: Minimum Gap Enforcement

- [x] **2.1** Add MIN_ATTACHMENT_GAP constant and enforcement logic
  → [tasks/2.1-min-gap-enforcement.md](./tasks/2.1-min-gap-enforcement.md)

## Phase 3: Single-Rank Backward Edge Routing

- [x] **3.1** Implement generate_backward_waypoints()
  → [tasks/3.1-synthetic-backward-waypoints.md](./tasks/3.1-synthetic-backward-waypoints.md)

- [x] **3.2** Wire into route_edge() and add canvas margin
  → [tasks/3.2-wire-backward-routing.md](./tasks/3.2-wire-backward-routing.md)

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Spread Formula | Complete | b6cc0e2 |
| 2 - Min Gap | Complete | 45f8c5f |
| 3 - Backward Routing | Complete | 95cf793 |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Remaining Visual Issues | [research/0014-remaining-visual-issues/synthesis.md](../../research/0014-remaining-visual-issues/synthesis.md) |
| Research: Attachment Overlap | [research/0014-remaining-visual-issues/q3-attachment-overlap.md](../../research/0014-remaining-visual-issues/q3-attachment-overlap.md) |
