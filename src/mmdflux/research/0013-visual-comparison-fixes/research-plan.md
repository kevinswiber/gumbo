# Research: Visual Comparison Fixes (Issues 0002)

## Status: SYNTHESIZED

---

## Goal

Investigate the 9 open issues from the visual comparison against Mermaid's
renderer (issues/0002), understand root causes precisely, and determine fix
strategies. Issues are grouped into 5 categories (A-E) that share underlying
root causes.

## Context

- Branch: `fix/lr-rl-routing`
- Issues documented in `issues/0002-visual-comparison-issues/`
- 9 individual issue files in `issues/0002-visual-comparison-issues/issues/`
- Prior research in `research/0011-lr-rl-rendering-issues/` covers LR/RL broadly
- Plan-0019 (direct translation pipeline) is the current default renderer
- Plan-0019's claim of "zero regressions" was incorrect — issues 1, 4, 6 remain
- 11 of 26 fixtures have visible issues; 15 match well (some with minor jogs)

### Issue Summary

| # | Issue | Severity | Category |
|---|-------|----------|----------|
| 1 | LR forward edge: no horizontal line, wrong arrow | High | A: LR/RL routing |
| 2 | Skip-edge stagger missing | High | B: BK stagger |
| 3 | Edge centering jog for different-width nodes | Medium | D: Coord mapping |
| 4 | LR backward edge arrow wrong, passes through node | Medium | A: LR/RL routing |
| 5 | LR label placement at edges | Low | E: Labels |
| 6 | LR backward edge disconnected | Medium | A: LR/RL routing |
| 7 | Fan attachment point ordering causes crossings | Medium | C: Attachment points |
| 8 | Attachment overlap: missing arrows, edge collisions | High | C: Attachment points |
| 9 | Backward/skip edges pass behind nodes | High | B: BK stagger |

---

## Questions

### Q1: Why do LR forward edges lack horizontal segments and have wrong arrows?

**Where:** `src/render/router.rs` (resolve_attachment_points, build_orthogonal_path_for_direction), `src/render/edge.rs` (arrow rendering), `src/render/layout.rs` (LR coordinate setup)

**What:**
- The exact code path for a same-rank LR edge (e.g., User Input → Process Data in left_right.mmd)
- Why a horizontal segment is generated for Process→Display but not for Input→Process
- How the arrow direction is determined and why it produces `▲` instead of `►`
- Whether the issue is in routing (no H segment generated) or rendering (H segment present but not drawn)

**How:** Add debug tracing to route_edge() for left_right.mmd. Compare the RoutedEdge segments for the first edge (broken) vs second edge (correct). Check if both edges go through the same code path or branch differently.

**Why:** Category A (issues 1, 4, 6) affects all LR layouts. This is the highest-impact fix since it makes LR diagrams fundamentally broken. Understanding the first-edge vs second-edge divergence will pinpoint the bug.

**Output file:** `q1-lr-edge-routing.md`

---

### Q2: How does dagre.js BK algorithm produce node stagger for skip edges?

**Where:** dagre.js source (npm `dagre` package), `src/dagre/bk.rs`, `src/dagre/normalize.rs`, `src/dagre/order.rs`, `src/dagre/position.rs`

**What:**
- The exact mechanism by which dummy nodes influence real node x-coordinates in BK
- How BK alignment/compaction treats dummy-to-real vs dummy-to-dummy edges
- What intermediate BK values (medians, blocks, alignments) dagre.js produces for double_skip.mmd
- Why mmdflux BK produces all nodes at the same x vs dagre.js producing the stagger

**How:** Read dagre.js coordinate.js/position.js. Trace through double_skip graph manually in both implementations. Compare BK get_neighbors() behavior.

**Why:** Category B (issues 2, 9) is the second highest-impact group. Without stagger, skip edges are forced into node borders. This is an architectural issue in the BK algorithm.

**Output file:** `q2-bk-stagger-mechanism.md`

