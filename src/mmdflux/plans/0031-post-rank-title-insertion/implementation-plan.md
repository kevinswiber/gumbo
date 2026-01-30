# Post-Rank Title Node Insertion Implementation Plan

## Status: 🚧 IN PROGRESS

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Fix the multi-subgraph title rank collision by moving title node creation from the nesting chain (before ranking) to after ranking, at `border_top_rank - 1`. This ensures title nodes never interfere with ranking and always occupy the correct position relative to their subgraph's actual content.

## Current State

Plan 0030 Phases 1-3 are committed and inert:
- Phase 1 (`e1e1a36`): Storage fields (`border_title`, `compound_titles`, `set_has_title()`) -- **KEEP**
- Phase 2 (`eb14a63`): Title insertion in `nesting::run()` with `root → title → border_top` nesting edges -- **MODIFY** (move to post-rank)
- Phase 3 (`21805ad`): Ordering fix for single-child ranks with title nodes -- **KEEP**

No `set_has_title()` calls exist in the render layer, so the title infrastructure is currently dormant. The codebase is clean and all 70 tests pass.

## Implementation Approach

### Pipeline Change

```
BEFORE (plan 0030):                    AFTER (plan 0031):
nesting::run()  ← creates title        nesting::run()  ← NO title
rank::run()     ← title at rank 1      rank::run()     ← no title interference
rank::normalize()                       rank::normalize()
nesting::cleanup()                      nesting::cleanup()
                                        insert_title_nodes()  ← NEW: at bt_rank - 1
nesting::assign_rank_minmax()           nesting::assign_rank_minmax()  ← unchanged
```

### Key Insight

By not putting the title in the nesting chain, the ranking of all other nodes (border_top, children, border_bottom) is identical to the working no-title case. The title is an extra node injected at a known-correct position. See Q5 research for the traced two-subgraph example.

## Files to Modify

| File | Change |
|------|--------|
| `src/dagre/nesting.rs` | Remove title from `run()`, add `insert_title_nodes()` |
| `src/dagre/mod.rs` | Wire `insert_title_nodes()` into pipeline |
| `src/dagre/order.rs` | Update test pipeline sequence |
| `src/render/layout.rs` | Wire `set_has_title()`, adjust bounds for title space |
| `tests/integration.rs` | Add multi-subgraph title integration test |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Remove title creation from `nesting::run()` | [tasks/1.1-remove-title-from-nesting.md](./tasks/1.1-remove-title-from-nesting.md) |
| 2.1 | Add `insert_title_nodes()` function | [tasks/2.1-insert-title-nodes.md](./tasks/2.1-insert-title-nodes.md) |
| 2.2 | Wire `insert_title_nodes()` into pipeline | [tasks/2.2-wire-pipeline.md](./tasks/2.2-wire-pipeline.md) |
| 3.1 | Update existing nesting and ordering tests | [tasks/3.1-update-tests.md](./tasks/3.1-update-tests.md) |
| 4.1 | Wire `set_has_title()` in render layer | [tasks/4.1-wire-set-has-title.md](./tasks/4.1-wire-set-has-title.md) |
| 4.2 | Adjust `convert_subgraph_bounds()` for title space | [tasks/4.2-adjust-subgraph-bounds.md](./tasks/4.2-adjust-subgraph-bounds.md) |
| 5.1 | Integration tests for multi-subgraph titles | [tasks/5.1-integration-tests.md](./tasks/5.1-integration-tests.md) |

## Research References

- [Q5: Post-rank title node insertion](../../research/0024-multi-subgraph-title-rank/q5-post-rank-title-insertion.md) -- detailed feasibility analysis
- [Synthesis](../../research/0024-multi-subgraph-title-rank/synthesis.md) -- cross-cutting findings from all approaches
- [Q1: Render-only approach](../../research/0024-multi-subgraph-title-rank/q1-render-only-approach.md) -- ruled out
- [Q4: dagre-js reference](../../research/0024-multi-subgraph-title-rank/q4-dagre-js-compound-titles.md) -- validates layout-level approach
- [Plan 0030 finding](../0030-subgraph-title-rank/findings/multi-subgraph-rank-collision.md) -- original problem description

## Testing Strategy

All tasks follow strict TDD Red/Green/Refactor. Key test scenarios:
- Single titled subgraph: title rank = border_top_rank - 1
- Two titled subgraphs with cross-edges: distinct title ranks, no garbled output
- Untitled subgraphs: unchanged behavior
- Nested subgraphs: each title correctly positioned relative to its own border_top
- All 70 existing integration tests continue passing
