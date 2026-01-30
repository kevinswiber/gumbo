# Q2: BK Block Graph for Full Stagger

## Summary

The key insight from Plan 0020's Phase 5 finding is that **mmdflux's BK implementation does correctly separate dummy nodes from real nodes via vertical alignment**, but the original prior research (Q2 from 0013) incorrectly concluded that a block graph was needed. However, the block graph *would* provide wider diagonal stagger by using a two-pass compaction algorithm (assign-smallest, then assign-greatest) that explicitly optimizes block separation constraints, whereas mmdflux uses single-pass left-neighbor compaction. Plan 0020 chose the correct fix (overhang offset propagation) over a full block graph rewrite because the overhang offset directly addresses the root cause, not the BK algorithm itself.

## Where

**Sources consulted:**
- `src/dagre/bk.rs` lines 501-593 (vertical_alignment), 694-769 (place_block), 940-959 (position_x)
- `src/dagre/position.rs` lines 41-82 (assign_vertical)
- Research document: `research/0013-visual-comparison-fixes/q2-bk-stagger-mechanism.md` (prior investigation)
- Plan finding: `plans/0020-visual-comparison-fixes/findings/skip-edge-waypoint-overhang-offset.md`
- dagre.js source: `lib/position/bk.js` (buildBlockGraph, horizontalCompaction, positionX)
- Brandes & Köpf 2001 paper reference

## What

### 1. How mmdflux's Current BK Works

mmdflux implements the full Brandes-Köpf algorithm with 4 alignment directions (UL, UR, DL, DR):

1. **Vertical alignment** (lines 501-593): Groups nodes into blocks where each block has a root and all nodes in the block share the same x-coordinate. Nodes align with median neighbors unless conflicts prevent it.

2. **Horizontal compaction** (lines 640-692): Single-pass recursive `place_block()` that assigns x-coordinates. For each block, it checks only the immediate left neighbor in the same layer and enforces separation.

3. **Balance**: Takes median of 4 alignment results for each node.

### 2. How dagre.js's Block Graph Works

dagre.js implements the BK algorithm with an additional refinement: **explicit block graph construction**:

1. **After vertical alignment**, it constructs a second graph where:
   - Nodes represent block roots (not individual nodes)
   - Edges connect adjacent blocks with weights based on separation requirements

2. **Two-pass compaction on the block graph**:
   - **Pass 1** (assign-smallest): depth-first sweep assigning minimum coordinates based on incoming edge constraints
   - **Pass 2** (assign-greatest): depth-first sweep removing unused space by maximizing coordinates based on outgoing constraints

3. **Propagate back**: block coordinates flow back to all nodes in each block via the `align` mapping.

### 3. Why The Prior Research Was Partially Incorrect

The prior research (0013 Q2) concluded that mmdflux's blocks force all nodes in a block to have identical x-coordinates, preventing stagger. This is technically true but **incomplete**:

- Plan 0020 Phase 5 diagnostic testing showed that BK *does* separate dummy nodes into different blocks (dummy _d0 at x=28.25, real nodes B/C/D at x=0-27.75 after balancing).
- The separation was computed correctly by BK (40 dagre-units center-to-center).
- The stagger disappeared because `compute_layout_direct()` applied the `max_overhang_x` offset to nodes but not to waypoints, destroying the separation.

**The fix applied**: propagate overhang to waypoints (not rewrite BK).

### 4. What Block Graph Would Provide

A block graph implementation in mmdflux would:

1. **Explicit separation graph**: Instead of just checking left-neighbor pairs, encode all separation constraints as edges in the block graph.

