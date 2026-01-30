# Q3: What Does Dagre Actually Compute for the Overlapping Cases?

## Summary

For the `double_skip.mmd` graph, both JS dagre and mmdflux's dagre produce the **same x-coordinate** for all dummy nodes of edges A->C and A->D at each shared rank, because they share the same vertical alignment block (aligned through A). This means the waypoints for these two long edges are **identical in the cross-axis**, and when `calculate_attachment_points()` uses those waypoints to compute where edges enter nodes C and D, both the direct edge B->C and the skip-edge A->C converge to the same attachment point on C's top edge. The information needed for spreading was **never produced** by dagre's coordinate assignment -- it would require the crossing-reduction ordering to separate the dummy nodes of A->C from B (and A->D's dummies from both B and C's dummies), but the Brandes-Kopf algorithm aligns them into the same block.

## Where

Sources consulted:
- `/Users/kevin/src/mmdflux/src/dagre/normalize.rs` -- dummy node creation for long edges
- `/Users/kevin/src/mmdflux/src/dagre/order.rs` -- crossing reduction (barycenter heuristic)
- `/Users/kevin/src/mmdflux/src/dagre/bk.rs` -- Brandes-Kopf coordinate assignment
- `/Users/kevin/src/mmdflux/src/dagre/position.rs` -- coordinate assignment entry point
- `/Users/kevin/src/mmdflux/src/dagre/mod.rs` -- full layout pipeline
- `/Users/kevin/src/mmdflux/src/render/layout.rs` -- dagre-to-draw coordinate transformation
- `/Users/kevin/src/mmdflux/src/render/router.rs` -- edge routing using waypoints
- `/Users/kevin/src/mmdflux/src/render/intersect.rs` -- attachment point calculation
- `/Users/kevin/src/dagre/lib/normalize.js` -- JS dagre normalization
- `/Users/kevin/src/dagre/lib/position/index.js` -- JS dagre position entry point
- `/Users/kevin/src/dagre/lib/position/bk.js` -- JS dagre Brandes-Kopf implementation
- `/Users/kevin/src/dagre/lib/layout.js` -- JS dagre `assignNodeIntersects()`
- `/Users/kevin/src/dagre/lib/util.js` -- JS dagre `intersectRect()`

## What

### The Double-Skip Graph Structure

```
graph TD
    A[Start] --> B[Step 1]
    B --> C[Step 2]
    C --> D[End]
    A --> C         (skip edge, spans 2 ranks)
    A --> D         (double skip edge, spans 3 ranks)
```

After ranking: A=rank 0, B=rank 1, C=rank 2, D=rank 3.

### Phase 1: Normalization -- Dummy Node Creation

The normalization phase (`normalize.rs`, lines 196-321) inserts dummy nodes for long edges:

- **Edge A->C** (spans ranks 0->2): 1 dummy node inserted at rank 1. Call it `_dAC1`.
- **Edge A->D** (spans ranks 0->3): 2 dummy nodes inserted at ranks 1 and 2. Call them `_dAD1` (rank 1) and `_dAD2` (rank 2).

After normalization, the rank structure is:
```
Rank 0: [A]
Rank 1: [B, _dAC1, _dAD1]     (3 nodes)
Rank 2: [C, _dAD2]             (2 nodes)
Rank 3: [D]
```

All dummy nodes have **width=0, height=0** (line 70-71 of `normalize.rs`).

### Phase 2: Ordering -- Crossing Reduction

The `order::run()` function (order.rs, lines 110-171) uses the barycenter heuristic with DFS-based initial ordering.

**Initial ordering (DFS):** Starting from A (rank 0), DFS explores successors. A's successors (in effective edge order) include B, _dAC1, and _dAD1 (since chain edges replace the originals). DFS from A visits:
- B (rank 1, order 0), then B's successors: C (rank 2, order 0), then C's successor: D (rank 3, order 0)
- Back to A's other successors: _dAC1 (rank 1, order 1), then _dAD1 (rank 1, order 2)
- _dAC1's successor: C (already visited)
- _dAD1's successor: _dAD2 (rank 2, order 1), _dAD2's successor: D (already visited)

