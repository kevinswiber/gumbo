# LR/RL Remaining Fixes Implementation Plan

## Status: 🚧 IN PROGRESS

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Fix 5 remaining LR/RL rendering issues identified in `issues/0001-lr-layout-and-backward-edge-issues/issues.md`. Issues 4 and 7 (backward edge routing bugs) were already fixed in commit 83d4877. The remaining issues are:

- **Issue 1:** Canvas vertical trimming — blank rows above LR content
- **Issue 2:** Source not centered among LR targets — BK algorithm limitation
- **Issue 3:** Excessive vertical spacing in LR — miscalibrated node_sep, missing edge_sep
- **Issues 5/6:** Edge labels detached in LR — naive midpoint placement

## TDD Methodology

All implementation follows strict **Red-Green-Refactor**:

1. **RED** — Write a failing test first. Run it. Confirm it fails for the expected reason. Do not write any implementation code during this phase.
2. **GREEN** — Write the minimum code to make the test pass. No more, no less. Run the test to confirm it passes.
3. **REFACTOR** — Clean up while keeping all tests green. Run `cargo test` to confirm no regressions. Commit after refactoring.

Each task file documents the full TDD cycle: what tests to write, what failure to expect, what minimal code satisfies the test, and what refactoring to consider.

## Current State

The `Display::fmt()` in `canvas.rs` only strips horizontal whitespace. The dagre module uses hardcoded `node_sep=50.0` with no `edge_sep` (dagre.js uses `edgesep=20` for dummy node separation). The BK algorithm only uses predecessors for alignment. LR label placement uses a naive midpoint formula.

## Implementation Approach

Five phases ordered by independence and risk:

1. **Canvas vertical trimming** — standalone fix, lowest risk
2. **Direction-aware separation** — add `edge_sep` for dummy nodes, direction-aware defaults
3. **Post-BK source centering** — algorithmic addition to dagre pipeline
4. **Segment-aware LR label placement** — render layer change
5. **Final validation** — full regression testing + visual verification

## Files to Modify

| File | Phase | Change |
|------|-------|--------|
| `src/render/canvas.rs` | 1 | Add leading/trailing empty row trimming to `Display::fmt()` |
| `src/dagre/types.rs` | 2 | Add `edge_sep` field to `LayoutConfig` |
| `src/dagre/bk.rs` | 2 | Add `edge_sep` to `BKConfig`, dummy-aware separation in `place_block()` |
| `src/dagre/position.rs` | 2, 3 | Pass `edge_sep` through `BKConfig`; add post-BK centering pass |
| `src/render/layout.rs` | 2 | Compute direction-aware `node_sep` and `edge_sep` |
| `src/render/edge.rs` | 4 | Add `select_label_segment_horizontal()` and rewrite LR/RL label branches |

## Task Details

| Task | Description | TDD Focus | Details |
|------|-------------|-----------|---------|
| 1.1 | Canvas vertical trimming | 3 unit tests on canvas row trimming | [tasks/1.1-canvas-vertical-trimming.md](./tasks/1.1-canvas-vertical-trimming.md) |
| 2.1 | Add `edge_sep` + dummy-aware separation | 3 unit tests on BK separation (dummy, real, mixed) | [tasks/2.1-direction-aware-nodesep.md](./tasks/2.1-direction-aware-nodesep.md) |
| 2.2 | Direction-aware defaults | 1 layout test on LR spacing | [tasks/2.2-direction-aware-defaults.md](./tasks/2.2-direction-aware-defaults.md) |
| 3.1 | Post-BK source centering | 1 layout test on source centering | [tasks/3.1-post-bk-centering.md](./tasks/3.1-post-bk-centering.md) |
| 4.1 | `select_label_segment_horizontal()` | 3 unit tests on segment selection | [tasks/4.1-select-label-segment-horizontal.md](./tasks/4.1-select-label-segment-horizontal.md) |
| 4.2 | Rewrite LR/RL label placement | 1-2 integration tests on label proximity | [tasks/4.2-lr-rl-label-placement.md](./tasks/4.2-lr-rl-label-placement.md) |
| 5.1 | Full test suite | `cargo test` | *(inline)* |
| 5.2 | LR/RL visual verification | Manual check of fixtures | *(inline)* |
| 5.3 | TD/BT visual verification | Manual check of fixtures (no regression) | *(inline)* |

## Research References

- [synthesis.md](../../research/0011-lr-rl-rendering-issues/synthesis.md) — Combined findings and fix plan
- [q1-canvas-top-margin.md](../../research/0011-lr-rl-rendering-issues/q1-canvas-top-margin.md) — Canvas vertical trimming analysis
- [q3-lr-label-placement.md](../../research/0011-lr-rl-rendering-issues/q3-lr-label-placement.md) — Label placement analysis
- [q4-lr-centering-and-spacing.md](../../research/0011-lr-rl-rendering-issues/q4-lr-centering-and-spacing.md) — Dagre coordinate mapping analysis
- [dagre-edge-points-analysis.md](../../research/archive/0009-attachment-point-spreading/dagre-edge-points-analysis.md) — dagre.js `sep()` and `edgesep` analysis

## Testing Strategy

**Per-task (TDD):**
- Each task writes failing tests first (RED)
- Minimal implementation makes tests pass (GREEN)
- Cleanup while green (REFACTOR)
- Commit after each phase

**Total new tests:** ~12 (3 canvas + 3 BK separation + 1 LR spacing + 1 centering + 3 segment selection + 1-2 label proximity)

**Final validation:**
1. `cargo test` — full suite, no regressions
2. `cargo test --test integration` — all fixtures
3. Visual verification of LR/RL fixtures
4. Visual verification of TD/BT fixtures (no regression)
