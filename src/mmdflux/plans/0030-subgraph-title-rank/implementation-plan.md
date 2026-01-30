# Subgraph Title Rank Implementation Plan

## Status: 🚧 IN PROGRESS

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Add a dedicated "title rank" to dagre's nesting system so that subgraph titles have guaranteed vertical space, preventing collisions with edge segments. For each compound node with a non-empty title, a title dummy node is inserted one rank above `border_top`, reserving vertical space that prevents edges from overlapping subgraph titles.

## Current State

Subgraph titles are embedded in the top border row (`┌─ Title ─┐`). Cross-subgraph edges entering from above can route through this same row, overwriting the title text. The dagre nesting system creates `border_top` and `border_bottom` dummy nodes but has no concept of a title rank.

## Design Decisions

1. **Only create title nodes for compounds with non-empty titles** — compounds without titles get no title node, avoiding wasted vertical space.
2. **Title node gets zero dimensions** — the implicit `rank_sep` (50.0 dagre units → ~3 char rows) provides sufficient space for a single title line.
3. **`assign_rank_minmax` uses title rank as min_rank** — the compound span includes the title rank so `add_segments()` creates border nodes at it.
4. **Fix ordering for single-child ranks** — extend `apply_compound_constraints()` to handle `== 1 child` for border placement.
5. **Adjust `convert_subgraph_bounds()` for title space** — extend top y-bound when a compound has a title.
6. **Title info flows via `DiGraph.set_has_title()`** → propagated to `LayoutGraph.compound_titles` in `from_digraph()`.
7. **No rendering changes** — title stays embedded in top border line; the structural fix is about space, not rendering style.

## Implementation Approach

The title dummy node mirrors the existing `border_top`/`border_bottom` pattern:
- ID: `_tt_{compound_id}`
- Chain: `root → title → border_top → children → border_bottom`
- Nesting edges auto-excluded after ranking
- No changes needed to: normalize, denormalize, router, BK, cleanup

Four phases (plus integration tests):
1. Add storage fields to DiGraph/LayoutGraph
2. Insert title dummy nodes in nesting
3. Fix ordering single-child gap
4. Wire render layer and adjust bounds

Phases 3 and 4 are independent; both depend on Phase 2.

## Files to Modify/Create

| File | Changes |
|------|---------|
| `src/dagre/graph.rs` | Add `border_title`, `compound_titles`, `set_has_title()` |
| `src/dagre/nesting.rs` | Insert title node in `run()`, update `assign_rank_minmax()` |
| `src/dagre/order.rs` | Fix `apply_compound_constraints()` for single-child ranks |
| `src/render/layout.rs` | Wire `set_has_title()`, adjust `convert_subgraph_bounds()` |
| `tests/fixtures/title_collision.mmd` | New test fixture |
| `tests/integration.rs` | Integration tests for title-rank behavior |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Add `border_title` field to LayoutGraph | [tasks/1.1-border-title-field.md](./tasks/1.1-border-title-field.md) |
| 1.2 | Add `compound_titles` and `set_has_title()` | [tasks/1.2-compound-titles-field.md](./tasks/1.2-compound-titles-field.md) |
| 2.1 | Create title dummy node in `nesting::run()` | [tasks/2.1-title-node-insertion.md](./tasks/2.1-title-node-insertion.md) |
| 2.2 | Test untitled compounds have no title node | *(Covered in 2.1)* |
| 2.3 | Update `assign_rank_minmax` for title rank | [tasks/2.3-assign-rank-minmax.md](./tasks/2.3-assign-rank-minmax.md) |
| 3.1 | Fix ordering for single-child ranks | [tasks/3.1-ordering-single-child.md](./tasks/3.1-ordering-single-child.md) |
| 4.1 | Wire title info in `compute_layout_direct()` | [tasks/4.1-wire-title-info.md](./tasks/4.1-wire-title-info.md) |
| 4.2 | Adjust `convert_subgraph_bounds()` for title space | [tasks/4.2-adjust-subgraph-bounds.md](./tasks/4.2-adjust-subgraph-bounds.md) |
| 5.1 | Add `title_collision.mmd` fixture and integration tests | [tasks/5.1-integration-tests.md](./tasks/5.1-integration-tests.md) |
| 5.2 | Verify existing subgraph fixtures and update snapshots | *(Covered in 5.1)* |

## Research References

- [Synthesis](../../research/0023-subgraph-title-arrow-collision/layout-level-structural-fix/synthesis.md) — Combined findings and recommendations
- [Q1: Nesting insertion](../../research/0023-subgraph-title-arrow-collision/layout-level-structural-fix/q1-nesting-insertion.md) — Title node creation design
- [Q2: Border ordering](../../research/0023-subgraph-title-arrow-collision/layout-level-structural-fix/q2-border-ordering-impact.md) — Single-child ordering gap
- [Q3: Coordinate assignment](../../research/0023-subgraph-title-arrow-collision/layout-level-structural-fix/q3-coordinate-assignment.md) — BK handles zero-dim nodes correctly
- [Q4: Bounds extraction](../../research/0023-subgraph-title-arrow-collision/layout-level-structural-fix/q4-bounds-extraction.md) — Render layer needs adjustment
- [Q5: Cross-subgraph edges](../../research/0023-subgraph-title-arrow-collision/layout-level-structural-fix/q5-cross-subgraph-edges.md) — Extra dummy at title rank is benign

## Testing Strategy

All tasks follow strict TDD (Red/Green/Refactor):
- Phase 1-2: Unit tests in dagre modules (graph, nesting)
- Phase 3: Ordering unit tests with titled compounds
- Phase 4: Layout tests verifying subgraph bounds
- Phase 5: Integration tests with fixtures, snapshot updates

## Risks

1. **Snapshot breakage:** Title rank adds vertical space to all titled subgraphs. Existing snapshots need updating.
2. **LR/RL layouts:** Title rank adds space in the rank direction (horizontal for LR). May need empirical verification.
3. **Scale factor sensitivity:** Title rank adds `rank_sep` (50.0) in dagre coords → `v_spacing` (~3) in chars. The `title_extra` constant in `convert_subgraph_bounds()` may need tuning.
