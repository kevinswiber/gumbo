# Issue 04: git_workflow LR backward edge arrow wrong and passes through node

**Severity:** Medium
**Category:** LR/RL backward edge routing
**Status:** Fixed — Plan 0021 (synthetic waypoints) + commit `fbafcec` (backward face classification)
**Affected fixtures:** `git_workflow`

## Description

In the git_workflow LR layout, the backward "git pull" edge (Remote Repo →
Working Dir) renders with the arrowhead `◄` to the LEFT of Working Dir's left
border, appearing to pass through the destination node. The arrow faces left
instead of arriving from a direction that makes visual sense.

## Reproduction

```
cargo run -q -- tests/fixtures/git_workflow.mmd
```

**mmdflux output (relevant portion):**
```
 ┌─────────────┐    │     └──────────────┘               └────────────┘       │       ┌─────────────┐
◄│ Working Dir │────┘                                                         └──────►│ Remote Repo │┐
 └─────────────┘                                                                      └─────────────┘│
             └───────────────git pull────────────────────────────────────────────────────────────────┘
```

The `◄│ Working Dir │` shows the backward edge arrow to the left of the node's
left border, pointing further left — as if the edge continues past the node.

## Expected behavior

The backward edge should arrive at Working Dir from a visible direction (below
or right), with the arrowhead indicating flow into the node, not passing
through it.

## Post Plan 0020 status

Plan 0020 Phase 1 fixed simpler LR cases (`left_right.mmd`, `fan_in_lr.mmd`)
but `git_workflow` still exhibits this problem. The backward edge (git pull,
Remote Repo → Working Dir) still shows `◄│ Working Dir │` — the arrow to the
left of the node's left border. The multi-rank backward edge routing in LR
layouts remains broken for complex topologies.

Additionally, the forward `git push` edge (Local Repo → Remote Repo) does not
connect to Remote Repo's left face — the `┌───────►` arrow floats above the
node with a gap. This is a related LR forward edge disconnection for edges that
span multiple visual rows.

## Resolution

Plan 0021 Phase 3 added synthetic waypoint generation for backward edges
without dagre waypoints — LR/RL backward edges now route below the nodes.
Commit `fbafcec` fixed face classification in `compute_attachment_plan()` so
backward edges attach on the correct face (Bottom for LR/RL, Right for TD/BT),
matching the synthetic routing path. The git_workflow backward edge (git pull)
now routes below all nodes and enters Working Dir from below with a proper
arrow.

## Cross-references

- Originally recorded as 0001 Issues 4 and 7
- Related to Issue 01 (LR forward arrow direction)
- Related to Issue 06 (backward edge disconnected)
- Fixed by Plan 0021 + commit `fbafcec`
