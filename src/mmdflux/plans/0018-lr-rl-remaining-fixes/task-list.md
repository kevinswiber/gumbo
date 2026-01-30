# LR/RL Remaining Fixes Task List

## Status: ✅ COMPLETE

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## TDD Methodology

Every task follows **Red-Green-Refactor**:

1. **RED** — Write a failing test (compile error or assertion failure). Run it. Confirm it fails for the expected reason. Do not write implementation code.
2. **GREEN** — Write the minimum code to make the test pass. Run it. Confirm it passes.
3. **REFACTOR** — Clean up while keeping tests green. Run `cargo test` to confirm no regressions. Commit.

Each task file documents what tests to write, what failure to expect, what minimal implementation satisfies the tests, and what refactoring opportunities exist.

---

## Phase 1: Canvas Vertical Trimming (Issue 1)

- [x] **1.1** Canvas vertical trimming
  → [tasks/1.1-canvas-vertical-trimming.md](./tasks/1.1-canvas-vertical-trimming.md)
  - RED: 3 tests — trims leading rows, trims trailing rows, preserves interior rows
  - GREEN: 4-line insertion in `Display::fmt()`
  - REFACTOR: verify `cargo test`

## Phase 2: Direction-Aware Separation (Issue 3)

- [x] **2.1** Add `edge_sep` and dummy-aware separation in BK compaction
  → [tasks/2.1-direction-aware-nodesep.md](./tasks/2.1-direction-aware-nodesep.md)
  - RED: 3 tests — dummy-dummy uses `edge_sep`, real-real uses `node_sep`, mixed uses average
  - GREEN: add `edge_sep` to `LayoutConfig`/`BKConfig`, dummy-aware `place_block()`
  - REFACTOR: update all existing `BKConfig` literals, `cargo test`

- [x] **2.2** Direction-aware defaults for `node_sep` and `edge_sep`
  → [tasks/2.2-direction-aware-defaults.md](./tasks/2.2-direction-aware-defaults.md)
  - RED: 1 test — LR fan-out vertical gaps <= 6 lines
  - GREEN: compute `node_sep`/`edge_sep` from avg node height for LR/RL
  - REFACTOR: verify TD/BT unchanged, `cargo test`

## Phase 3: Post-BK Source Centering (Issue 2)

- [x] **3.1** Post-BK centering pass for layer-0 nodes
  → [tasks/3.1-post-bk-centering.md](./tasks/3.1-post-bk-centering.md)
  - RED: 1 test — source A centered within 2 rows of targets center
  - GREEN: centering pass in `assign_horizontal()` after `position_x()`
  - REFACTOR: verify TD/BT unchanged, `cargo test`

## Phase 4: Segment-Aware LR Label Placement (Issues 5/6)

- [x] **4.1** Add `select_label_segment_horizontal()` function
  → [tasks/4.1-select-label-segment-horizontal.md](./tasks/4.1-select-label-segment-horizontal.md)
  - RED: 3 tests — short path returns last horizontal, long path returns longest inner, no horizontals returns None
  - GREEN: function mirroring `select_label_segment()` for horizontal segments
  - REFACTOR: consider generic helper (likely not worth it), `cargo test`

- [x] **4.2** Rewrite LR/RL label placement branches
  → [tasks/4.2-lr-rl-label-placement.md](./tasks/4.2-lr-rl-label-placement.md)
  - RED: 1-2 tests — label Y within 1 row of actual horizontal segment
  - GREEN: replace naive midpoint with `select_label_segment_horizontal()` in LR/RL branches
  - REFACTOR: consider deduplicating LR/RL branches, `cargo test`

## Phase 5: Final Validation

- [x] **5.1** Run `cargo test` — full suite, no regressions
- [x] **5.2** Visual verification of LR/RL fixtures (`left_right.mmd`, `fan_in_lr.mmd`, `right_left.mmd`, `git_workflow.mmd`)
- [x] **5.3** Visual verification of TD/BT fixtures (`simple.mmd`, `fan_in.mmd`, `fan_out.mmd`, `complex.mmd`, `labeled_edges.mmd`)

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Canvas Vertical Trimming | ✅ Complete | |
| 2 - Direction-Aware Separation | ✅ Complete | |
| 3 - Post-BK Source Centering | ✅ Complete | |
| 4 - LR Label Placement | ✅ Complete | |
| 5 - Final Validation | ✅ Complete | |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: LR/RL Issues | [research/0011-lr-rl-rendering-issues/synthesis.md](../../research/0011-lr-rl-rendering-issues/synthesis.md) |
| Issues File | [issues/0001-lr-layout-and-backward-edge-issues/issues.md](../../issues/0001-lr-layout-and-backward-edge-issues/issues.md) |
