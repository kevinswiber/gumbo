# Research Synthesis: Visual Comparison Fixes (Issues 0002)

## Summary

Investigation of all 9 visual comparison issues across 5 categories reveals 4 distinct root causes in the rendering pipeline: (1) attachment point y-coordinate misalignment for LR/RL layouts, (2) missing block graph in the BK horizontal compaction algorithm, (3) inconsistent spatial references between face classification and edge sorting, and (4) float-to-integer quantization in coordinate mapping. A 5th issue (label placement) is a downstream consequence of the LR routing problem. The fixes range from small (centering jog) to architecturally significant (BK block graph), but all are well-localized within specific pipeline stages.

## Key Findings

### Finding 1: LR attachment points use independent center_y() values (Issues 1, 4, 6)

`resolve_attachment_points()` (router.rs:315-346) forces LR/RL edges to exit/enter side faces using each node's `center_y()` independently. When same-rank nodes have different heights, their center_y values diverge, causing `build_orthogonal_path_for_direction()` to generate H-V-H paths instead of simple horizontal segments. The final vertical segment produces wrong arrow characters (`▲` instead of `►`). This is the highest-impact bug — it breaks all LR layouts fundamentally.

**Root cause:** `center_y()` is computed per-node without a consensus y-coordinate for same-rank edges.

### Finding 2: BK algorithm lacks block graph for horizontal compaction (Issues 2, 9)

mmdflux's BK implementation (bk.rs) correctly performs vertical alignment and left-neighbor compaction, but lacks the **block graph** refinement that dagre.js uses. Without a block graph, dummy node chains between skip edges don't create separation constraints between blocks of real nodes. All real nodes in the same alignment block receive the same x-coordinate, eliminating the stagger that would keep skip edges clear of node borders.

**Root cause:** Architectural gap — `place_block()` only enforces separation from immediate left neighbors, not across block boundaries created by dummy chain topology.

### Finding 3: Face classification and edge sorting use different spatial references (Issues 7, 8)

`compute_attachment_plan()` (router.rs:809-912) classifies edge faces using waypoint approach points but sorts edges on a shared face by opposite node geometric center. For backward edges routed around the diagram, these two references diverge significantly. Additionally, `draw_arrow_with_entry()` unconditionally overwrites canvas characters, so closely-spaced attachment points cause earlier arrows to disappear under later edges' line characters.

**Root cause:** Face classification uses waypoint-based approach angles; sorting uses opposite-node center position — inconsistent spatial references.

### Finding 4: Float-to-integer quantization causes centering jog (Issue 3)

When two nodes share the same dagre float x-center but have different widths, the float-to-integer conversion in layout.rs produces different rounded center positions. `NodeBounds.center_x()` (shape.rs:19-20) then recalculates centers via integer division (`x + width / 2`), losing the original alignment. Nodes differing by 2 in width systematically diverge by 1 cell, producing the characteristic jog on simple diagrams.

**Root cause:** Integer division on different widths loses float alignment; no mechanism preserves the original dagre center.

### Finding 5: LR label fallback uses averaged coordinates (Issue 5)

`select_label_segment_horizontal()` (edge.rs:418-451) returns None for certain waypoint-routed backward edges. The fallback (edge.rs:118-122) averages start/end coordinates, producing a midpoint in empty space. TD's fallback uses an anchor coordinate; LR's doesn't.

**Root cause:** Downstream consequence of complex waypoint paths; fallback logic doesn't anchor to any actual segment.

## Recommendations

1. **Fix LR attachment point alignment (Category A)** — Modify `resolve_attachment_points()` to use a consensus y-coordinate for same-rank LR/RL edges. Either average both `center_y()` values, align to a common baseline from the layout, or fall back to `calculate_attachment_points()` for geometric accuracy. This fixes issues 1, 4, 6 and unblocks LR/RL layouts.

2. **Fix centering jog (Category D)** — Store the original dagre float center in `NodeBounds` or compute attachment x from the float center rather than re-deriving via integer division. Alternatively, snap attachment points to the same column when nodes share a dagre center. Small fix, high visual impact on the simplest diagrams.

3. **Fix attachment point ordering (Category C)** — Use consistent spatial references: either sort by waypoint approach angle (matching face classification) or classify faces by opposite node position (matching sorting). Add minimum gap enforcement between attachment points to prevent arrow overwriting. Fixes issues 7, 8.

4. **Fix LR label fallback (Category E)** — Make `select_label_segment_horizontal()` always return a segment (be more lenient in filtering), or fix the fallback to use `routed.start.y` as anchor, mirroring TD's `routed.end.x` strategy. Low severity, localized fix.

5. **Implement BK block graph (Category B)** — Build a block graph from vertical alignment results where nodes are blocks and edges represent dummy chain topology. Run compaction on the block graph to enforce separation between blocks connected by dummy chains. This is the most architecturally significant change but addresses the skip-edge aesthetic that affects many diagrams. Consider a simpler "post-BK nudge" pass as an alternative.

## Plan 0020 Implementation Results

Plan 0020 (`fix/lr-rl-routing` branch, 5 phases) implemented recommendations
1–5 above. Results:

