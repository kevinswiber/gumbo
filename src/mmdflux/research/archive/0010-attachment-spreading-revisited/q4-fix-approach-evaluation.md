# Q4: What's the Right Fix -- Plan 0015's Approach or Something Different?

## Summary

Plan 0015's post-routing attachment spreading approach is the right fix, with modifications. The core mechanism -- pre-pass face grouping and even distribution of attachment points -- is sound and directly addresses the root cause identified in Q1-Q3: multiple edges converging to the same boundary cell despite having distinct dagre coordinates. However, the plan needs retargeting: its original test fixtures (`multiple_cycles.mmd`, `complex.mmd`, `ci_pipeline.mmd`) no longer exhibit overlap after stagger preservation was implemented. The plan should target the 6 forward-forward overlap cases from Q1, and its scope is simpler than originally envisioned since no mixed forward/backward grouping is needed.

## Where

Sources consulted:

- `/Users/kevin/src/mmdflux/plans/0015-attachment-point-spreading/implementation-plan.md` -- the existing plan
- `/Users/kevin/src/mmdflux/src/render/layout.rs` -- coordinate transform pipeline, `compute_stagger_positions()`, `map_cross_axis()`
- `/Users/kevin/src/mmdflux/src/render/router.rs` -- edge routing, `route_edge()`, `route_all_edges()`
- `/Users/kevin/src/mmdflux/src/render/intersect.rs` -- `calculate_attachment_points()`, `intersect_rect()`, `intersect_diamond()`
- `/Users/kevin/src/mmdflux/src/render/edge.rs` -- edge rendering pipeline
- Q1 findings (overlap inventory), Q2 findings (prior research validation), Q3 findings (dagre computation trace)

## What

### Approach A: Better Coordinate Transform

**How it would work:** Modify `compute_stagger_positions()` and `map_cross_axis()` to preserve more of dagre's dummy node separation during the dagre-to-ASCII coordinate conversion. The idea is that if we maintained enough cross-axis separation between waypoints of different long edges, the different approach angles would naturally produce different attachment cells via `intersect_rect()`.

**Analysis:**

- Q3 established that dagre gives distinct x-coordinates to dummy nodes (e.g., B=0, \_dAC1=1, \_dAD1=2, separated by ~50 dagre units). The current `compute_stagger_positions()` compresses 50-125 dagre-unit separations down to 1-2 ASCII characters.
- To fix this, we would need to increase the scaling factor so that waypoint separations survive into ASCII space. The current formula caps stagger at `max_layer_content / 2`, which is very aggressive compression.
- Even if we increased waypoint separation, `intersect_rect()` on a 5-8 character wide node still quantizes approach angles to at most ~3-4 distinct boundary cells on the top face. For 5-fan-in cases, this is still insufficient.
- This approach also does not help direct (short) edges at all -- only long edges have waypoints. Q1 shows that many overlap cases involve direct edges converging on the same target.

**Pros:**
- Would be "automatic" -- no new pass needed
- Preserves information already computed by dagre

**Cons:**
- Cannot fix direct (1-rank) edge overlap -- only helps long edges with waypoints
- Increasing waypoint separation requires widening the canvas, wasting space for most diagrams
- Even with more separation, `intersect_rect()` quantization still collapses distinct angles to the same cell on narrow nodes
- Would require canvas width increases that affect all diagrams, not just fan-in cases

**Does it fix all 6 cases?** No. It cannot fix `fan_in.mmd` (direct edges) or any case where edges span only 1 rank. At best it reduces overlap for the long-edge cases (`double_skip.mmd`) but even there, narrow target nodes quantize the attachment points.

**Verdict: Insufficient as a standalone fix.**

### Approach B: Synthetic Waypoint Offsets

**How it would work:** After routing, detect edges that converge to the same attachment point on a node face. Add small cross-axis offsets to the last waypoint (or synthesize a new waypoint) for each converging edge, spreading them apart so they arrive at different boundary cells.

**Analysis:**

- This is conceptually similar to plan 0015 but operates on waypoints rather than attachment points. Instead of spreading the final attachment cells, we perturb the approach vectors.
- The key problem: after offsetting a waypoint, we still call `intersect_rect()`, which may quantize the new angle back to the same cell. On a 5-wide node, a 1-character waypoint offset translates to a tiny angle change that rounds to the same boundary cell.
- For direct edges (no waypoints), we would need to synthesize waypoints, which adds complexity without clear benefit over directly setting the attachment point.
- This approach conflates two concerns: path routing (where the edge travels) and attachment (where it connects to the node). Modifying paths to influence attachment is indirect and fragile.

**Pros:**
- Could work for long edges where waypoints already exist
- Does not require changes to `intersect_rect()`