Initial order:
```
Rank 0: [A=0]
Rank 1: [B=0, _dAC1=1, _dAD1=2]
Rank 2: [C=0, _dAD2=1]
Rank 3: [D=0]
```

**Barycenter sweeps:** During sweep_down from rank 0 to lower ranks:
- Rank 1 nodes connected to rank 0 (all connected to A at order 0): barycenter of B = 0.0, barycenter of _dAC1 = 0.0, barycenter of _dAD1 = 0.0. **All three have equal barycenters.** Tie-breaking uses original position, so order stays: B=0, _dAC1=1, _dAD1=2.

- Rank 2 nodes connected to rank 1: C is connected to B(order 0) and _dAC1(order 1), barycenter = 0.5. _dAD2 is connected to _dAD1(order 2), barycenter = 2.0. So C=0, _dAD2=1. This is fine.

- Rank 3: D connected to C(order 0) and _dAD2(order 1), barycenter = 0.5. Only node, so D=0.

Final ordering after all sweeps:
```
Rank 0: [A=0]
Rank 1: [B=0, _dAC1=1, _dAD1=2]
Rank 2: [C=0, _dAD2=1]
Rank 3: [D=0]
```

**This ordering is correct and gives crossing-free layout.** The dummy nodes for A->C and A->D are placed to the right of B in rank 1, which is correct.

### Phase 3: Coordinate Assignment -- Brandes-Kopf

The `bk.rs` `position_x()` function (line 925) computes x-coordinates as:

1. **Conflict detection:** Between ranks 0-1, the inner segments are edges connecting dummy-to-dummy pairs. In rank 0->1, only one inner segment candidate exists: none (rank 0 only has real node A). Between ranks 1->2, the inner segment is `_dAD1 -> _dAD2` (both dummies). No non-inner segments cross it. So **no conflicts detected**.

2. **Vertical alignment (4 directions):** For UL (downward, prefer left):
   - Rank 1: B's predecessors = [A(order 0)], median = A. Align B with A. Root of B = A.
   - _dAC1's predecessors = [A(order 0)], median = A. But A is already aligned to B (prevIdx = 0, and A's order = 0, so prevIdx < pos[A] fails since 0 < 0 is false). **_dAC1 cannot align with A** -- it stays as its own block.
   - _dAD1's predecessors = [A(order 0)], median = A. Same: prevIdx = 0, pos[A] = 0, 0 < 0 is false. **_dAD1 cannot align with A** either.
   - Rank 2: C's predecessors = [B(order 0), _dAC1(order 1)], medians (prefer left, even count) = [B, _dAC1]. Try B first: prevIdx = -1, pos[B] = 0, -1 < 0 = true. Align C with B. Root of C = root of B = A. Block: {A, B, C}.
   - _dAD2's predecessors = [_dAD1(order 2)]. Align _dAD2 with _dAD1. Block: {_dAD1, _dAD2}.
   - Rank 3: D's predecessors = [C(order 0), _dAD2(order 1)]. Medians = [C, _dAD2]. Try C first: prevIdx = -1, pos[C] = 0, -1 < 0 = true. Align D with C. Root of D = root of C = A. Block: {A, B, C, D}.

   UL blocks: **{A, B, C, D}** (one block at x=0), **{_dAC1}** (separate block), **{_dAD1, _dAD2}** (separate block).

