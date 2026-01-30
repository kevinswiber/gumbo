# Research: LR/RL Rendering Issues

## Status: SYNTHESIZED

---

## Goal

Investigate the 7 open issues from the fix/lr-rl-routing branch to understand root causes, determine fixes, and prioritize implementation. Issues range from critical rendering bugs (backward edges passing through nodes, disconnected paths) to layout quality (spacing, centering) to cosmetic (label placement).

## Context

Branch `fix/lr-rl-routing` (commit 83d4877) introduced correct side-face attachment for LR/RL layouts and H-V-H Z-shaped paths. All 315 tests pass, but 7 issues remain documented in `issues/0001-lr-layout-and-backward-edge-issues/issues.md`.

The issues cluster into three groups:
- **Critical bugs (Issues 4, 7):** Backward edge rendering in git_workflow.mmd — arrow passes through node border, path is disconnected
- **Layout quality (Issues 1, 2, 3):** Canvas top margin grows, source not centered, excessive vertical spacing
- **Cosmetic (Issues 5, 6):** Edge labels detached from their edges in LR mode

## Questions

### Q1: Canvas top margin and vertical trimming

**Where:** `src/render/canvas.rs` (Display impl, strip_common_leading_whitespace), `src/render/layout.rs` (canvas dimension computation, grid_to_draw_horizontal)
**What:** Why do blank rows accumulate above content in LR fan-out layouts? Is the canvas allocated too tall, or is trimming only horizontal?
**How:** Read the Display/to_string path for Canvas. Check if empty leading rows are trimmed. Trace how canvas height is computed in `grid_to_draw_horizontal()` and whether stagger positions can push content downward. Test with fan_out.mmd and increasing fan counts.
**Why:** Issue 1 — growing top margin is visually distracting and wastes terminal space. Fix is likely simple (add vertical trimming to Display impl).

**Output file:** `q1-canvas-top-margin.md`

---

### Q2: LR backward edge routing — arrow through node and disconnected path

**Where:** `src/render/router.rs` (route_backward_edge, resolve_attachment_points, build_orthogonal_path_for_direction), `src/render/edge.rs` (render_edge arrow placement)
**What:** Why does the backward "git pull" edge place ◄ to the LEFT of Working Dir's left border? Why is the └───┘ bottom path disconnected from the node? How does route_backward_edge() construct paths for LR layouts?
**How:** Trace route_backward_edge() for the git_workflow.mmd "git pull" edge step by step. Check waypoint transformation, attachment point computation, and path segment generation. Compare with working TD backward edges. Determine if the issue is in path construction, attachment point resolution, or arrow rendering.
**Why:** Issues 4 and 7 — these are the most severe rendering bugs. Backward edges in LR mode are broken: the arrow appears inside/before the node border, and the routing path has gaps.

**Output file:** `q2-lr-backward-edge-bugs.md`

---

### Q3: LR edge label placement

**Where:** `src/render/edge.rs` (label positioning for LR/RL in render_edge), `src/render/router.rs` (Z-path segment structure)
**What:** Why are "git push" and "git add" labels detached from their edges? How does the label placement algorithm choose position for LR Z-shaped paths? Does it account for backward edge path geometry?
**How:** Trace the label placement code path for LR backward edges. Check if the label y-coordinate matches the actual edge path segments. Compare label placement for forward vs backward LR edges.
**Why:** Issues 5 and 6 — labels floating away from edges makes diagrams hard to read. Likely the label placement code assumes a path geometry that doesn't match backward edge Z-paths.

**Output file:** `q3-lr-label-placement.md`

---

### Q4: Dagre coordinate mapping for LR layouts — centering and spacing

**Where:** `src/render/layout.rs` (compute_stagger_positions, grid_to_draw_horizontal), `src/dagre/position.rs` and `src/dagre/bk.rs` (Brandes-Kopf coordinate assignment)
**What:** Why isn't the source node vertically centered among its targets in LR layouts? Why is there excessive vertical spacing between target nodes? Is nodesep being applied incorrectly for horizontal layouts?
**How:** Trace how dagre assigns y-coordinates for LR nodes and how those map through stagger computation to draw coordinates. Check if nodesep/ranksep are swapped correctly for LR. Compare dagre output vs final draw positions.
**Why:** Issues 2 and 3 — layout quality suffers when the source isn't centered and targets are too spread out. These may be dagre configuration issues or coordinate mapping bugs.

**Output file:** `q4-lr-centering-and-spacing.md`

---

## Sources

| Source | Location | Used by |
|--------|----------|---------|
| Issues file | `issues/0001-lr-layout-and-backward-edge-issues/issues.md` | All |
| Router | `src/render/router.rs` | Q2, Q3 |
| Canvas | `src/render/canvas.rs` | Q1 |
| Layout | `src/render/layout.rs` | Q1, Q4 |
| Edge rendering | `src/render/edge.rs` | Q2, Q3 |
| Shape/faces | `src/render/shape.rs` | Q2 |
| Dagre position | `src/dagre/position.rs`, `src/dagre/bk.rs` | Q4 |
| Test fixtures | `tests/fixtures/git_workflow.mmd`, `tests/fixtures/fan_out.mmd` | Q1, Q2, Q3 |

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-canvas-top-margin.md` | Q1: Canvas top margin and vertical trimming | Complete |
| `q2-lr-backward-edge-bugs.md` | Q2: LR backward edge routing bugs | Complete |
| `q3-lr-label-placement.md` | Q3: LR edge label placement | Complete |
| `q4-lr-centering-and-spacing.md` | Q4: Dagre coordinate mapping for LR | Complete |
| `synthesis.md` | Combined findings and fix plan | Complete |
