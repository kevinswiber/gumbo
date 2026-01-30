# Q5: Coordinate Assignment (Brandes-Kopf)

## Summary

mmdflux's `bk.rs` (2,288 LOC) is far larger than Dagre.js's `bk.js` (429 LOC), but the size difference is overwhelmingly due to Rust verbosity, extensive inline tests (~1,248 lines of tests vs ~1,040 lines of production code), and explicit data structures that Dagre.js handles with plain JS objects. The two implementations follow the same high-level algorithm -- four alignment passes, conflict detection, block graph compaction, and median balance -- with structurally equivalent logic. The key algorithmic difference is that mmdflux's conflict detection uses a different (less faithful) approach than Dagre.js's scanning algorithm from the original paper, and mmdflux's separation function omits Dagre.js's `labelpos` adjustment for edge labels.

## Where

- mmdflux: `/Users/kevin/src/mmdflux/src/dagre/bk.rs` (2,288 lines; ~1,040 production, ~1,248 tests)
- mmdflux: `/Users/kevin/src/mmdflux/src/dagre/position.rs` (377 lines; coordinate assignment driver)
- Dagre.js: `/Users/kevin/src/dagre/lib/position/bk.js` (429 lines; all production code)
- Dagre.js: `/Users/kevin/src/dagre/lib/position/index.js` (41 lines; y-coordinate assignment)
- Plan 0022: `/Users/kevin/src/mmdflux/plans/0022-bk-block-graph-compaction/` (block graph refactor)

## What

### Size Breakdown

| Component | mmdflux LOC | Dagre.js LOC | Notes |
|-----------|-------------|--------------|-------|
| Production code | ~1,040 | ~429 | mmdflux has explicit types, doc comments, helper fns |
| Inline tests | ~1,248 | 0 | Dagre.js tests are in separate test files |
| position driver | 377 | 41 | mmdflux handles LR/RL axis swap, margin, reversal |
| **Total** | **2,665** | **470** | 5.7x ratio total, 2.4x ratio production-only |

### Structural Correspondence

Both implementations follow the same Brandes-Kopf pipeline:

1. **Conflict detection** (Type-1 and Type-2)
2. **Four alignment passes** (UL, UR, DL, DR)
3. **Horizontal compaction** via block graph
4. **Alignment coordination** to smallest width
5. **Balance** via median of four results

### Detailed Differences

#### 1. Conflict Detection -- Different Algorithm

**Dagre.js** (`findType1Conflicts`, lines 41-81): Uses the paper's scanning algorithm. It processes each layer left-to-right, tracking the last inner-segment boundary (`k0`). When it encounters a node incident on an inner segment, it scans backwards through the window to find non-inner edges that cross the boundary. This is an O(n) sweep per layer pair.

**mmdflux** (`find_type1_conflicts`, lines 359-408): Uses a different approach. It first collects all inner segments between a layer pair, then iterates all non-inner edges and checks each against every inner segment using `segments_cross()`. This is O(e * i) per layer pair where e = edges and i = inner segments.

**mmdflux** also stores conflicts differently. Dagre.js uses a nested object `conflicts[v][w] = true` keyed by node IDs. mmdflux uses a `ConflictSet = HashMap<(layer, pos1, pos2), Conflict>` keyed by layer and position tuples.

**Dagre.js** (`findType2Conflicts`, lines 83-127): Scans for border nodes (compound graph feature) and checks dummy-to-dummy crossings within border regions. mmdflux's `find_type2_conflicts` (lines 414-442) does an O(i^2) pairwise check of all inner segments for crossings, ignoring border nodes entirely (mmdflux has no compound graph support).

The `has_conflict` function also differs: Dagre.js does O(1) lookup by node pair; mmdflux iterates all conflict keys checking if any fall within a position range (O(|conflicts|) per call).

#### 2. Vertical Alignment -- Structurally Equivalent

Both implementations follow the same logic:

- Process layers in sweep order (top-down for UL/UR, bottom-up for DL/DR)
- For each node, find median neighbor(s)
- Attempt alignment if no conflict and ordering constraint satisfied
- Update root/align chain

**Dagre.js** (lines 166-204): Uses `pos` cache, processes both medians for even neighbor count by iterating `floor(mp)` to `ceil(mp)`.

**mmdflux** (lines 490-582): Uses a dedicated `get_medians()` helper that returns 1 or 2 candidates ordered by preference. Logic is equivalent.

Minor difference: mmdflux processes nodes in reversed order for right-preferring alignments (`prefer_left` flag controls iteration direction). Dagre.js instead reverses the entire layer arrays before calling `verticalAlignment`.

#### 3. Horizontal Compaction -- Now Equivalent (Post Plan 0022)

Both implementations use the same block graph approach:

**Dagre.js** (`horizontalCompaction`, lines 206-264): Builds a block graph, then does two passes. Pass 1 assigns smallest coordinates (sources first). Pass 2 assigns greatest coordinates (sinks first), skipping border nodes matching `borderType`. Uses a manual DFS-based iteration with a stack.

**mmdflux** (`horizontal_compaction`, lines 629-703): Builds block graph via `build_block_graph()`, does two passes using Kahn's topological sort. Pass 1: longest-path from sources. Pass 2: reverse topological, pull right. Does not implement the `borderType` guard (no compound graph support).

Plan 0022 specifically refactored mmdflux from a recursive `place_block()` approach to this block graph approach. The finding from Plan 0022 was that Pass 2 is mathematically a no-op for simple DAGs (without compound/border nodes), making the refactor a structural improvement with no behavioral change.

**Block graph construction** is structurally identical: iterate layers, for each adjacent pair with different block roots, add an edge with separation weight. Duplicate edges are merged by max weight.

#### 4. Separation Function -- Dagre.js Has labelpos Handling

**Dagre.js** `sep()` (lines 389-425): Computes center-to-center separation. Includes `labelpos` adjustments -- when a node has a `labelpos` of "l" or "r", the separation is adjusted by +/- half the node width. The `reverseSep` parameter flips the adjustment direction for right-biased alignments.

