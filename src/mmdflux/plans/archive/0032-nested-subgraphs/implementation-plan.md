# Nested Subgraph Support Implementation Plan

## Status: ✅ COMPLETE

**Completed:** 2026-01-29

**Task List:** [task-list.md](./task-list.md)

**Commits:**
- `7ab93db` - feat(plan-0032): Phase 1 - builder subgraph parent tracking
- `5c7d9af` - feat(plan-0032): Phase 2 - layout wiring for nested subgraphs
- `b18b2d7` - feat(plan-0032): Phase 3+4 - inside-out bounds and nested overlap skip
- `211e519` - feat(plan-0032): Phase 5 - z-order border rendering for nested subgraphs
- `98d0455` - feat(plan-0032): Phase 6 - integration tests for nested subgraphs

---

## Overview

Add nested subgraph support to mmdflux. The parser already handles nested syntax recursively. Changes are needed in three pipeline stages: builder (track parent relationships), layout (wire `set_parent` for subgraph-to-subgraph nesting), and rendering (inside-out bounds computation, nested-aware overlap resolution, z-order border rendering).

## Current State

- **Parser**: Already supports nested `subgraph...end` blocks recursively via PEG grammar
- **Builder**: `Subgraph` struct has no `parent` field; `collect_node_ids` returns empty for `Statement::Subgraph` (line 89 in builder.rs), so outer subgraphs lose track of inner subgraph nodes
- **Dagre**: Compound graph infrastructure (`set_parent`, nesting edges, border nodes) supports multi-level nesting, but `render/layout.rs` never calls `set_parent(child_sg, parent_sg)`
- **Rendering**: `convert_subgraph_bounds()` computes bounds from direct member nodes only and skips subgraphs with empty node lists; overlap resolution treats all pairs as siblings

## Implementation Approach

Six phases, each following strict TDD (Red/Green/Refactor):

1. **Builder** — Add `parent` field to `Subgraph`, propagate parent in `process_statements`, make `collect_node_ids` recursive, add hierarchy query helpers
2. **Layout Wiring** — Wire `set_parent` for nested subgraphs in dagre graph setup, verify multi-level nesting works
3. **Bounds Computation** — Redesign `convert_subgraph_bounds()` for inside-out (bottom-up) computation
4. **Overlap Resolution** — Distinguish nested pairs (skip) from sibling pairs (trim)
5. **Z-Order Rendering** — Sort borders by nesting depth (outer first, inner last)
6. **Integration Tests** — Create fixtures and end-to-end tests

## Files to Modify/Create

| File | Changes |
|------|---------|
| `src/graph/diagram.rs` | Add `parent: Option<String>` to `Subgraph`, add `subgraph_children()` and `subgraph_depth()` helpers |
| `src/graph/builder.rs` | Propagate parent in `process_statements`, recurse in `collect_node_ids` |
| `src/render/layout.rs` | Wire `set_parent` for nested subgraphs, redesign `convert_subgraph_bounds` to inside-out, add `build_children_map` and `is_ancestor` helpers, update `resolve_subgraph_overlap` |
| `src/render/subgraph.rs` | Z-order sort by nesting depth in `render_subgraph_borders` |
| `tests/fixtures/*.mmd` | New nested subgraph test fixtures |
| `tests/integration.rs` | Integration tests for nested subgraph rendering |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Add `parent` field to `Subgraph` struct | [tasks/1.1-subgraph-parent-field.md](./tasks/1.1-subgraph-parent-field.md) |
| 1.2 | Propagate parent context in `process_statements` | [tasks/1.2-propagate-parent-context.md](./tasks/1.2-propagate-parent-context.md) |
| 1.3 | Make `collect_node_ids` recurse into nested subgraphs | [tasks/1.3-recursive-collect-node-ids.md](./tasks/1.3-recursive-collect-node-ids.md) |
| 1.4 | Add `subgraph_children()` and `subgraph_depth()` helpers | [tasks/1.4-hierarchy-helpers.md](./tasks/1.4-hierarchy-helpers.md) |
| 2.1 | Wire `set_parent(child_sg, parent_sg)` for nested subgraphs | [tasks/2.1-wire-set-parent.md](./tasks/2.1-wire-set-parent.md) |
| 2.2 | Verify dagre handles multi-level nesting | [tasks/2.2-verify-dagre-nesting.md](./tasks/2.2-verify-dagre-nesting.md) |
| 3.1 | Implement `build_children_map()` helper | [tasks/3.1-build-children-map.md](./tasks/3.1-build-children-map.md) |
| 3.2 | Implement inside-out bounds computation | [tasks/3.2-inside-out-bounds.md](./tasks/3.2-inside-out-bounds.md) |
| 3.3 | Test bounds containment for nested subgraphs | [tasks/3.3-bounds-containment-test.md](./tasks/3.3-bounds-containment-test.md) |
| 4.1 | Add `is_ancestor()` helper | [tasks/4.1-is-ancestor-helper.md](./tasks/4.1-is-ancestor-helper.md) |
| 4.2 | Skip nested pairs in overlap resolution | [tasks/4.2-nested-overlap-skip.md](./tasks/4.2-nested-overlap-skip.md) |
| 5.1 | Sort subgraphs by nesting depth before rendering | [tasks/5.1-zorder-border-rendering.md](./tasks/5.1-zorder-border-rendering.md) |
| 6.1 | Create nested subgraph test fixtures | [tasks/6.1-test-fixtures.md](./tasks/6.1-test-fixtures.md) |
| 6.2 | Add integration tests | [tasks/6.2-integration-tests.md](./tasks/6.2-integration-tests.md) |

## Research References

- [Synthesis](../../research/0025-nested-subgraphs/synthesis.md)
- [Q1: Builder parent tracking](../../research/0025-nested-subgraphs/q1-builder-parent-tracking.md)
- [Q2: Dagre compound nesting](../../research/0025-nested-subgraphs/q2-dagre-compound-nesting.md)
- [Q3: Rendering nested bounds](../../research/0025-nested-subgraphs/q3-rendering-nested-bounds.md)
- [Q4: Mermaid reference impl](../../research/0025-nested-subgraphs/q4-mermaid-reference-implementation.md)

## Testing Strategy

All tasks follow TDD Red/Green/Refactor:
- **Unit tests** in each module for struct changes, helpers, and computation logic
- **Integration tests** that parse `.mmd` fixtures through the full pipeline and verify rendered output
- **Regression tests** ensuring existing single-level subgraph behavior is unchanged

## Risks and Deferred Items

- **Cross-boundary edge routing**: Edges crossing multiple nesting levels may route oddly — deferred
- **Per-subgraph direction**: Mermaid supports `direction LR` inside a TD subgraph — deferred
- **Empty nested subgraphs**: Subgraphs with no nodes and no children will still be skipped (matches Mermaid behavior)
- **Deeply nested (3+ levels)**: Should work but not explicitly tested beyond 2 levels initially
