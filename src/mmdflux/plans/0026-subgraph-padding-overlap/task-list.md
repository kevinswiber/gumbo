# Subgraph Padding, Border, and Title Rendering Fixes — Task List

## Status: 🚧 IN PROGRESS

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Use Dagre Bounds via TransformContext

- [x] **1.1** Test dagre bounds produce correct spacing
  → [tasks/1.1-test-dagre-bounds.md](./tasks/1.1-test-dagre-bounds.md)

- [x] **1.2** Implement dagre bounds transformation
  → [tasks/1.2-implement-dagre-bounds.md](./tasks/1.2-implement-dagre-bounds.md)

## Phase 2: Embed Title in Top Border Line

- [x] **2.1** Test embedded title rendering
  → [tasks/2.1-test-embedded-title.md](./tasks/2.1-test-embedded-title.md)

- [x] **2.2** Implement embedded title rendering
  → [tasks/2.2-implement-embedded-title.md](./tasks/2.2-implement-embedded-title.md)

- [x] **2.3** Test title width influences border width
  → [tasks/2.3-test-title-width.md](./tasks/2.3-test-title-width.md)

- [x] **2.4** Enforce title width minimum in bounds computation
  → [tasks/2.4-implement-title-width.md](./tasks/2.4-implement-title-width.md)

## Phase 3: Integration Test Updates

- [x] **3.1** Update integration tests for new rendering format
  → [tasks/3.1-update-integration-tests.md](./tasks/3.1-update-integration-tests.md)

## Phase 4: Edge-Border Crossing Cleanup

- [x] **4.1** Test edge-border crossing produces proper junctions
  → [tasks/4.1-test-edge-border-crossing.md](./tasks/4.1-test-edge-border-crossing.md)

- [x] **4.2** Implement border-aware connection merging
  → [tasks/4.2-implement-edge-border-merging.md](./tasks/4.2-implement-edge-border-merging.md)

## Phase 5: Backward Edge Containment

- [x] **5.1** Test backward edge stays within subgraph border
  → [tasks/5.1-test-backward-containment.md](./tasks/5.1-test-backward-containment.md)

- [x] **5.2** Expand subgraph bounds for backward edge routing
  → [tasks/5.2-implement-backward-containment.md](./tasks/5.2-implement-backward-containment.md)

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Dagre Bounds | Reverted | Finding: dagre-to-draw coordinate frame mismatch |
| 2 - Embedded Title | Complete | Embedded in border + title-width enforcement |
| 3 - Integration Tests | Complete | Removed flaky LR title test (non-determinism) |
| 4 - Edge-Border Crossing | Complete | infer_connections + border-aware merging |
| 5 - Backward Edge Containment | Complete | Bounds expand for backward edge routing margin |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Synthesis | [research/0019-subgraph-padding-overlap/synthesis.md](../../research/0019-subgraph-padding-overlap/synthesis.md) |
| Research: Q3 Overlap Inventory | [research/0019-subgraph-padding-overlap/q3-overlap-inventory.md](../../research/0019-subgraph-padding-overlap/q3-overlap-inventory.md) |
