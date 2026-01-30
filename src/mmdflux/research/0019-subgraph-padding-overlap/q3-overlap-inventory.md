# Q3: Overlap and clipping inventory

## Summary

The current subgraph implementation has at least seven distinct overlap and clipping issues. The most severe are: (1) title text that extends beyond the border width is silently clipped, (2) title text overlaps with content positioned above the subgraph, (3) edges crossing subgraph borders produce corrupted border characters, and (4) multiple subgraph borders collide when subgraphs are laid out in the same column. These issues stem from the border bounds being computed purely from member-node positions without accounting for title width, external node proximity, edge routing paths, or neighboring subgraph borders.

## Where

Sources consulted:
- `/Users/kevin/src/mmdflux-subgraphs/src/render/subgraph.rs` — border rendering logic
- `/Users/kevin/src/mmdflux-subgraphs/src/render/layout.rs` — `convert_subgraph_bounds()` function (lines 696-749), canvas sizing (lines 491-497)
- `/Users/kevin/src/mmdflux-subgraphs/src/render/canvas.rs` — `set_subgraph_border()` and overwrite semantics
- `/Users/kevin/src/mmdflux-subgraphs/src/render/mod.rs` — rendering pipeline order (borders, then nodes, then edges)
- `/Users/kevin/src/mmdflux-subgraphs/src/render/router.rs` — edge routing (no subgraph-awareness)
- `/Users/kevin/src/mmdflux-subgraphs/tests/fixtures/simple_subgraph.mmd`
- `/Users/kevin/src/mmdflux-subgraphs/tests/fixtures/subgraph_edges.mmd`
- `/Users/kevin/src/mmdflux-subgraphs/tests/fixtures/multi_subgraph.mmd`
- Various constructed test inputs (listed below)

## What

### Issue 1: Title text clipped when wider than border

**Input:**
```
graph TD
subgraph sg1[This Is A Very Long Subgraph Title]
A[Start] --> B[End]
end
```

**Output:**
```
This Is A Ver
┌──────────┐
│          │
│          │
│┌───────┐ │
││ Start │ │
│└───────┘ │
│    │     │
│    │     │
│    ▼     │
│ ┌─────┐  │
│ │ End │  │
│ └─────┘  │
│          │
└──────────┘
```

The title "This Is A Very Long Subgraph Title" is truncated to "This Is A Ver" because the border width is determined solely by member node bounding boxes. The title is written character by character at `x + i` positions starting from the border's x-coordinate, but characters beyond the canvas width are silently dropped (the `canvas.set()` call returns false for out-of-bounds positions). The border width is never expanded to accommodate the title.

### Issue 2: Title text overlaps with content above the subgraph

**Input:**
```
graph TD
X[Top] --> A
subgraph sg1[Process]
A[Step1] --> B[Step2]
end
B --> Y[Bottom]
```

**Output:**
```
   ┌─────┐
   │ Top │
Pro└─────┘
┌─────│─────┐
│     │     │
│     ▼     │
│ ┌───────┐ │
│ │ Step1 │ │
│ └───────┘ │
...
```

The title "Process" is placed at `y - 1` of the border, which is the same row as the bottom border of the "Top" node above. The characters "Pro" from "Process" overwrite the left portion of `└─────┘`. The title placement does not account for whether the row above is already occupied by other content.

### Issue 3: Title text overlaps with neighboring subgraph titles

**Input:**
```
graph TD
W[External1] --> A
X[External2] --> B
subgraph sg1[GroupWithEdgesFromMultipleSides]
A[Node1]
B[Node2]
end
A --> Z[Below]
```

**Output:**
```
 ┌──────┐     ┌───────┐
 │ Left │     │ Right │
G└──────┘Edges└───────┘ple
┌────│────────────│─────┐
...
```

