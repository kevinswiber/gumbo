# Q2: What Did Stagger Preservation Actually Fix, and What Did the Prior Research Get Right/Wrong?

## Summary

Stagger preservation was implemented (via `compute_stagger_positions()` in `layout.rs`) and successfully eliminated backward-edge overlap -- the prior research's primary predicted fix. `multiple_cycles.mmd`, `complex.mmd`, and `simple_cycle.mmd` all render cleanly now. However, the prior research did not predict the forward-forward same-face overlap pattern that Q1 found in 6 fixtures. Of the 5 gaps identified in SYNTHESIS.md, gaps 1 and 5 (backward edge face classification) are now moot, while gaps 2-4 remain relevant. Plan 0015 is still needed but its target has shifted from backward-edge overlap to forward-forward fan-in/skip-edge overlap.

## Where

Sources consulted:

- `/Users/kevin/src/mmdflux/research/0010-attachment-spreading-revisited/prior-research/SYNTHESIS.md` -- Executive synthesis of prior attachment research
- `/Users/kevin/src/mmdflux/research/0010-attachment-spreading-revisited/prior-research/stagger-preservation-analysis.md` -- Detailed analysis of dagre stagger being discarded
- `/Users/kevin/src/mmdflux/research/0010-attachment-spreading-revisited/q1-current-overlap-inventory.md` -- Q1 findings on current overlap state
- `/Users/kevin/src/mmdflux/src/render/layout.rs` -- Current implementation of `compute_stagger_positions()` and coordinate transforms
- `/Users/kevin/src/mmdflux/plans/0015-attachment-point-spreading/implementation-plan.md` -- Plan 0015 approach and task list

## What

### Predictions from stagger-preservation-analysis.md

The prior research made these specific predictions about what stagger preservation would fix:

| Predicted Case | Predicted Outcome | Actual Outcome | Verdict |
|---|---|---|---|
| `multiple_cycles.mmd` (TD, forward+backward) | **Yes, stagger helps** -- different node x-positions produce different approach angles | **Correct.** Q1 found NO overlap. Backward edges route cleanly on separate sides. | RIGHT |
| `complex.mmd` (TD, diamond with forward+backward) | **Likely yes** -- same mechanism | **Correct.** Q1 found NO overlap. The complex diagram renders cleanly. | RIGHT |
| `ci_pipeline.mmd` (LR, diamond with 2 outgoing) | **No, stagger won't help** -- stagger is in primary axis, not cross axis | **Correct** (but for wrong reason). Q1 found NO overlap because the two targets are at different y-positions and the edges separate cleanly. The LR layout actually works fine here. | PARTIALLY RIGHT |
| Fan-in/fan-out (already works) | **No change needed** -- these already work | **Wrong.** Q1 found overlaps in `fan_in.mmd`, `fan_out.mmd`, `five_fan_in.mmd`. These have near-overlaps (`▼ ▼` single-space-gap). | WRONG |
| Simple diagrams (no backward edges) | Should remain centered, no stagger | **Correct.** `compute_stagger_positions()` returns empty map when `dagre_range < 1.0`, preserving center-aligned layout. | RIGHT |

### What stagger preservation actually fixed

The `compute_stagger_positions()` implementation (lines 1017-1131 of `layout.rs`) successfully:

1. **Detects when dagre produces cross-axis offset** by comparing dagre cross-axis values across all layers (`dagre_range < 1.0` threshold)
2. **Scales the stagger proportionally** using `target_stagger = (dagre_range / nodesep * (spacing + 2.0))`, mapping dagre's continuous coordinate space to ASCII character space
3. **Preserves centering for non-staggered diagrams** by returning an empty HashMap, which causes `grid_to_draw_vertical()` to use the original centering logic
4. **Enforces minimum node spacing** in multi-node layers (lines 1114-1123) to prevent stagger from causing node collisions

This fixed the backward-edge overlap that was the prior research's central concern. The `multiple_cycles.mmd` fixture -- the motivating example -- now renders with backward edges cleanly separated from forward edges.

### What was NOT predicted

The prior research's blind spot was **forward-forward same-face overlap**. The SYNTHESIS.md stated:

> "Fan-in/fan-out patterns -- verified in current output: Three edges arrive at distinct x-positions on Target's top face. This works because [sources are at different x-positions]."

This was wrong for several cases. The research verified `fan_in.mmd` as working, but Q1 found it has a `▼ ▼` near-overlap. The research did not consider:

- **Skip edges** (edges spanning 2+ ranks) converging with direct edges at a narrow target (the `double_skip.mmd`, `stacked_fan_in.mmd`, `skip_edge_collision.mmd` pattern)
- **Narrow target nodes** where 3-char width provides insufficient room for 3 attachment points (`narrow_fan_in.mmd`)
- **Fan-out departure overlap** where multiple edges leave from adjacent cells on the source's bottom face (`fan_out.mmd`)

### Status of the 5 Gaps from SYNTHESIS.md

