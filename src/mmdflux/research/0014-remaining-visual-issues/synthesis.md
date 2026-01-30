# Research Synthesis: Remaining Visual Comparison Issues

## Summary

The 6 remaining visual issues (from issue tracker 0002) stem from four distinct root causes across the rendering pipeline. **Q1, Q3 are fully resolved. Q4 is fixed.** Q2 (BK block graph) remains deferred.

- **Q1** was resolved across Plan 0020 (LR/RL routing alignment) and Plan 0021 (attachment spreading + backward routing). The final fix (commit `fbafcec`) corrected face classification in `compute_attachment_plan` for backward edges using synthetic waypoints.
- **Q3** was resolved by Plan 0021: endpoint-maximizing spread formula + `MIN_ATTACHMENT_GAP` enforcement. The overlap artifacts in `http_request` and `labeled_edges` are eliminated.
- **Q4** was fixed in commit `995a6ef` (TD label source-near segment placement).
- **Q2** remains deferred — BK block graph is aesthetic-only, large scope.

## Key Findings

### 1. LR/RL backward edge routing — RESOLVED (Q1)

The original research diagnosed the issue as consensus-y not propagating through waypoint paths. Implementation revealed **four distinct root causes**, none of which were consensus-y propagation:

1. **Wrong target face**: Backward LR edges used LEFT/LEFT faces (source exits left, target enters left). Changed to LEFT/RIGHT — backward edges now enter the target from the RIGHT face, matching Mermaid. Symmetric fix for RL.

2. **Corner offset ambiguity**: `offset_from_boundary()` checked top/bottom before left/right. At corner cells (where two faces meet), this chose vertical offset for LR edges. Replaced with `offset_for_face()` using explicit face parameters from new `edge_faces()` function.

3. **Side face extent too narrow**: `face_extent()` excluded corner rows for Left/Right faces. Height-3 nodes had only 1 usable cell, preventing spreading. Changed to include full height.

4. **Attachment plan face classification**: `compute_attachment_plan()` hardcoded Right/Left for all LR edges regardless of backward status. Updated to use `edge_faces()`.

**Files changed:** `src/render/router.rs`, `src/render/shape.rs`
**Tests:** All 367 tests pass. All fixtures render correctly.

**Remaining visual artifacts — ALL RESOLVED by Plan 0021 + commit `fbafcec`:**
- ~~Corner attachment points overwrite node border characters~~ — Fixed by `backward_routing_faces()` in `compute_attachment_plan()`, ensuring backward edges attach on the correct face (Right for TD/BT, Bottom for LR/RL) instead of the geometric face.
- ~~The spread formula doesn't maximize separation~~ — Fixed by endpoint-maximizing formula `(i * range) / (count - 1)` (Plan 0021 Phase 1).
- ~~Single-rank backward edges route through the gap~~ — Fixed by synthetic waypoint generation (Plan 0021 Phase 3).

### 2. BK single-pass compaction is correct but minimal (Q2)

mmdflux's BK correctly separates dummy and real nodes into different blocks and computes adequate separation. The prior research (0013 Q2) was partially incorrect in attributing the stagger gap to BK — the immediate cause was the overhang offset bug (fixed in Plan 0020 Phase 5). A block graph implementation (two-pass compaction with explicit separation constraints) would produce wider diagonal stagger matching Mermaid's output, but this is an aesthetic improvement, not a correctness fix.

**Fix scope:** Large — requires building a block graph after vertical alignment, two-pass DFS compaction, and coordinate propagation. Marginal visual improvement for most diagrams.

### 3. Attachment overlap — RESOLVED (Q3)

The theoretical gap identified in Q3 has been fully addressed by Plan 0021:

1. **Endpoint-maximizing spread formula** (Phase 1): Replaced centering formula `((i+1) * range) / (count+1)` with `(i * range) / (count - 1)`, placing edges at face extremes for maximum separation.
2. **MIN_ATTACHMENT_GAP enforcement** (Phase 2): Added `MIN_ATTACHMENT_GAP = 2` constant with forward correction pass, ensuring adjacent attachment points maintain minimum separation.
3. **Synthetic backward waypoints** (Phase 3): Backward edges now route around nodes instead of through the gap, eliminating the forward/backward collision pattern.

The `http_request` and `labeled_edges` fixtures no longer show overlap artifacts.

**Note:** Plan 0021 findings documented that `MIN_ATTACHMENT_GAP` enforcement is mathematically redundant given the endpoint formula — the formula naturally produces gaps >= 2 when the face extent is large enough. The enforcement remains as a safety net for edge cases.

### 4. Label segment selection is wrong for short forward edges (Q4)

`select_label_segment()` returns the last vertical segment for paths with < 6 segments. For short forward edges (3-4 segments), this is the segment closest to the target node, placing labels where they appear to belong to the target rather than the edge. Long backward edges (6+ segments) use the longest inner vertical segment, which works correctly.