3. **Horizontal compaction:** For the UL alignment:
   - Block {A, B, C, D} gets x = 0 (root A, first block).
   - Block {_dAC1} at rank 1, order 1: left neighbor is B (root A, x=0). Separation = width(B)/2 + width(_dAC1)/2 + node_sep = 50 + 0 + 50 = 100 (**in mmdflux**; in JS dagre with edgeSep=20: 50 + 0 + (50+20)/2 = 50 + 35 = 85). So _dAC1 gets x = 0 + 100 = 100.
   - Block {_dAD1, _dAD2} at rank 1, order 2: left neighbor of _dAD1 is _dAC1 (root _dAC1, x=100). Separation = width(_dAC1)/2 + width(_dAD1)/2 + node_sep = 0 + 0 + 50 = 50 (**in mmdflux**; in JS dagre: 0 + 0 + 20 = 20). So _dAD1 gets x = 100 + 50 = 150.
   - _dAD2 is in same block as _dAD1, gets x = 150.

4. **After balancing across all 4 alignments:** The median of UL, UR, DL, DR determines final x. The exact values depend on all four alignments, but the key structural point is: **A, B, C, D are all in the same vertical block (same x)**, and the dummy nodes are offset to the right.

### Phase 4: Waypoint Extraction (Denormalization)

`normalize::denormalize()` (lines 331-364) extracts waypoints from dummy positions:

- **Edge A->C (edge index 4):** Waypoint at position of _dAC1 = (x=100, y at rank 1).
- **Edge A->D (edge index 5):** Waypoints at _dAD1 = (x=150, y at rank 1) and _dAD2 = (x=150, y at rank 2).

### Phase 5: Attachment Point Calculation

The render pipeline (`render/layout.rs` `compute_layout_dagre()`) transforms dagre coordinates to ASCII draw coordinates, then the router uses waypoints to compute attachment points.

For a TD layout, `calculate_attachment_points()` (`intersect.rs`, lines 152-177) does:

- **Source attachment:** `intersect_node(source_bounds, first_waypoint, source_shape)`
- **Target attachment:** `intersect_node(target_bounds, last_waypoint, target_shape)`

For edges entering node C:
1. **B->C (direct edge):** No waypoints. Source attach = intersect(B, C_center). Target attach = intersect(C, B_center). B and C are vertically aligned (same x block), so target attachment = C's **top center**.
2. **A->C (via waypoint _dAC1):** Last waypoint for A->C is _dAC1's position (x=100 in dagre space, mapped to some draw x). Target attach = intersect(C, _dAC1_draw_position). Since _dAC1 is to the right of C's center, the intersection is on C's **top edge but shifted right**.

For edges entering node D:
1. **C->D (direct edge):** No waypoints. Target attach = D's **top center**.
2. **A->D (via waypoints _dAD1, _dAD2):** Last waypoint is _dAD2's position (x=150 in dagre, mapped to draw space). Target attach = intersect(D, _dAD2_draw_position). Since _dAD2 is to the right, intersection is on D's **top edge but shifted right**.

### What the ASCII Output Actually Shows

Running `cargo run -q -- tests/fixtures/double_skip.mmd` produces:

```
      +-------+
      | Start |
      +-------+
         |  +--+
      +--+     |
      v        |
+--------+     |
| Step 1 |     |
+--------+-----+
      |  |     |
      +| |     |
       v v     |
  +--------+   |
  | Step 2 |   |
  +--------+---+
        | |
        +||
         vv
      +-----+
      | End |
      +-----+
```

The overlapping arrows (`vv`) at nodes C ("Step 2") and D ("End") show that two edges arrive at adjacent but very close attachment points. The `v v` at Step 2 and `vv` at End demonstrate that while the waypoints do give _different_ x-coordinates for the skip edges vs. direct edges, the **discrete ASCII grid collapses them to adjacent cells**, and the resulting visual distinction is minimal.

### Comparison: JS Dagre vs. mmdflux Dagre