| Gap | Description | Still Relevant? | Notes |
|---|---|---|---|
| **Gap 1: Backward edge face classification** | Pre-pass must reverse waypoints for backward edges before classifying face | **Moot.** No backward-edge overlap exists. Stagger preservation fixed this upstream. The face classification logic may still be needed for correctness, but it's not blocking any real overlap case. |
| **Gap 2: Partial overrides with sentinel values** | `(0, 0)` sentinel is fragile; should use `Option<(usize, usize)>` | **Still relevant.** Plan 0015's implementation should use `Option` types regardless of which overlaps it targets. Good engineering practice. |
| **Gap 3: Interaction with `offset_from_boundary`** | Spread attachment points near face edges may get incorrect offset direction | **Still relevant.** Forward-forward spreading will move attachment points away from center, so the offset direction issue applies to the new target cases too. |
| **Gap 4: Edge segment routing after spread** | Non-center attachment points may need different initial segment direction | **Still relevant.** Same reasoning as Gap 3 -- forward-forward spreading creates non-center attachment points. |
| **Gap 5: Backward edges on opposite face** | Forward and backward edges sharing the same face need mixed grouping | **Moot.** No backward-forward overlap exists. Stagger preservation resolved the face sharing by producing different approach angles. |

### Assessment of Plan 0015's Approach

Plan 0015's core mechanism (pre-pass face classification, grouping, spreading) is **still valid** but the **target cases have changed**:

**Original targets (from plan):**
1. Forward + backward edges share attachment points (TD/BT) -- `multiple_cycles.mmd`, `complex.mmd`
2. Multiple forward edges from diamond share attachment points (LR) -- `ci_pipeline.mmd`

**Actual remaining targets (from Q1):**
1. Forward-forward skip-edge convergence at narrow nodes -- `double_skip.mmd`, `stacked_fan_in.mmd`, `skip_edge_collision.mmd`
2. Forward-forward fan-in at narrow targets -- `narrow_fan_in.mmd`, `fan_in.mmd`, `five_fan_in.mmd`
3. Forward-forward fan-out departure crowding -- `fan_out.mmd`

The plan's tasks 4.1 (test `multiple_cycles.mmd`) and 4.2 (test `ci_pipeline.mmd` LR diamond) reference fixtures that **no longer have overlap**. These test tasks need updating to target the actual overlap fixtures.

The plan's phases 1-3 (face classification, attachment plan, router integration) remain sound for the new targets. The key difference is that instead of handling forward-backward mixed grouping (the complex case), the plan only needs to handle forward-forward grouping on the same face -- a simpler variant.

## How

Methodology:

1. Read the prior research predictions in `stagger-preservation-analysis.md`, specifically the "Impact on Attachment Point Overlap" section and the per-fixture prediction table
2. Read the current `compute_stagger_positions()` implementation to verify it matches what the research proposed (Option A: dagre x-coordinate scaling, which was implemented as a variant of the research's recommended approach)
3. Cross-referenced each prior prediction against Q1's rendered output for the same fixture
4. Evaluated each of the 5 SYNTHESIS.md gaps against whether the overlap pattern they addressed still exists
5. Compared plan 0015's target fixtures and test cases against Q1's actual overlap inventory

## Why

This validation reveals three important things for the path forward:

1. **Stagger preservation was a major win.** It eliminated the most visible overlap category (backward-edge overlap) and aligned ASCII output with mermaid's intended layout behavior. The prior research was correct that this should be the first fix.

2. **Plan 0015's scope should narrow.** The original plan targeted backward-forward and LR-diamond cases that no longer exist. The remaining cases are simpler (all forward-forward, all TD direction), which means the plan's implementation can be streamlined. Gaps 1 and 5 can be dropped. The face classification still matters but doesn't need to handle mixed forward/backward grouping.

3. **The remaining problem is fundamentally different.** The prior research framed overlap as a "converging approach angles" problem (different edges approaching from the same direction). The actual remaining problem is more about **physical space**: narrow target nodes don't have enough character cells to accommodate multiple attachment points, regardless of approach angle. This suggests the spreading algorithm needs to consider node width as a constraint and may need to widen the routing corridor or accept some minimum visual spacing as "good enough."

## Key Takeaways

- Stagger preservation fixed all backward-edge overlap -- the prior research's primary prediction was correct
- The prior research's claim that "fan-in/fan-out already works" was wrong -- 6 fixtures show forward-forward overlap
- Of the 5 SYNTHESIS.md gaps, 2 are moot (gaps 1 and 5 about backward edges), 3 remain relevant (gaps 2-4 about implementation correctness)
- Plan 0015 is still needed but should be retargeted from backward-forward overlap to forward-forward skip-edge and fan-in overlap
- Plan 0015's test fixtures (tasks 4.1 and 4.2) reference cases that no longer overlap and need updating
- The core spreading mechanism (pre-pass face grouping and even distribution) is still the right approach for the remaining cases

## Open Questions

- Should plan 0015 be updated in-place or cancelled and replaced with a new plan targeting the revised scope?
- Is single-space-gap (`▼ ▼`) acceptable spacing, or should the spreading algorithm guarantee 2+ cell gaps between arrows?
- For very narrow nodes (5 chars wide), is it physically possible to spread 3 attachment points? If not, should the router use a wider margin or a vertical stagger instead?
- The `compute_stagger_positions()` function applies to all dagre layouts -- should we verify it doesn't introduce regressions for edge cases not in the fixture set?
- Does the fan-out departure overlap (`│ │` in `fan_out.mmd`) need the same fix as the fan-in arrival overlap, or is departure-side crowding less visually harmful?
