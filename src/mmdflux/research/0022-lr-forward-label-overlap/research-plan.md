# Research: LR Forward Edge Label Overlap with Adjacent Nodes

## Status: SYNTHESIZED

---

## Goal

Understand why forward edge labels in LR layouts overlap with adjacent node boxes in git_workflow.mmd (Issue 0004-01), and determine the root cause of the stray segment artifact. This research will inform a fix for precomputed label positioning in tight LR layouts.

## Context

In git_workflow.mmd (LR layout), the "git commit" and "git push" forward edge labels are hidden behind adjacent nodes. The canvas `is_node` protection suppresses label characters that overlap node cells, leaving only fragments visible (e.g., "mmit" for "git commit"). There is also a stray segment (`─┴─────┘`) between "Staging Area" and "Local Repo" that doesn't correspond to any visible edge path.

Current rendered output:
```
                               ┌──────────────┐              ┌────────────┐
             git add───┐       │ Staging Area │mmit  ┌──────►│ Local Repo │push──┐
  ┌─────────────┐┘     └──────►└──────────────┘│     │       └────────────┘┘     └──────►┌─────────────┐
  │ Working Dir │                              │     │                                   │ Remote Repo │
  └─────────────┘                             ─┴─────┘                                   └─────────────┘
         ▲                                                                                    │
         │                                                                                    │
         └──────────────────────────────────────git pull──────────────────────────────────────┘
```

The label placement pipeline has two divergent paths:
- **Path A (Precomputed):** Forward edges use `draw_label_at_position()` with positions from `transform_label_positions_direct()` — NO collision avoidance
- **Path B (Heuristic):** Backward edges use `draw_edge_label_with_tracking()` with `find_safe_label_position()` — full collision avoidance

This asymmetry means forward edge labels in tight layouts can land inside node boundaries. The implementation lives on the `~/src/mmdflux-label-dummy` worktree (branch `label-dummy-experiment`).

## Questions

### Q1: Trace the precomputed label position pipeline for "git commit"

**Where:** `~/src/mmdflux-label-dummy` worktree — `src/dagre/normalize.rs`, `src/render/layout.rs`, `src/render/edge.rs`
**What:** The exact (x, y) coordinates at each stage of the label position pipeline for the "git commit" edge (Staging Area → Local Repo). Starting from the label dummy node creation in `normalize.rs::run()` (lines 225-257), through `get_label_position()` (lines 364-388), to `transform_label_positions_direct()` (layout.rs:814-848), and finally `draw_label_at_position()` (edge.rs:760-783).
**How:** Add targeted debug prints at each pipeline stage (or use `--debug` flag output), run `cargo run -- tests/fixtures/git_workflow.mmd`, and capture the coordinate values. Track: dagre float coordinates → rank-snapped layer position → scaled ASCII coordinates → final draw position after centering (`x - label_len/2`).
**Why:** Without knowing the actual coordinates, we can't determine whether the problem is in dagre's position assignment, the coordinate transform, or the centering logic.

**Output file:** `q1-label-position-trace.md`

---

### Q2: Why does the label position land inside node boundaries?

**Where:** `~/src/mmdflux-label-dummy` worktree — `src/render/layout.rs`, `src/dagre/position.rs`, `src/dagre/bk.rs`, `src/render/edge.rs`
**What:** Compare the precomputed label coordinates (from Q1) against the drawn node bounds for "Staging Area" and "Local Repo". Determine: (a) does the raw precomputed position already fall inside a node boundary, or (b) does centering the label (`x - label_len/2`) push it into node territory? Also check whether dagre allocates sufficient inter-node spacing for LR label dummy nodes — does the label dummy node's width influence the gap between adjacent real nodes?
**How:** Extract node bounds from the layout output (node x, y, width, height → draw coordinates). Compare with the label position from Q1. Check `transform_label_positions_direct()` rank-snapping logic — does `layer_starts[rank]` for the label rank point to a position between the two nodes or coinciding with one? Examine whether LR layouts double minlen correctly for labeled edges.
**Why:** Understanding whether the overlap is caused by insufficient space allocation (dagre) vs. bad coordinate mapping (render transform) determines whether the fix belongs in the layout engine or the render layer.