| Aspect | JS Dagre | mmdflux Dagre |
|--------|----------|---------------|
| Dummy node width | 0 | 0 |
| Separation between adjacent dummies | edgeSep (default 20) | node_sep (50) |
| Separation dummy-to-real-node | (nodeSep + edgeSep) / 2 = 35 | node_sep (50) |
| Block alignment algorithm | Same Brandes-Kopf | Same Brandes-Kopf |
| Dummy x-coordinates | Different from main chain | Different from main chain |
| Waypoint extraction | `undo()` collects `node.x, node.y` from dummies | `denormalize()` collects `positions[dummy_idx]` |
| Intersection calculation | `intersectRect()` in post-processing (`assignNodeIntersects`) | `intersect_rect()` / `intersect_node()` in render |
| `assignNodeIntersects` equivalent | Runs on all edges after layout, using first/last waypoint to compute source/target boundary intersection | `calculate_attachment_points()` in `intersect.rs` does the same |

**Key structural difference:** JS dagre uses `edgeSep` (20, smaller) between dummy nodes, while mmdflux uses `node_sep` (50, larger). This means in JS dagre, dummy nodes for parallel long edges are **closer together** (20px apart) vs. mmdflux (50 dagre-units apart). However, both produce dummy nodes at **different x-coordinates** for different long edges' dummy chains at the same rank.

**The algorithms are structurally equivalent** -- both produce distinct x-coordinates for dummy nodes of different long edges. The difference is in spacing magnitude, not in kind.

## How

### Step-by-step Algorithm Trace for double_skip.mmd

**Input graph:**
- Nodes: A(Start), B(Step 1), C(Step 2), D(End)
- Edges: A->B (idx 0), B->C (idx 1), C->D (idx 2), A->C (idx 3), A->D (idx 4)

**Step 1: Acyclic** -- No cycles, no changes.

**Step 2: Ranking** -- Longest path: A=0, B=1, C=2, D=3.

**Step 3: Normalize** -- normalize::run():
- Edge A->C (rank 0 -> rank 2): insert _dAC1 at rank 1, width=0, height=0.
  - New edges: A->_dAC1, _dAC1->C (both with orig_idx=3)
- Edge A->D (rank 0 -> rank 3): insert _dAD1 at rank 1, _dAD2 at rank 2, width=0, height=0.
  - New edges: A->_dAD1, _dAD1->_dAD2, _dAD2->D (all with orig_idx=4)
- Original edges A->C and A->D are removed; A->B, B->C, C->D remain.

**Post-normalization edges:**
- A->B (idx 0), B->C (idx 1), C->D (idx 2)
- A->_dAC1, _dAC1->C (chain for edge 3)
- A->_dAD1, _dAD1->_dAD2, _dAD2->D (chain for edge 4)

**Step 4: Order** -- init_order + barycenter sweeps:

Rank 1 has [B, _dAC1, _dAD1]. All three have A as their sole predecessor at order 0. Barycenters are all 0.0. Tie-breaking preserves insertion/DFS order: B=0, _dAC1=1, _dAD1=2.

Rank 2 has [C, _dAD2]. C's predecessors in rank 1: B(0), _dAC1(1) -> barycenter 0.5. _dAD2's predecessor: _dAD1(2) -> barycenter 2.0. Order: C=0, _dAD2=1.

Rank 3 has [D]. D's predecessors in rank 2: C(0), _dAD2(1) -> barycenter 0.5. Only node, D=0.

**Step 5: BK Position Assignment (UL alignment trace):**

Processing layers top-to-bottom, prefer-left:

_Layer 1 (rank 1):_
- B: neighbors (preds) = [A], median = A. align[B] not yet set. No conflict. prevIdx = -1, pos[A] = 0, -1 < 0 -> align. Block {A, B}. prevIdx = 0.
- _dAC1: neighbors = [A], median = A. align[_dAC1] not yet set. prevIdx = 0, pos[A] = 0, 0 < 0 = false -> **SKIP**. _dAC1 remains its own block.
- _dAD1: neighbors = [A], median = A. Same: 0 < 0 = false -> **SKIP**.

_Layer 2 (rank 2):_
- C: neighbors = [B, _dAC1], medians (prefer-left, even) = [B, _dAC1]. Try B: prevIdx = -1, pos[B] = 0, -1 < 0 -> align. Block {A, B, C}. prevIdx = 0.
- _dAD2: neighbors = [_dAD1], median = _dAD1. prevIdx = 0, pos[_dAD1] = 2, 0 < 2 -> align. Block {_dAD1, _dAD2}. prevIdx = 2.