2. **Two-pass algorithm**:
   - Pass 1: maximize incoming constraints (push blocks left from their successors' requirements)
   - Pass 2: minimize outgoing constraints (pull blocks right to create gaps)

3. **Wider stagger**: The two-pass approach can create larger gaps between blocks because:
   - In mmdflux's single-pass, if block A's root is placed left-neighbor to block B's root, the separation is exactly `(w_A + w_B) / 2 + sep` — the minimum required.
   - In dagre's two-pass, Pass 1 assigns based on incoming (upper) constraints, then Pass 2 can *increase* the gap if there's outgoing (lower) space to claim.

4. **Dummy chain topology awareness**: The block graph can encode that dummy D0 → D1 → D2 chains should increase block separation proportionally, creating the diagonal stagger visible in Mermaid's output.

### 5. Comparison of Compaction Algorithms

**mmdflux's single-pass (place_block):**
```
For each block root (in layer order):
  x[root] = 0
  For each node in block:
    if left_neighbor exists and in different block:
      x[root] = max(x[root], x[left_root] + min_separation)
```

**dagre's two-pass on block graph:**
```
Pass 1 (assign-smallest):
  DFS from sources, push blocks right based on incoming edge constraints

Pass 2 (assign-greatest):
  DFS from sinks, pull blocks left based on outgoing edge constraints
  This creates larger gaps by exploiting slack (unused coordinate space)
```

## How

### The BK Algorithm Pipeline

In mmdflux (`position_x`, lines 940-959):

1. Find Type-1/Type-2 conflicts (edges crossing dummy chains)
2. Compute 4 alignments: `vertical_alignment()` then `horizontal_compaction()` for each
3. Find smallest width
4. Align all results to smallest's bounds
5. Return median of 4 alignments

The **conflict detection** (lines 363-482) correctly prevents alignments that would cause crossings with long edges (dummy chains). This is where stagger *should* be encouraged — by detecting that A→C (A→_d0→C) conflicts with B→D and therefore should separate blocks.

### Where the Gap Is

Our single-pass `place_block()` enforces:
- **Left-neighbor separation**: If block A is left of block B, enforce `x[B] >= x[A] + min_sep(A, B)`

But it doesn't optimize:
- **Downstream separation**: How much space B can claim below (in lower layers)
- **Block chain topology**: That dummy chains should use the entire available width to stagger

dagre.js optimizes both via the block graph:
- Edges in the block graph encode both upstream and downstream constraints
- Two-pass allows blocks to "settle" at positions that maximize spacing

### Why It Matters

For `stacked_fan_in.mmd` (A→B, A→C, A→D with long dummy chains):
- mmdflux places dummy nodes minimally (just enough to avoid crossing)
- dagre places them more spread out, creating the visual diagonal stagger

## Why

### Design Rationale in mmdflux

1. **Correctness First**: The single-pass compaction is sufficient to prevent edge crossings (via conflict detection). This is the hard requirement.

2. **Simplicity**: Single-pass recursion is easier to reason about and debug than two-pass DFS on a derived graph structure.

3. **Pragmatic Trade-off**: The overhang offset fix (Plan 0020) shows that the stagger issue wasn't in BK itself — it was in the layout transform. Fixing that was lower-cost than rewriting BK.

### Why Block Graph Is Architecturally Elegant

1. **Separation as a First-Class Concept**: The block graph makes separation constraints explicit as edges, not implicit in layer-by-layer iteration.

2. **Slack Exploitation**: Two-pass allows blocks to "move up" to claim available space, creating tighter layouts and better stagger.

3. **Dummy Chain Awareness**: Chains of dummy nodes naturally create edge weights in the block graph that encourage spreading.

### Why It Wasn't Implemented

1. **Higher Complexity**: Adding `buildBlockGraph()` requires:
   - Extracting block roots after vertical alignment
   - Constructing edges between adjacent blocks
   - Two-pass DFS on the block graph
   - Propagating block coordinates back to nodes

2. **Diminishing Returns**: For most flowcharts (fan patterns, simple chains), the conflict detection + single-pass compaction is adequate. The block graph provides only marginal improvement in stagger.

3. **Existing Bug Obscured the Issue**: The overhang offset bug masked BK's actual output, making the problem appear to be in BK rather than in the layout transform.

## Key Takeaways

- **BK Separation Is Working**: Vertical alignment correctly groups dummy and real nodes into separate blocks. The separation *is* computed and expressed in the 4 alignments.

- **Single-Pass vs. Two-Pass**: mmdflux uses single-pass left-neighbor compaction (minimum sufficient separation). dagre uses two-pass block graph compaction (maximum available separation given constraints).

- **Overhang Offset Was the Real Fix**: The waypoint transform bug (Plan 0020 Phase 5) was the direct cause of skip-edge collision. Fixing that was more efficient than a block graph rewrite.

- **Block Graph Would Improve Aesthetics, Not Correctness**: A block graph implementation would produce wider diagonal stagger and tighter overall layouts, but wouldn't fix the core crossing-prevention problem (conflicts already do that).

- **Architectural Lesson**: The BK algorithm is modular. The "block graph refinement" is an optimization layer that improves compactness and aesthetics without changing the core conflict-detection + alignment strategy.

## Open Questions

- Would a block graph implementation noticeably improve stagger on real-world flowcharts, or are the gains marginal for typical patterns?
- Could a post-BK "nudge" pass (like the collision nudge at layout.rs:495-516) apply stagger without a full block graph rewrite?
- Is there a simpler heuristic (e.g., "ensure dummy chains use at least N% of available width") that achieves similar results?
- How much of Mermaid's visual stagger comes from the block graph vs. other Mermaid-specific layout heuristics?