The title "GroupWithEdgesFromMultipleSides" prints on the same row as the node borders above. It overwrites and interleaves with those characters, producing "G" then node borders then "Edges" then node borders then "ple" — completely garbled output.

### Issue 4: Edges crossing subgraph borders corrupt border characters

**Input (subgraph_edges.mmd):**
```
graph TD
subgraph sg1[Input]
A[Data]
B[Config]
end
subgraph sg2[Output]
C[Result]
D[Log]
end
A --> C
B --> D
```

**Output:**
```
Input
┌───────────────────────┐
│                       │
│                       │
│┌────────┐    ┌──────┐ │
││ Config │    │ Data │ │
│└────────┘    └──────┘ │
│┌────│────────────│─────┐
└│────│────────────│────┘│
 │    ▼            ▼     │
 │ ┌─────┐    ┌────────┐ │
 │ │ Log │    │ Result │ │
 │ └─────┘    └────────┘ │
 │                       │
 └───────────────────────┘
```

The vertical edge lines pass through the bottom border of sg1 and the top border of sg2. Where edges cross the border, the border characters are replaced by edge characters (│). This is because edges are rendered AFTER borders, and the `set_with_connection()` method overwrites cells that are not marked `is_node`. Subgraph border cells are not protected — they have `is_subgraph_border = true` but `set_with_connection()` only checks `is_node`. The result is broken border lines with edge pipes punched through them.

Additionally, the two subgraph borders collide: sg1's bottom border and sg2's top border share or overlap rows, creating garbled combined characters.

### Issue 5: Multiple subgraph borders collide (same-column layout)

**Input:**
```
graph TD
subgraph sg1[Left Group]
A[Alpha] --> B[Beta]
end
subgraph sg2[Right Group]
C[Gamma] --> D[Delta]
end
B --> C
```

**Output:**
```
Left Group
┌──────────┐
│          │
│          │
│┌───────┐ │
││ Alpha │ │
│└───────┘ │
│    │     │
│    │     │
│    ▼     │
│┌──────┐  │
││ Beta │  │
│└──────┘up│
│────│─────│
└────│─────┘
│    ▼     │
│┌───────┐ │
││ Gamma │ │
│└───────┘ │
...
```

Two subgraphs that should appear side-by-side (or stacked with clear separation) are laid out with overlapping borders. The text "up" from "Right Group" appears inside sg1's border area. The border lines merge and overlap creating a broken visual. The bottom of sg1 and top of sg2 share the same row region, and the borders blend together into incoherent characters.

### Issue 6: Three subgraphs with chain edges produce completely garbled layout

**Input:**
```
graph TD
subgraph sg1[First]
A --> B
end
subgraph sg2[Second]
C --> D
end
subgraph sg3[Third]
E --> F
end
A --> C
C --> E
```

**Output:**
```
First
┌──────┐
│      │
│      │
│┌───┐ │
││ A │ │
│└───┘ │Second
│ │ │  │┌───────┐
│ └┐└─────┐     │
│  ▼   ││ ▼     │
│┌───┐ ││ ┌───┐ │
││ B │ ││ │ C │ │
│└───┘ ││ └───┘ │
│──────││  │ │  │
└──┌──────┬┴─┘  │
│  ▼   ││ ▼     │
│┌───┐ ││ ┌───┐ │
││ E │ ││ │ D │ │
│└───┘ ││ └───┘ │
│  │   ││       │
│  │   │└───────┘
│  ▼   │
│┌───┐ │
││ F │ │
│└───┘ │
│      │
└──────┘
```

All three subgraphs' borders overlap and interleave. The border characters from sg1, sg2, and sg3 share columns, and edge routing characters mix with border characters. "Second" title text appears mid-way through sg1's border. The layout has not separated the subgraphs horizontally — they are partially overlapping in the same x-coordinate region.

### Issue 7: Backward edge routing inside subgraph escapes the border

**Input:**
```
graph TD
subgraph sg1[Group]
A[Node] --> B[Node2]
B --> A
end
```

