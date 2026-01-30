# Deviations from Plan

## 1. Old Pipeline Code Retained (Phase 9.1)

**Plan said:** Remove `compute_layout_dagre()`, `compute_stagger_positions()`,
`map_cross_axis()`, `rank_cross_anchors` construction, and `global_scale` computation
(~300 lines).

**What happened:** `compute_layout_dagre` was referenced in 15+ test locations across
`layout.rs`, `router.rs`, and `integration.rs`. Removing it would have required
updating all those tests — a significant scope expansion that risked introducing
test failures unrelated to the pipeline switch.

**Decision:** Keep old code for test compatibility. Switch only the `render()` default.
Defer full removal as a separate cleanup task.

**Impact:** ~300 lines of dead code remain in `layout.rs`. The old pipeline is still
exercised by existing tests, which provides an incidental safety net but also means
two code paths need maintenance.

## 2. Task 9.2 Deferred (Layout Struct Cleanup)

**Plan said:** Remove unused fields from the `Layout` struct (specifically
`grid_positions`).

**What happened:** Since we didn't remove the old pipeline, `grid_positions` is still
populated by `compute_layout_dagre()`. Removing the field would break the retained
old code. Deferred to a future cleanup pass.

## 3. Lines of Code: Addition vs Removal

**Plan estimated:** ~400 lines removed, ~100 lines added (net reduction of ~300 lines).

**Actual:** ~430 lines added, 0 lines removed. The new pipeline functions were added
alongside the old ones. Net increase of ~430 lines.

This is a direct consequence of deviation #1. If the old code is eventually removed,
we'd get close to the plan's estimate: ~430 new lines minus ~300 old lines = net
increase of ~130 lines (still more than estimated because the plan underestimated
the size of the assembly function and tests).

## 4. Phase 7 Fixture Change

**Plan said:** Use `multiple_cycles.mmd` to test backward-edge stagger preservation.

**What happened:** `multiple_cycles.mmd` produces a single-column layout (A, B, C each
in their own layer). All three nodes having the same x-center is *correct* behavior,
not a stagger to preserve. The test was meaningless with this fixture.

**Fix:** Changed to `fan_out.mmd` (A→B, A→C, A→D) where B/C/D share a layer and dagre
assigns them distinct x positions. Renamed test from
`direct_preserves_backward_edge_stagger` to `direct_preserves_cross_axis_stagger`.

## 5. Phase 1 Snapshot Approach

**Plan said:** Capture baseline snapshots for comparison.

**What happened:** Implemented as a `#[test]` function (`generate_baseline_snapshots`)
that writes `.txt` files to `tests/snapshots/`. This was more automated than the plan
implied but worked well. The snapshots were regenerated after switching the default
pipeline in Phase 9.1.

## 6. Phase 6 Assembly Function Size

**Plan said:** ~50 lines for `compute_layout_direct()`.

**Actual:** ~250 lines. The assembly function needed to:
- Build and run the dagre layout
- Extract node dimensions and layer structure
- Compute scale factors
- Apply scaling and rounding to node positions
- Run collision repair
- Compute canvas dimensions
- Transform waypoints
- Transform label positions
- Build the final Layout struct

The plan underestimated the amount of dagre result extraction and Layout struct
population code needed.
