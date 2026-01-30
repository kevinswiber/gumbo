# Q2: How does BK algorithm produce node stagger for skip edges?

## Summary

The Brandes-Kopf algorithm in mmdflux positions all nodes in the same layer at identical x-coordinates because the vertical alignment process treats dummy nodes and real nodes equally, grouping them into the same "blocks" with no separation logic. dagre.js implements a more sophisticated approach where dummy node chains implicitly create separation constraints between blocks via a **block graph**. mmdflux's `place_block()` only enforces separation based on immediate left neighbors in the same layer, not across block boundaries created by dummy node topology.

## Where

**Key files investigated:**
- `src/dagre/bk.rs` — BK implementation (lines 501-593 for vertical_alignment, 694-769 for place_block)
- `src/dagre/position.rs` — Coordinate assignment (calls position_x at line 52)
- `src/dagre/normalize.rs` — Dummy node creation (lines 196-321)
- `tests/fixtures/double_skip.mmd` and `skip_edge_collision.mmd`

## What

### 1. Vertical Alignment Block Formation (bk.rs:501-593)

`vertical_alignment()` creates 4 alignments (UL, UR, DL, DR). Each sweep processes layers and aligns each node with its median neighbor:

```rust
// Line 571-582
alignment.align.insert(m, v);           // m aligns with v
alignment.root.insert(v, m_root);       // v shares m's root
alignment.align.insert(v, m_root);      // v points back to root
```

All nodes in the same "block" share a root and get the **same x-coordinate** in compaction.

For double_skip.mmd (A->B, B->C, C->D, A->C, A->D):
- After ranking: A(0), B(1), C(2), D(3)
- After normalization: A->C creates dummy D0 at rank 1; A->D creates D1, D2 at ranks 1, 2
- Vertical alignment UL (top-to-bottom): B aligns with A, C aligns with B, D aligns with C
- **Result: All real nodes end up in the same block with A as root**

### 2. Dummy Nodes Not Treated Specially (bk.rs:263-275)

`get_neighbors()` treats dummy nodes as regular nodes. A dummy D0 between A and C:
- Has its own rank and order
- Has predecessors/successors (A and C)
- Can be aligned into the same block as real nodes
- **Does NOT force separation between adjacent real nodes**

### 3. Horizontal Compaction Only Enforces Left-Neighbor Separation (bk.rs:694-769)

`place_block()` only looks at the immediate left neighbor in each layer. If all real nodes are in the same block, they all get placed at x=0 (no separation needed within a block).

```rust
// Line 724-767: Only enforces min separation from left neighbor's block
if left_root != root {
    let min_separation = (left_width + node_width) / 2.0 + sep;
    // ... enforce min_x
}
```

### 4. Missing Block Graph Construction

dagre.js (and the BK paper) uses a **block graph** approach:
1. Vertical alignment creates blocks
2. A new graph is constructed where **nodes are blocks** and **edges represent dummy chain topology**
3. Compaction runs on the block graph, not individual nodes
4. This naturally forces blocks apart when dummy chains separate them

**mmdflux has no block graph.** It compacts individual nodes layer-by-layer, so:
- Dummy nodes and real nodes in the same block get the same x
- No mechanism to "spread out" blocks connected by dummy chains
- Stagger only occurs accidentally if dummy nodes end up in different blocks

## How

### The BK pipeline in mmdflux (position_x at bk.rs:940-959):

1. Find conflicts (Type-1: non-inner edges crossing inner edges; Type-2: inner edges crossing each other)
2. Compute 4 alignments: for each direction, call `vertical_alignment()` then `horizontal_compaction()`
3. Select smallest width
4. Align others to smallest's bounds
5. Balance (median of 4 alignments)

### Why stagger doesn't happen:

In `vertical_alignment()` for UL (top-to-bottom, left bias):
- Layer 1 has B and dummy D0
- B has predecessor A, D0 has predecessor A (via dummy chain)
- B aligns with A; D0 stays in its own block (or aligns with a dummy parent)
- **In compaction:** both blocks end up adjacent with minimal separation — no logic says "D0 is a dummy between A and C, so separate their blocks"

### What should happen (dagre.js approach):

After `vertical_alignment()`:
- Create a "block graph" where nodes are block roots
- For each dummy chain (A->D0->C), add edges in the block graph between roots
- Run compaction on the block graph
- Forces blocks containing A and C to be separated by the block containing D0

## Why

**Design choice:** mmdflux implemented the core BK algorithm (4 alignments, conflict detection, left-neighbor compaction) which works for many graphs. The block graph refinement is an additional sophistication in dagre.js that specifically improves skip-edge aesthetics.

**Impact:** Skip edges (spanning multiple ranks) are common in flowcharts. Without stagger, they route along node borders, merging visually with nodes they pass. The block graph approach uses topology to guide separation.

**Why it wasn't implemented:** Adds complexity to the compaction phase. The current implementation correctly handles crossing prevention via conflicts. Stagger is an aesthetic improvement, not a correctness requirement — but it significantly impacts readability for skip-edge-heavy diagrams.

## Key Takeaways

- Vertical alignment merges real and dummy nodes into the same blocks, preventing horizontal stagger
- Horizontal compaction has no block graph, so it can't enforce separation between blocks connected by dummy chains
- `get_neighbors()` is correct as-is; the issue is architectural (missing block graph), not in neighbor selection
- `place_block()` correctly enforces left-neighbor separation, but nothing separates nodes within one block
- Type-1/Type-2 conflict detection prevents crossings but doesn't encourage separation
- **The fix requires:** building a block graph from vertical alignment results, computing separation constraints on it, and re-assigning x-coordinates based on block positions — a significant architectural change to `bk.rs`

## Open Questions

- Exactly how does dagre.js build and use its block graph? (Requires reading dagre.js coordinate.js source)
- Could a simpler fix prevent real node endpoints of dummy chains from aligning in `vertical_alignment()`?
- How much does the order (position in layer) of dummy nodes matter? Is ordering the real bottleneck?
- Is the issue primarily in BK, or does crossing reduction (`order.rs`) fail to properly position dummies?
- Could a post-BK "nudge" pass apply stagger without a full block graph rewrite?
