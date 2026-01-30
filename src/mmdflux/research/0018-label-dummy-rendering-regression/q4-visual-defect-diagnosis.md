# Q4: What specifically causes the visual corruption in the labeled_edges.mmd output?

## Summary
The label-dummy branch introduces four distinct visual defects when rendering `labeled_edges.mmd`: (1) diamond node text garbled as "Val**triangle**d?" due to a backward-edge arrow overwriting a node cell, (2) massive vertical expansion from extra label-dummy ranks inflating inter-node spacing, (3) phantom vertical columns from a backward edge routed as a straight vertical strip instead of a curve, and (4) edge misalignment from waypoints creating unnecessary horizontal jogs. All defects trace to the label-dummy normalization inserting extra ranks that inflate the layout, combined with the rendering pipeline not properly handling the resulting coordinate distortions.

## Where
- `~/src/mmdflux-label-dummy/tests/fixtures/labeled_edges.mmd` -- test fixture
- `~/src/mmdflux-label-dummy/src/dagre/mod.rs` -- `layout_with_labels()`, `make_space_for_edge_labels()`
- `~/src/mmdflux-label-dummy/src/dagre/normalize.rs` -- `run()`, label dummy insertion
- `~/src/mmdflux-label-dummy/src/render/layout.rs` -- `compute_layout_direct()`, `transform_waypoints_direct()`
- `~/src/mmdflux-label-dummy/src/render/mod.rs` -- `render()`, rendering order (nodes then edges)
- `~/src/mmdflux-label-dummy/src/render/edge.rs` -- `render_all_edges_with_labels()`, `draw_label_at_position()`
- `~/src/mmdflux-label-dummy/src/render/router.rs` -- `route_edge()`, `route_edge_with_waypoints()`
- `~/src/mmdflux/` -- main branch for correct output comparison

## What

### Defect 1: Diamond text corruption ("Val**triangle**d?" instead of "Valid?")

**Type: Rendering issue (z-order / edge-overwrites-node)**

The Config diamond node renders as `< Val▲d? >` instead of `< Valid? >`. The `▲` (up-arrow) character replaces the `i` in "Valid?".

The `▲` is the arrow drawn for the backward edge (Error --> Setup, the "retry" edge). In the label-dummy branch, this backward edge is routed through dagre waypoints that place a vertical path running straight through the column where the diamond's text sits. When the edge arrow is drawn at a position that overlaps the diamond node, it overwrites the `i` character.

**Root cause**: The rendering pipeline draws nodes first (Step 3 in `render()`), then edges (Step 4). Edge arrows are drawn with `canvas.set()` which unconditionally overwrites any existing character, including node content. The `render_node()` function calls `canvas.mark_as_node()` to protect node cells, but `draw_arrow_with_entry()` uses `canvas.set()` directly (not `set_with_connection()`), bypassing the node-cell protection.

On the main branch, this doesn't happen because the backward edge is routed around the right side of the diagram (synthetic waypoints), so its arrow never overlaps a node cell. On the label-dummy branch, the backward edge goes through dagre normalization and gets waypoints that route it through node territory.

### Defect 2: Massive vertical expansion (53 lines vs 29 lines)

**Type: Layout issue (extra ranks from label dummies)**

The label-dummy output is 53 lines tall (excluding build output). The main branch output is 29 lines tall. This is an 83% increase.

**Root cause**: `make_space_for_edge_labels()` sets `minlen=2` for every labeled edge. In `labeled_edges.mmd`, there are 5 edges and 5 have labels: "initialize", "configure", "yes", "no", "retry". Each labeled edge gets `minlen=2`, doubling the number of ranks between connected nodes. This inflates the total rank count. In the main branch, all edges span 1 rank; in the label-dummy branch, each labeled edge spans 2 ranks with a label dummy at the intermediate rank.

With 5 labeled edges all getting `minlen=2`, the layout goes from ~5 ranks to ~9+ ranks. Each extra rank adds roughly `v_spacing + node_height` rows (3 + 3 = 6 rows each), accounting for the dramatic vertical expansion.

Additionally, the layer grouping in `compute_layout_direct()` Phase B groups nodes by their dagre primary-axis coordinate with a 25.0 tolerance. The extra label-dummy ranks push real nodes further apart in dagre space, creating more distinct layers and more inter-layer gaps.

