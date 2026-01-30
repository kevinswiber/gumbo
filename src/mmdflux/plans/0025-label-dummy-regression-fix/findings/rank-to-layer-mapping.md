# Finding: Rank-to-layer mapping needed for doubled ranks

**Type:** discovery
**Task:** 2.1
**Date:** 2026-01-29

## Details

With global minlen doubling, real nodes sit at even dagre ranks (0, 2, 4, ...) and dummy/label nodes at odd ranks (1, 3, 5, ...). The `layer_starts` vec was indexed by layer index (0, 1, 2, ...) but `WaypointWithRank.rank` contains the dagre rank.

This meant `layer_starts[rank]` gave the wrong draw coordinate for:
- Waypoints at intermediate ranks: `layer_starts[1]` mapped to node B's layer instead of the gap between A and B
- Label positions: same issue, labels placed ON nodes instead of between them

## Impact

Required building an expanded `rank_positions` vec that maps dagre ranks to draw coordinates:
- Even ranks (real nodes): `layer_starts_raw[rank/2]`
- Odd ranks (dummies/labels): midpoint of `layer_starts_raw[rank/2]` and `layer_starts_raw[rank/2 + 1]`

This mapping is conditional on `ranks_doubled` being true. Without doubling, the 1:1 rank-to-layer mapping is correct.

## Action Items

- [x] Fixed in Phase 2 implementation
