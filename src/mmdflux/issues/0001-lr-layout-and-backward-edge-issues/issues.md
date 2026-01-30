# Issues: LR Layout and Backward Edge Rendering

## Date: 2026-01-28

These issues were identified by comparing mmdflux LR output against Mermaid's
official renderer (mmdc) and by inspecting `git_workflow.mmd`.

---

## Issue 1: Growing top margin in LR fan-out

**Severity:** Visual / cosmetic

When a single source fans out to multiple targets in LR layout, blank lines
accumulate above the rendered output. The margin grows with the number of
targets.

**Reproduction:**

```
echo -e "graph LR\n A-->B\nA-->C\nA-->D" | cargo run -q
```

**mmdflux output** (3 targets — 2 blank lines above):
```


         ┌───┐
      ┌─►│ B │
      │  └───┘
┌───┐ │
│ A │─┤
└───┘ │  ┌───┐
      ├─►│ C │
      │  └───┘
      │
      │
      │  ┌───┐
      └─►│ D │
         └───┘
```

**Mermaid:** No top margin; content starts at the top of the canvas.

**Root cause:** Likely `strip_common_leading_whitespace()` in `canvas.rs`
handles columns but not rows, or the canvas is allocated larger than needed
and top rows aren't trimmed.

---

## Issue 2: Source node not vertically centered among targets (LR)

**Severity:** Layout quality

In Mermaid, the source node A is vertically centered among all its targets.
In mmdflux, the source node appears at an offset that doesn't match the
visual center of the target group.

**Reproduction (3 targets):**

```
echo -e "graph LR\n A-->B\nA-->C\nA-->D" | cargo run -q
```

**mmdflux:** A is positioned between B and C (row-wise), leaving D far
below with extra vertical space.

**Mermaid:** A is centered vertically among B, C, D.

**Root cause:** This is a dagre layout issue — the Brandes-Kopf coordinate
assignment may not be centering the source optimally for horizontal layouts.

---

## Issue 3: Excessive vertical spacing between LR target nodes

**Severity:** Layout quality

Target nodes in LR fan-out have too much vertical space between them,
especially visible with 3+ targets. Mermaid packs targets tightly with
minimal vertical gap.

**Reproduction (4 targets):**

```
echo -e "graph LR\n A-->B\nA-->C\nA-->D\nA-->E" | cargo run -q
```

**mmdflux output:** 2 blank lines between each target node pair.

**Mermaid output:** Targets are tightly packed with minimal spacing.

**Root cause:** The dagre `nodesep` (node separation) for horizontal layouts
may be applying as vertical separation between same-rank nodes. The value
may be too large, or it may be using the TD-appropriate value instead of
a horizontal-layout-appropriate one.

---

## Issue 4: Backward edge passes through target node (git_workflow.mmd)

**Severity:** Rendering bug

In `git_workflow.mmd`, the "git pull" backward edge from Remote Repo to
Working Dir places a left-arrow (`◄`) to the LEFT of Working Dir's left
border character, making it appear the edge passes through the node:

```
◄│ Working Dir │
```

The arrow should connect to the node boundary, not appear outside/through it.

**Reproduction:**

```
cargo run -q -- tests/fixtures/git_workflow.mmd
```

**Full output:**
```
                  git add     ┌──────────────┐ git commit   ┌────────────┐  git push
 ┌─────────────┐      ┌──────►│ Staging Area │─────────────►│ Local Repo │──────┐       ┌─────────────┐
◄│ Working Dir │──────┘       └──────────────┘              └────────────┘      └──────►│ Remote Repo │┐
 └─────────────┘                                                                        └─────────────┘│
               └───────────────────────────────────────────────────────────────────────────────────────┘
```

The backward edge path goes: Remote Repo `┐` → down `│` → left along
bottom `└───...───┘` → but then the path doesn't have a visible vertical
segment going up from the bottom row to Working Dir. Instead, the `◄` arrow
appears at column 0, detached from the routing path.

**Root cause:** The backward edge routing for LR layouts likely computes the
target attachment on the wrong face or the path segments don't connect
properly to the target node's boundary. The arrow is rendered at the offset
position but the path doesn't reach it.

---

## Issue 5: "git push" label detached from edge (git_workflow.mmd)

**Severity:** Visual / cosmetic

The "git push" label appears above the edge path rather than along it. In the
output, "git push" is on the first line while the actual edge path connecting
Local Repo to Remote Repo is on the second line.

**Root cause:** Label placement for LR Z-shaped paths may be selecting a
position on the first horizontal segment (which is at a different y than the
label expects) rather than along the visible path.

---

## Issue 6: "git add" label detached from edge (git_workflow.mmd)

**Severity:** Visual / cosmetic

Similar to issue 5, the "git add" label appears on the first line, above the
Z-shaped edge path from Working Dir to Staging Area. The edge path itself
goes through lines 2-3.

---

## Issue 7: Backward edge path disconnected (git_workflow.mmd)

**Severity:** Rendering bug (related to Issue 4)

The backward edge from Remote Repo to Working Dir has a visible gap in its
path. The bottom segment `└───...───┘` starts at column ~15 (below Working
Dir's right side) and goes right to Remote Repo's column, but there's no
visible vertical segment connecting the bottom path up to Working Dir's
boundary. The `◄` arrow at column 0 is spatially disconnected from the
`└` corner at column 15.

The "git pull" label appears at the bottom-right of the path, which is
reasonable for the bottom segment, but the overall path is visually broken.

---

## Summary

| # | Issue | Severity | Category |
|---|-------|----------|----------|
| 1 | Growing top margin in LR fan-out | Cosmetic | Canvas |
| 2 | Source not centered among LR targets | Layout | Dagre |
| 3 | Excessive vertical spacing in LR | Layout | Dagre |
| 4 | Backward edge passes through node | Bug | Routing |
| 5 | "git push" label detached | Cosmetic | Labels |
| 6 | "git add" label detached | Cosmetic | Labels |
| 7 | Backward edge path disconnected | Bug | Routing |
