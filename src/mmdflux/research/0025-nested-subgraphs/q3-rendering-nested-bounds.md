# Q3: Rendering and Bounds Computation for Nested Subgraphs

## Summary

Nested subgraph bounds computation requires a fundamental redesign from the current node-only approach to a bottom-up (child-first, then parent) computation model. The existing `convert_subgraph_bounds()` function skips empty subgraphs (line 826-828), which breaks nested scenarios where outer subgraphs have no direct member nodes. Nested borders must be rendered in reverse z-order (inner borders drawn after outer) to avoid occlusion, and padding/spacing rules between nested borders differ from sibling spacing, requiring new logic for containment checking.

## Where

**Files Analyzed:**
- `src/render/layout.rs` (lines 792-916): `convert_subgraph_bounds()` entry point, `resolve_subgraph_overlap()` sibling resolution
- `src/render/subgraph.rs` (lines 1-78): `render_subgraph_borders()` z-order rendering, title placement at (x, y)
- `src/render/mod.rs` (lines 43-81): `render()` pipeline orchestration, border rendering at line 59
- `src/graph/diagram.rs` (lines 22-31): `Subgraph` struct (currently no parent field)
- `src/graph/builder.rs` (lines 82-98): `collect_node_ids()` excludes subgraphs from member lists (line 89)
- `src/render/canvas.rs` (lines 36-77): `Cell` struct with `is_subgraph_border` (not protected from overwrite)

## What

### Current Bounds Computation Behavior

1. **Direct Node Only**: `convert_subgraph_bounds()` iterates `sg.nodes` list and computes min/max x,y from their draw positions (lines 815-824). The function has no concept of nesting.

2. **Early Exit on Empty**: If a subgraph has no direct member nodes (`min_x == usize::MAX`), it skips to the next subgraph with `continue` (lines 826-828). This is the critical blocker for nested subgraphs.

3. **Title Width Enforcement**: The function enforces a minimum width based on title length (overhead: 2 corners + "─ " prefix + " ─" suffix = 6 characters). This works fine for any subgraph but doesn't help with empty (nested) ones.

4. **Backward Edge Expansion**: For TD/BT layouts, if the subgraph contains backward edges (Y-axis reversal), the width is expanded by `BACKWARD_ROUTE_GAP + 2` (lines 859-895). This logic doesn't apply to nested subgraphs since they have no direct edges.

5. **Sibling Overlap Resolution**: After all bounds are computed, `resolve_subgraph_overlap()` (lines 918-1012) checks every pair of subgraphs for 2D overlap and trims borders at the midpoint if they collide. This logic assumes sibling relationships and doesn't distinguish nested from sibling pairs.

### Problem: Nested Subgraphs

**Example diagram:**
```
graph TD
subgraph a[Outer]
  b[Node B]
  subgraph d[Inner]
    c[Node C]
  end
end
```

**What happens now:**
1. `collect_node_ids("d")` collects only direct nodes: ["C"]
2. `collect_node_ids("a")` collects only direct nodes: ["B"] (subgraph "d" is skipped at line 89)
3. In `compute_layout_direct()`, both "a" and "d" are added as compound nodes (line 147)
4. In `convert_subgraph_bounds()`:
   - Subgraph "d": `sg.nodes = ["C"]`, bounds computed from C's position
   - Subgraph "a": `sg.nodes = ["B"]`, bounds computed from B's position
   - Missing: outer "a" should include inner "d" bounds, not just "B"

**Current Issue:**
- Subgraph "a" bounds are based on B alone, potentially making "d" fall outside "a"'s border
- No constraint ensures outer bounds include inner bounds

### Canvas and Z-Order

The `render_subgraph_borders()` function (line 14-78 in `subgraph.rs`) draws all borders in a single loop (line 19: `for bounds in subgraph_bounds.values()`). There is no z-order control; all borders are marked `is_subgraph_border` (not protected), allowing nodes/edges to overwrite them. For nested subgraphs:

- Outer borders should be drawn first (background)
- Inner borders should be drawn after (foreground, visible on top)
- Currently, iteration order is undefined (HashMap), so nesting z-order is unpredictable

### Title Placement

Titles are embedded in the top border at (x, y) — line 26-27 set top-left and top-right corners, line 43-49 place title text inside the top-edge row. For nested subgraphs:

- Outer subgraph title at (a.x, a.y)
- Inner subgraph title at (d.x, d.y)
- If inner title's x-position overlaps outer title (same row), they may collide

## How

### Proposed Design: Inside-Out Bounds Computation

Bounds should be computed in two passes:

**Pass 1: Compute Leaf Subgraph Bounds (bottom-up)**
- Start with subgraphs that have no nested children (leaf subgraphs)
- For each leaf, compute bounds from direct member nodes (existing logic)
- Store in a temporary map

**Pass 2: Compute Parent Subgraph Bounds (propagate upward)**
- For each parent subgraph:
  - Collect direct member nodes (existing `sg.nodes` list)
  - Collect child subgraphs (requires new `Subgraph.parent` field)
  - Compute bounds from union of:
    - Direct member nodes (min/max x, y from draw_positions)
    - Child subgraph bounds (min/max x, y from bounds map)
  - Apply padding around the union (border_padding = 2)
  - Enforce title-width minimum
  - Check for backward edges (existing logic)

**Implementation approach (pseudocode):**

