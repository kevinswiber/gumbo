# Issues: Visual Comparison Against Mermaid (mmdc)

## Date: 2026-01-28 (updated 2026-01-29, Plan 0021 + commit fbafcec)

These issues were identified by comparing mmdflux output against Mermaid's
official renderer (mmdc) for all 26 test fixtures. Individual issue files are
in the `issues/` subdirectory.

**Comparison method:** Mermaid SVGs were generated with `mmdc` and node
positions extracted from `transform="translate(x, y)"` attributes. mmdflux
output was generated with `cargo run -q -- <fixture>`.

---

## Plan 0020 Resolution Summary

Plan 0020 (`fix/lr-rl-routing` branch) addressed 7 of 9 original issues across
5 phases:

| Phase | Issues Fixed | Description |
|-------|-------------|-------------|
| 1 | 1; 4, 6 partial | LR/RL routing alignment — consensus-y for attachment points (simple cases fixed; git_workflow persists) |
| 2 | 3 | Centering jog — overhang offset for dagre center consistency |
| 3 | 7 | Attachment ordering — approach-based sort key for face groups |
| 4 | 5 | LR label placement — anchor y to source exit point |
| 5 | 2, 9 (partial) | Skip-edge separation — overhang offset for waypoint/label transforms |

Issues 2 and 9 are improved (edges no longer merge with node borders) but have
residual: BK does not produce the diagonal stagger Mermaid uses, so skip edges
still route adjacent to intermediate nodes rather than through wide open space.

Issues 4 and 6 (LR backward edge) are now fixed — Plan 0021 synthetic
waypoints + face-aware attachment plan (commit `fbafcec`).

Issue 8 (attachment overlap) is now fixed — Plan 0021 endpoint-maximizing
spread formula + MIN_ATTACHMENT_GAP + synthetic backward waypoints.

Issue 10 (TD label ambiguous pairing) is fixed (commit 995a6ef).

---

## Issue Index

| # | Issue | Severity | Category | Status | Fixtures | File |
|---|-------|----------|----------|--------|----------|------|
| 1 | LR forward edge missing horizontal line, arrow wrong direction | High | LR/RL edge routing | **Fixed** (0020 P1) | `left_right`, `fan_in_lr` | [issue-01](issues/issue-01-lr-forward-arrow-reversed.md) |
| 2 | Skip-edge stagger missing, edges pass behind nodes | High | Dagre BK coords | **Fixed** (0020 P2+P5) | `double_skip`, `skip_edge_collision`, `stacked_fan_in` | [issue-02](issues/issue-02-skip-edge-stagger-missing.md) |
| 3 | Edge centering jog for different-width nodes | Medium | Edge routing / coords | **Fixed** (0020 P2) | `simple`, `bottom_top`, `simple_cycle` | [issue-03](issues/issue-03-edge-centering-jog.md) |
| 4 | git_workflow LR backward edge arrow wrong, passes through node | Medium | LR/RL backward edge | **Fixed** (0021 + fbafcec) | `git_workflow` | [issue-04](issues/issue-04-lr-backward-edge-arrow-wrong.md) |
| 5 | ci_pipeline LR label placement at edges | Low | Label placement | **Fixed** (0020 P4) | `ci_pipeline` | [issue-05](issues/issue-05-lr-label-placement.md) |
| 6 | git_workflow LR backward edge disconnected | Medium | LR/RL backward edge | **Fixed** (0021 + fbafcec) | `git_workflow` | [issue-06](issues/issue-06-lr-backward-edge-disconnected.md) |
| 7 | Fan-in/fan-out attachment point ordering causes crossings | Medium | Attachment points | **Fixed** (0020 P3) | `fan_in`, `fan_out`, `multiple_cycles` | [issue-07](issues/issue-07-fan-attachment-point-crossing.md) |
| 8 | Attachment point overlap causes missing arrows and collisions | High | Attachment overlap | **Fixed** (0021) | `http_request`, `labeled_edges` | [issue-08](issues/issue-08-attachment-overlap-missing-arrow.md) |
| 9 | Backward/skip edges pass behind intermediate nodes | High | Edge routing | **Fixed** (0020 P2+P5) | `http_request`, `skip_edge_collision`, `stacked_fan_in` | [issue-09](issues/issue-09-backward-edge-passes-behind-node.md) |
| 10 | TD edge label has ambiguous pairing with target node | Medium | Label placement | **Fixed** (995a6ef) | `decision`, `labeled_edges` | [issue-10](issues/issue-10-td-label-ambiguous-pairing.md) |

---

## Categories

### A. LR/RL Edge Routing (Issues 1, 4, 6) — FIXED

Forward LR edges lack horizontal segments and have wrong arrow direction.
Backward LR edges pass through destination nodes with detached arrows.
All are visible in `left_right`, `fan_in_lr`, and `git_workflow`.

**Issue 1 fixed in Plan 0020, Phase 1:** Consensus-y for same-rank LR/RL
attachment points, zero-gap entry direction fix.

