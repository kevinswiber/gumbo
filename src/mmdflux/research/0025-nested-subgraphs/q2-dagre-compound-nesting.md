# Q2: Dagre Layout for Multi-Level Compound Nesting

## Summary

The dagre compound graph infrastructure **partially supports** multi-level nesting when parent relationships are properly set. The nesting algorithm (border/title node creation) works recursively at the `LayoutGraph` level because it operates on indices rather than IDs. However, the `from_digraph()` conversion and nesting edge setup were not designed for nested subgraphs: (1) `from_digraph()` only marks direct parents as compounds, skipping subgraph-to-subgraph relationships, and (2) the nesting root only connects to top-level compounds, not nested ones. The layout phases (rank, order, position) should handle nesting transparently once edges are correct, but the initial setup breaks for multi-level cases.

## Where

**Files consulted with line numbers:**
- `src/dagre/nesting.rs` lines 18-79 (run function), 41-48 (child discovery), 64-78 (root connection)
- `src/dagre/graph.rs` lines 277-286 (from_digraph compound setup), 188-189 (parents vec structure)
- `src/dagre/mod.rs` lines 93-149 (layout pipeline, compound handling)
- `src/render/layout.rs` lines 146-157 (subgraph compound node setup)

## What

**Current behavior for multi-level nesting:**

1. **Parent relationship discovery** (`nesting.rs:42-48`): For each compound node, `nesting::run()` iterates the `parents` vec and collects all nodes where `parents[i] == Some(compound_idx)`. This correctly finds **direct children only**. For nested subgraphs, if `parents[child_sg_idx] = Some(parent_sg_idx)` is set, the algorithm should discover this relationship and create nesting edges between the compounds.

2. **Nesting root connection** (`nesting.rs:64-78`): The root connects to:
   - All top-level nodes: those with `parents[i].is_none() && !compound_nodes.contains(i)` (line 67)
   - All compound nodes' border_tops (line 73-78)

   For nested compounds, inner compounds have parents, so they're not connected to the root directly. But their border_top nodes still get connected to the root (line 75), which is incorrect for deeply nested hierarchies—the border_top of inner_sg should connect to parent_sg's nesting edges, not the global root.

3. **from_digraph compound setup** (`graph.rs:277-286`): The conversion builds the parent index from DiGraph's parent map. It correctly marks all nodes with children as compounds (`compound_nodes.insert(parent_idx)` at line 285). If the DiGraph has `set_parent(child_sg_id, parent_sg_id)` called for nested relationships, this propagates correctly to the LayoutGraph's `parents` vec and `compound_nodes` set. This part works correctly for arbitrary nesting depth.

