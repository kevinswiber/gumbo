# Finding: Block Graph Compaction is a No-Op

**Type:** plan-error
**Task:** All (3.1 verification)
**Date:** 2026-01-29

## Details

The two-pass block graph compaction algorithm implemented in Plan 0022 produces
**identical output** to the original recursive `place_block` approach for all 27
test fixtures. The `compare-binaries.sh` script confirms zero differences.

### Why Pass 2 is mathematically a no-op

For any DAG, Pass 1 (topological order, assign `max(pred + weight)`) produces
coordinates satisfying `x[succ] >= x[node] + weight` for every edge. Pass 2
(reverse topological order, assign `min(succ - weight)` if strictly greater) can
never fire because `min(succ - weight) >= x[node]` by construction (equality at
best, never strictly greater).

This was confirmed by `test_pass2_is_noop` which checks all 4 alignments.

### Why stagger already exists

The original diagnostic test (`test_double_skip_bk_coordinates`) showed 0 dummies
and no stagger because it called `rank::normalize` (which only shifts rank numbers
to start at 0) but NOT `normalize::run` (which actually splits long edges into
dummy node chains).

After adding `normalize::run(&mut lg, &HashMap::new())`, the test showed:
- 7 nodes (4 real + 3 dummies)
- Layer 1: `[Step1, _d0, _d1]` (3 nodes)
- Layer 2: `[Step2, _d2]` (2 nodes)
- Per-alignment x-coords differ (UL: all 0, UR: {120,0,60,120}, etc.)
- Final balanced: Start=27.5, Step1=-32.5, Step2=-2.5, End=27.5 — **stagger exists**

The 4-alignment balance mechanism (median of UL/UR/DL/DR) creates stagger when
dummy nodes produce multi-node layers. This works identically in both the old
`place_block` recursion and the new block graph two-pass algorithm.

### Issue #2 status

Issue #2 ("skip edge stagger missing") was already resolved before Plan 0022.
The main branch already produces the correct diagonal stagger pattern:
Step1 leftmost, Step2 middle, Start/End rightmost.

## Impact

Plan 0022 is a correct refactor but provides no behavioral change. The plan's
premise — that replacing `place_block` with a block graph two-pass algorithm
would produce stagger — was based on a misunderstanding. Both algorithms solve
the same constraint system and produce identical results.

## Action Items

- [ ] Consider reverting Plan 0022 changes (they add complexity for no benefit)
- [ ] Update Issue #2 status to Fixed (stagger already works)
- [ ] Remove diagnostic tests added during investigation
