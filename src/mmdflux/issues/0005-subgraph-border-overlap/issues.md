# Issue 01: Subgraph borders overlap when cross-subgraph edges force vertical stacking

**Severity:** High
**Category:** Compound layout — inter-subgraph spacing
**Status:** Open
**Affected fixtures:** `subgraph_edges.mmd`
**Source finding:** `plans/0026-subgraph-padding-overlap/findings/dagre-to-draw-coordinate-mismatch.md`

## Description

When two subgraphs have cross-subgraph edges (e.g., `A --> C` where A is in sg1 and C is in sg2), dagre's ranking forces them onto different layers (sg1 at rank 0, sg2 at rank 1). The subgraph borders should stack vertically with a gap between them. Instead, sg1's bottom border and sg2's top border collide — sg2's embedded title overwrites sg1's bottom border, producing garbled output.

Current rendering of `subgraph_edges.mmd`:

```
┌─ Input ───────────────┐
│                       │
│┌────────┐    ┌──────┐ │
││ Config │    │ Data │ │
│└────────┘    └──────┘ │
│     │            │    │
└┌─ Ou│put ────────┼─────┐
 │    ▼            ▼     │
 │ ┌─────┐    ┌────────┐ │
 │ │ Log │    │ Result │ │
 │ └─────┘    └────────┘ │
 │                       │
 └───────────────────────┘
```

Line 7 shows the collision: `└┌─ Ou│put ────────┼─────┐` — sg1's bottom-left corner `└`, sg2's top-left corner `┌`, and the title "Output" all render on the same row, interleaved with edge pipes from the cross-subgraph edges.

## Reproduction

```bash
echo 'graph TD
subgraph sg1[Input]
A[Data]
B[Config]
end
subgraph sg2[Output]
C[Result]
D[Log]
end
A --> C
B --> D' | cargo run
```

## Expected behavior

The two subgraph borders should be fully separated with a gap between them, like:

```
┌─ Input ───────────────┐
│                       │
│┌────────┐    ┌──────┐ │
││ Config │    │ Data │ │
│└────────┘    └──────┘ │
│     │            │    │
└─────┼────────────┼────┘
      │            │
 ┌─ Ou┼put ────────┼─────┐
 │    ▼            ▼     │
 │ ┌─────┐    ┌────────┐ │
 │ │ Log │    │ Result │ │
 │ └─────┘    └────────┘ │
 │                       │
 └───────────────────────┘
```

Or ideally, with clean edge-border crossings using junction characters.

## Root cause hypothesis

`convert_subgraph_bounds()` computes each subgraph's border independently from its member-node draw positions with a fixed 2-cell `border_padding`. There is no inter-subgraph collision detection or spacing enforcement.

The dagre compound layout *does* guarantee non-overlapping subgraph bounds (via border nodes, nesting edges, and subgraph ordering constraints — see Research section below), but mmdflux cannot currently use those dagre bounds because of a coordinate frame mismatch between dagre space and draw space (documented in the finding linked above). The node draw position formula uses a right-edge offset + overhang correction that differs from the linear `to_ascii()` transformation, so transforming dagre Rects via `to_ascii()` produces incorrect screen positions.

With the dagre bounds unusable, the member-node fallback has no awareness of neighboring subgraphs. When dagre places sg1's nodes at ranks 0 and sg2's nodes at rank 1, the gap between node rows may be smaller than the combined border padding of both subgraphs (2 cells bottom padding for sg1 + 2 cells top padding for sg2 = 4 cells needed, but rank spacing may only provide 2-3 cells).

### Why this is hard to fix

There are two possible approaches, each with challenges:

1. **Fix the dagre-to-draw coordinate transformation** so that dagre Rects can be used directly. This requires making `convert_subgraph_bounds()` use the same formula as node positions (right-edge offset + overhang correction) rather than `to_ascii()`. The dagre compound layout already guarantees non-overlapping bounds, so if the transformation were correct, borders would not overlap.

2. **Add post-hoc collision detection** to the member-node fallback path. After computing all subgraph bounds from member-node positions, scan for overlapping borders and push them apart. This is more fragile than using dagre's built-in guarantees.

Approach 1 is the better fix but requires understanding and replicating the node position formula for subgraph Rects.

## How dagre.js and Mermaid handle this

### dagre.js compound layout

Dagre guarantees non-overlapping sibling subgraph bounds through three mechanisms:

1. **Border nodes as physical constraints.** For each compound node, dagre creates zero-width, zero-height border dummy nodes (top/bottom from `nesting-graph.js` lines 63-70, left/right from `add-border-segments.js` lines 16-21). Since these are real nodes in the layout graph, the Sugiyama algorithms place them without overlap.

2. **High-weight nesting edges.** The nesting graph creates weighted edges from a compound's top border to each child's top, and from each child's bottom to the compound's bottom (`nesting-graph.js` lines 81-91, weight = `sumWeights(g) + 1`). This guarantees children are ranked between their parent's border ranks.

3. **Subgraph ordering constraints.** `add-subgraph-constraints.js` (lines 3-27) adds constraints between sibling subgraphs, preventing horizontal interleaving at the same rank.

After positioning, `removeBorderNodes()` in `layout.js` (lines 309-330) derives compound dimensions from border node positions:
```javascript
node.width = Math.abs(r.x - l.x);
node.height = Math.abs(b.y - t.y);
```

These derived bounds are non-overlapping because the border nodes were laid out without overlap.

### Mermaid post-processing

Mermaid applies additional post-dagre adjustments:
- Shifts cluster nodes by `subGraphTitleTotalMargin` to make room for labels
- Uses `updateNodeBounds()` to measure actual SVG bounding boxes after rendering
- Redirects edges targeting cluster IDs to internal anchor nodes

### mmdflux gap

mmdflux implements the border node pipeline (via `border.rs`), and dagre's `remove_nodes()` returns valid compound bounding Rects. However, the coordinate transformation to draw space is broken (see finding above), so these bounds are currently unused. The member-node fallback computes bounds independently per subgraph with no inter-subgraph awareness.

## Cross-References

- **Plan 0026:** `plans/0026-subgraph-padding-overlap/` — Phase 1 attempted dagre bounds, reverted due to coordinate mismatch
- **Finding:** `plans/0026-subgraph-padding-overlap/findings/dagre-to-draw-coordinate-mismatch.md`
- **Research 0019:** `research/0019-subgraph-padding-overlap/` — Q3 overlap inventory (this is Issue 4/5), Q4 dagre.js compound sizing, Q5 Mermaid rendering
- **Research 0016:** `research/0016-compound-graph-subgraphs/synthesis.md` — compound graph architecture
- **dagre.js source:** `/Users/kevin/src/dagre/lib/` — `nesting-graph.js`, `add-border-segments.js`, `order/add-subgraph-constraints.js`, `layout.js` (removeBorderNodes)