4. **Nesting edges creation** (`nesting.rs:50-56`): For each compound, nesting edges are added: `border_top -> child` and `child -> border_bottom` with high weight. These constrain ranking so children stay between borders. For nested compounds:
   - If sg2 is a child of sg1, nesting edges are created for both: `sg1_border_top -> sg2` and `sg2_border_top -> C,D` (sg2's members)
   - The edges stack correctly

5. **Border segments** (`border.rs:17-65`): After ranking, left/right border nodes are added for each compound at each rank in its span. For nested compounds, **the critical issue**: if sg1 contains sg2, sg1's bounds must include sg2's bounds. Currently, `border::remove_nodes()` (lines 71-129) extracts bounds from positioned border nodes, but this only includes direct borders. Nested subgraph bounds aren't automatically included.

**Trace through nested example:**
```
Given: sg2 (with nodes C, D) is a child of sg1 (with no direct nodes)

After from_digraph:
  parents[C] = Some(sg2_idx)
  parents[D] = Some(sg2_idx)
  parents[sg2] = Some(sg1_idx)
  compound_nodes = {sg1_idx, sg2_idx}

In nesting::run():
  - Process sg1: children = [sg2]
    Create border_top_sg1, border_bottom_sg1
    Add nesting edges: border_top_sg1 -> sg2, sg2 -> border_bottom_sg1
  - Process sg2: children = [C, D]
    Create border_top_sg2, border_bottom_sg2
    Add nesting edges: border_top_sg2 -> C, C -> border_bottom_sg2, etc.
  - Root connects to border_top_sg1 (sg1 is top-level)

After ranking: sg1 spans ranks R_min to R_max, sg2 spans a subrange
After positioning: sg2's border nodes are positioned inside sg1's border nodes
```

This produces correct rank constraints. The issue is in bounds computation and rendering.

## How

**What works without changes:**

1. If `set_parent(child_sg, parent_sg)` is called in `render/layout.rs`, the LayoutGraph parent indices are correctly set.
2. The nesting algorithm recursively discovers hierarchies via the parents vec.
3. Nesting edges are created for all levels, producing correct rank constraints.
4. Rank assignment respects nesting edges and produces correct rank spans for all compounds.
5. Ordering and positioning phases don't reference parents directly; they work on edges, so nested compounds should order/position correctly.

**What requires changes:**

1. **render/layout.rs convert_subgraph_bounds()** (lines 797-916): Currently computes bounds from member nodes only. For nested subgraphs with no direct member nodes, bounds are skipped. Must be changed to:
   - First compute bounds for all compounds (including nested ones with no members)
   - Inside-out: inner subgraph bounds should be computed first, then outer subgraphs expand to include child subgraph bounds
   - This requires a recursive pass or topological sort on the subgraph parent hierarchy

2. **Possible ordering phase impact**: The order::run() phase must handle compounds as orderable nodes. When a compound is a direct child of another compound (not just its direct nodes), the order algorithm should still place it correctly relative to sibling compounds/nodes.

3. **Nesting root logic**: The current approach of connecting root to all top-level compounds might need adjustment. For deeply nested structures, intermediate compounds (neither top-level nor leaves) should be properly constrained through their parent nesting edges, not through separate root edges.

## Why

**Design rationale:**

The dagre nesting algorithm was designed for single-level compound graphs. The design extends to arbitrary nesting depth because:

1. The `parents` vec is indexed by node index, allowing O(1) lookup at any depth
2. The child-discovery pattern finds direct children only, but processes all compounds
3. Nesting edges stack naturally: outer edges constrain compounds, inner edges constrain nodes within compounds

This is elegant but requires the calling layer to properly set parent relationships. The conversion layer (`from_digraph()`) correctly handles this if given a DiGraph with nested parent relationships, but the build layer hasn't been updated to detect and propagate nested subgraph relationships.

**Trade-offs:**

- **Advantage**: Dagre is generic and doesn't need to know about subgraph semantics
- **Disadvantage**: The rendering layer must handle nested bounds computation, which it doesn't currently do

## Key Takeaways

- **Multi-level nesting works at the dagre level**: The nesting algorithm correctly handles arbitrary hierarchies. Rank constraints and edge setup work for nested compounds.
- **The critical issue is subgraph-to-subgraph parent relationships**: `render/layout.rs` doesn't call `set_parent(child_sg, parent_sg)` for nested subgraphs because `Diagram` doesn't track subgraph parents.
- **Bounds computation must become recursive**: `convert_subgraph_bounds()` needs to compute inside-out: inner subgraph bounds first, then expand outer subgraphs to encompass them.
- **Nesting edge creation should work correctly**: Once parent relationships are set, nesting edges for all levels are created automatically.
- **No algorithmic changes needed in core dagre phases**: Rank, order, and position phases should all work correctly once parent relationships are set.

## Open Questions

- Does the root nesting node need special handling for deeply nested structures, or does the automatic edge stacking handle it correctly?
- When a compound node is ordered within another compound node (not its direct children), does the order::run() phase handle mixed orderable types (compounds and regular nodes) correctly?
- How should border segment nodes be sized when a compound contains nested compounds? Should they expand to the nested compound's bounds, or maintain separation?
- For rendering: when nested borders are drawn, should inner borders be drawn on top of outer borders, or vice versa? What's the correct z-order?