### Defect 3: Phantom vertical columns (right-side "wall")

**Type: Layout + rendering issue (backward edge as vertical column)**

The right side of the label-dummy output has two persistent vertical lines (`│`) running from line 3 to line 53, forming a rectangular "wall" structure:

```
     │            │        ┌───────┐
     │     ┌───────┐       │       │
     │     │ Begin │       │       │
     ...
     │      │   │ │     │  │       │
```

This structure does not exist in the main branch output.

**Root cause**: The backward edge (Error --> Setup, "retry") is being routed through dagre waypoints instead of synthetic waypoints. Because the backward edge was normalized (it spans multiple ranks due to `minlen=2` plus the reversed direction), it has dagre-assigned waypoints. These waypoints create a path that runs as a tall vertical column on the right side of the diagram.

In the main branch, backward edges without dagre waypoints get synthetic waypoints from `generate_backward_waypoints()`, which routes them compactly around the right side of the source/target nodes. In the label-dummy branch, the backward edge gets dagre waypoints from normalization, and these waypoints create a path that spans the full height of the diagram because the edge connects nodes that are now many ranks apart.

The `┌───────┐` / `│       │` structure at the far right is the backward edge's path rendered as a vertical rectangle. The edge enters from the bottom of the diagram, goes up the right side, and connects back to Setup at the top.

### Defect 4: Edge misalignment and unnecessary horizontal jogs

**Type: Layout issue (waypoint-induced Z-paths)**

Forward edges that were straight vertical lines in the main branch now have unnecessary horizontal jogs. For example, the Start --> Setup edge ("initialize") shows:

```
     │          └─┼──┐     │       │
     │            │  │     │       │
     ...
     │    initialize │     │       │
     ...
     │            │▲─┤     │       │
```

Instead of the main branch's clean straight-down path:

```
              │
              │
   initialize │
              │
              ▼
```

**Root cause**: With `minlen=2`, the Start-->Setup edge now spans 2 ranks (with a label dummy at the intermediate rank). The label dummy gets its own x-position from the BK coordinate assignment algorithm, which may differ from Start's and Setup's x-positions. This creates waypoints at a different x-coordinate, forcing the edge router to create Z-shaped paths (V-H-V) through the waypoint instead of a straight vertical line.

In the main branch, Start-->Setup is a single-rank-span edge with no waypoints, so it routes as a straight vertical line between the two nodes' centers.

## How

### Main branch output (correct, 29 lines):
```
          ┌───────┐
          │ Begin │
          └───────┘
              │
              │
   initialize │
              │
              ▼
          ┌───────┐
          │ Setup │
          └───────┘
           │     ▲
 configure │     │
      ┌────┘     └─────┐
      │                │
      ▼                │
┌────────┐             │
< Valid? >           retry
└────────┘             │
 │      │              │
 │ yes  │              │
 └───┐  └───no─────┐   │
     │             │   │
     ▼             ▼   └────────┐
┌─────────┐       ┌──────────────┐
│ Execute │       │ Handle Error │
└─────────┘       └──────────────┘
```

### Label-dummy branch output (defective, 51 lines):
```
     │            │        ┌───────┐
     │     ┌───────┐       │       │
     │     │ Begin │       │       │
     │     └───────┘       │       │
     │          └─┼──┐     │       │
     │            │  │     │       │
     │            │  │     │       │
     │            │  │     │       │
     │            │  │     │       │
     │            │  │     │       │
     │    initialize │     │       │
     │            │  │     │       │
     │            │  │     │       │
     │            │  │     │       │
     │            │  │     │       │
     │            │  │     │       │
     │            │▲─┤     │       │
     │     ┌───────┐ │     │       │
     │     │ Setup │       │       │
     │     └───────┘       │       │
     │      ┌──┘▲ │        │       │
     │      │   │ │        │       │
     │      │   │ │        │       │
     │      │   │ ├─────┐  │       │
     │      │   │ │     │  │       │
     │      │   │ │     │  │       │
    configure   │ │     │  │       │
     │      │   │ │     │  │       │
     │      │   │ │     │  │       │
     │      │   │ │     │  │       │
     │      │   │ │     │  │       │
     │      │   │ │     │  │       │
     │      │   │ │     │  │       │
   ┌────────┐   │ │     │  │       │
   < Val▲d? >───┴─┴─────┼retry─────┤
   └────────┘           │  │       │
     │  │   │           │  │       │
     │  │   │           │  │       │
     │  │   │           │  │       │
     │  │   │           │  │       │
     │  │   │           │  │       │
     │  └───┤           │  │       │
    yes     │    no     │  │       │
     │      │           │  │       │
     │      │           │  │       │
     │      │           │  │       │
     │      │           │  │       │
     ▼      │           ▼──┘       │
┌─────────┐ │     ┌──────────────┐ │
│ Execute │       │ Handle Error │
└─────────┘       └──────────────┘
```

