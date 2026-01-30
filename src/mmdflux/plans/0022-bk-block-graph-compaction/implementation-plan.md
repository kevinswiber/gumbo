# BK Block Graph Compaction Implementation Plan

## Status: 🚧 IN PROGRESS

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Replace the single-pass `place_block()` recursive placement in the Brandes-Kopf horizontal compaction with dagre.js's two-pass block graph compaction. This creates the diagonal stagger visible in dagre.js/Mermaid output for skip edges (edges spanning 2+ ranks), fixing Issues 2 and 9 from the visual comparison tracker.

## Root Cause

The current `horizontal_compaction()` in `bk.rs` uses a single-pass left-neighbor recursive placement (`place_block()`, lines 704-771). Each block root is placed at the minimum x that satisfies its immediate left neighbor's separation constraint. This produces the smallest valid layout but does not distribute available slack.

dagre.js replaces this with a fundamentally different approach:

1. **Build a block graph**: After vertical alignment, construct a secondary directed graph where nodes are block roots and edges represent minimum separation between adjacent blocks (using `edgeSep` for dummy nodes, `nodeSep` for real nodes).

2. **Two-pass compaction on the block graph**:
   - **Pass 1 (assign-smallest)**: Topological order from sources — each block gets `max(predecessor_x + edge_weight)`, pushing blocks as far right as constraints require.
   - **Pass 2 (assign-greatest)**: Reverse topological order from sinks — each block gets `max(current_x, min(successor_x - edge_weight))`, pulling blocks right to consume unused slack.

Pass 2 is what creates the diagonal stagger. When dummy chain nodes exist between real blocks, the block graph edges encode tighter separation (edge_sep) for those pairs, and two-pass compaction creates wider gaps around real nodes.

## Current State

- `place_block()` (bk.rs:704-771) — recursive single-pass placement
- `horizontal_compaction()` (bk.rs:640-692) — initializes sink/shift, calls place_block per root
- `CompactionResult` — carries `x`, `sink`, `shift` maps (sink/shift unused outside compaction)

## Implementation Approach

Three phases following TDD:

1. **Phase 1**: Build `BlockGraph` data structure and `build_block_graph()` function
2. **Phase 2**: Replace `horizontal_compaction()` with two-pass block graph compaction
3. **Phase 3**: Integration verification, fixture updates, cleanup

## Files to Modify/Create

| File | Change |
| ---- | ------ |
| `src/dagre/bk.rs` | Add `BlockGraph` struct, `build_block_graph()`, `compute_sep()`, replace `horizontal_compaction()` internals, remove `place_block()` |
| `tests/integration.rs` | Update any snapshot assertions that change due to wider stagger |

## Task Details

| Task | Description | Details |
| ---- | ----------- | ------- |
| 1.1 | Implement BlockGraph struct | [tasks/1.1-block-graph-struct.md](./tasks/1.1-block-graph-struct.md) |
| 1.2 | Implement compute_sep function | [tasks/1.2-compute-sep.md](./tasks/1.2-compute-sep.md) |
| 1.3 | Implement build_block_graph function | [tasks/1.3-build-block-graph.md](./tasks/1.3-build-block-graph.md) |
| 2.1 | Replace horizontal_compaction with two-pass block graph | [tasks/2.1-two-pass-compaction.md](./tasks/2.1-two-pass-compaction.md) |
| 2.2 | Remove place_block and simplify CompactionResult | [tasks/2.2-cleanup-old-compaction.md](./tasks/2.2-cleanup-old-compaction.md) |
| 3.1 | Integration verification and fixture updates | [tasks/3.1-integration-verification.md](./tasks/3.1-integration-verification.md) |

## Research References

- [q2-bk-block-graph.md](../../research/0014-remaining-visual-issues/q2-bk-block-graph.md) — Latest analysis of block graph fix
- [synthesis.md](../../research/0014-remaining-visual-issues/synthesis.md) — Overall context; Q2 section
- [q2-bk-stagger-mechanism.md](../../research/0013-visual-comparison-fixes/q2-bk-stagger-mechanism.md) — How BK stagger currently works
- [q1-dagre-bk-to-final-coords.md](../../research/0012-edge-sep-pipeline-comparison/q1-dagre-bk-to-final-coords.md) — How dagre.js BK produces final coordinates

## Testing Strategy

All tasks follow TDD Red/Green/Refactor:

**Unit tests** (in `bk.rs`):
- BlockGraph construction: empty, chain, diamond, with dummies, max-weight edge merging
- compute_sep: dummy-dummy (edge_sep), real-real (node_sep), mixed
- Two-pass compaction: sources at zero, Pass 2 pulls right, dummy chain stagger
- Full algorithm: double_skip topology produces wider stagger than single-pass

**Integration tests**:
- All existing tests must pass (possibly with updated coordinate expectations)
- Visual verification of `double_skip.mmd`, `skip_edge_collision.mmd`, `stacked_fan_in.mmd`

## Risk Analysis

**Low risk**: Simple chains, fan patterns without skip edges — block graph produces identical results to single-pass.

**Medium risk**: Wider layouts overall (Pass 2 distributes slack), LR/RL layouts (BK optimizes cross-axis), existing BK unit tests (may need coordinate updates — invariants are separation constraints, not exact values).

**High risk**: CompactionResult sink/shift fields (unused outside compaction — safe to remove), balance behavior (median of 4 alignments may differ with wider individual alignments — verify `align_to_smallest` handles this).