_Layer 3 (rank 3):_
- D: neighbors = [C, _dAD2], medians (prefer-left, even) = [C, _dAD2]. Try C: prevIdx = -1, pos[C] = 0, -1 < 0 -> align. Block {A, B, C, D}. prevIdx = 0.

UL blocks: {A, B, C, D} at x=some_value, {_dAC1} at x=further_right, {_dAD1, _dAD2} at x=even_further_right.

**Compaction:**
- Block root A: x = 0 (placed first, no left neighbor).
- Block root _dAC1 (rank 1, order 1): left neighbor B (root A, x=0). sep = width(B)/2 + width(_dAC1)/2 + node_sep. With real node B having some width (e.g., 50 for "Step 1" label) and _dAC1 having width 0: sep = 25 + 0 + 50 = 75. _dAC1 x = 75.
- Block root _dAD1 (rank 1, order 2): left neighbor _dAC1 (x=75). sep = 0 + 0 + 50 = 50. _dAD1 x = 125.

After balancing 4 alignments, exact values differ, but the relative ordering is:
**A,B,C,D block center < _dAC1 center < _dAD1/_dAD2 center**

**Step 6: Waypoint extraction:**
- Edge A->C: waypoint at _dAC1's (x, y) position -> x is **to the right** of A/B/C/D main block.
- Edge A->D: waypoints at _dAD1 (rank 1) and _dAD2 (rank 2) -> both x even further right.

**Step 7: Draw coordinate transformation:**
`compute_layout_dagre()` transforms dagre coordinates to ASCII space using `compute_stagger_positions()` and `map_cross_axis()`. The stagger positions scale dagre's large separation (50-125 units) down to ASCII character spacing (a few characters). This compression dramatically reduces the visual separation between dummy waypoints and the main node positions.

**Step 8: Attachment point calculation:**
For edge B->C (direct): `calculate_attachment_points(B_bounds, Rect, C_bounds, Rect, &[])` -> both attach at top/bottom center (vertically aligned).

For edge A->C (via _dAC1 waypoint): `calculate_attachment_points(A_bounds, Rect, C_bounds, Rect, &[_dAC1_draw_pos])` -> target attachment uses `intersect_rect(C_bounds, _dAC1_draw_pos)`. Since _dAC1's draw x is to the right of C's center, the intersection slides right along C's top edge -- but only by 1-2 ASCII characters due to the compressed scaling.

**Result:** Both edges enter C from the top, but at slightly different x positions (center vs. slightly-right-of-center). In the ASCII grid, this produces the `v v` pattern visible in the output.

## Why

### The Core Problem

Dagre's layout algorithm **does** produce different x-coordinates for dummy nodes of different long edges at the same rank. The A->C dummy and the A->D dummy at rank 1 have different positions (B=leftmost, _dAC1=middle, _dAD1=rightmost). This information **is present** in the dagre output.

However, there are **two stages where separation is lost**:

1. **Dagre-to-ASCII coordinate compression:** The `compute_stagger_positions()` function in `layout.rs` scales dagre's coordinate space (with separations of 50-125 units) down to ASCII space (with separations of 4-6 characters). A separation of 50 dagre units between _dAC1 and _dAD1 might map to only 1-2 ASCII characters, making the visual distinction minimal.

2. **Attachment point convergence:** Even with different waypoint x-positions, the `intersect_rect()` calculation maps the approach angle to a boundary point. When the node is small (5-8 chars wide) and the waypoint is not far off-center, the intersection point ends up at or very near the center of the top/bottom edge. The discrete ASCII grid (integer positions) means that a small angular difference rounds to the same cell.

### What JS Dagre Does Differently

JS dagre uses `assignNodeIntersects()` (layout.js line 266-283) which does **exactly the same thing** -- it computes `intersectRect(nodeV, p1)` and `intersectRect(nodeW, p2)` using the first/last waypoint as the approach point. So JS dagre would produce the same overlapping attachment points for this graph.