**Output file:** `q2-node-boundary-analysis.md`

---

### Q3: Should precomputed labels use collision avoidance?

**Where:** `~/src/mmdflux-label-dummy` worktree — `src/render/edge.rs` (lines 686-757, 329-391, 72-251)
**What:** Understand the design decision behind skipping `find_safe_label_position()` for precomputed labels. Examine what `find_safe_label_position()` actually does (line 329-391) and whether it would produce correct results for precomputed positions. Check whether applying collision avoidance to precomputed positions would fix the overlap or just displace the label to an undesirable location.
**How:** Read the code paths for both precomputed and heuristic label placement. Compare their assumptions. Experimentally apply `find_safe_label_position()` to the precomputed position and see where the label ends up. Consider whether the right fix is: (a) collision avoidance on precomputed positions, (b) better space allocation in dagre, (c) adjusting the coordinate transform, or (d) a combination.
**Why:** The fix strategy depends on whether precomputed positions should be authoritative (fix the positions) or advisory (add collision avoidance as a safety net).

**Output file:** `q3-collision-avoidance-analysis.md`

---

### Q4: What causes the stray segment between "Staging Area" and "Local Repo"?

**Where:** `~/src/mmdflux-label-dummy` worktree — `src/render/router.rs`, `src/render/edge.rs`, `src/render/layout.rs`
**What:** Identify what draws the `─┴─────┘` fragment on row 5 between the two nodes. Determine whether this is: (a) a waypoint artifact from the label dummy node for "git commit" that gets routed through an incorrect position, (b) an edge segment drawn at the wrong coordinates due to coordinate transform issues, or (c) a rendering artifact from edge routing that creates segments at label dummy node positions.
**How:** Enable debug output to trace the waypoints and segments for the Staging Area → Local Repo edge. Check `route_edge()` or `route_edge_with_waypoints()` to see if label dummy node waypoints generate extra routing segments. Compare the stray segment's position with the label dummy node's coordinates.
**Why:** The stray segment is a visible defect that may share a root cause with the label overlap (both could stem from label dummy node coordinate issues).

**Output file:** `q4-stray-segment-investigation.md`

## Sources

| Source | Location | Used by |
|--------|----------|---------|
| normalize.rs | `~/src/mmdflux-label-dummy/src/dagre/normalize.rs` | Q1, Q2, Q4 |
| layout.rs | `~/src/mmdflux-label-dummy/src/render/layout.rs` | Q1, Q2, Q4 |
| edge.rs | `~/src/mmdflux-label-dummy/src/render/edge.rs` | Q1, Q2, Q3 |
| router.rs | `~/src/mmdflux-label-dummy/src/render/router.rs` | Q4 |
| position.rs | `~/src/mmdflux-label-dummy/src/dagre/position.rs` | Q2 |
| bk.rs | `~/src/mmdflux-label-dummy/src/dagre/bk.rs` | Q2 |
| git_workflow.mmd | `~/src/mmdflux-label-dummy/tests/fixtures/git_workflow.mmd` | Q1, Q2, Q4 |
| Issue 0004-01 | `issues/0004-label-placement-backward-edges/issues/issue-01-git-workflow-label-defects.md` | All |
| Research 0018 Q3 | `research/0018-label-dummy-rendering-regression/q3-render-layer-analysis.md` | Q3 |

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-label-position-trace.md` | Q1: Trace the precomputed label position pipeline | Complete |
| `q2-node-boundary-analysis.md` | Q2: Why does the label position land inside node boundaries? | Complete |
| `q3-collision-avoidance-analysis.md` | Q3: Should precomputed labels use collision avoidance? | Complete |
| `q4-stray-segment-investigation.md` | Q4: What causes the stray segment? | Complete |
| `synthesis.md` | Combined findings and fix recommendations | Complete |
