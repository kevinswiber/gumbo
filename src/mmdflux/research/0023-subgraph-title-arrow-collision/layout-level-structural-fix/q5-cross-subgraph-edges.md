# Q5: What happens to cross-subgraph edges spanning the title rank?

## Summary

Cross-subgraph edges undergo standard long-edge normalization: dummy nodes are created at each intermediate rank, including the title rank. This is benign — the title-rank dummy participates in crossing reduction and coordinate assignment normally, and its position becomes a waypoint during denormalization. No special handling is needed. The existing normalize → denormalize → transform → route pipeline handles title-rank dummies seamlessly.

## Where

- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/normalize.rs` (lines 248-290): Long edge normalization loop creates dummies at every intermediate rank
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/normalize.rs` (lines 337-370): `denormalize()` extracts waypoints from dummy positions
- `/Users/kevin/src/mmdflux-subgraphs/src/render/layout.rs` (lines 997-1010): `transform_waypoints_direct()` converts waypoints to draw coordinates using `layer_starts[rank]`
- `/Users/kevin/src/mmdflux-subgraphs/src/render/router.rs` (lines 197-220): Routes via waypoints if available
- `/Users/kevin/src/mmdflux-subgraphs/tests/fixtures/subgraph_edges.mmd`: Test fixture with cross-subgraph edges

## What

### Normalization of long edges

When edge A→C spans from rank 0 to rank N:
- Loop: `for rank in (from_rank + 1)..to_rank` creates a dummy at each intermediate rank
- With title rank inserted (e.g., at rank 1), the loop includes rank 1
- A dummy node is created at the title rank — no detection or special handling

### Denormalization and waypoints

`denormalize()` extracts dummy positions as waypoints:
- Each dummy's position (x, y) and rank are stored
- Title-rank dummy becomes one waypoint in the edge's waypoint chain
- Chain: `source → wp(title_rank) → wp(content_rank) → ... → target`

### Waypoint transformation

`transform_waypoints_direct()` converts dagre coordinates to draw coordinates:
```rust
let rank_idx = wp.rank as usize;
let layer_pos = layer_starts.get(rank_idx).copied();
```
Title rank waypoints use `layer_starts[title_rank]` for primary-axis positioning.

### Edge routing

Router treats all waypoints equally:
- Looks up waypoints for the edge
- Routes via `route_edge_with_waypoints()` using all waypoints including title rank
- The title rank waypoint becomes a turning point in the orthogonal path
- No awareness of which waypoints came from title-rank vs content-rank dummies

## How

### Scenario walkthrough: A→C with title rank

1. **Normalization**: A(rank 0), C(rank 3), title at rank 1 → dummies at ranks 1, 2
2. **Coordinate assignment**: Title-rank dummy gets (x, y) from BK + rank positioning
3. **Denormalization**: Two waypoints extracted: wp1(rank=1), wp2(rank=2)
4. **Transform**: wp1 uses layer_starts[1], wp2 uses layer_starts[2]
5. **Routing**: Orthogonal path: A → wp1 → wp2 → C

### Impact assessment

| Aspect | Impact | Severity |
|--------|--------|----------|
| Extra dummy node | One more dummy per long cross-subgraph edge | Negligible |
| Waypoint overhead | Waypoints include title rank position | Negligible |
| Crossing reduction | Title-rank dummy participates in ordering | Benign |
| Visual effect | May add slight jog to edge path at title rank | Minor aesthetic |
| Collision repair | Phase I nudging handles overlaps | Already covered |

## Why

### Why not special-case title rank dummies?

Attempting to skip title-rank dummies would require:
- Flagging dummies at specific rank types during normalization
- Removing them from waypoint chains during denormalization
- Handling routing gaps for missing waypoint ranks
- Edge cases with label dummies at title rank

This complexity is unjustified — uniform treatment is simpler and correct.

### Why this works

The normalization system is rank-agnostic by design. All intermediate ranks get dummies, all dummies get positions, all positions become waypoints. The title rank is just another rank from normalization's perspective.

## Key Takeaways

- Title-rank dummies are created automatically during normalization — no special detection needed
- Waypoints include title rank entries, transformed via `layer_starts[title_rank]`
- Edge routing treats all waypoints equally — no title-rank awareness needed
- Title-rank dummies are benign: they may add a slight aesthetic jog but cause no structural issues
- No architectural modifications needed to normalize, denormalize, transform, or route

## Open Questions

- Are `layer_starts` values correctly initialized for the title rank? If no real nodes occupy it, does `layer_starts[title_rank]` have a sensible value?
- Does the title-rank dummy's participation in crossing reduction affect content node positions via barycenter?
- Can edge labels at the title rank coexist with the subgraph border rendering?
- Should test cases verify edge paths through title ranks (e.g., modified subgraph_edges.mmd)?
