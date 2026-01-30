# Finding: Skip-Edge Collision Is a Waypoint Transform Bug, Not a BK Problem

**Type:** discovery
**Task:** 5.1 (research)
**Date:** 2026-01-28

## Summary

The prior research (q2-bk-stagger-mechanism.md) concluded that skip edges collide
with nodes because mmdflux's BK implementation lacks a "block graph" mechanism.
This finding **reverses that conclusion**: BK correctly separates dummy nodes from
real nodes. The actual root cause is that `compute_layout_direct()` applies the
Phase 2 overhang offset to node positions but not to waypoint positions, destroying
the separation BK computed.

## Evidence

### BK produces correct separation

Diagnostic test on `double_skip.mmd` (A->B, B->C, C->D, A->C, A->D) shows:

```
Layer 0: [A]
Layer 1: [B(ord=0), _d0(ord=1), _d1(ord=2)]   # _d0=A->C dummy, _d1=A->D dummy
Layer 2: [C(ord=0), _d2(ord=1)]                 # _d2=A->D dummy
Layer 3: [D]

UL alignment:
  Block root=A: [A, B, C, D]     x=0
  Block root=_d0: [_d0]          x=40
  Block root=_d1: [_d1, _d2]     x=60

Final balanced: B=-11.75, C=7.75, D=27.75, A=28.25, _d0=28.25, _d1=58.25
```

Dummy `_d0` is 40 dagre-units from B (center-to-center). After scaling
(scale_cross ~= 0.22), this maps to ~9 character columns of center-to-center
distance, or ~4 chars of gap from B's right edge. **This is correct and visible
separation.**

### Overhang offset eats the gap

Phase 2 introduced `max_overhang_x` in `compute_layout_direct()` (layout.rs:343-369)
to prevent `saturating_sub` clipping when a node's half-width exceeds its raw
center coordinate. This offset is added to all **node** center positions but is
**not passed to** `transform_waypoints_direct()` or `transform_label_positions_direct()`.

For `double_skip.mmd`:
- `max_overhang_x = 4` (B has half_w=5, raw center=1)
- Node B center: `raw_cx(1) + overhang(4) + padding(1)` = column 6
- B right edge: column 6 + 5 = **column 11**
- Waypoint _d0: `raw_wp_x(10) + padding(1)` = **column 11** (no overhang added)
- Result: **zero gap** between B's right edge and _d0

With overhang applied to waypoints:
- Waypoint _d0: `raw_wp_x(10) + overhang(4) + padding(1)` = **column 15**
- Gap from B's right edge: 15 - 11 = **4 characters**

### Phase I collision nudge misses by 1

There's already a collision nudge at layout.rs:495-516 that checks
`wp.0 >= bounds.x && wp.0 < bounds.x + bounds.width`. For _d0 at column 11
and B spanning columns 1..11, the check `11 < 11` is false, so the nudge
doesn't trigger. The waypoint lands exactly at the boundary.

## Impact on Phase 5

**The block graph rewrite is not needed.** The fix is to propagate `max_overhang_x`
and `max_overhang_y` to `transform_waypoints_direct()` and
`transform_label_positions_direct()`.

### What changes

1. Pass `max_overhang_x` and `max_overhang_y` to `transform_waypoints_direct()`
2. Add the overhang to waypoint x/y coordinates in the transform
3. Same for `transform_label_positions_direct()`
4. Verify with `double_skip.mmd` and `skip_edge_collision.mmd`

### What doesn't change

- BK algorithm (`bk.rs`) - working correctly
- `position.rs` - working correctly
- No block graph, no nudge pass needed

## Block Graph: Still Worth Considering?

For completeness, here's what the dagre.js block graph does differently:

1. Builds a graph where nodes are block roots and edges carry separation weights
2. Uses two-pass compaction (assign-smallest then pull-back) instead of mmdflux's
   single-pass recursive `place_block()`
3. Can create self-edges (same-block internal separation)

In practice, mmdflux's `place_block()` produces equivalent results for the test
cases examined. The separation constraints it enforces match dagre.js's. The
only scenario where the block graph would differ is when a block has internal
nodes that need separation (nodes in the same block on the same layer). This
happens rarely and the existing collision repair handles it.

**Recommendation:** File the block graph as a future improvement (deferred), not
needed for Phase 5. The overhang fix is the correct and minimal solution.

## dagre.js Reference

The dagre.js BK implementation lives in `lib/position/bk.js` (430 lines).
Key functions: `positionX()`, `buildBlockGraph()`, `horizontalCompaction()`,
`verticalAlignment()`. The block graph construction is at lines 267-287.
The two-pass compaction is at lines 238-258.
