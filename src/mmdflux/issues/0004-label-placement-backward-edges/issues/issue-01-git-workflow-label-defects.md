# Issue 01: git_workflow.mmd Label Placement Defects

**Severity:** High
**Category:** Forward edge label placement in LR layouts
**Status:** Fixed
**Affected fixtures:** `git_workflow.mmd`
**Source finding:** Plan 0025 regression sweep

## Description

The git_workflow.mmd fixture had three label rendering problems. All are now fixed.

### ~~2. git pull label collision~~ — **Fixed by Plan 0027**

The git pull label on the backward edge (Remote Repo → Working Dir) previously rendered 2 spaces above its horizontal segment. Now renders centered on the backward edge's routed path via path-midpoint algorithm.

### ~~1. "git commit" label hidden behind "Staging Area" node~~ — **Fixed by Plan 0029**

The "git commit" label was placed at a position that overlapped with the "Staging Area" node box, and the canvas `is_node` protection suppressed the label characters. Only "mmit" was partially visible, clipped by the node boundary.

**Root cause:** The `layer_starts` odd-rank interpolation used left-edge-to-left-edge midpoints, placing labels inside wide source nodes. Fixed by computing `layer_ends_raw` (right edge per layer) and using right-edge-to-left-edge midpoints.

### ~~3. Stray segment between "Staging Area" and "Local Repo"~~ — **Fixed by Plan 0029**

There was an extra/misplaced edge segment visible between these two nodes (`─┴─────┘`), caused by the same incorrect midpoint placing the label dummy waypoint inside the source node, triggering `nudge_colliding_waypoints()` to create a U-shaped routing detour.

## Current rendered output (fixed)

```
                             ┌──────────────┐              ┌────────────┐
               ┌───git add   │ Staging Area │──git commit─►│ Local Repo │┌──git push
┌─────────────┐┘         └──►└──────────────┘              └────────────┘┘         └──►┌─────────────┐
│ Working Dir │                                                                        │ Remote Repo │
└─────────────┘                                                                        └─────────────┘
       ▲                                                                                    │
       │                                                                                    │
       └──────────────────────────────────────git pull──────────────────────────────────────┘
```

## Cross-References

- **Plan 0027:** Fixed symptom 2 (git pull backward edge label)
- **Plan 0029:** Fixed symptoms 1 and 3 (forward label overlap and stray segment)
- **Research 0022:** Root cause analysis of LR forward label overlap
- **Plan 0025:** Phase 2 (rank-based label snapping, commit a22f04e), Phase 3 (backward edge waypoint stripping, commit 77a5055)
- **Research 0018 Q3:** `research/0018-label-dummy-rendering-regression/q3-render-layer-analysis.md`
