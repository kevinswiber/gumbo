# Q2: mmdflux subgraph title rendering

## Summary

mmdflux renders subgraph titles by placing them directly above the border box at position (x, y-1) without any enclosing or padding. The title is rendered using basic character placement via `canvas.set()`, which does not protect against overwriting by nodes or edges, creating potential visual artifacts when titles are wider than borders or when content above the subgraph is dense.

## Where

Sources consulted:
- `/Users/kevin/src/mmdflux-subgraphs/src/render/subgraph.rs:14-52` - `render_subgraph_borders()` function with inline title rendering
- `/Users/kevin/src/mmdflux-subgraphs/src/render/layout.rs:696-749` - `convert_subgraph_bounds()` function with `title_height` constant at line 706
- `/Users/kevin/src/mmdflux-subgraphs/src/render/layout.rs:732` - border_y calculation accounting for title_height
- `/Users/kevin/src/mmdflux-subgraphs/src/render/mod.rs:57-60` - rendering pipeline order (borders first, then nodes, then edges)
- `/Users/kevin/src/mmdflux-subgraphs/src/render/canvas.rs:123-130` - `canvas.set()` method (unprotected write)
- `/Users/kevin/src/mmdflux-subgraphs/tests/integration.rs:973-1046` - subgraph rendering tests

## What

**Title Placement Mechanism:**

The title is placed at position `(x + i, y - 1)` for each character index `i`:

```rust
// Lines 26-30 from subgraph.rs
if y > 0 {
    for (i, ch) in bounds.title.chars().enumerate() {
        canvas.set(x + i, y - 1, ch);
    }
}
```

Key facts:
1. **Position**: The title row is exactly **1 cell above** the border's top-left corner
2. **No padding**: The title starts at the same x-coordinate as the border's left edge
3. **No enclosure**: The title is raw text with no surrounding characters
4. **No protection**: Uses `canvas.set()` which overwrites without checking for existing content

**Title Height in Layout:**

The layout computation reserves exactly **1 row** for the title:

```rust
// Line 706 from layout.rs
let title_height: usize = 1; // row above border for title

// Line 732 from layout.rs
let border_y = min_y.saturating_sub(border_padding + title_height);
```

The border's top-left corner y-position is pushed down by `(border_padding + title_height)` from the member nodes' minimum y-coordinate.

**Canvas Rendering Order:**

The rendering pipeline draws borders **before** nodes and edges (lines 57-60 from render/mod.rs), which means titles are rendered first but can be overwritten by subsequent node/edge rendering.

## How

1. **Layout phase** (`convert_subgraph_bounds()`):
   - Finds bounding box of member nodes
   - Applies `border_padding` and `title_height` to compute border coordinates
   - Border's y-coordinate is moved up by 1 extra row (for title)
   - Stores title text in `SubgraphBounds`

2. **Render phase** (`render_subgraph_borders()`):
   - Iterates over each subgraph's bounds
   - Checks boundary condition: `if y > 0`
   - For each character in title: calls `canvas.set(x + i, y - 1, ch)`
   - Draws the border box at (x, y) and below

3. **Canvas write** (`Canvas::set()`):
   - Updates the cell character without checking existing content
   - Does NOT mark cell as protected
   - Nodes and edges can overwrite the title during their rendering phase

## Why

1. **Simplicity**: Direct character placement avoids complex text positioning logic
2. **Border relationship**: y-1 placement visually associates title with border at y
3. **Left-alignment**: Starting at border's x creates clean visual alignment
4. **No protection**: Titles are decorative, not structural (unlike nodes)

**Constraints:**
1. **Single-row allocation**: Only 1 row for titles, regardless of length
2. **No text wrapping**: Long titles simply overflow to the right
3. **No escape logic**: No mechanism to shift subgraph down if content above is dense
4. **Boundary check only**: Only safety is `if y > 0` to prevent negative coordinates

## Key Takeaways

- **Title is unprotected** — can be overwritten by nodes/edges during rendering
- **Width has no bounds checking** — titles wider than border simply extend past it
- **Y-boundary check only** — `if y > 0` is the only safety mechanism
- **Title is purely decorative** — rendered as unprotected cells (low z-order priority)
- **Layout accounts for title** — border bounds calculation properly reserves the row

## Open Questions

- What prevents nodes from being placed in the title row? Layout should via border padding, but needs verification.
- Is there any truncation for titles longer than border width? Code shows none — title extends past border.
- Can nodes/edges overwrite titles? Yes, due to unprotected `canvas.set()` call.
- Is there a design decision to keep titles single-line, or is this a limitation?
- Should title cells be marked `is_subgraph_border` like border chars to indicate they're decorative?
- If `border_padding` changes, does the title still align correctly with the border?
