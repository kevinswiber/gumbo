# Q6: Rendering Pipeline Changes for Subgraph Borders

## Summary

Subgraph borders must be rendered as labeled rectangles drawn on the canvas BEFORE nodes and edges, achieving z-ordering through render sequence (terminal ASCII art has no true depth). The `Layout` struct needs a new `subgraph_bounds` field, the `Canvas` needs an `is_subgraph_border` cell flag (allowing overwrite by nodes/edges), and a new render pass inserts between canvas creation and node rendering. Box-drawing characters should use thin lines to visually distinguish from node borders, with labels placed outside the top-left corner.

## Where

- `/Users/kevin/src/mmdflux/src/render/layout.rs` -- `compute_layout()` and `Layout` struct
- `/Users/kevin/src/mmdflux/src/render/canvas.rs` -- Canvas 2D character grid
- `/Users/kevin/src/mmdflux/src/render/shape.rs` -- Node shape rendering
- `/Users/kevin/src/mmdflux/src/render/chars.rs` -- CharSet for box-drawing characters
- `/Users/kevin/src/mmdflux/src/render/edge.rs` -- Edge rendering
- `/Users/kevin/src/mmdflux/src/render/mod.rs` -- Render orchestration

## What

### Current Rendering Pipeline

The `render()` function orchestrates 5 steps:
1. Compute layout via `compute_layout_direct()`
2. Create canvas
3. Render nodes (marking cells as `is_node` for protection)
4. Route and render edges (collision avoidance with `is_node`)
5. Convert canvas to string

**Key structures:**
- `Layout` struct: node positions, bounding boxes, canvas dimensions, edge waypoints -- **no subgraph info**
- `Canvas`: 2D character grid with per-cell `is_node` and `is_edge` flags
- `CharSet`: box-drawing characters for Unicode and ASCII modes

### Z-Order Constraint

Terminal rendering has no true z-order. Layering is achieved by render sequence:
- Background (subgraph borders) must render FIRST
- Foreground (nodes, edges) renders on top, overwriting border cells

### Required Changes

**1. Layout struct extension:**
```rust
pub struct SubgraphBounds {
    pub x: usize,
    pub y: usize,
    pub width: usize,
    pub height: usize,
    pub label: String,
    pub parent: Option<String>,
}

pub struct Layout {
    // ... existing fields ...
    pub subgraph_bounds: HashMap<String, SubgraphBounds>,
}
```

**2. Canvas cell tracking:**
```rust
pub struct Cell {
    pub ch: char,
    pub connections: Connections,
    pub is_node: bool,
    pub is_edge: bool,
    pub is_subgraph_border: bool,  // NEW: allows overwrite by nodes/edges
}
```

**3. New render pass:**
```
Step 1: Compute layout (with subgraph bounding boxes)
Step 2: Create canvas
Step 3: Render subgraph borders (NEW -- before nodes)
Step 4: Render nodes
Step 5: Route and render edges
Step 6: Convert canvas to string
```

## How

### compute_layout() Changes

After computing node positions, add bounding box computation:
- Group nodes by subgraph membership (from Diagram.subgraphs)
- For each subgraph, compute minimal bounding box containing all member nodes
- Add padding (1-2 cells) for border rendering
- Handle nested subgraphs: parent bounds enclose all children
- Expand canvas size if borders extend beyond node bounds

### New render_subgraph_borders() Function

```rust
pub fn render_subgraph_borders(
    canvas: &mut Canvas,
    subgraph_bounds: &HashMap<String, SubgraphBounds>,
    charset: &CharSet,
) {
    // Render outer subgraphs first, inner subgraphs second
    // (outer borders can be overwritten by inner borders)
    for (id, bounds) in sorted_by_nesting_depth(subgraph_bounds) {
        draw_border_box(canvas, bounds, charset);
        draw_label(canvas, bounds);
    }
}
```

Border drawing uses thin box-drawing characters, with cells marked as `is_subgraph_border` (NOT `is_node`) so nodes and edges can overwrite them.