---

### Q3: Why are attachment points ordered incorrectly, causing crossings and overlaps?

**Where:** `src/render/router.rs` (compute_attachment_plan), `src/render/edge.rs` (arrow rendering/overwrite)

**What:**
- How compute_attachment_plan() orders edges on a shared node face
- Whether edges are sorted by opposite-node spatial position or by edge index
- For fan_in.mmd: what order are Source A, B, C assigned attachment points on Target's top face?
- For http_request.mmd: how do forward and backward edges sharing Send Response's top face get assigned?
- When do arrow characters get overwritten by later-drawn edge characters?

**How:** Trace compute_attachment_plan() for fan_in.mmd and http_request.mmd. Log the edge ordering and resulting attachment x-coordinates. Compare with the spatial positions of the opposite nodes.

**Why:** Category C (issues 7, 8) affects fan patterns, complex diagrams, and any diagram where multiple edges share a node face. The crossing problem makes diagrams confusing; the overlap problem makes arrows invisible.

**Output file:** `q3-attachment-point-ordering.md`

---

### Q4: How do float-to-ASCII coordinate mappings produce centering jogs?

**Where:** `src/render/layout.rs` (coordinate mapping), `src/render/router.rs` (resolve_attachment_points)

**What:**
- What dagre float coordinates are assigned to Start and End in simple.mmd?
- How those floats map to ASCII column positions
- Where the 1-cell offset arises between source and target attachment columns
- Whether the issue is in dagre (different x-centers) or in rendering (same x-center, different columns)

**How:** Add debug output for simple.mmd showing dagre x-center, ASCII left-edge, ASCII width, and computed attachment column for both Start and End. Check if rounding creates the discrepancy.

**Why:** Category D (issue 3) affects the simplest graphs (simple.mmd, bottom_top.mmd). A jog on a two-node diagram is a bad first impression. Fix is likely small if the root cause is clear.

**Output file:** `q4-centering-jog-analysis.md`

---

### Q5: Why does LR label placement use the wrong position for ci_pipeline?

**Where:** `src/render/edge.rs` (lines 104-137, select_label_segment_horizontal)

**What:**
- What segments the router produces for Deploy→Staging and Deploy→Production edges
- Whether select_label_segment_horizontal() returns a segment or falls through to naive midpoint
- What the computed label coordinates are vs where they should be

**How:** Trace label placement for ci_pipeline edges. Check if the fallback midpoint path is triggered and why.

**Why:** Category E (issue 5) is low severity but straightforward to investigate. The fix should be localized to edge.rs label placement.

**Output file:** `q5-lr-label-placement.md`

---

## Sources

| Source | Location | Used by |
|--------|----------|---------|
| dagre.js source | npm `dagre` / GitHub | Q2 |
| mmdflux BK | `src/dagre/bk.rs` | Q2, Q4 |
| mmdflux normalize | `src/dagre/normalize.rs` | Q2 |
| mmdflux router | `src/render/router.rs` | Q1, Q3, Q4 |
| mmdflux layout | `src/render/layout.rs` | Q1, Q4 |
| mmdflux edge render | `src/render/edge.rs` | Q1, Q3, Q5 |
| Issue descriptions | `issues/0002-visual-comparison-issues/issues/` | All |
| Research 0011 | `research/0011-lr-rl-rendering-issues/` | Q1, Q2 |

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-lr-edge-routing.md` | Q1: LR forward/backward edge routing | Pending |
| `q2-bk-stagger-mechanism.md` | Q2: BK stagger for skip edges | Pending |
| `q3-attachment-point-ordering.md` | Q3: Attachment point ordering and overlap | Pending |
| `q4-centering-jog-analysis.md` | Q4: Float-to-ASCII centering jog | Pending |
| `q5-lr-label-placement.md` | Q5: LR label placement | Pending |
| `synthesis.md` | Combined findings and fix strategies | Pending |