**Output:**
```
Group
┌──────────┐
│          │
│          │
│┌──────┐  │
││ Node │◄──┐
│└──────┘  ││
│    │     ││
│    │     ││
│    ▼     ││
│┌───────┐ ││
││ Node2 │──┘
│└───────┘ │
│          │
└──────────┘
```

The backward edge from B to A routes to the right of both nodes, and its path (the `──┐` and `││` segments) extends beyond the right border of the subgraph. The edge path at x-coordinates past the border's right wall draws outside the enclosed area, breaking the visual containment that a subgraph border should provide.

### Issue 8: LR subgraph titles are missing

**Input (multi_subgraph.mmd):**
```
graph LR
subgraph sg1[Frontend]
A[UI] --> B[API]
end
subgraph sg2[Backend]
C[Server] --> D[DB]
end
B --> C
```

**Output:**
```
┌──────────────────────┐ ┌───────────────────────┐
│ ┌────┐       ┌─────┐ │ │ ┌────────┐     ┌────┐ │
│ │ UI │──────►│ API │────►│ Server │────►│ DB │ │
│ └────┘       └─────┘ │ │ └────────┘     └────┘ │
│                      │ │                       │
└──────────────────────┘ └───────────────────────┘
```

The titles "Frontend" and "Backend" are completely absent. This is because the title is rendered at `y - 1` of the border, but when the border starts at `y = 0`, the condition `if y > 0` prevents title rendering entirely. The canvas has no row above the top border to place the title.

### Issue 9: LR layout cross-edge passes through subgraph border

In the same LR multi_subgraph output above, the edge from API to Server passes through sg1's right border and sg2's left border. The `────►` segment overwrites the border characters. The edge `│` at the column of the border simply replaces the border's `│` — in this case it looks correct by coincidence (both are `│`), but the edge from API exits through the border wall rather than routing around or through a gap.

### Issue 10: Single-node subgraphs with cross-edge have overlapping borders

**Input:**
```
graph TD
subgraph sg1[A Group]
A[X]
end
subgraph sg2[B Group]
B[Y]
end
A --> B
```

**Output:**
```
A Group
┌──────┐
│      │
│      │
│┌───┐ │
││ X │ │
B└───┘p│
┌──│───┐
│──│───│
│  ▼   │
│┌───┐ │
││ Y │ │
│└───┘ │
│      │
└──────┘
```

The title "B Group" is rendered at `y - 1` of sg2's border, which overlaps with the bottom border of sg1. The characters "B" and "p" from "B Group" overwrite sg1's border characters. The middle characters are lost. The two subgraph borders have no gap between them, so they collide directly.

## How

Each issue manifests due to specific rendering pipeline deficiencies:

1. **Title clipping (Issues 1, 3, 8, 10):** `convert_subgraph_bounds()` computes border width solely from member-node bounding boxes plus a fixed 2-cell padding. It never considers `title.len()`. Titles wider than the border are simply clipped when writing to the canvas. When `y == 0`, titles are skipped entirely.

2. **Title-content collision (Issues 2, 3, 10):** The title is placed at `y - 1` unconditionally (when `y > 0`), but there is no reserved row for the title in the layout. The `convert_subgraph_bounds()` function uses `title_height = 1` when computing `border_y = min_y.saturating_sub(border_padding + title_height)`, but this only affects where the border top is drawn — it does not push external nodes further away. External nodes above the subgraph can occupy the exact row where the title will be rendered.

3. **Edge-border collision (Issues 4, 7, 9):** Edge routing (`router.rs`) has no awareness of subgraph borders. It routes edges purely based on node positions and waypoints. When an edge path crosses a subgraph border, the edge rendering overwrites border cells because `set_with_connection()` only protects `is_node` cells, not `is_subgraph_border` cells. Subgraph borders are intentionally not protected (designed to be background), but this means edges punch holes through them.

