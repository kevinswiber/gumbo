# Q3: Should Precomputed Labels Use Collision Avoidance?

## Summary

Precomputed labels intentionally skip collision avoidance because the design assumes dagre's label-dummy positioning produces correct, non-overlapping positions. The `draw_label_at_position()` function has only minimal protection (skipping node cells), with no checks for edge cell overlap or label-label overlap. This is a deliberate design choice rather than an oversight -- the precomputed path trusts the layout algorithm -- but it becomes a problem when the coordinate transformation from dagre space to canvas space introduces positioning errors, which is exactly the scenario the label-dummy branch encounters.

## Where

Sources consulted:
- `/Users/kevin/src/mmdflux-label-dummy/src/render/edge.rs` -- all three key functions: `render_all_edges_with_labels()` (line 686), `draw_label_at_position()` (line 760), `find_safe_label_position()` (line 329), `draw_edge_label_with_tracking()` (line 72)
- `/Users/kevin/src/mmdflux-label-dummy/src/render/layout.rs` -- `transform_label_positions_direct()` (line 814) and `transform_waypoints_direct()` (line 772)
- `/Users/kevin/src/mmdflux/research/0018-label-dummy-rendering-regression/q3-render-layer-analysis.md` -- prior analysis of the render pipeline
- Git history of `src/render/edge.rs` (30 commits tracing label placement evolution)

## What

### 1. The Code Path Split in `render_all_edges_with_labels()`

The function (line 706-756) processes each labeled edge through a three-way branch:

```
if routed.is_backward:
    -> calc_label_position() on routed segments
    -> find_safe_label_position() for collision avoidance
    -> draw_label_direct()
else if precomputed position available and in-bounds:
    -> draw_label_at_position()         # NO collision avoidance
else:
    -> draw_edge_label_with_tracking()  # Full collision avoidance
```

The precomputed path (line 740-741) is used for **forward edges that have a label position from the dagre label-dummy pipeline**. The bounds check (line 714-718) validates that the position fits within the canvas, but this is a sanity check, not collision avoidance.

### 2. What `find_safe_label_position()` Does (Lines 329-391)

This function performs three collision checks:
1. **Node collision** (`label_collides_with_node`): checks if any cell in the label span has `is_node == true`
2. **Edge collision** (`label_collides_with_edge`): checks if any cell has `is_edge == true` (can be disabled via `check_edge_collision` parameter)
3. **Label-label collision**: checks if the proposed position overlaps any previously placed `PlacedLabel` bounding box

If the base position collides, it tries up to 12 alternative shifts (up to 3 cells in each cardinal direction). If all shifts fail, it returns the base position as a fallback (relying on the per-cell `is_node` check during writing to prevent node overwriting).

### 3. What `draw_label_at_position()` Has for Protection (Lines 760-783)