The key difference is that **JS dagre is designed for pixel-based SVG rendering**, where fractional coordinates are meaningful. A 0.5-pixel offset produces a visually distinct line. In ASCII rendering, fractional offsets are lost to integer rounding.

### The Missing `edgeSep` Configuration

One notable gap in mmdflux's dagre: JS dagre has a separate `edgeSep` parameter (default 20) used for spacing between dummy nodes (and between dummy and real nodes). mmdflux uses `node_sep` (50) for everything. This means mmdflux actually gives **more** separation between dummy nodes than JS dagre does (50 vs. 20). However, this larger separation is then compressed during the dagre-to-ASCII transformation, so the net effect is similar.

## Key Takeaways

- **Dagre DOES produce different positions for dummy nodes of different long edges.** The A->C dummy at rank 1 gets a different x-coordinate than the A->D dummy at rank 1 (offset by ~50 units in mmdflux's dagre space). This information is not lost during dagre computation -- it's present in the waypoints.

- **The information is lost during two subsequent stages:** (a) dagre-to-ASCII coordinate compression squashes large separations into 1-2 character differences, and (b) the intersection calculation on small ASCII nodes produces attachment points that are the same or adjacent cells.

- **JS dagre has the same fundamental limitation** for attachment point computation -- `assignNodeIntersects()` uses the same ray-intersection approach. The difference is that JS dagre outputs to pixel-space where sub-pixel differences produce visible line separation.

- **mmdflux is missing `edgeSep` configuration** -- JS dagre uses separate `nodeSep` (50) and `edgeSep` (20) values. The `sep()` function in `bk.js` (line 389-425) uses `edgeSep` for spacing involving dummy nodes. mmdflux uses a flat `node_sep` for all cases. This doesn't cause the overlapping problem but is a fidelity gap.

- **The Brandes-Kopf alignment constrains x-coordinates.** In the UL alignment, once B aligns with A, both _dAC1 and _dAD1 are **blocked from aligning with A** (the `prevIdx < pos[w]` check fails since A was already used at position 0). They form separate blocks, which get distinct x-coordinates. But across all 4 alignment directions, the median balancing may bring these coordinates closer together.

- **The overlapping problem is inherent to ASCII rendering** and cannot be fully solved by tweaking dagre parameters alone. A dedicated post-layout spreading pass is needed to ensure edges enter/exit nodes at visually distinct attachment points.

## Open Questions

- **Would increasing `edgeSep` help?** If mmdflux added a separate `edgeSep` parameter and set it to a larger value, would that produce enough ASCII-space separation to visually distinguish dummy waypoints? Probably not -- the compression step would still collapse the difference.

- **Could we bypass intersection calculation and directly assign attachment points?** Instead of computing ray-intersection from waypoint to node boundary (which depends on angles and rounds to discrete cells), we could enumerate incoming edges per node side and spread them evenly across the available boundary cells. This would guarantee visual separation regardless of dagre coordinates.

- **Does the `map_cross_axis()` function preserve enough fidelity?** The piecewise linear interpolation in `map_cross_axis()` (layout.rs line 1142-1220) maps dagre dummy positions through real-node anchor points. If no real node exists at the same rank as a dummy, the mapping falls back to global scale, which may further compress differences.

- **What happens with wider nodes?** For nodes with labels like "Authentication Service" (20+ chars), would the existing intersection calculation produce visually separated attachment points? The wider the node, the more boundary cells available, so the same angular difference could map to a 2-3 cell offset -- potentially sufficient.

- **Is the ordering optimal for spreading?** The current order [B=0, _dAC1=1, _dAD1=2] at rank 1 places dummies to the right of B. Would a different ordering (e.g., [_dAD1=0, B=1, _dAC1=2]) produce better visual separation? The barycenter heuristic determines this, and it may not optimize for attachment point diversity.