| Rec | Category | Result | Plan 0020 Phase |
|-----|----------|--------|-----------------|
| 1 | A: LR routing | **Fixed** — consensus-y for same-rank attachment points | Phase 1 |
| 2 | D: Centering jog | **Fixed** — two-pass overhang offset, dagre centers in NodeBounds | Phase 2 |
| 3 | C: Attachment ordering | **Partially fixed** — approach-based sort (Issue 7 fixed), overlap (Issue 8) remains | Phase 3 |
| 4 | E: Label placement | **Fixed** for LR — anchor y to source exit | Phase 4 |
| 5 | B: BK stagger | **Partially fixed** — waypoint overhang offset bug fixed; BK block graph deferred | Phase 5 |

**Key discovery during Phase 5:** The original hypothesis (missing BK block
graph) was partially wrong for the immediate symptom. A diagnostic investigation
found that BK *does* produce correct separation between dummy and real nodes.
The actual bug was that `transform_waypoints_direct()` and
`transform_label_positions_direct()` did not apply the Phase 2 overhang offset,
destroying the separation BK computed. After fixing the transform functions,
skip edges clear node borders. However, BK still doesn't produce the wider
diagonal stagger Mermaid uses — that would require the block graph refinement.

**New issue discovered post-0020:** Issue 10 — TD edge labels placed at
junction points near target nodes create ambiguous source-target pairing.
Affects `decision` and `labeled_edges`.

**Remaining open issues:** 2 (residual stagger), 8 (attachment overlap),
9 (residual adjacent routing), 10 (TD label ambiguity).

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | `router.rs` (attachment points, face classification, sorting), `bk.rs` (block formation, compaction), `layout.rs`/`shape.rs` (coordinate mapping), `edge.rs` (labels, arrow rendering) |
| **What** | 4 distinct root causes: LR y-misalignment, missing block graph, inconsistent face/sort references, float-to-int quantization. Plus 1 downstream label issue. |
| **How** | Each bug is well-localized: attachment points → router.rs, BK stagger → bk.rs, centering → layout.rs/shape.rs, labels → edge.rs. Fixes don't overlap. |
| **Why** | LR support was added assuming same-rank nodes share y-coordinates (they don't always). BK was implemented without the block graph refinement. Float-to-int conversion doesn't preserve alignment invariants. |

## Open Questions

- ~~Should LR attachment point fix use consensus y, layout-stored baseline, or geometric intersection?~~ **Resolved:** Consensus-y (Plan 0020 Phase 1)
- Is a "post-BK nudge" pass sufficient for stagger, or is a full block graph required? **Partially answered:** Post-BK nudge was unnecessary — the immediate bug was a transform offset. Full block graph still needed for Mermaid-equivalent diagonal stagger.
- ~~Should `NodeBounds` store the original float center to avoid re-deriving it?~~ **Resolved:** Yes, `dagre_center_x`/`dagre_center_y` fields added (Plan 0020 Phase 2)
- Can attachment point minimum gap enforcement be added without breaking existing layouts? **Still open** — Issue 8 remains.
- ~~How do these fixes interact?~~ **Resolved:** Fixes are well-isolated across pipeline stages; no negative interactions observed across 57 tests.
- **New:** How should TD label placement be improved to avoid ambiguous pairing with target nodes? (Issue 10)

## Fix Priority and Dependencies

| Priority | Category | Issues | Complexity | Dependencies | Status |
|----------|----------|--------|------------|--------------|--------|
| 1 | A: LR routing | 1, 4, 6 | Medium | None | **Fixed** (0020 P1) |
| 2 | D: Centering jog | 3 | Low | None | **Fixed** (0020 P2) |
| 3 | C: Attachment ordering | 7, 8 | Medium | Benefits from A | **Issue 7 fixed** (0020 P3), Issue 8 open |
| 4 | E: Label placement | 5, 10 | Low | Benefits from A | **Issue 5 fixed** (0020 P4), Issue 10 open |
| 5 | B: BK stagger | 2, 9 | High | None | **Improved** (0020 P5), residual open |

## Next Steps

- [x] Create implementation plan for Category A (LR routing fix) — **Done: Plan 0020 Phase 1**
- [x] Create implementation plan for Category D (centering jog) — **Done: Plan 0020 Phase 2**
- [x] Create implementation plan for Category C (attachment ordering) — **Done: Plan 0020 Phase 3** (Issue 7 fixed; Issue 8 remains)
- [x] Fix Category E (label fallback) — **Done: Plan 0020 Phase 4**
- [x] Research dagre.js block graph implementation for Category B — **Done: Plan 0020 Phase 5** (waypoint offset fixed; block graph deferred)
- [ ] Fix attachment point overlap for forward/backward edge collisions (Issue 8)
- [ ] Research BK block graph for full diagonal stagger (Issues 2, 9 residual)
- [ ] Fix TD label ambiguous pairing (Issue 10)

## Source Files

| File | Question |
|------|----------|
| `q1-lr-edge-routing.md` | Q1: LR forward/backward edge routing |
| `q2-bk-stagger-mechanism.md` | Q2: BK stagger for skip edges |
| `q3-attachment-point-ordering.md` | Q3: Attachment point ordering and overlap |
| `q4-centering-jog-analysis.md` | Q4: Float-to-ASCII centering jog |
| `q5-lr-label-placement.md` | Q5: LR label placement |
