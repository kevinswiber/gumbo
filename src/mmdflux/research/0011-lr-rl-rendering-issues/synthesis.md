# Research Synthesis: LR/RL Rendering Issues

## Summary

Investigation of 7 open issues from the `fix/lr-rl-routing` branch reveals four distinct root causes across three severity levels. The two critical backward edge bugs (Issues 4, 7) were already fixed in commit 83d4877 by forcing direction-aware side-face attachments and H-V-H Z-shaped paths. The remaining 5 issues fall into three independent categories: (1) canvas vertical trimming is missing from the `Display` impl (Issue 1 — simple fix), (2) edge label placement for LR/RL uses a naive midpoint formula instead of segment-aware positioning (Issues 5, 6 — moderate fix), and (3) dagre's `node_sep=50.0` is miscalibrated for LR layouts and the BK algorithm doesn't center layer-0 source nodes among their children (Issues 2, 3 — deeper architectural fix).

## Key Findings

### Finding 1: Canvas vertical trimming is absent (Issue 1)

The `Display` impl in `canvas.rs` (lines 187-228) strips horizontal leading whitespace and trailing spaces per line, but does NOT trim leading or trailing empty rows. When stagger positioning in LR layouts places nodes with top padding, blank rows accumulate above content. The canvas allocation and node positioning are correct — the issue is purely in the string conversion path. This is the simplest fix: add `lines.iter().position(|line| !line.is_empty())` to skip leading empty rows.

### Finding 2: Backward edge routing was fixed but residual issues remain (Issues 4, 7 — fixed; Issues 5, 6 — open)

Commit 83d4877 correctly addressed the two critical backward edge bugs by:
- Forcing direction-aware side-face attachments instead of geometric intersection
- Switching from H-V L-shaped to H-V-H Z-shaped paths for correct arrow glyphs
- Direction-aware face classification in attachment spreading

However, edge label placement (Issues 5, 6) was NOT addressed by this fix. Labels remain detached because the label positioning code path is separate from the routing fix.

### Finding 3: LR label placement lacks segment awareness (Issues 5, 6)

TD/BT layouts use `select_label_segment()` (edge.rs lines 349-384) to intelligently choose the longest vertical segment for label placement. LR/RL layouts use a naive formula `mid_y = (routed.start.y + routed.end.y) / 2` (edge.rs line 107) that doesn't consult actual path segments. For backward edges that arc around the diagram with waypoints at varied Y-coordinates, this midpoint doesn't correspond to any actual edge segment, causing labels to float in empty space.

### Finding 4: Dagre parameters are not direction-aware (Issues 2, 3)

Two independent problems cause poor LR layout quality:

**Source not centered (Issue 2):** The Brandes-Kopf algorithm aligns nodes using median predecessors (upward edges). Layer-0 source nodes have no predecessors, so they receive default positioning instead of centering among their children. The source aligns with its first child rather than the vertical midpoint of all children.

**Excessive spacing (Issue 3):** `node_sep=50.0` is hardcoded in `dagre/mod.rs:240-246` regardless of direction. For TD, this is reasonable (node widths are 50-100+ pixels). For LR, this applies to vertical separation between nodes of height 3-5 characters — a 1000%+ mismatch. The stagger scaling formula `(dagre_range / nodesep * spacing)` amplifies this by using nodesep as a normalization factor.

## Recommendations

1. **Fix canvas vertical trimming (Issue 1)** — Add leading/trailing empty row trimming to `Display::fmt()` in `canvas.rs`. Lowest risk, highest impact-per-effort. Independent of all other fixes.

2. **Implement segment-aware label placement for LR/RL (Issues 5, 6)** — Port the `select_label_segment()` approach from TD/BT to LR/RL, choosing the longest horizontal segment for label Y-coordinate instead of the naive midpoint. Moderate complexity, independent of other fixes.

3. **Make dagre node_sep direction-aware (Issue 3)** — In `compute_layout_dagre()`, set `node_sep` based on direction and average node dimensions. For LR/RL, something like `avg_node_height * 2.0` (~6-10) instead of 50.0. This will also improve stagger scaling since it uses nodesep as a normalization factor.

4. **Add post-BK source centering (Issue 2)** — After BK coordinate assignment, add a pass that centers layer-0 nodes (those with no predecessors) among their children's Y-coordinates. This is an architectural addition to the dagre pipeline and should be done carefully. Alternatively, modify `get_neighbors()` in `bk.rs` to consider successors when predecessors are absent.

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | `canvas.rs` Display impl (Q1), `router.rs` attachment/path (Q2), `edge.rs` label placement (Q3), `dagre/mod.rs` + `bk.rs` + `layout.rs` stagger (Q4) |
| **What** | Missing vertical trim, naive label midpoint, miscalibrated node_sep, BK predecessor-only alignment |
| **How** | Display skips vertical trim; label uses `(start.y+end.y)/2` not segments; BK uses node_sep=50 for 3-char-tall nodes; BK ignores successors for layer-0 |
| **Why** | Horizontal-only trimming was sufficient for TD; LR label code was simplified; node_sep was ported from pixel-scale TD; BK algorithm inherently uses predecessors |

## Open Questions

- Should vertical trimming also handle trailing empty rows (defensive)?
- For LR/RL label placement, should labels go on the longest horizontal segment or the middle segment by count?
- Should `node_sep` be computed dynamically from node dimensions, or should separate LR/RL defaults be hardcoded?
- Would fixing source centering (Issue 2) also improve backward edge aesthetics by reducing path deviations?
- What test coverage exists for RL backward edges specifically?

## Next Steps

- [ ] Implement canvas vertical trimming (Issue 1) — standalone fix in `canvas.rs`
- [ ] Implement segment-aware LR/RL label placement (Issues 5, 6) — changes in `edge.rs`
- [ ] Make node_sep direction-aware (Issue 3) — changes in `dagre/mod.rs` and potentially `layout.rs` stagger scaling
- [ ] Add post-BK source centering for LR/RL (Issue 2) — changes in `dagre/position.rs` or `dagre/bk.rs`
- [ ] Add integration tests for each fix using existing fixtures (fan_out.mmd, git_workflow.mmd)
- [ ] Verify fixes don't regress TD/BT layouts (run full test suite)

## Source Files

| File | Question |
|------|----------|
| `q1-canvas-top-margin.md` | Q1: Canvas top margin and vertical trimming |
| `q2-lr-backward-edge-bugs.md` | Q2: LR backward edge routing bugs |
| `q3-lr-label-placement.md` | Q3: LR edge label placement |
| `q4-lr-centering-and-spacing.md` | Q4: Dagre coordinate mapping for LR |