### Box-Drawing Character Strategy

**Recommended: Thin lines for subgraphs, standard for nodes:**

```
Node:     ┌─────┐    (standard box-drawing)
Subgraph: ┌─────────────┐    (thin lines, same chars but visually distinct context)
```

Or with distinct styles:
```
Node:     ┌─────┐
Subgraph: ╭─────────────╮    (rounded corners for subgraphs)
```

CharSet extension:
```rust
pub struct CharSet {
    // ... existing ...
    pub thin_horizontal: Option<char>,
    pub thin_vertical: Option<char>,
    pub thin_corner_tl: Option<char>,
    pub thin_corner_tr: Option<char>,
    pub thin_corner_bl: Option<char>,
    pub thin_corner_br: Option<char>,
}
```

### Label Placement

**Recommended: Outside top-left corner (Mermaid style):**
```
subgraph_id
┌─────────────┐
│  Nodes...   │
└─────────────┘
```

This avoids label-node collisions. Fallback if no space above: inline in top border.

### Nested Subgraphs

For `subgraph A { subgraph B { nodes } }`:
- Compute inner B bounds first
- Compute outer A bounds to enclose B with padding
- Draw A border first (outermost), then B border (inside A)
- Nodes and edges render on top of both

### Canvas Sizing

After subgraph bounds are known, expand canvas if needed:
```rust
let width = base_width.max(subgraph_max_width);
let height = base_height.max(subgraph_max_height);
```

### Modified render() Orchestration

```rust
pub fn render(diagram: &Diagram, options: &RenderOptions) -> String {
    let charset = select_charset(options);
    let layout = compute_layout_direct(diagram, &config);
    let mut canvas = Canvas::new(layout.width, layout.height);

    // NEW: Render subgraph borders FIRST
    render_subgraph_borders(&mut canvas, &layout.subgraph_bounds, &charset);

    // Render nodes (overwrites border cells where they overlap)
    render_nodes(&mut canvas, diagram, &layout, &charset);

    // Route and render edges
    render_edges(&mut canvas, diagram, &layout, &charset);

    canvas.to_string()
}
```

### ASCII-Only Mode

For `--ascii` mode, use ASCII equivalents:
```
+- label ---------+
|   Nodes...      |
+-----------------+
```

## Why

### Design Rationale

1. **Z-order via render sequence:** Only viable approach for terminal character grids. Subgraph borders render first so nodes/edges can overwrite.

2. **is_subgraph_border flag:** Distinguishes border cells from node cells. Node cells are protected from edge overwrite; border cells are not.

3. **Thin line distinction:** Helps users visually distinguish subgraph borders from node borders in dense layouts.

4. **Label outside top-left:** Matches Mermaid's convention. Minimizes collision with nodes inside the subgraph.

5. **Nested border ordering:** Outer-first ensures inner borders can overwrite outer borders at overlap points without visual artifacts.

### Terminal Rendering Constraints

- Character grid: no sub-pixel positioning, no fractional widths
- No transparency: each cell has exactly one character
- No overlapping: can't draw "behind" something already drawn
- Unicode support varies: thin/thick line distinction may not render on all terminals
- ASCII fallback must work with `+-|` only

## Key Takeaways

- Z-order via rendering order: subgraph borders must render first
- Canvas cell type: `is_subgraph_border` flag (not `is_node`) allows overwrites
- Layout extension: `Layout` struct needs `subgraph_bounds` HashMap
- Box-drawing: thin lines recommended to distinguish from nodes
- Label placement: outside top-left corner (Mermaid style)
- Nested handling: outer borders first, then inner
- Canvas expansion: final size must account for both nodes and subgraph borders

## Open Questions

- How to handle label collision with nodes if label is placed outside?
- For deeply nested subgraphs (3+ levels), how much padding between borders?
- Should edge routing avoid subgraph borders (like nodes) or pass through?
- How to render subgraph borders near canvas edges?
- For ASCII mode with `+` corners, how to distinguish subgraph borders from nodes visually?