**Cons:**
- Indirect: modifying waypoints to change attachment points is fragile
- `intersect_rect()` quantization still defeats small offsets on narrow nodes
- Requires synthetic waypoints for direct edges, adding complexity
- Changes the visual path of edges (creates bends), which may look worse

**Does it fix all 6 cases?** Unlikely. The quantization problem at `intersect_rect()` is the fundamental bottleneck, and this approach does not bypass it. Direct-edge cases require synthesizing waypoints, which is effectively inventing a new routing approach.

**Verdict: Overly indirect and fragile.**

### Approach C: Port-Based Allocation (Original Plan 0008)

**How it would work:** Pre-allocate specific "ports" (attachment slots) on each node face. Before routing, analyze all edges to determine which face they use, assign each edge a unique port on that face, and pass the port coordinates directly to the routing functions, bypassing `intersect_rect()` entirely for port-assigned edges.

**Analysis:**

- This was the original plan 0008 approach, never implemented. Plan 0015 was created to supersede it with a "simpler approach."
- Port allocation is conceptually clean: each face is divided into N equal slots for N edges, and edges are assigned to slots based on cross-axis ordering of their other endpoint.
- The main difference from plan 0015 is that ports are assigned before routing, while plan 0015 spreads after routing. In practice, the difference is small because plan 0015's pre-pass also runs before individual edge routing.
- Port-based allocation has a well-known issue: it requires knowing the face assignment before routing, but the face assignment depends on the approach direction, which depends on routing. This chicken-and-egg problem is solvable (classify faces using waypoints/other-node-center, same as plan 0015), but it means this approach converges to plan 0015 anyway.

**Pros:**
- Clean conceptual model (ports are pre-determined)
- Used by many graph layout tools

**Cons:**
- Chicken-and-egg: face classification needs approach direction, which needs routing
- In practice, converges to the same solution as plan 0015 (pre-pass face classification + even distribution)
- Slightly more complex API surface (port objects vs. simple point overrides)

**Does it fix all 6 cases?** Yes, if fully implemented. It directly assigns distinct boundary cells, bypassing `intersect_rect()`.

**Verdict: Sound but converges to plan 0015 in practice.**

### Approach D: Plan 0015 Post-Routing Spreading (Recommended, with modifications)

**How it would work (per the plan):**

1. Before individual edge routing, run a pre-pass inside `route_all_edges()`.
2. Classify which face of each node each edge uses (top, bottom, left, right) via `classify_face()` using the approach direction (first waypoint or other node center).
3. Group edges by (node_id, face).
4. For groups with >1 edge, compute evenly-spread attachment points along the face.
5. Sort edges within a group by cross-axis position of the other endpoint (to minimize crossings).
6. Pass pre-computed attachment points into each edge's routing call, bypassing `intersect_rect()`.

**Analysis:**

This approach directly addresses the root cause: multiple edges map to the same boundary cell because `intersect_rect()` quantizes different approach angles to the same cell. By computing attachment points independently of `intersect_rect()` for multi-edge faces, we guarantee distinct cells.

The mechanism is straightforward:
- `classify_face()` uses the same data already available in the routing pipeline (waypoints, node positions)
- `spread_points_on_face()` is simple arithmetic (evenly divide face width/height by N+1)
- Edge sorting by cross-axis position of the opposite endpoint is a clean heuristic that minimizes crossings

**Needed modifications based on Q1-Q3:**

1. **Retarget test fixtures:** Replace `multiple_cycles.mmd`, `complex.mmd`, `ci_pipeline.mmd` with the actual overlapping cases from Q1:
   - Zero-gap: `double_skip.mmd`, `stacked_fan_in.mmd`, `narrow_fan_in.mmd`
   - Single-gap: `skip_edge_collision.mmd`, `fan_in.mmd`, `five_fan_in.mmd`
   - Departure: `fan_out.mmd`

2. **Simplify scope:** No mixed forward/backward grouping is needed. All 6 overlap cases are forward-forward on the same face. Backward-edge overlap was fixed by stagger preservation.

3. **Handle both arrival and departure:** Q1 identified departure-side overlap in `fan_out.mmd` (multiple edges leaving the bottom of Source). The plan's face grouping naturally handles this since it groups by (node_id, face), capturing both incoming and outgoing edges.

4. **Consider `route_edge()` signature change:** The plan calls for `route_edge()` to accept optional pre-computed attachment points. This is a clean API change -- add an `Option<(usize, usize)>` parameter for source and target attachment overrides. When `Some`, skip `calculate_attachment_points()`.

5. **Diamond shapes:** `intersect_diamond()` has a similar quantization problem. The plan's `spread_points_on_face()` needs to handle diamond geometry (vertices at face midpoints, not rectangular edges). This is noted in the plan but should be a priority.

