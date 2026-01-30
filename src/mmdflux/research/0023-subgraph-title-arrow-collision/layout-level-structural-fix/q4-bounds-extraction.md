# Q4: How does border::remove_nodes() need to change?

## Summary

`remove_nodes()` extracts subgraph bounding boxes from border node positions (border_left/right for x, border_top/bottom for y). It already handles the title rank correctly IF border nodes span all ranks including the title rank — the min/max aggregation naturally includes title-rank border positions. However, `convert_subgraph_bounds()` in render/layout.rs independently recomputes bounds from member-node positions and does NOT use dagre's compound bounds, so it needs adjustment to account for the title rank's vertical footprint.

## Where

- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/border.rs` (lines 67-125): `remove_nodes()` extracts bounds from border positions
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/border.rs` (lines 90-107): x-bounds from left/right borders, y-bounds from top/bottom borders
- `/Users/kevin/src/mmdflux-subgraphs/src/render/layout.rs` (lines 696-806): `convert_subgraph_bounds()` recomputes bounds from member positions
- `/Users/kevin/src/mmdflux-subgraphs/src/render/layout.rs` (line 707): `border_padding = 2` fixed padding
- `/Users/kevin/src/mmdflux-subgraphs/src/render/layout.rs` (lines 739-747): title-width enforcement
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/graph.rs` (lines 176-200): LayoutGraph border storage

## What

### Two-stage bounds computation

**Stage 1: dagre's `remove_nodes()` (float coordinates)**
1. Retrieves border_left and border_right vectors
2. Iterates over all border nodes to find min/max x-positions (lines 90-97)
3. If border_top/border_bottom exist, uses their y-positions (lines 99-107)
4. Computes center + dimensions: `(x_min+x_max)/2`, `(y_min+y_max)/2` (lines 109-121)

**Stage 2: render's `convert_subgraph_bounds()` (character coordinates)**
1. Collects all member-node draw positions (lines 714-722)
2. Computes min/max x and y from member positions
3. Applies `border_padding = 2` on all sides (line 707)
4. Adjusts x-bounds for title width (lines 739-747)
5. Does NOT use dagre's compound bounds

### Key finding: render layer doesn't use dagre bounds

`convert_subgraph_bounds()` independently recomputes bounds from member-node positions. This means:
- dagre's `remove_nodes()` output is NOT the authority for the render layer
- Changes to `remove_nodes()` alone are insufficient
- The render layer needs its own title-rank awareness

### Current title handling in render

Lines 739-747 handle title width enforcement:
- Computes title text width
- If title is wider than member bounds, expands x-bounds to center the title
- No y-axis adjustment for title height — title is drawn INTO the top border row

## How

### Impact of title rank

**On `remove_nodes()` (dagre layer):**
- If `add_segments()` creates border nodes at the title rank, `remove_nodes()` automatically includes them in x-bounds aggregation
- If border_top is at the title rank (above content), y_min naturally shifts upward
- No code changes needed — the existing aggregation handles it

**On `convert_subgraph_bounds()` (render layer):**
- Member nodes do NOT include the title dummy (it's infrastructure, not content)
- Y-bounds computed from members don't account for title rank space
- Need to add: if compound has title, shift top y upward by `1 + v_spacing` (title height + gap)
- The current `border_padding = 2` may partially cover this, but not reliably

### Required changes

1. **`remove_nodes()`**: No changes needed (handles title rank automatically through border aggregation)
2. **`convert_subgraph_bounds()`**: Needs targeted fix:
   - Detect if compound has a title
   - Extend top y-bound upward by title height (typically 1 character row)
   - May need to replace current "draw title into border" logic with "title has its own space"

## Why

### Why two-stage computation exists
- dagre uses float coordinates; render uses discrete character coordinates
- Direct mapping from dagre floats to character grid doesn't produce correct boundaries
- Recomputing from member positions ensures integer grid alignment

### Why the render layer needs the fix
- dagre's bounds include the title rank automatically (infrastructure change)
- But the render layer independently computes bounds from members
- The render layer is what actually produces the visual output
- Title space must be accounted for in character-grid coordinates

### Tradeoff
- Could pass dagre's compound bounds to the render layer, but this requires float→char coordinate conversion
- Simpler to adjust the render layer's independent computation with title awareness

## Key Takeaways

- `remove_nodes()` already supports the title rank correctly if border nodes span all ranks
- `convert_subgraph_bounds()` is the critical change point — it independently computes bounds from member positions and has no title-rank awareness
- The fix is a targeted adjustment: extend top y-bound by title height when a compound has a title
- Border width (x-bounds) is unaffected by the title rank
- The existing `border_padding = 2` is insufficient to reliably cover title space

## Open Questions

- Should `convert_subgraph_bounds()` use dagre's compound bounds instead of recomputing from members?
- How does the title height (1 char row) map to the y-offset in draw coordinates?
- Should `border_padding` be increased to account for titles, or should title space be separate from padding?
- If the title rank is present, should the current "draw title into top border" logic be removed entirely?
