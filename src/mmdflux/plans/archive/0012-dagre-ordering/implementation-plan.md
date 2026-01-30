# Dagre-Style Ordering Algorithm Implementation Plan

## Status: ✅ COMPLETE

**Completed:** 2026-01-27

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Rewrite `src/dagre/order.rs` to match Dagre's ordering behavior for maximum parity. The ordering algorithm determines left-to-right node order within each layer, which directly controls layout structure (e.g., main flow vs. error branch placement). The current implementation lacks bias exploration, DFS initialization, and adaptive termination -- all of which Dagre uses to escape local minima and find better orderings.

## Current State

`src/dagre/order.rs` (245 lines) implements barycenter-based crossing reduction with:
- Arbitrary initial ordering (parse/insertion order)
- Always left-bias tie-breaking
- Paired down+up sweeps per iteration
- Hard cap of 24 iterations, stops on first plateau
- No best-order tracking (may end with worse order)

## Implementation Approach

Three phases, all modifying only `src/dagre/order.rs`:

### Phase 1: Add Bias Parameter
Add `bias_right: bool` to `reorder_layer()`, `sweep_down()`, `sweep_up()`. Pass `false` from `run()` to preserve current behavior. This is foundational for Phase 3.

### Phase 2: DFS Initial Ordering
Add `init_order()` function matching Dagre's `initOrder()`. Uses iterative DFS from nodes sorted by rank, assigning order values as nodes are first visited. Add `layers_sorted_by_order()` helper.

### Phase 3: Dagre-Style Adaptive Loop
Replace `run()` with Dagre's exact loop structure:
- Each iteration does ONE sweep (not paired), alternating direction via `i % 2`
- Bias alternates via `i % 4 >= 2` (pattern: false, false, true, true)
- Tracks best order by crossing count, saves on improvement or equal
- Terminates after 4 consecutive non-improving iterations
- Remove `MAX_ITERATIONS` constant

## Files to Modify/Create

| File | Action |
|------|--------|
| `src/dagre/order.rs` | Modify: add bias parameter, DFS init, rewrite loop |

No changes to `mod.rs`, `rank.rs`, `graph.rs`, `bk.rs`, or any other files.

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Add `bias_right` parameter to sweep/reorder functions | [tasks/1.1-add-bias-parameter.md](./tasks/1.1-add-bias-parameter.md) |
| 1.2 | Add unit test for bias behavior | [tasks/1.2-test-bias-parameter.md](./tasks/1.2-test-bias-parameter.md) |
| 2.1 | Add `init_order()` DFS function | [tasks/2.1-dfs-initial-ordering.md](./tasks/2.1-dfs-initial-ordering.md) |
| 2.2 | Add `layers_sorted_by_order()` helper | [tasks/2.2-layers-sorted-helper.md](./tasks/2.2-layers-sorted-helper.md) |
| 2.3 | Add unit tests for DFS init | [tasks/2.3-test-dfs-init.md](./tasks/2.3-test-dfs-init.md) |
| 3.1 | Rewrite `run()` with Dagre-style adaptive loop | [tasks/3.1-adaptive-loop.md](./tasks/3.1-adaptive-loop.md) |
| 3.2 | Add unit tests for adaptive loop | [tasks/3.2-test-adaptive-loop.md](./tasks/3.2-test-adaptive-loop.md) |
| 3.3 | Run full test suite and fix regressions | [tasks/3.3-integration-validation.md](./tasks/3.3-integration-validation.md) |

## Research References

- [00-initial-analysis.md](../../research/archive/0007-ordering-algorithm/00-initial-analysis.md) - Gap analysis showing ordering as root cause
- [01-dagre-ordering-analysis.md](../../research/archive/0007-ordering-algorithm/01-dagre-ordering-analysis.md) - Dagre's algorithm in detail
- [02-mmdflux-ordering-analysis.md](../../research/archive/0007-ordering-algorithm/02-mmdflux-ordering-analysis.md) - Current implementation analysis
- [03-solution-options.md](../../research/archive/0007-ordering-algorithm/03-solution-options.md) - Solution options with code sketches
- [04-synthesis.md](../../research/archive/0007-ordering-algorithm/04-synthesis.md) - Synthesis recommending A + B2 + C

## Testing Strategy

1. **After Phase 1**: All existing tests pass unchanged (behavior identical with `bias_right = false`)
2. **After Phase 2**: Existing tests still pass; DFS init may change orderings but crossing counts should be equal or better
3. **After Phase 3**: Full adaptive loop; validate with `cargo test`, `cargo clippy`, and manual check of `complex.mmd` output
4. **Integration**: Run `cargo run -- tests/fixtures/complex.mmd` and compare against Mermaid's expected layout
