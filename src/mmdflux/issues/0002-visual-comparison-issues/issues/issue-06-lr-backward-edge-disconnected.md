# Issue 06: git_workflow LR backward edge path disconnected

**Severity:** Medium
**Category:** LR/RL backward edge routing
**Status:** Fixed — Plan 0021 (synthetic waypoints) + commit `fbafcec` (backward face classification)
**Affected fixtures:** `git_workflow`

## Description

The backward edge from Remote Repo to Working Dir (git pull) has a visible gap
in its path. The bottom horizontal segment doesn't visually connect to Working
Dir. The edge routes along the bottom but terminates at the left-facing arrow
outside the node boundary rather than connecting to the node's face.

## Reproduction

See Issue 04 for the full git_workflow output. The backward edge path:
```
             └───────────────git pull────────────────────────────────────────────────────────────────┘
```

Routes along the bottom from Remote Repo (right) to Working Dir (left), but
the connection at Working Dir is through the `◄` arrow that appears detached
from the node.

## Post Plan 0020 status

Plan 0020 Phase 1 fixed LR routing for simpler cases but `git_workflow` still
shows the disconnected path. The backward edge `◄` is still detached from
Working Dir's left border, and the bottom routing segment doesn't visually
connect to the node.

The forward `git push` edge also shows disconnection — `┌───────►` floats
above Remote Repo without connecting to its left face.

## Resolution

See Issue 04 resolution. The backward edge path now connects fully via
synthetic waypoints routing below the nodes.

## Cross-references

- Originally recorded as 0001 Issue 7
- Closely related to Issue 04 (same edge, different aspect)
- Fixed by Plan 0021 + commit `fbafcec`
