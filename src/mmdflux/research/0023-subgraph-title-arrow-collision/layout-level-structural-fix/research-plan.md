# Research: Layout-Level Structural Fix for Title-Arrow Collision

## Status: SYNTHESIZED

---

## Goal

Design and validate the approach for inserting a "title rank" into dagre's nesting system so that subgraph titles have guaranteed vertical space, preventing collisions with edge segments by construction.

## Context

Parent research (`research/0023-subgraph-title-arrow-collision/`) identified that subgraph titles embedded in the top border row can block edge junctions. The recommended structural fix is to add a title dummy node during `nesting::run()` that reserves a rank between `border_top` and the first child node. This creates physical separation in the layout graph.

The dagre compound-node system uses border_top/border_bottom dummy nodes with high-weight nesting edges to constrain children between parent boundaries. Adding a title node follows this existing pattern:
- `border_top -> title_dummy -> children -> border_bottom`

Key dagre pipeline: `nesting::run() -> rank::run() -> nesting::cleanup() -> nesting::assign_rank_minmax() -> normalize::run() -> border::add_segments() -> order::run() -> position::run() -> border::remove_nodes()`

## Questions

### Q1: How should the title dummy node be created and connected in nesting::run()?

**Where:** `src/dagre/nesting.rs`, `src/dagre/graph.rs`
**What:** Determine the exact insertion point, node ID pattern, edge weight strategy, and parent relationship. Should the title dummy connect to all children or just to border_top? How does it interact with `nesting::cleanup()` and `assign_rank_minmax()`?
**How:** Read `nesting.rs` in detail. Trace the existing border_top/border_bottom creation. Design the title node insertion to mirror that pattern. Verify that `cleanup()` handles the new edges correctly (they should be marked as nesting edges). Check that `assign_rank_minmax()` still computes correct min/max ranks.
**Why:** This is the core change. Getting the nesting edges wrong would break rank assignment for the entire subgraph.

**Output file:** `q1-nesting-insertion.md`

---

### Q2: How does the title rank affect border segment creation and ordering constraints?

**Where:** `src/dagre/border.rs`, `src/dagre/order.rs`
**What:** After ranking, `border::add_segments()` creates left/right border nodes at each rank in [min_rank, max_rank]. The title rank will be included in this range. Does the title dummy need left/right borders? How does `apply_compound_constraints()` in ordering handle the title rank? Should the title node be treated as a border node or a regular child?
**How:** Read `border.rs` `add_segments()` and `order.rs` `apply_compound_constraints()`. Trace what happens when a rank contains only a zero-dimension dummy (the title node). Verify ordering constraints maintain the title node's position at the top of the subgraph.
**Why:** Border segments and ordering constraints maintain the visual structure of compound nodes. If the title rank breaks these, the entire subgraph layout could be wrong.

**Output file:** `q2-border-ordering-impact.md`

---

### Q3: How does the title rank affect coordinate assignment (BK/position)?

**Where:** `src/dagre/position.rs`, `src/dagre/bk.rs`
**What:** The title dummy node has zero dimensions. How does Brandes-Kopf handle zero-dimension nodes? Does the title rank create additional inter-rank spacing? How does the vertical spacing between the title rank and the first content rank compare to normal inter-rank spacing? Is the spacing configurable?
**How:** Read `position.rs` and `bk.rs` to understand how inter-rank distance is computed. Check whether zero-dimension nodes at a rank affect the rank's height calculation. Trace the coordinate assignment for a compound node with an extra rank.
**Why:** We need the title rank to create exactly enough space for the title text without excessive gaps. Understanding the spacing mechanics tells us whether we need to adjust rank separation or node dimensions.

**Output file:** `q3-coordinate-assignment.md`

---

### Q4: How does border::remove_nodes() extract subgraph bounds, and what changes for the title rank?

**Where:** `src/dagre/border.rs` (`remove_nodes()`), `src/render/layout.rs` (`convert_subgraph_bounds()`)
**What:** After positioning, `remove_nodes()` extracts the bounding box from border node positions. The title rank adds an extra row at the top. Does `remove_nodes()` need to account for this? Does `convert_subgraph_bounds()` need changes? How does the extra rank affect the y-coordinate of the subgraph top border?
**How:** Read `remove_nodes()` to see how it computes compound node dimensions. The title node's position becomes the new top-of-content. Check whether the current border padding in `convert_subgraph_bounds()` still makes sense with the extra rank.
**Why:** The final output of dagre is node positions and compound bounding boxes. If the title rank changes these dimensions, the render layer's subgraph bounds computation must adapt.

**Output file:** `q4-bounds-extraction.md`

---

### Q5: What are the implications for cross-subgraph edges that span the title rank?

**Where:** `src/dagre/normalize.rs`, `src/render/router.rs`, `src/render/layout.rs`
**What:** Cross-subgraph edges (e.g., A->C in subgraph_edges.mmd) span from outside the subgraph to inside. If the title rank is between border_top and the first content rank, do long edges get an extra dummy node at the title rank? Does this affect edge routing or waypoint computation? Could the title dummy node interfere with edge normalization?
**How:** Trace what happens when a cross-subgraph edge is normalized. Check if dummy nodes are created at the title rank. If so, do they need special handling? Read `denormalize()` to see how waypoints are extracted from dummy positions.
**Why:** Cross-subgraph edges are the exact scenario that triggers the collision. If the title rank changes how these edges are routed, we need to understand the impact to ensure they still connect correctly.

**Output file:** `q5-cross-subgraph-edges.md`

---

## Sources

| Source | Location | Used by |
|--------|----------|---------|
| dagre nesting | `src/dagre/nesting.rs` | Q1, Q2 |
| dagre graph types | `src/dagre/graph.rs` | Q1, Q2, Q3 |
| dagre ranking | `src/dagre/rank.rs` | Q1 |
| dagre border segments | `src/dagre/border.rs` | Q2, Q4 |
| dagre ordering | `src/dagre/order.rs` | Q2 |
| dagre positioning | `src/dagre/position.rs`, `src/dagre/bk.rs` | Q3 |
| dagre normalization | `src/dagre/normalize.rs` | Q5 |
| dagre pipeline | `src/dagre/mod.rs` | All |
| render layout | `src/render/layout.rs` | Q4, Q5 |
| render router | `src/render/router.rs` | Q5 |
| parent research | `research/0023-subgraph-title-arrow-collision/` | Context |

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-nesting-insertion.md` | Q1: Title node in nesting::run() | Complete |
| `q2-border-ordering-impact.md` | Q2: Border segments and ordering | Complete |
| `q3-coordinate-assignment.md` | Q3: BK/position coordinate effects | Complete |
| `q4-bounds-extraction.md` | Q4: Subgraph bounds extraction | Complete |
| `q5-cross-subgraph-edges.md` | Q5: Cross-subgraph edge impact | Complete |
| `synthesis.md` | Combined findings and implementation design | Complete |
