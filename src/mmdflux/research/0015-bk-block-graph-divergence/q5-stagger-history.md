# Q5: When did mmdflux's stagger start working, and what change enabled it?

## Summary

The stagger in double_skip.mmd started working at commit `ed803b8` (plan-0020, Phase 2 -- "Fix centering jog via overhang offset", 2026-01-28). The BK algorithm had always been computing correct dummy-node separation, but `saturating_sub` in the draw-position calculation was clipping wide nodes to x=0, destroying the stagger. The Phase 2 two-pass overhang offset eliminated the clipping, revealing stagger that BK had produced all along. A subsequent fix at `1846cfb` (plan-0020, Phase 5) propagated the overhang offset to waypoints, giving skip edges proper clearance from node borders.

## Where

- **Issue #2:** `issues/0002-visual-comparison-issues/issues/issue-02-skip-edge-stagger-missing.md`
- **Plan 0020:** `plans/0020-visual-comparison-fixes/implementation-plan.md` (Phase 2 and Phase 5)
- **Plan 0020 findings:** `plans/0020-visual-comparison-fixes/findings/overhang-offset-centering-fix.md` and `skip-edge-waypoint-overhang-offset.md`
- **Research 0013 Q2:** `research/0013-visual-comparison-fixes/q2-bk-stagger-mechanism.md`
- **Plan 0022:** `plans/0022-bk-block-graph-compaction/implementation-plan.md` (block graph compaction)
- **Snapshot history:** `tests/snapshots/double_skip.txt` across commits

## What

### Timeline of double_skip.mmd stagger

| Commit | Plan/Phase | Start col | Step 1 col | Step 2 col | End col | Stagger? |
|--------|-----------|-----------|------------|------------|---------|----------|
| `f366a5e` | Baseline snapshots | 6 | 0 | 0 | 7 | No -- Step 1 and Step 2 flush-left |
| `b7402d4` | Plan 0020 Phase 1 | 6 | 0 | 0 | 7 | No -- unchanged |
| `ed803b8` | Plan 0020 Phase 2 | 10 | 0 | 4 | 11 | **Yes** -- first stagger |
| `1846cfb` | Plan 0020 Phase 5 | 10 | 0 | 4 | 11 | Yes -- waypoints now have clearance |
| `b6cc0e2` | Plan 0021 Phase 1 | 10 | 0 | 4 | 11 | Yes -- unchanged |
| `097907a4` | Plan 0022 Phase 2 | 10 | 0 | 4 | 11 | Yes -- edge routing refined |
| `1b341e7` | Plan 0022 Phase 3 | 10 | 0 | 4 | 11 | Yes -- unchanged |

### Key commit: `ed803b8` (plan-0020, Phase 2)

**Commit message:** "Fix centering jog via overhang offset"