4. **Border-border collision (Issues 4, 5, 6, 10):** `convert_subgraph_bounds()` computes each subgraph's border independently from member-node positions. There is no inter-subgraph spacing or collision detection. When dagre places member nodes of different subgraphs close together, their borders overlap. The layout engine's `collision_repair()` and `rank_gap_repair()` only operate on nodes, not on subgraph borders.

## Why

Root causes:

1. **No title-width-aware sizing:** `convert_subgraph_bounds()` at line 705 uses a fixed `border_padding = 2` and computes width from `max_x - min_x + 2 * border_padding`. The title string length is never compared against this width. The fix would be to widen the border to `max(node_extent_width, title.len() + margin)`.

2. **No inter-subgraph gap enforcement:** The dagre compound layout assigns positions to subgraph compound nodes, but `convert_subgraph_bounds()` ignores dagre's subgraph positioning (the `_dagre_bounds` parameter is prefixed with underscore — unused). Instead, it recomputes bounds from member node draw positions. This means dagre's inter-subgraph spacing is lost. Subgraphs can end up abutting or overlapping because only member-node collision repair is applied.

3. **No subgraph-aware edge routing:** The edge router treats the canvas as a flat space of nodes and empty space. It has no concept of "subgraph border regions" that edges should avoid or pass through at designated crossing points. Edges that connect nodes inside a subgraph to nodes outside simply draw straight through the border.

4. **Z-order without gap reservation:** The rendering pipeline draws borders first (background), then nodes, then edges. This z-order is correct conceptually, but because no space is reserved for borders during the layout phase, edges and adjacent content inevitably overlap with borders. The border padding of 2 cells only provides internal spacing between member nodes and the border — it does not reserve space on the outside of the border.

5. **Title row not integrated into layout:** The title occupies one row above the border (`y - 1`), but this row is not reserved during layout computation. When the subgraph is at the top of the canvas (`y = 0`), the title is simply not rendered. When there are external nodes above, the title collides with them because the layout engine does not know about the title row.

## Key Takeaways

- The most critical fix is **inter-subgraph collision avoidance** — without it, multiple subgraphs produce completely broken output (Issues 5, 6, 10). This likely requires using dagre's compound-node bounding boxes rather than recomputing bounds from member nodes.
- **Title width must be factored into border width** calculation. The current code ignores title length entirely.
- **Title placement needs a reserved row** in the layout — either as additional padding above the border or by integrating the title row into the subgraph's layout footprint so that `rank_gap_repair()` avoids the title.
- **Edge routing through subgraph borders** is a fundamental architectural gap. A minimal fix would be to make edges visually "cross" borders cleanly (e.g., create gaps in the border at crossing points). A more thorough fix would route edges to exit/enter subgraphs at designated ports.
- The **backward-edge synthetic routing** does not account for subgraph boundaries at all, causing edges to escape their enclosing subgraph (Issue 7).
- The **`_dagre_bounds` parameter is unused** in `convert_subgraph_bounds()`, suggesting the dagre compound layout's sizing output is being discarded. Leveraging this data could fix multiple issues simultaneously.

## Open Questions

- Should edges that cross subgraph borders create explicit gaps in the border line (like a door), or should they route around to exit at the top/bottom of the subgraph?
- Is it feasible to make the dagre compound layout compute inter-subgraph spacing directly, or does the post-hoc `convert_subgraph_bounds()` approach need its own collision pass?
- How should backward edges inside a subgraph be contained? Should the backward route gap extend the subgraph border, or should the route be constrained to stay within the border?
- Should titles be rendered inside the top border (e.g., embedded in the top border line like `┌─ Title ─┐`) rather than above it, to avoid the y=0 clipping problem and reduce vertical space?
- What is the interaction between subgraph padding and the existing `left_label_margin` / `right_label_margin` configuration? Do labeled edges inside subgraphs need additional border width?