**mmdflux** `compute_sep()` (lines 807-813): Simpler formula: `left_width/2 + (left_sep + right_sep)/2 + right_width/2`. No `labelpos` handling. The averaging of left/right separation is a minor formula difference from Dagre.js which sums `(left_dummy ? edgeSep : nodeSep) / 2` and `(right_dummy ? edgeSep : nodeSep) / 2` separately (mathematically equivalent to mmdflux's approach).

#### 5. Balance and Alignment Coordination -- Equivalent

Both find the smallest-width alignment, shift all alignments to match its bounds (left-biased align left edges, right-biased align right edges), then take median of 4 values per node.

Dagre.js `balance()` supports an optional `align` parameter to select a single alignment instead of median. mmdflux always uses median (no single-alignment override).

#### 6. Y-Coordinate Assignment (position driver)

**Dagre.js** `position()` / `positionY()` (index.js): Simple -- accumulates Y by max layer height + rankSep. Supports `rankalign` (top/bottom/center within layer).

**mmdflux** `position::run()` (position.rs): More complex. Handles four directions (TD, BT, LR, RL) by swapping axes. For LR/RL, BK optimizes the y-axis (perpendicular to rank). Includes post-BK centering of layer-0 source nodes (lines 98-119) -- this is mmdflux-specific logic to center root nodes among their successors for horizontal layouts. Also handles direction reversal (BT/RL) by flipping coordinates.

## How

### Four Alignment Passes

Both implementations compute four alignments by varying:
- **Sweep direction**: top-to-bottom (U) or bottom-to-top (D)
- **Neighbor preference**: left median (L) or right median (R)

Dagre.js achieves the four variants by reversing the layering array (for D) and reversing each layer (for R), then negating x-coordinates for R alignments. mmdflux uses an `AlignmentDirection` enum and handles direction within the alignment function itself.

### Block Placement (Horizontal Compaction)

1. Build block graph: nodes = block roots, edges = separation constraints from adjacent pairs in each layer
2. Pass 1 (smallest coordinates): topological order, `x[node] = max(x[pred] + weight, 0)`
3. Pass 2 (greatest coordinates): reverse topological order, `x[node] = max(x[node], min(x[succ] - weight))`
4. Propagate root coordinates to all block members

### Conflict Detection

Type-1: non-inner segment crosses inner segment (long edge). Dagre.js uses paper's sweep; mmdflux uses brute-force pairwise check.

Type-2: inner segment crosses inner segment. Both check pairwise, but Dagre.js restricts to border regions (compound graphs).

## Why

### Why mmdflux is larger

1. **Tests (1,248 lines)**: 54% of bk.rs is inline unit tests covering helpers, conflict detection, alignment, compaction, block graph construction, and separation. Dagre.js tests are in separate files not counted here.

2. **Explicit types and structures**: mmdflux defines `Conflict`, `ConflictSet`, `BlockAlignment`, `CompactionResult`, `AlignmentDirection`, `BKConfig`, `BlockGraph` as explicit types with methods. Dagre.js uses plain objects and arrays.

3. **Helper functions**: mmdflux has ~14 small helper functions (`get_layers`, `get_predecessors`, `get_successors`, `get_neighbors`, `get_position`, `get_layer`, `is_dummy`, `get_width`, `segments_cross`, `is_inner_segment`, `find_inner_segments`, `get_medians`, `separation_for`, `compute_sep`). Dagre.js uses inline code or relies on graphlib methods.

4. **Doc comments**: Extensive documentation on every public function and type.

5. **Direction handling**: mmdflux's `get_width()` swaps between width/height based on layout direction (LR/RL vs TD/BT), which Dagre.js handles upstream.

6. **Plan 0022 additions**: The `BlockGraph` struct with `topological_order()`, `add_edge()` with max-weight merging, and the two-pass compaction loop replaced the earlier `place_block()` recursion.

### Design tradeoffs

- mmdflux's conflict detection is simpler to understand but less efficient (O(e*i) vs O(n) per layer). For small flowcharts this is irrelevant.
- mmdflux lacks `labelpos` support, which means edge labels positioned left/right would not get correct spacing. This is a missing feature, not a bug for current usage.
- mmdflux's `position.rs` contains direction-aware logic that Dagre.js doesn't need (Dagre.js always layouts in one direction and rotates externally).

## Key Takeaways

- The 2,288 vs ~430 LOC difference is misleading: production code is ~1,040 lines (2.4x), and much of the difference is Rust's type system, doc comments, and explicit helper functions vs Dagre.js's terser JS style.
- The core algorithm is equivalent: four BK alignments, block graph compaction, median balance. Plan 0022 brought the compaction approach to match Dagre.js exactly.
- Three algorithmic gaps exist: (1) conflict detection uses brute-force instead of the paper's sweep, (2) no `labelpos` separation adjustment, (3) no `borderType` guard in Pass 2 (compound graph feature).
- mmdflux adds direction-aware logic in `position.rs` (LR/RL axis swap, post-BK source centering, coordinate reversal) that Dagre.js handles differently or not at all.
- Plan 0022 discovered that Pass 2 of block graph compaction is mathematically a no-op for non-compound graphs -- the refactor improved code structure but had no behavioral effect.

## Open Questions

- Should the conflict detection algorithm be replaced with the paper's sweep algorithm for correctness on larger graphs, or is the brute-force approach sufficient for mmdflux's text-rendering use case?
- Is the missing `labelpos` separation handling causing any visible issues with edge label positioning? mmdflux may handle label offsets differently in the rendering layer.
- If compound graph support is ever added, Pass 2's `borderType` guard will need implementation -- is this tracked?
- The `has_conflict` function iterates all conflict keys on each call. For graphs with many conflicts, this could be a performance issue. Should it be changed to match Dagre.js's O(1) lookup?