The only protection is per-cell: each character is written only if `!cell.is_node`. There is:
- **No node-bounding-box collision check** (doesn't try to avoid the node entirely, just skips individual node cells)
- **No edge cell collision check** (will silently overwrite edge drawing characters)
- **No label-label collision check** (two precomputed labels could overlap each other)
- **No position shifting** (if the position is bad, no alternatives are tried)

The function also centers the label by subtracting `label_len / 2` from x, which means the actual draw position differs from the precomputed position. If the precomputed position assumed left-aligned placement, this centering adjustment could shift the label into a node.

### 4. What Would Happen If Precomputed Positions Used Collision Avoidance

If we wrapped precomputed positions in `find_safe_label_position()`:

**Likely outcome for well-placed labels**: No change. The base position passes all collision checks, so `find_safe_label_position()` returns it unchanged.

**For labels near nodes (the problem case)**: The collision check would detect the overlap and try shifts. However, the shift table is limited (max 3 cells in each direction). If the precomputed position is fundamentally wrong (e.g., placing a label inside a node due to coordinate transformation errors), a 3-cell shift may not be enough to escape the node's bounding box. The function would fall back to the base position anyway.

**For label-label overlaps**: Adding collision avoidance would detect and resolve cases where two precomputed labels land on the same row at overlapping x positions. Currently this goes undetected.

**Critical consideration**: The `placed_labels` vector is already being maintained in the loop (line 705, 752-754), so precomputed labels are tracked for subsequent collision checks. However, the precomputed label itself does not check against previous entries. This means: if edges are processed in order (A->B, then A->C), the second edge's heuristic label will avoid the first edge's precomputed label. But if both edges have precomputed positions, neither checks against the other.

### 5. Design Intent: Trust Dagre's Output

The git history reveals a clear progression:

1. **Initial implementation** (`44d9080`, `0566770`): Collision avoidance was added to fix label overlap issues in the heuristic path.
2. **Label-dummy pipeline** (`bd63def`, `60d919c`): Precomputed positions were wired in with the explicit intent that dagre's label-dummy positioning would make collision avoidance unnecessary. Commit `60d919c` ("verify edge rendering with precomputed labels") added tests confirming labels appear between source/target nodes, treating the precomputed path as authoritative.
3. **Backward edge fix** (`719ff00`): Backward edges were explicitly given collision avoidance because their positions come from routing, not dagre layout. The commit message says "run through find_safe_label_position() for node/label collision avoidance" -- showing the developer consciously chose collision avoidance for backward but not forward precomputed.

The design philosophy is: **dagre positions should be correct by construction; the fix for bad positions belongs in the dagre/transform layer, not in a render-layer workaround**.

### 6. The Transform Layer Is the Weak Link

The prior research (Q3 from research 0018) identified that `transform_label_positions_direct()` uses rank-based snapping (`layer_starts[rank]`) for the primary axis, which should place labels at the correct rank. However, the cross-axis uses uniform scaling from dagre coordinates, and collision repair (node shifting) can invalidate these positions after transformation.

The current code in the label-dummy branch (layout.rs lines 814-848) now correctly uses `layer_starts` for rank snapping (matching waypoint transformation), which is an improvement over the earlier node-bounds-midpoint approach documented in the prior research. But uniform scaling on the cross-axis can still place labels at incorrect x positions if dagre's coordinate output doesn't align well with the canvas grid.

## How

### The Two Paths Differ in Protection Level

| Protection | `draw_label_at_position()` | `draw_edge_label_with_tracking()` |
|------------|---------------------------|-----------------------------------|
| Node cell skip (per-char) | Yes (`!cell.is_node`) | Yes (`!cell.is_node`) |
| Node bounding-box avoidance | No | Yes (via `find_safe_label_position`) |
| Edge cell avoidance | No | Conditional (skipped for h-seg labels) |
| Label-label collision | No | Yes (via `placed_labels` parameter) |
| Position shifting on collision | No | Yes (up to 12 shifts, 3 cells each direction) |
| Arrow position protection | No | Yes (skips arrow cell at `routed.end`) |
| Centering logic | `x - label_len/2` | Direction-dependent heuristic |

### The Backward Edge Path Has Full Protection

Backward edges (line 720-739) use `calc_label_position()` to find the path midpoint, then pass through `find_safe_label_position()` with `check_edge_collision: false`. This gives them node avoidance and label-label collision protection. The `draw_label_direct()` function (line 790-816) also expands the canvas if needed.

This is the most robust path. Forward precomputed labels get the least protection.

## Why

### Design Rationale: Layered Correctness

The architecture follows a principle of **layered correctness**:
1. **Dagre layer**: Computes structurally correct positions via label dummies that participate in crossing reduction and position assignment
2. **Transform layer**: Converts dagre coordinates to canvas space, using rank snapping for primary axis accuracy
3. **Render layer**: Draws at the given positions, trusting upstream layers

Collision avoidance in the render layer is a **workaround for the heuristic path**, which doesn't have the benefit of dagre's structural layout. The precomputed path is supposed to not need it.

### Why This Breaks Down

The assumption fails when:
1. **Cross-axis scaling is imprecise**: Uniform float-to-int scaling can place a label at x=14 when the node boundary is at x=13, causing a 1-cell overlap that `find_safe_label_position` would catch trivially
2. **Centering adjustment in `draw_label_at_position`**: The function subtracts `label_len/2` from x after the transform, which can shift the label leftward into a node
3. **No label-label deconfliction**: Two edges from the same source with precomputed positions could have their labels computed independently in dagre space, but overlap after transformation

### Adding Collision Avoidance Would Be Low-Risk, Moderate-Benefit

- **Low risk**: If dagre positions are correct, `find_safe_label_position` returns the base position unchanged (no shift needed)
- **Moderate benefit**: Catches transform-layer imprecision and centering artifacts
- **Not a fix**: It would mask upstream bugs rather than fix them. The real fix is ensuring `transform_label_positions_direct()` produces correct positions

## Key Takeaways

- Precomputed labels intentionally skip collision avoidance based on the design assumption that dagre positions are correct by construction. This is a deliberate architectural choice, not an oversight.
- `draw_label_at_position()` has only per-cell `is_node` protection. It lacks node bounding-box avoidance, edge cell protection, label-label deconfliction, and position shifting -- all of which `draw_edge_label_with_tracking()` provides.
- Adding `find_safe_label_position()` to the precomputed path would be a safe defensive measure: it returns the base position unchanged when no collision exists, so correct positions are unaffected.
- The centering adjustment (`x - label_len/2`) inside `draw_label_at_position()` is a potential source of misalignment -- if the precomputed position is already a center point, this double-centers the label.
- Backward edges were explicitly given collision avoidance (commit `719ff00`) because their positions come from routing rather than dagre layout, establishing a precedent that non-dagre positions need collision protection.
- The real fix for label overlap in the precomputed path belongs in the transform layer (`transform_label_positions_direct`), not the render layer. Collision avoidance is a safety net, not a solution.

## Open Questions

- Is the centering adjustment in `draw_label_at_position()` (`x.saturating_sub(label_len / 2)`) correct? If `transform_label_positions_direct()` already returns a center point, this shifts the label further left than intended.
- Should `placed_labels` tracking apply symmetrically? Currently, precomputed labels are added to `placed_labels` (line 752-754) so heuristic labels avoid them, but precomputed labels don't check `placed_labels` themselves.
- Would a hybrid approach work better -- use the precomputed position as the base, but run it through `find_safe_label_position()` as a safety net? This preserves dagre's structural intent while catching transform-layer errors.
- How does the LR/RL overlap issue from this research relate? If the precomputed x position for an LR label lands inside a node due to cross-axis scaling error, collision avoidance would shift it, but the shift might not produce a visually good result (e.g., shifting a label meant to be between two nodes to above them).