**Issues 4, 6 fixed by Plan 0021 + commit `fbafcec`:** Plan 0021 Phase 3
added synthetic waypoint generation for backward edges without dagre waypoints,
routing around the bottom (LR/RL) or right (TD/BT) of nodes. Commit `fbafcec`
fixed the face classification mismatch in `compute_attachment_plan()` by adding
`backward_routing_faces()` — backward edges without dagre waypoints now attach
on the face matching the synthetic routing path (Right for TD/BT, Bottom for
LR/RL). The `git_workflow` backward edge (git pull) now routes below all nodes
and enters Working Dir properly.

### B. Skip-Edge Stagger / Node Offset (Issues 2, 9) — FIXED

BK always computed correct stagger; the rendering pipeline (`saturating_sub`
clipping) was destroying it. Fixed by two-pass overhang offset (Plan 0020,
Phase 2) and waypoint offset propagation (Phase 5). Confirmed by research/0015
Q5: the initial hypothesis that BK needed a block graph for stagger was wrong.

**Issue 2 fixed in Plan 0020, Phases 2+5.** Issue 9 (adjacent routing) resolved
as a consequence — edges now route through the BK-computed stagger space.

### C. Attachment Point Management (Issues 7, 8) — FIXED

Attachment points on shared node faces are not ordered by the spatial position
of the opposite node, causing unnecessary crossings. When many edges share a
face, attachment points overlap, overwriting arrows. Affects `fan_in`,
`fan_out`, `multiple_cycles`, `http_request`, `labeled_edges`.

**Issue 7 fixed in Plan 0020, Phase 3:** Approach-based sort key for face
groups, arrow overwrite protection.

**Issue 8 fixed by Plan 0021:** Three changes eliminated overlap:
1. Endpoint-maximizing spread formula places edges at face extremes (Phase 1).
2. `MIN_ATTACHMENT_GAP` enforcement ensures minimum 2-cell separation (Phase 2).
3. Synthetic backward waypoints route backward edges around nodes instead of
   through the gap, eliminating forward/backward collisions on shared faces
   (Phase 3). The `http_request` and `labeled_edges` fixtures are clean.

### D. Coordinate Mapping (Issue 3) — FIXED

Float-to-ASCII coordinate mapping produces off-by-one attachment columns for
different-width nodes that share dagre x-centers, causing small jogs.
Affects `simple`, `bottom_top`, `simple_cycle`.

**Fixed in Plan 0020, Phase 2:** Two-pass layout with overhang offset,
dagre centers stored in NodeBounds.

### E. Label Placement (Issues 5, 10) — FIXED

LR label placement falls back to naive midpoint for complex paths.
TD label placement positions labels at junctions near target nodes, causing
ambiguous pairing.

**Issue 5 fixed in Plan 0020, Phase 4:** Anchor y to source exit point for
LR layouts.

**Issue 10 fixed (commit 995a6ef):** TD labels now placed on the horizontal
jog segment (overlapping edge characters) or on a source-near vertical
segment, making source-target pairing unambiguous.

---

## Remaining Open Issues

All issues in this set are now fixed or resolved.

## Fixtures That Match Well

These fixtures have layouts that closely match Mermaid (expanded post-0020):

- `ampersand` — fan-in/fan-out matches well
- `bottom_top` — straight edges, centering jog fixed
- `chain` — straight vertical chain, correct
- `ci_pipeline` — LR layout correct, label placement fixed
- `complex` — complex topology rendered correctly
- `decision` — label placement fixed, "Yes"/"No" unambiguously paired
- `diamond_fan` — fan-in/fan-out with 2 branches correct
- `edge_styles` — all edge styles rendered correctly
- `fan_in` — attachment ordering fixed, no more crossings
- `fan_in_lr` — LR routing fixed, horizontal segments correct
- `fan_out` — attachment ordering fixed, no more crossings
- `five_fan_in` — 5-source fan-in correct
- `git_workflow` — LR forward edges fixed; backward edge (git pull) now routes below nodes correctly (Issues 4, 6 fixed)
- `label_spacing` — branching labels positioned correctly
- `left_right` — LR forward edges fixed
- `multiple_cycles` — attachment ordering fixed
- `narrow_fan_in` — narrow 3-source fan-in correct
- `right_left` — RL layout correct
- `shapes` — all node shapes rendered correctly
- `simple` — centering jog fixed, straight edges
- `simple_cycle` — centering jog fixed

---

## Cross-References

- **0001 Issues:** Issues 4, 5, 6 overlap with 0001 Issues 4–7
- **Plan 0018:** Phase 4 addressed LR/RL label placement
- **Plan 0019:** Direct coordinate translation pipeline
- **Plan 0020:** Fixed issues 1, 3, 5, 7; improved 2, 4, 6, 9; identified 10
- **Plan 0021:** Fixed issues 4, 6, 8 (attachment spreading + backward routing)
- **Commit fbafcec:** Fixed backward edge face classification in attachment plan
- **Research 0012:** Edge separation pipeline comparison
- **Research 0013:** Investigation of remaining visual comparison fixes