```rust
fn convert_subgraph_bounds_nested(subgraphs, draw_positions, node_dims, direction, edges) {
    // Phase 1: Build parent -> children map
    let children_map = build_children_map(subgraphs);

    // Phase 2: Recursive bottom-up computation
    let mut bounds = HashMap::new();
    let mut visited = HashSet::new();

    for sg_id in subgraphs.keys() {
        compute_bounds_recursive(sg_id, subgraphs, &children_map,
            draw_positions, node_dims, &mut bounds, &mut visited, direction, edges);
    }

    // Phase 3: Sibling-only overlap resolution
    resolve_subgraph_overlap_siblings_only(&mut bounds, &children_map);

    bounds
}

fn compute_bounds_recursive(sg_id, ...) {
    if visited.contains(sg_id) { return; }
    visited.insert(sg_id);

    // First: compute all children recursively
    for child_id in children_map.get(sg_id) {
        compute_bounds_recursive(child_id, ...);
    }

    // Then: compute this subgraph's bounds from union of:
    // - direct member nodes
    // - child subgraph bounds
    let (min_x, min_y, max_x, max_y) = union_of(direct_nodes, child_bounds);

    // Apply padding, title width, backward edge expansion
    bounds.insert(sg_id, computed_bounds);
}
```

### Nested-Aware Overlap Resolution

The current `resolve_subgraph_overlap()` treats all subgraph pairs equally. For nested subgraphs:

**Nested pairs (parent-child):**
- Don't trim borders; parent should entirely contain child
- Add spacing rule: minimum gap between inner and outer borders (e.g., 1-2 characters)

**Sibling pairs (same parent or no parent):**
- Apply existing trim logic to avoid collision

**Implementation:**
- Before overlap resolution, check if one subgraph is an ancestor of the other
- Skip nested pairs entirely (containment is enforced by the inside-out computation)
- Only apply trimming to sibling pairs

### Z-Order Rendering

To ensure proper z-order, sort subgraphs before rendering based on nesting depth:

- Draw from shallowest to deepest (outer to inner)
- This prevents inner borders from being obscured by outer borders

### Nested Border Spacing Rules

For nested subgraphs, padding between nested borders should differ from sibling spacing:

- **Outer -> Inner padding**: 1-2 characters minimum (to avoid touching borders)
- **Sibling padding**: Apply existing `resolve_subgraph_overlap()` logic

This is naturally achieved by the inside-out computation: child bounds are computed first, then parent bounds are sized to include them with border_padding added.

### Title Placement for Nested Borders

Titles are embedded at the top-left of each border. For nested subgraphs:

- Outer title: (a.x + 1, a.y) — outermost border
- Inner title: (d.x + 1, d.y) — nested inside, at its own row

As long as compute_layout properly positions inner subgraph bounds, titles won't collide because they're placed at different (x, y) rows within their respective borders.

## Why

### Design Rationale

1. **Inside-Out (Bottom-Up) Computation**: The recursive, depth-first approach ensures children's bounds are finalized before parents compute their bounds. This is the natural model for hierarchical containment — parents must know their children's extent to properly wrap them.

2. **Elimination of Empty Subgraph Skip**: By including child subgraph bounds in the computation, outer subgraphs never become "empty" — they always have content (either direct nodes or nested subgraphs). The `min_x == usize::MAX` check can remain, but it will only trigger for truly childless subgraphs with no nodes, which should be rare.

3. **Separation of Nested vs. Sibling Logic**: Nested pairs have a containment relationship; sibling pairs have an adjacency relationship. Overlap resolution (trimming borders) only makes sense for sibling pairs. Nested pairs should maintain spacing rather than trim.

4. **Z-Order Preservation**: Drawing outer borders first (shallowest depth) then inner (deepest) ensures proper layering.

5. **Backward Edge Containment**: Backward edges within a subgraph are expanded in the parent's bounds. For nested subgraphs, backward edges in the child increase the child's bounds, which in turn increase the parent's bounds via the union operation.

### Tradeoffs

**Pro:**
- Correctly models Mermaid's nested subgraph rendering
- Maintains existing sibling overlap logic
- Incremental change (only affects bounds computation)

**Con:**
- Requires adding `parent: Option<String>` field to `Subgraph` struct (Q1 prerequisite)
- More complex computation (recursive instead of flat iteration)
- May expose edge cases in dagre layout for nested compound nodes (Q2 investigation)

## Key Takeaways

- **Current blocker**: `convert_subgraph_bounds()` line 826 skips subgraphs with no direct nodes, breaking nested subgraphs
- **Root cause**: Bounds computation is node-centric, not hierarchy-aware
- **Solution pattern**: Inside-out (child-first) recursive traversal with union of direct nodes + child bounds
- **Prerequisite**: `Subgraph` struct must track parent relationship; `graph/builder.rs` must propagate it
- **Z-order**: Render borders by depth (shallow to deep) to ensure proper layering
- **Overlap handling**: Distinguish nested pairs (containment) from sibling pairs (adjacency); only trim siblings
- **Backward edges**: Automatically handled via bounds union — inner backward edges increase inner bounds, which increase outer bounds

## Open Questions

- What is the minimum spacing between nested borders? Current design uses `border_padding = 2` for all subgraphs. Should nested padding differ (e.g., 1) to keep diagrams compact?
- How should deeply nested subgraphs (3+ levels) be rendered? Are there z-order or title placement issues beyond 2 levels?
- What happens when a subgraph spans multiple branches? Example: subgraph "a" contains nodes "A, B" in separate layers; nested subgraph "d" contains only "C" which is far from "A, B". Does inside-out computation place "a" borders around all three?
- Should edges between nested subgraphs trigger layout constraints?
- Can sibling subgraphs share a border section?
