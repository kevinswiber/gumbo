# Post-Rank Title Node Insertion Task List

## Status: ✅ COMPLETE

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Remove Title from Nesting Chain

- [x] **1.1** Remove title node creation and title nesting edges from `nesting::run()`
  → [tasks/1.1-remove-title-from-nesting.md](./tasks/1.1-remove-title-from-nesting.md)

## Phase 2: Post-Rank Title Insertion

- [x] **2.1** Add `insert_title_nodes()` function to `nesting.rs`
  → [tasks/2.1-insert-title-nodes.md](./tasks/2.1-insert-title-nodes.md)

- [x] **2.2** Wire `insert_title_nodes()` into the dagre pipeline in `mod.rs`
  → [tasks/2.2-wire-pipeline.md](./tasks/2.2-wire-pipeline.md)

## Phase 3: Update Existing Tests

- [x] **3.1** Update nesting and ordering tests for new pipeline sequence
  → [tasks/3.1-update-tests.md](./tasks/3.1-update-tests.md)

## Phase 4: Render Layer Wiring

- [x] **4.1** Wire `set_has_title()` in `compute_layout_direct()`
  → [tasks/4.1-wire-set-has-title.md](./tasks/4.1-wire-set-has-title.md)

- [x] **4.2** Adjust `convert_subgraph_bounds()` for title space
  → [tasks/4.2-adjust-subgraph-bounds.md](./tasks/4.2-adjust-subgraph-bounds.md)

## Phase 5: Integration Tests

- [x] **5.1** Add multi-subgraph title integration tests; update existing snapshots
  → [tasks/5.1-integration-tests.md](./tasks/5.1-integration-tests.md)

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Remove from Nesting | Complete | Removed title from nesting::run() |
| 2 - Post-Rank Insertion | Complete | insert_title_nodes() with title→border_top edge |
| 3 - Update Tests | Complete | Un-ignored and updated pipeline sequence |
| 4 - Render Wiring | Complete | has_explicit_title field, set_has_title(), title_extra padding |
| 5 - Integration Tests | Complete | 3 integration tests added |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Q5 Post-Rank Insertion | [q5-post-rank-title-insertion.md](../../research/0024-multi-subgraph-title-rank/q5-post-rank-title-insertion.md) |
| Research: Synthesis | [synthesis.md](../../research/0024-multi-subgraph-title-rank/synthesis.md) |
| Plan 0030: Original Title Rank | [../0030-subgraph-title-rank/](../0030-subgraph-title-rank/) |
| Plan 0030 Finding | [multi-subgraph-rank-collision.md](../0030-subgraph-title-rank/findings/multi-subgraph-rank-collision.md) |
