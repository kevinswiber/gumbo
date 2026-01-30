# Q3: Attachment Point Overlap

## Summary

Phase 3 of Plan 0020 partially fixed the attachment point overlap issue by changing the sorting key from opposite-node center coordinates to the actual approach point coordinates (derived from waypoints). This eliminated face classification mismatches for backward edges. However, the fix is incomplete: when multiple edges arrive on the same face with very small (1-2 cell) spacing, they can still collide due to arrow character rendering occupying the same cell as the second edge's path. The core issue is that `spread_points_on_face()` allocates positions evenly without considering arrow width (1 cell) or requiring minimum separation gaps.

## Where

**Files investigated:**
- `src/render/router.rs` (lines 814-927) — `compute_attachment_plan()`, attachment point allocation and sorting
- `src/render/intersect.rs` (lines 61-97) — `spread_points_on_face()`, evenly-spaced point calculation
- `src/render/canvas.rs` (line 155) — Arrow protection in `set_with_connection()`
- `src/render/chars.rs` (lines 101-108) — `is_arrow()` check to protect arrow characters
- `src/render/edge.rs` (line 536) — `draw_arrow_with_entry()` uses unconditional `canvas.set()`

**Test fixtures and baselines:**
- `tests/fixtures/labeled_edges.mmd` — Handle Error node with "no" forward and "retry" backward edges
- `tests/fixtures/http_request.mmd` — Send Response node with multiple convergent edges
- `tests/snapshots/labeled_edges.txt` — Current baseline (clean, no visible overlap)
- `tests/snapshots/http_request.txt` — Current baseline (clean with proper spacing)

**Prior research:**
- `research/0013-visual-comparison-fixes/q3-attachment-point-ordering.md` — Found the face classification vs. sorting mismatch
- `plans/0020-visual-comparison-fixes/implementation-plan.md` — Plan phases 1-5
- `issues/0002-visual-comparison-issues/issues/issue-08-attachment-overlap-missing-arrow.md` — Documents the collision cases

## What

### 1. The Phase 3 Fix (Applied)

Phase 3 changed `compute_attachment_plan()` from:
```
OLD: Sort edges by opposite_node.center_x/y (geometric position)
NEW: Sort edges by approach_point.cross_axis (waypoint-derived)
```

The new approach:
- Extracts the cross-axis coordinate (x for top/bottom, y for left/right) from the actual approach point (first/last waypoint or node center)
- Sorts face groups by this value before spreading
- Ensures edges with long waypoints route around nodes correctly (no backward crossings)

**Example (labeled_edges.mmd, Handle Error top face, assuming 16-cell width):**
- Edge "no" (Config → Handle Error): forward, approach point from waypoints at x=8, cross_axis=8
- Edge "retry" (Setup → Handle Error backward): backward, routed around, approach point at waypoint ~x=2, cross_axis=2
- NEW sort: [2, 8] (left-to-right)
- Spread on range [0, 16] for 2 edges: positions = [5, 10] (evenly spaced at (2+1)*16/(2+1)=5, (2+2)*16/(2+1)=10)
- Result: edges attach at x=5 and x=10 (5-cell gap)

### 2. Arrow Protection (Applied)

Phase 3 added arrow character protection:
- `CharSet::is_arrow()` method identifies arrow characters (↑↓←→)
- Modified `canvas.set_with_connection()` to reject overwrites if the existing cell contains an arrow (line 155)
- This prevents later-drawn edges from erasing earlier arrows

**But note:** `draw_arrow_with_entry()` (line 536) still uses unconditional `canvas.set()`, which bypasses the protection check. This is correct because we want to place the arrow regardless.

### 3. Remaining Overlap Scenarios

Despite the fix, the algorithm can still produce collisions in narrow cases:

**Scenario A: Narrow node faces with many edges**
- Node width = 8 cells, 3 edges converging
- Spread formula: positions at (1*8)/4=2, (2*8)/4=4, (3*8)/4=6
- Edges attach at x=2, 4, 6 (2-cell gaps)
- Each edge includes a 1-cell arrow plus a path segment
- Arrow at x=4 can collide with the x=2 edge's vertical line if they're on the same/adjacent rows

**Scenario B: Forward + backward mixed edges on same face**
- Forward edge's approach point is node center (e.g., x=8)
- Backward edge's approach point is a waypoint (e.g., x=2)
- After reordering: [2, 8] are now sorted correctly
- But if the node is narrow (width < 10), the spread positions will be very close
- Gap = (8-2)/3 ≈ 2 cells, minus arrow width = ~1 cell actual separation

**Scenario C: Zero-width case (clamping)**
- When `pos.min(end)` clamps a position to the edge, multiple edges can end up at the same coordinate
- Example: Node width=5, spread 3 edges: (1*5)/4=1, (2*5)/4=2, (3*5)/4=3 — all valid
- But in a very narrow node: all positions converge

