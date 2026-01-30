# Q2: Quick-Fix Options at Canvas/Render Layer

## Summary

Five render-time approaches were evaluated. **Option C (render title AFTER edges, dodge occupied cells)** is the most pragmatic quick-fix: ~35 lines, no new parameters, naturally respects what's already rendered, and handles all directions. **Option A (let arrows overwrite)** is minimal (~5 lines) but produces visual defects. **Option E (inner padding)** is robust but adds height. The recommended path is Option C as the quick fix, with a layout-level structural fix to follow.

## Where

- `src/render/canvas.rs` — cell protection (`set()` lines 127-137, `set_with_connection()` lines 158-182)
- `src/render/chars.rs` — arrow detection (`is_arrow()` lines 102-107)
- `src/render/edge.rs` — arrow placement (`draw_arrow_with_entry()` lines 568-585)
- `src/render/subgraph.rs` — title rendering (`render_subgraph_borders()` lines 14-77)
- `src/render/mod.rs` — rendering pipeline order (lines 43-81)

## What

### Option A: Let Arrows Overwrite Title Chars
- Change `canvas.set()` to allow arrow characters through title protection
- **~20 lines** including callsite updates (need to pass `CharSet` to `set()`)
- Produces holes in titles: `┌── Gr▼up ──┐` — visually unacceptable
- **Not recommended**

### Option B: Detect Collision and Shift Title
- After edge rendering, scan border row for arrows, re-render title shifted left/right
- **~60 lines** across 2 files
- Fails with multiple arrows; off-center titles look wrong
- **Medium complexity, medium robustness**

### Option C: Render Title AFTER Edges, Dodge Occupied Cells (RECOMMENDED)
- Split border rendering: draw border lines first (without title), render edges, then place title chars only on unoccupied cells
- **~35-50 lines** across 2 files (`subgraph.rs`, `mod.rs`)
- Natural ordering that respects canvas state after edges
- Graceful degradation: partial title if many edges present
- No new parameters or dependencies needed
- **Low complexity, high robustness**

### Option D: Title Exclusion Zone
- Predict edge positions before rendering, offset title to avoid them
- **~120 lines** across 3 files — requires routing before border rendering
- Tight coupling between routing and rendering; fragile prediction
- **High complexity, low robustness**

### Option E: Add 1 Row Inner Padding
- Reserve extra row inside subgraph at layout level
- **~30-40 lines** across 2 files
- Structurally sound but makes all subgraphs 1 row taller
- Better suited as a layout-level fix (see Q3)

## How

### Option C Implementation Plan
1. Extract title rendering from `render_subgraph_borders()` into `render_subgraph_titles()`
2. In `render_subgraph_borders()`, skip the title placement (draw border lines and corners only)
3. In `mod.rs`, call `render_subgraph_titles()` after `render_all_edges_with_labels()`
4. In `render_subgraph_titles()`, only write title chars where the cell is still a space or horizontal border char

### New Pipeline Order
```
render_subgraph_borders()   // borders without titles
render_nodes()              // nodes
render_all_edges_with_labels()  // edges (can cross borders freely)
render_subgraph_titles()    // titles last, dodge occupied cells
```

## Why

Option C is preferred because:
1. **No prediction needed** — it reacts to what's actually on the canvas
2. **No new coupling** — doesn't need edge routing info at title render time
3. **Graceful degradation** — partial title is better than missing arrow
4. **Direction-agnostic** — works for TD/BT/LR/RL without special cases
5. **Minimal code** — small, focused change

## Key Takeaways

- Current rendering order (borders+titles first, edges last) is the root cause — edges can't write through protected title cells
- Reversing title render order (after edges) is the simplest structural fix at the render layer
- All render-layer fixes are workarounds; the "correct forever" solution is at the layout level (Q3)
- Option C provides the best quick-fix tradeoff between code size, robustness, and visual quality

## Open Questions

- If many edges cross the title area, should we show a truncated title or no title at all?
- Should title chars that can't be placed generate a warning/diagnostic?
- Does splitting border rendering into two phases affect the junction-merging logic?
