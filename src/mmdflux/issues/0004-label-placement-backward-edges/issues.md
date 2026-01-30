# Issues: Label Placement Defects on Backward Edges

## Date: 2026-01-29

Rendering issues discovered during Plan 0025 regression sweep. All issues are now **fixed**.

- Issues 2 and 3 shared a common root cause: backward edge label positions were computed from dagre's label dummy coordinates, but backward edge routing uses synthetic waypoints at a completely different cross-axis position. **Fixed by Plan 0027.**
- Issue 1's remaining symptoms were forward edge label placement problems in LR layouts. **Fixed by Plan 0029.**

**Source:** Plan 0025 regression sweep, Research 0018 Q3

---

## Issue Index

| # | Issue | Severity | Status | Category | Affected Fixture | File |
|---|-------|----------|--------|----------|------------------|------|
| 1 | git_workflow label placement defects (3 symptoms) | High | **Fixed** (Plans 0027, 0029) | Forward edge label placement (LR) | `git_workflow.mmd` | [issue-01](issues/issue-01-git-workflow-label-defects.md) |
| 2 | http_request backward edge label misplaced | Medium | **Fixed** (Plan 0027) | Backward edge label cross-axis | `http_request.mmd` | [issue-02](issues/issue-02-http-request-backward-label.md) |
| 3 | labeled_edges backward edge label far from edge | Medium | **Fixed** (Plan 0027) | Backward edge label cross-axis | `labeled_edges.mmd` | [issue-03](issues/issue-03-labeled-edges-backward-label.md) |

---

## Categories

### A. Backward Edge Label Cross-Axis Positioning (Issues 2, 3) — **Fixed**

Backward edge labels used dagre-computed coordinates for cross-axis placement, but backward edge routing uses `generate_backward_waypoints()` which places the vertical column at a completely different cross-axis position. Fixed by Plan 0027's path-midpoint algorithm (`calc_label_position()`), which computes label positions from the actual routed segments.

### B. Forward Edge Label Placement in LR Layouts (Issue 1) — **Fixed**

Forward edge labels ("git commit", "git push") in git_workflow.mmd overlapped with adjacent node boxes. The `layer_starts` odd-rank interpolation used left-edge-to-left-edge midpoints, placing label positions inside wide source nodes. Fixed by Plan 0029's `layer_ends_raw` computation (right-edge-to-left-edge midpoints) and collision avoidance safety net for precomputed labels.

---

## Cross-References

- **Plan 0029:** Fixed forward edge label overlap (Issue 1 symptoms 1, 3)
- **Plan 0027:** Fixed backward edge labels (Issues 2, 3, and Issue 1 symptom 2)
- **Plan 0025:** Phase 2 (rank-based label snapping, commit a22f04e), Phase 3 (backward edge waypoint stripping, commit 77a5055)
- **Research 0022:** Root cause analysis of LR forward label overlap
- **Research 0020:** Backward edge label placement (`research/0020-backward-edge-label-placement/`)
- **Research 0018 Q3:** `research/0018-label-dummy-rendering-regression/q3-render-layer-analysis.md` (render layer label placement pipeline)