Key observable defects:
1. Line 37: `< Val▲d? >` -- up-arrow overwrites `i` in "Valid?"
2. Lines 3-53: diagram is 51 lines instead of 27, with excessive spacing between nodes
3. Lines 3-53 right side: `│       │` -- persistent vertical columns from backward edge
4. Lines 5-17: Start-->Setup edge has horizontal jog (`└─┼──┐`) instead of straight vertical

## Why

### Root cause chain:

1. **`make_space_for_edge_labels()`** sets `minlen=2` for ALL labeled edges (5 of 5 edges in this diagram). This doubles the rank span of every edge.

2. **`normalize::run()`** inserts label dummies at intermediate ranks for each labeled edge. This means every single-rank edge now has a dummy node at an intermediate rank.

3. **Rank inflation**: With all edges having `minlen=2`, the total rank count roughly doubles. The 4-layer diagram (Start, Setup, Config, Run/Error) becomes an 8+ layer diagram with intermediate label-dummy ranks.

4. **BK coordinate assignment** places label dummies at x-positions that may differ from the connected real nodes, because label dummies have non-zero width (label text length + 2) and participate in the BK alignment algorithm as independent nodes.

5. **Waypoint generation**: `denormalize()` extracts waypoints from dummy node positions. These waypoints have x-coordinates determined by BK, which may not align with the source/target nodes.

6. **Edge routing**: `route_edge_with_waypoints()` builds Z-shaped orthogonal paths through waypoints. If a waypoint x differs from source/target x, the path gets horizontal jogs.

7. **Backward edge routing**: The backward edge (Error-->Setup, "retry") now has dagre waypoints from normalization (because it spans multiple ranks after reversal + minlen inflation). This prevents the synthetic waypoint path (which would route compactly around the right side). Instead, the edge is routed through dagre waypoints that create a tall vertical column.

8. **Arrow overwrite**: The backward edge's arrow (`▲`) is rendered at a position inside the Config diamond node because the dagre waypoints route the edge through that area. `draw_arrow_with_entry()` uses `canvas.set()` which doesn't check `is_node`, so it overwrites the diamond's text character.

## Key Takeaways
- The label-dummy approach inflates rank count proportionally to the number of labeled edges. In diagrams where most edges have labels (like labeled_edges.mmd with 5/5), this roughly doubles the diagram height.
- Backward edges are particularly problematic because normalization assigns them dagre waypoints, preventing the compact synthetic routing that the main branch uses. The dagre waypoints span the full inflated rank range.
- The arrow rendering has a z-order bug: `draw_arrow_with_entry()` unconditionally overwrites cells, including node content. This is latent in the main branch but only manifests when edge paths cross node territories (which the label-dummy approach enables).
- Label dummy x-coordinates from BK don't necessarily align with the source/target nodes, creating unnecessary horizontal jogs on edges that should be straight.
- The `minlen=2` approach is too aggressive for edges that already span 1 rank -- it doubles every gap regardless of whether the label actually needs dedicated space.

## Open Questions
- Could `minlen=2` be applied selectively (e.g., only for edges where the label won't fit in the existing gap)?
- Should backward edges be excluded from label-dummy normalization and continue using synthetic waypoints?
- Should `draw_arrow_with_entry()` check `is_node` before writing, similar to how `draw_label_at_position()` does?
- Would a post-normalization pass to align label dummy x-coordinates with their parent edge's source/target nodes reduce the horizontal jog problem?
- Is the label-dummy approach fundamentally incompatible with diagrams that have many labeled edges, or can the rank inflation be mitigated?