**What changed in `src/render/layout.rs`:**
- Replaced single-pass draw-position computation that used `saturating_sub` with a two-pass approach
- Pass 1: compute raw dagre centers and find `max_overhang_x` (maximum amount any node's half-width exceeds its raw center coordinate)
- Pass 2: add `max_overhang_x` as uniform offset to all centers, then compute draw positions with plain subtraction (no clipping)

**Before (clipping):**
```rust
let x = center_x.saturating_sub(w / 2) + config.padding + config.left_label_margin;
```

**After (overhang offset):**
```rust
let center_x = raw_cx + max_overhang_x;
let x = center_x - w / 2 + config.padding + config.left_label_margin;
```

### Follow-up commit: `1846cfb` (plan-0020, Phase 5)

**Commit message:** "Fix waypoint overhang offset for skip-edge separation"

This applied the same `max_overhang_x`/`max_overhang_y` offset to `transform_waypoints_direct()` and `transform_label_positions_direct()`. Without this, waypoints were still computed without the overhang, landing at node borders despite the node stagger.

### Plan 0022 (block graph compaction)

Plan 0022 replaced single-pass `place_block()` with two-pass block graph compaction. However, for double_skip.mmd, the node positions did not change. The diff between pre-0022 and post-0022 shows only edge routing changes (attachment point shifts of 1-2 characters), not node position changes. The block graph compaction may matter for other topologies but did not affect this specific test case.

## How

### Why BK already produced stagger

The BK algorithm in `bk.rs` correctly handles dummy nodes. For double_skip.mmd:

- Layer 0: `[A]`
- Layer 1: `[B(ord=0), _d0(ord=1), _d1(ord=2)]` (dummies for A->C and A->D skip edges)
- Layer 2: `[C(ord=0), _d2(ord=1)]` (dummy for A->D)
- Layer 3: `[D]`

Vertical alignment creates blocks where B is separate from the dummy nodes. Horizontal compaction places B at x=-11.75 and the dummies at x=28-58, creating genuine separation. The balanced final coordinates preserve this separation.

### How `saturating_sub` destroyed stagger

After BK, dagre coordinates are scaled to character-cell space. For a wide node near the origin (e.g., B with half-width 5 and raw center 1), the draw position calculation was:

```
x = saturating_sub(1, 5) = 0   // clips to zero
```

This forced B to column 0. Other nodes with higher centers were also clipped or shifted minimally. The relative separations BK computed were destroyed because all clipped nodes piled up at x=0.

### How the overhang offset fixed it

The two-pass approach finds the worst-case overhang (B needs 4 extra columns: half-width 5 minus center 1 = 4). It adds this offset to ALL node centers uniformly:

```
B center:  1 + 4 = 5    ->  x = 5 - 5 = 0   (correct, no clipping)
C center:  raw + 4       ->  preserves offset from B
```

Since the offset is uniform, relative separations from BK are perfectly preserved. The subtraction can never underflow.

## Why

### Why the previous implementation didn't produce stagger

The `saturating_sub` function silently clipped negative results to zero. This was a safe fallback for preventing underflow in unsigned arithmetic, but it had the unintended side effect of collapsing all nodes whose half-width exceeded their raw center coordinate to the same column. For left-positioned nodes in BK output, this was common.

### Why the fix works

The overhang offset is a translation (uniform shift of all coordinates). Translations preserve relative distances. By shifting the entire coordinate space right by `max_overhang_x`, every node's center becomes large enough that `center - half_width >= 0`, and the actual BK-computed separations are faithfully rendered.

### Why the initial research was wrong

Research 0013 Q2 concluded that BK lacked a block graph and couldn't produce stagger. Plan 0020's Phase 5 finding (`skip-edge-waypoint-overhang-offset.md`) **reversed this conclusion**: "BK correctly separates dummy nodes from real nodes. The actual root cause is that compute_layout_direct() applies the Phase 2 overhang offset to node positions but not to waypoint positions." The BK algorithm was correct; the rendering pipeline was destroying its output.

## Key Takeaways

- The BK algorithm in mmdflux always produced correct node stagger for skip edges. The stagger was destroyed by `saturating_sub` clipping in the draw-position pipeline.
- The fix was a coordinate-space translation (overhang offset), not an algorithm change. It shipped in commit `ed803b8` (plan-0020, Phase 2, 2026-01-28).
- A second fix at `1846cfb` (plan-0020, Phase 5) extended the overhang offset to waypoints, giving skip edges proper clearance.
- Plan 0022's block graph compaction changed edge routing details but did not alter node stagger for double_skip.mmd. It may affect other topologies.
- The fix is robust and intentional: it is a mathematically correct coordinate transformation that preserves all BK-computed separations. It is not a side effect of another change.
- Research 0013 Q2's conclusion (that a block graph was needed for stagger) was incorrect, as discovered during plan-0020 Phase 5 implementation.

## Open Questions

- Does plan-0022's block graph compaction produce different stagger for any fixture besides double_skip? The diff showed only edge routing changes, but other topologies may differ.
- Are there topologies where the single-pass `place_block()` and two-pass block graph compaction produce meaningfully different node positions? The plan-0022 implementation plan suggested diamond patterns and complex graphs might diverge.
- Could there be other places in the pipeline where coordinate transformations similarly destroy BK-computed separations (e.g., LR/RL layouts)?
