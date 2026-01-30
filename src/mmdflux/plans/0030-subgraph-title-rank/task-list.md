# Subgraph Title Rank Task List

## Status: 🚧 IN PROGRESS

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Add Storage Fields

- [x] **1.1** Add `border_title` field to LayoutGraph
  → [tasks/1.1-border-title-field.md](./tasks/1.1-border-title-field.md)

- [x] **1.2** Add `compound_titles` to LayoutGraph and `set_has_title()` to DiGraph
  → [tasks/1.2-compound-titles-field.md](./tasks/1.2-compound-titles-field.md)

## Phase 2: Insert Title Dummy Nodes

- [x] **2.1** Create title dummy node in `nesting::run()` for titled compounds
  → [tasks/2.1-title-node-insertion.md](./tasks/2.1-title-node-insertion.md)

- [x] **2.3** Update `assign_rank_minmax` to use title rank as min_rank
  → [tasks/2.3-assign-rank-minmax.md](./tasks/2.3-assign-rank-minmax.md)

## Phase 3: Fix Ordering

- [x] **3.1** Handle single-child ranks in `apply_compound_constraints()`
  → [tasks/3.1-ordering-single-child.md](./tasks/3.1-ordering-single-child.md)

## Phase 4: Render Layer Adjustments

- [ ] **4.1** Wire title info in `compute_layout_direct()`
  → [tasks/4.1-wire-title-info.md](./tasks/4.1-wire-title-info.md)

- [ ] **4.2** Adjust `convert_subgraph_bounds()` for title space
  → [tasks/4.2-adjust-subgraph-bounds.md](./tasks/4.2-adjust-subgraph-bounds.md)

## Phase 5: Integration Tests

- [ ] **5.1** Add title collision fixture and integration tests; update existing snapshots
  → [tasks/5.1-integration-tests.md](./tasks/5.1-integration-tests.md)

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Storage Fields | Complete | e1e1a36 |
| 2 - Title Dummy Nodes | Complete | eb14a63 |
| 3 - Ordering Fix | Complete | 21805ad |
| 4 - Render Adjustments | Not Started | Independent of Phase 3 |
| 5 - Integration Tests | Not Started | Depends on Phases 3+4 |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Synthesis | [synthesis.md](../../research/0023-subgraph-title-arrow-collision/layout-level-structural-fix/synthesis.md) |
| Research: Q1 Nesting | [q1-nesting-insertion.md](../../research/0023-subgraph-title-arrow-collision/layout-level-structural-fix/q1-nesting-insertion.md) |
| Research: Q2 Ordering | [q2-border-ordering-impact.md](../../research/0023-subgraph-title-arrow-collision/layout-level-structural-fix/q2-border-ordering-impact.md) |
