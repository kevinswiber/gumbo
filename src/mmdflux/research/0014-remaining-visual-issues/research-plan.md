# Research: Remaining Visual Comparison Issues (Post Plan 0020)

## Status: SYNTHESIZED

---

## Goal

Investigate the 6 remaining open issues from the visual comparison against
Mermaid (issues 0002: #2, #4, #6, #8, #9, #10). Plan 0020 fixed the simpler
cases; these are the harder residuals. We need root cause analysis and fix
strategies for each, building on prior research in 0013 rather than repeating it.

## Context

Plan 0020 (branch fix/lr-rl-routing) resolved 4 issues fully (1, 3, 5, 7) and
improved 2 partially (2, 9). Issues 4 and 6 were initially thought fixed but
persist in git_workflow.mmd. Issue 10 is newly discovered. Issue 8 was never
addressed.

Prior research: research/0013-visual-comparison-fixes/ has detailed root cause
analysis for the original 9 issues. Reference it — don't repeat the analysis.
Focus on what 0013 got wrong or didn't cover, and what the post-0020 codebase
reveals.

Key files:
- issues/0002-visual-comparison-issues/issues.md — full issue index with status
- research/0013-visual-comparison-fixes/synthesis.md — prior root cause analysis
- src/render/layout.rs — layout pipeline (overhang offset at 343-369, waypoint transform at 1794-1840)
- src/render/router.rs — edge routing, attachment points
- src/render/edge.rs — edge rendering, label placement
- src/dagre/bk.rs — Brandes-Köpf horizontal coordinate assignment

## Questions

### Q1: LR multi-rank edge routing (Issues 4, 6)

**Where:** src/render/router.rs, src/render/edge.rs, tests/fixtures/git_workflow.mmd
**What:** Why does Plan 0020 Phase 1 fix simple LR cases (left_right.mmd,
fan_in_lr.mmd) but not git_workflow? The backward edge (git pull, Remote→Working)
still shows ◄ to the left of Working Dir. The forward edge (git push, Local→Remote)
doesn't connect to Remote Repo's left face. Identify what's different about
multi-rank or backward edges in complex LR topologies.
**How:** Trace the routing path for both broken edges through route_edge /
route_backward_edge. Compare waypoint data and attachment point resolution
between working cases (left_right) and broken (git_workflow).
**Why:** These are the only remaining LR routing bugs.

Prior research: 0013 Q1 (q1-lr-edge-routing.md) analyzed the consensus-y
root cause. That fix worked for simple cases. Focus on what's different for
git_workflow's multi-rank backward edge.

**Output file:** `q1-lr-multirank-routing.md`

---

### Q2: BK block graph for full stagger (Issues 2, 9)

**Where:** src/dagre/bk.rs, src/dagre/position.rs, dagre.js source code
**What:** Plan 0020 Phase 5 finding showed BK does separate dummy from real
nodes, but lacks the wider diagonal stagger Mermaid produces. What would a
block graph implementation look like? Is there a simpler alternative (post-layout
nudge, minimum clearance enforcement)?
**How:** Study dagre.js positionX() and the block graph construction. Compare
the coordinate values our BK produces vs what dagre.js produces for
double_skip.mmd and stacked_fan_in.mmd. Determine if the gap is in alignment,
compaction, or both.
**Why:** Issues 2/9 are the highest-severity remaining issues.

Prior research: 0013 Q2 (q2-bk-stagger-mechanism.md) described the block graph
gap. Plan 0020 finding (skip-edge-waypoint-overhang-offset.md) showed the
transform bug was the immediate cause. Now we need the deeper BK improvement.

**Output file:** `q2-bk-block-graph.md`

---

### Q3: Attachment point overlap (Issue 8)

**Where:** src/render/router.rs (compute_attachment_plan, sort_face_group),
src/render/edge.rs (draw_arrow_with_entry)
**What:** Forward and backward edges arriving at the same node face still
collide (labeled_edges Handle Error, http_request Send Response). Plan 0020
Phase 3 fixed ordering but not overlap. What minimum gap enforcement or
face-splitting strategy would prevent collisions?
**How:** Trace the attachment points for Handle Error in labeled_edges.mmd.
Identify where the forward "no" edge and backward "retry" edge get assigned
overlapping positions. Determine if the fix is in spreading, rendering, or both.
**Why:** This is the only remaining High severity issue in attachment management.

Prior research: 0013 Q3 (q3-attachment-point-ordering.md) analyzed the sorting
inconsistency (now fixed). Focus on the overlap/collision aspect that remains.

**Output file:** `q3-attachment-overlap.md`

---

### Q4: TD label ambiguous pairing (Issue 10)

**Where:** src/render/edge.rs (label placement logic), tests/fixtures/decision.mmd,
tests/fixtures/labeled_edges.mmd
**What:** TD labels placed at junction points near target nodes make it unclear
which edge owns the label. In decision.mmd, "No" appears above Debug rather
than along the edge from "Is it working?". How does the current label placement
algorithm choose position, and what heuristic would place labels unambiguously?
**How:** Trace label position computation for the "No" and "Yes" edges in
decision.mmd. Compare against Mermaid's label positions. Identify whether the
fix is in the position algorithm or needs a different anchor strategy.
**Why:** New issue, no prior research coverage.

**Output file:** `q4-td-label-placement.md`

---

## Sources

| Source | Location | Used by |
|--------|----------|---------|
| Issue tracker | issues/0002-visual-comparison-issues/ | All |
| Prior research | research/0013-visual-comparison-fixes/ | All |
| Plan 0020 findings | plans/0020-visual-comparison-fixes/findings/ | Q1, Q2 |
| Router source | src/render/router.rs | Q1, Q3 |
| Edge rendering | src/render/edge.rs | Q1, Q3, Q4 |
| Layout pipeline | src/render/layout.rs | Q2 |
| BK algorithm | src/dagre/bk.rs | Q2 |
| Test fixtures | tests/fixtures/*.mmd | All |

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-lr-multirank-routing.md` | Q1: LR multi-rank edge routing | Complete |
| `q2-bk-block-graph.md` | Q2: BK block graph for stagger | Complete |
| `q3-attachment-overlap.md` | Q3: Attachment point overlap | Complete |
| `q4-td-label-placement.md` | Q4: TD label ambiguous pairing | Complete |
| `synthesis.md` | Combined findings and fix priorities | Complete |
