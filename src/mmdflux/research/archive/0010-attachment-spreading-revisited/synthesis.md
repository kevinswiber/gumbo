# Research Synthesis: Attachment Point Spreading Revisited

## Summary

After stagger preservation (plan 0016) eliminated all backward-edge overlap, the remaining attachment point overlap problem is exclusively **forward-forward same-face overlap** in TD-direction diagrams. Six of eleven tested fixtures exhibit this: three with zero-gap overlaps (`double_skip`, `stacked_fan_in`, `narrow_fan_in`) and three with single-space-gap near-overlaps (`skip_edge_collision`, `fan_in`, `five_fan_in`). One fixture (`fan_out`) also shows departure-side overlap. The root cause is `intersect_rect()` quantization: dagre produces distinct waypoint coordinates for different long edges, but the ASCII coordinate compression and discrete boundary-cell rounding collapse them to the same attachment point. Plan 0015's post-routing spreading approach is the correct fix, with scope narrowed to forward-forward cases only.

## Key Findings

### 1. Stagger preservation fully solved backward-edge overlap

The `compute_stagger_positions()` implementation successfully preserves dagre's cross-axis offset for backward edges. `multiple_cycles.mmd`, `complex.mmd`, and `simple_cycle.mmd` — the prior research's primary concern — all render cleanly with no overlap. No backward-backward or forward-backward overlap exists in any fixture.

### 2. Forward-forward overlap is the sole remaining problem

All six overlap cases share the same pattern: a narrow target node receives multiple forward edges (from direct edges and/or skip edges that span 2+ ranks), and the arrows converge to adjacent or identical boundary cells on the target's top face. The `fan_out.mmd` fixture shows the departure-side variant (multiple edges leaving the source's bottom face at adjacent cells).

**Zero-gap overlaps (`▼▼`):**
- `double_skip.mmd` — End node (direct C→D + skip A→D)
- `stacked_fan_in.mmd` — Bot node (direct B→C + skip A→C)
- `narrow_fan_in.mmd` — X node (3 edges into 5-char-wide node, plus `┼` path crossing)

**Single-space-gap near-overlaps (`▼ ▼`):**
- `skip_edge_collision.mmd` — End node (direct C→D + skip A→D)
- `fan_in.mmd` — Target node (3 direct edges)
- `five_fan_in.mmd` — Target node (5 direct edges)

**Departure-side overlap (`│ │`):**
- `fan_out.mmd` — Source bottom face (3 outgoing edges)

### 3. Dagre produces sufficient information, but ASCII rendering loses it

Dagre's Brandes-Kopf algorithm assigns distinct x-coordinates to dummy nodes of different long edges at the same rank (e.g., B=0, _dAC1=1, _dAD1=2 at rank 1, separated by ~50 dagre units). This separation is lost in two stages:

1. **Coordinate compression** (`compute_stagger_positions()`) scales 50–125 dagre-unit separations to 1–2 ASCII characters
2. **Intersection quantization** (`intersect_rect()`) maps slightly different approach angles to the same boundary cell on narrow nodes (5–8 chars wide)

JS dagre has the same intersection calculation but targets pixel-space SVG where sub-pixel differences produce visually distinct lines. The problem is inherent to discrete ASCII rendering.

### 4. Prior research was right about backward edges, wrong about fan-in

The stagger-preservation-analysis.md correctly predicted that backward-edge overlap would be fixed. It incorrectly claimed "fan-in/fan-out patterns already work." Of the 5 gaps identified in the prior SYNTHESIS.md, gaps 1 and 5 (backward edge face classification) are now moot; gaps 2, 3, and 4 (Option types, offset interaction, segment routing) remain relevant for the forward-forward spreading implementation.

### 5. Plan 0015's approach is correct but needs retargeting

The plan's core mechanism — pre-pass face grouping and even distribution of attachment points — directly bypasses the `intersect_rect()` quantization bottleneck by assigning distinct boundary cells without relying on approach angles. Three alternative approaches were evaluated:

- **Better coordinate transform (A):** Cannot fix direct-edge overlap; `intersect_rect()` quantization still defeats it on narrow nodes
- **Synthetic waypoint offsets (B):** Indirect and fragile; same quantization bottleneck
- **Port-based allocation (C):** Sound but converges to plan 0015 in practice (same chicken-and-egg face classification)

Plan 0015 is preferred because it already exists as a detailed plan, integrates cleanly with `route_all_edges()`, and its scope is now simpler (forward-forward only, no mixed forward/backward grouping).

## Recommendations

1. **Proceed with plan 0015, updated for the narrower scope** — Retarget test fixtures from backward-edge cases to the 6 forward-forward overlap cases. Drop mixed forward/backward grouping logic. The core phases (face classification, attachment plan, router integration) remain as designed.

2. **Update plan 0015's test fixtures** — Replace tasks 4.1 (`multiple_cycles.mmd`) and 4.2 (`ci_pipeline.mmd`) with the actual overlapping fixtures: `double_skip.mmd`, `stacked_fan_in.mmd`, `narrow_fan_in.mmd`, `fan_in.mmd`, `five_fan_in.mmd`, `fan_out.mmd`.

3. **Handle departure-side overlap** — The plan's (node_id, face) grouping naturally captures both incoming and outgoing edges, so departure overlap (`fan_out.mmd`) is handled without extra effort.

4. **Address diamond spreading geometry** — Diamond nodes have vertex-based faces, not flat edges. `spread_points_on_face()` needs special handling for diamond geometry (spread along diagonal edges near the vertex).

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | Overlap occurs in `intersect_rect()` (intersect.rs) and becomes visible in rendered output. Dagre produces distinct waypoints in `bk.rs`/`position.rs` but separation is lost in `compute_stagger_positions()` (layout.rs) and `intersect_rect()`. |
| **What** | 6 fixtures have forward-forward same-face overlap. All TD direction. Narrow target nodes (5–8 chars) receiving 2–5 edges. No backward-edge overlap remains. |
| **How** | Dagre assigns distinct dummy-node x-coordinates via Brandes-Kopf. Coordinate compression (dagre→ASCII) and boundary-cell quantization (intersect_rect) collapse the separation. Post-routing spreading bypasses both stages. |
| **Why** | ASCII rendering's discrete character grid cannot represent sub-character differences. Ray-intersection attachment (designed for pixel rendering) is fundamentally limited on narrow nodes. Direct cell assignment is the correct approach. |

## Open Questions

- Should single-space-gap (`▼ ▼`) be considered acceptable, or must the spreading guarantee 2+ cell gaps?
- For very narrow nodes (5 chars wide) with 3+ edges, is it physically possible to spread all attachment points? May need minimum node width enforcement.
- Does the `fan_in_lr.mmd` rendering defect (garbled output with wrong arrow directions) indicate a separate LR routing bug?
- How should diamond face spreading work geometrically?
- Should edge labels be repositioned after attachment point spreading changes vertical segment positions?

## Next Steps

- [ ] Update plan 0015's scope, test fixtures, and task descriptions to reflect Q1–Q3 findings
- [ ] Implement plan 0015 phases 1–3 (face classification, attachment plan, router integration)
- [ ] Validate against all 6 overlap fixtures plus non-overlapping fixtures (regression check)
- [ ] Investigate `fan_in_lr.mmd` rendering defect separately (likely an LR routing bug)

## Source Files

| File | Question |
|------|----------|
| `q1-current-overlap-inventory.md` | Q1: Current overlap cases |
| `q2-prior-research-validation.md` | Q2: Prior research validation |
| `q3-dagre-computation-trace.md` | Q3: Dagre computation trace |
| `q4-fix-approach-evaluation.md` | Q4: Fix approach evaluation |