**Fix scope:** Moderate — change the segment selection heuristic for short forward edges to prefer earlier segments (closer to source or edge midpoint), or use the geometric midpoint of the full path.

## Recommendations

1. ~~**Fix Q1 (LR multi-rank routing) first**~~ **DONE** — Plan 0020 (face assignment, offset, extent, attachment plan) + Plan 0021 (synthetic waypoints, spread formula) + commit `fbafcec` (backward face classification in attachment plan).

2. ~~**Fix Q4 (TD label placement) next**~~ **DONE** — Commit `995a6ef`. Source-near segment + horizontal jog overlap.

3. ~~**Fix Q3 (attachment overlap) as hardening**~~ **DONE** — Plan 0021 Phase 1 (endpoint spread formula) + Phase 2 (MIN_ATTACHMENT_GAP) + Phase 3 (synthetic waypoints eliminate forward/backward collisions).

4. **Defer Q2 (BK block graph) to a separate plan** — Large scope, aesthetic-only improvement. The overhang offset fix already resolved the correctness issue. A block graph rewrite should be its own plan with proper BK algorithm research. Addresses Issues 2 and 9.

5. ~~**Spread formula improvement**~~ **DONE** — Plan 0021 Phase 1 implemented endpoint-maximizing formula.

6. ~~**Synthetic waypoints for single-rank backward edges**~~ **DONE** — Plan 0021 Phase 3 implemented synthetic waypoint generation for TD/BT (right side) and LR/RL (bottom side).

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | router.rs (Q1 face assignment + offset + attachment plan), shape.rs (Q1 face extent), edge.rs (Q4 label segment selection), bk.rs (Q2 compaction) |
| **What** | Q1: wrong face, corner offset, narrow extent, plan classification — ALL FIXED. Q2: single-pass vs two-pass compaction — DEFERRED. Q3: no minimum gap — FIXED (endpoint formula + MIN_GAP). Q4: last-segment heuristic wrong for short edges — FIXED |
| **How** | Q1: `edge_faces()` + `offset_for_face()` + full-height extent + backward-aware plan + `backward_routing_faces()` — DONE. Q2: block graph + two-pass DFS. Q3: endpoint-maximizing spread + `MIN_ATTACHMENT_GAP` + synthetic waypoints — DONE. Q4: source-near segment selection — DONE |
| **Why** | Q1: backward edges weren't modeled separately from forward edges. Q2: simplicity trade-off. Q3: Phase 3 focused on ordering not spacing. Q4: heuristic conflates short/long edge types |

## Open Questions

- ~~Does Q1's fix also resolve RL backward edges, or is RL handled differently?~~ **ANSWERED:** Yes, symmetric fix applied for RL (RIGHT/LEFT).
- ~~For Q4, should dagre pre-compute label positions for all edges (not just long ones) to avoid render-time heuristics?~~ **ANSWERED:** Render-time heuristic change was sufficient (commit `995a6ef`).
- For Q2, how much of Mermaid's stagger comes from the block graph vs. other Mermaid-specific layout heuristics?
- ~~Should Q3's minimum gap be a fixed constant or derived from node width and edge count?~~ **ANSWERED:** Fixed constant (`MIN_ATTACHMENT_GAP = 2`) is sufficient — mathematically redundant given the endpoint formula but serves as a safety net.
- ~~Should single-rank backward edges get synthetic waypoints to route around nodes, or is through-the-gap routing acceptable?~~ **ANSWERED:** Yes, synthetic waypoints implemented in Plan 0021 Phase 3. Routes right (TD/BT) or below (LR/RL).
- ~~Should the spread formula be changed from centering to endpoint-maximizing for better visual separation on small faces?~~ **ANSWERED:** Yes, implemented in Plan 0021 Phase 1. Significant improvement for narrow faces.

## Next Steps

- [x] Fix Q1 (LR/RL backward edge routing) — **DONE** (Plan 0020, Plan 0021, commit `fbafcec`)
- [x] Fix Q4 (TD label placement) — **DONE** (commit `995a6ef`)
- [x] Fix Q3 (attachment overlap hardening) — **DONE** (Plan 0021)
- [x] Evaluate spread formula change and single-rank backward edge routing — **DONE** (Plan 0021)
- [x] Update issues/0002-visual-comparison-issues/ — **DONE** (2026-01-29)
- [ ] Create separate research/plan for Q2 BK block graph (deferred, large scope)

## Source Files

| File | Question |
|------|----------|
| `q1-lr-multirank-routing.md` | Q1: LR multi-rank edge routing — **RESOLVED** |
| `q2-bk-block-graph.md` | Q2: BK block graph for stagger — **DEFERRED** |
| `q3-attachment-overlap.md` | Q3: Attachment point overlap — **RESOLVED** |
| `q4-td-label-placement.md` | Q4: TD label ambiguous pairing — **RESOLVED** |