### 4. Why Current Output Looks Clean

The current test fixtures (labeled_edges, http_request) have sufficient node widths and edge counts that `spread_points_on_face()` naturally distributes them far enough apart. The Handle Error node in labeled_edges.mmd is 16 cells wide; spreading 2 edges produces ~5-cell gaps. This is visually clean.

However, the algorithm has **no explicit minimum gap enforcement**. If a diagram with narrower nodes or more edges converging were added, collisions would re-emerge.

## How

The attachment spreading algorithm works in three steps:

**Step 1: Face Classification** (lines 846-869)
- For LR/RL: force Right/Left faces unconditionally
- For TD/BT: use approach point (waypoint or node center) to classify which face
- Extract cross-axis coordinate: `src_cross = approach.x for top/bottom, approach.y for left/right`

**Step 2: Grouping and Sorting** (lines 894-906)
- Group edges by (node_id, face) tuple
- For groups with >1 edge: sort by approach_cross value
- This replaces the old `sort_face_group()` which sorted by opposite node's center

**Step 3: Spreading and Override Assignment** (lines 908-923)
```rust
let points = spread_points_on_face(*face, fixed, extent, sorted.len());
// spread_points_on_face formula:
// pos[i] = start + ((i+1) * range) / (count+1)
```

For count=2 on range [0, 16]:
- pos[0] = 0 + (1*16)/3 = 5
- pos[1] = 0 + (2*16)/3 = 10
- Gap = 5 cells between them

**Why Collisions Can Still Occur:**

The formula `((i+1) * range) / (count+1)` divides available space evenly but doesn't account for:
1. **Arrow width**: Each attachment point includes a 1-cell arrow character
2. **Path segments**: Vertical/horizontal lines can be adjacent to attachment points
3. **Character overwrite order**: Edges are rendered sequentially; later ones can collide with earlier arrows

## Why

**Root cause:**
The `spread_points_on_face()` algorithm is mathematically sound but **makes no assumptions about minimum gaps**. It treats attachment points as abstract coordinates and delegates collision handling to the rendering layer. The rendering layer then:
- Places arrows with `canvas.set()` (unconditional overwrite)
- Places segments with `set_with_connection()` which respects arrows (line 155)

This creates a **race condition**: arrow placement order matters. If Edge A's arrow is placed, then Edge B's segment may refuse to overwrite it (good). But if Edge B's segment is placed first, then Edge A's arrow can overwrite it (bad).

**Design decision in Phase 3:**
Instead of adding minimum-gap enforcement to `spread_points_on_face()`, the fix opted for:
1. Correct sorting (waypoint-based instead of geometry-based)
2. Arrow character protection in the rendering layer

**Why this is incomplete:**
- Correct sorting solves the **crossing problem** (backward edges appearing to cross forward edges)
- Arrow protection solves the **overwrite problem** (arrows disappearing)
- But together they don't solve the **proximity problem**: two edges can still be 1-2 cells apart, making the diagram visually cramped

## Key Takeaways

- **Phase 3 solved two problems:** (1) attachment point ordering consistency (waypoint-based), (2) arrow character protection. These fixes eliminate visible crossings and missing arrows.

- **Phase 3 did not add minimum gap enforcement.** `spread_points_on_face()` allocates positions evenly without requiring spacing. Collision prevention relies on the rendering layer respecting arrow positions.

- **The current test fixtures pass because they have sufficient node width.** The Handle Error node (16 cells) can comfortably spread 2 edges with 5-cell gaps. A narrower node with more edges could expose the issue.

- **Arrow protection prevents overwrite in one direction only.** If Edge A's arrow is placed before Edge B's segment arrives, protection works. If Edge B's segment is placed first, Edge A's arrow can still overwrite it.

- **The fix trades architecture simplicity for edge cases.** A more robust solution would enforce minimum gaps at the spreading stage (e.g., `MIN_GAP = 3` or dynamic calculation), preventing tight spacing proactively.

## Open Questions

- Does Plan 0020 or any other active plan address the minimum-gap scenario? Or is it considered acceptable for rare narrow-node cases?

- What is the intended behavior when nodes are too narrow for the minimum gap? Should edges:
  - (A) Be forced to wider faces (e.g., if top is too narrow, try left/right)?
  - (B) Be allowed to share/overlap attachment points (with special rendering)?
  - (C) Trigger an error/warning in debug output?

- Could `spread_points_on_face()` detect impossible spacing (count > available_cells) and trigger face-splitting or node resizing?

- Should the rendering order of edges be controlled (e.g., sort by attachment point before rendering) to ensure consistent overwrite behavior?