**Pros:**
- Directly fixes the root cause (same-cell quantization) by assigning distinct cells
- Runs as a pre-pass, keeping individual edge routing stateless
- Handles both arrival and departure overlap
- Handles any number of converging edges (not limited by node width)
- Minimal risk of breaking existing cases: single-edge faces get center attachment (unchanged)
- Aligns with how dagre-d3/mermaid solve this (port-based attachment with even distribution)

**Cons:**
- New code path (classify_face, spread_points, attachment plan)
- Adds a pre-pass to `route_all_edges()`, increasing its complexity
- Edge sorting heuristic may not be optimal for all topologies (but is the standard approach)

**Does it fix all 6 cases?** Yes. All 6 cases involve multiple edges sharing the same face of a node. The pre-pass will detect these groups and spread their attachment points across the face, guaranteeing distinct cells.

**Does it handle both arrival and departure overlap?** Yes. The grouping is by (node_id, face), which captures both incoming edges arriving at a face and outgoing edges departing from a face.

**Risk of breaking currently-working cases?** Low. Single-edge faces return the center point (unchanged from current behavior). The main risk is edge sorting: if the cross-axis sort order differs from the current intersection-based order, some edge paths may shift slightly. This should be cosmetic, not functional.

**Implementation complexity:** Moderate. The plan identifies 11 tasks across 4 phases. With the simplified scope (forward-forward only), phases 1-3 are the core work (~6 tasks), and phase 4 is testing.

**Alignment with dagre/mermaid:** Strong. Both dagre-d3 and mermaid.js use port-based edge attachment with even distribution along node faces. Plan 0015's approach is the ASCII-grid analog of this.

## How

1. Read plan 0015 to understand the proposed architecture.
2. Read the four render pipeline files (`layout.rs`, `router.rs`, `intersect.rs`, `edge.rs`) to understand what would need to change for each approach and where the root cause manifests.
3. Traced the data flow for each approach:
   - **A:** `compute_stagger_positions()` scale factor -> `map_cross_axis()` -> waypoint x-coords -> `intersect_rect()` -> attachment cell. Bottleneck: `intersect_rect()` quantization.
   - **B:** Offset waypoints -> `intersect_rect()` -> attachment cell. Same bottleneck.
   - **C:** Pre-allocate ports -> bypass `intersect_rect()` -> direct attachment. Works but converges to D.
   - **D:** Pre-pass classify + spread -> bypass `intersect_rect()` for multi-edge faces -> direct attachment. Works.
4. Cross-referenced Q1-Q3 findings to verify each approach addresses all 6 overlap cases and both arrival/departure sides.

## Why

The fundamental issue is that `intersect_rect()` quantizes continuous approach angles to a small number of discrete boundary cells (constrained by node width in ASCII characters). Approaches A and B try to work around this quantization indirectly, which is fragile and incomplete. Approaches C and D bypass it entirely by directly assigning distinct attachment cells.

Between C and D, plan 0015 (approach D) is preferred because:
- It already exists as a detailed plan with task breakdown
- It uses the same face-classification technique that port-based allocation would need
- It integrates cleanly with the existing `route_all_edges()` pipeline
- Its scope is now simpler than originally designed (forward-forward only)

The recommendation is to proceed with plan 0015, updated to reflect the Q1-Q3 findings.

## Key Takeaways

- Plan 0015's core mechanism (pre-pass face grouping + even distribution) is correct and should be implemented.
- The plan needs retargeting: its test fixtures and scope description reference backward-edge overlap that has already been fixed. The actual targets are the 6 forward-forward overlap cases from Q1.
- The plan's scope is simpler than originally designed: no mixed forward/backward face grouping is needed.
- Approaches that try to improve coordinate transforms (A) or perturb waypoints (B) cannot solve the problem because `intersect_rect()` quantization is the fundamental bottleneck, and these approaches do not bypass it.
- The pre-pass naturally handles both arrival-side and departure-side overlap because it groups by (node_id, face), which captures edges from both directions.

## Open Questions

- **Diamond spreading geometry:** How should `spread_points_on_face()` distribute points on diamond faces? A diamond's "top face" is a single vertex, not a flat edge. Should we spread along the diagonal edges leading to the vertex, or define a virtual "face zone" near the vertex?
- **Minimum node width:** If a node is very narrow (e.g., 3 chars wide) and has 4+ edges on one face, the spread points may be closer than 1 character apart. Should we expand the node width, overlap gracefully, or cap the number of distinct attachment points?
- **Edge label interaction:** Spreading attachment points changes the vertical segment positions of Z-shaped paths, which affects label placement. Do we need to update the label positioning heuristics to account for the new attachment point positions?
- **Plan 0015 test fixture update:** Should we formally update the plan document before implementation, or just implement against the Q1 inventory and update the plan afterward?
