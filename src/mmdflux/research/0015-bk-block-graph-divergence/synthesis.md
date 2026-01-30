# Research Synthesis: BK Block Graph Compaction — Why dagre.js Differs and Whether It Matters

## Summary

The five investigated differences between dagre.js's and mmdflux's BK horizontal coordinate assignment are either provably equivalent or irrelevant to mmdflux's use case. Right-biased coordinate negation (Q1) and layer/node reversal (Q4) are different implementation strategies that produce identical final coordinates thanks to the `align_to_smallest` normalization step. The borderType guard (Q2) is compound-graph-only logic that never fires for simple flowcharts. DFS vs BFS traversal order (Q3) is mathematically irrelevant because the compaction is a longest-path computation with a unique solution determined by DAG structure alone. Most surprisingly, the stagger fix (Q5) was never a BK algorithm issue at all — `saturating_sub` in the rendering pipeline was destroying correct BK output, and a coordinate-space translation fixed it.

## Key Findings

### 1. mmdflux's BK implementation is functionally equivalent to dagre.js for simple flowcharts

All four algorithmic differences (Q1-Q4) resolve to "provably equivalent" or "not applicable":

- **Q1 (negation):** dagre.js negates right-biased coordinates; mmdflux uses bidirectional constraints. Both produce identical final coordinates after `align_to_smallest` normalization.
- **Q2 (borderType):** Compound-graph-only. `borderType` is only set by `addBorderSegments()` for subgraph nodes. Simple flowcharts never have border nodes, so Pass 2's guard is vacuously satisfied. Pass 2 itself is a no-op for DAGs.
- **Q3 (DFS vs BFS):** The compaction is a longest-path computation with a unique result determined by the DAG structure and edge weights. Any valid topological ordering produces identical coordinates.
- **Q4 (alignment directions):** Both implementations produce identical root[] and align[] arrays for all 4 directions (UL, UR, DL, DR). dagre.js transforms input data; mmdflux uses inline flags. Both preserve the same neighbor relationships, ordering constraints, and median selection.

### 2. The stagger fix was a rendering pipeline issue, not a BK algorithm issue

Research 0013 Q2 incorrectly concluded that BK needed a block graph to produce stagger. Plan-0020 Phase 5 reversed this: BK had always computed correct dummy-node separation. The `saturating_sub` call in `compute_layout_direct()` was clipping wide nodes to x=0, destroying relative separations. The fix (commit `ed803b8`) was a uniform coordinate-space translation (overhang offset) that preserves all BK-computed separations.

### 3. Plan 0022's block graph compaction was a correctness improvement but didn't change stagger

The block graph compaction (plan-0022) replaced recursive `place_block` with explicit two-pass topological traversal. For all 27 test fixtures, node positions were unchanged. Only edge routing details changed (attachment point shifts of 1-2 characters). The block graph may matter for future topologies not yet covered by fixtures.

## Recommendations

1. **No action needed on BK divergences** — All investigated differences are provably equivalent or irrelevant for simple flowcharts. mmdflux's implementation is correct.

2. **Close issue #2 (skip-edge stagger missing)** — The stagger was fixed at commit `ed803b8` (plan-0020 Phase 2) and has been stable through subsequent changes. The fix is mathematically robust (coordinate translation preserving all separations).

3. **Keep Pass 2 as-is** — Although Pass 2 is a no-op for DAGs, it serves as defensive code that would matter if the block graph ever contained cycles (unlikely but possible in edge cases). Removing it saves negligible computation but removes a safety net.

4. **Document the rendering pipeline lesson** — The stagger bug (Q5) was caused by the rendering pipeline destroying correct layout output. Future layout debugging should check the rendering pipeline first, not just the layout algorithm.

5. **If compound graph support is added, implement borderType** — The borderType guard (Q2) would become necessary for subgraph border nodes. This is the only dagre.js feature that mmdflux intentionally omits.

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | dagre.js `bk.js` (positionX, verticalAlignment, horizontalCompaction); mmdflux `bk.rs` (position_x, vertical_alignment, horizontal_compaction, BlockGraph); `src/render/layout.rs` (compute_layout_direct) |
| **What** | 4 algorithmic differences (negation, borderType, traversal order, alignment flags) + 1 rendering pipeline bug (saturating_sub clipping) |
| **How** | Negation vs flags both normalize via align_to_smallest; borderType only set for compound graphs; longest-path compaction is order-independent; overhang offset preserves BK separations |
| **Why** | dagre.js targets compound graphs (subgraphs, border nodes, label positioning); mmdflux targets simple flowcharts. The implementations diverge in mechanism but converge in results for their shared use case |

## Open Questions

- Could there be topologies where single-pass `place_block` and two-pass block graph compaction produce different node positions? Plan-0022 suggested diamond patterns might diverge, but no fixture demonstrated this.
- Are there other places in the rendering pipeline where coordinate transformations could destroy layout-computed separations (e.g., LR/RL layouts)?
- Does dagre.js's `sep()` function for edge label positioning (labelpos "l"/"r") need equivalent handling in mmdflux?
- Could floating-point rounding differences from dagre.js's negation vs mmdflux's bidirectional constraints ever produce visible differences in complex graphs?

## Next Steps

- [ ] Close issue #2 (skip-edge stagger missing) — fixed at `ed803b8`, confirmed stable
- [ ] Consider adding a note to `bk.rs` documenting why Pass 2 is retained (defensive, no-op for DAGs)
- [ ] If compound graph support is planned, create a tracking issue for borderType implementation
- [ ] Archive this research

## Source Files

| File | Question |
|------|----------|
| `q1-right-bias-negation.md` | Q1: Right-biased coordinate negation |
| `q2-border-type-guard.md` | Q2: borderType guard in Pass 2 |
| `q3-dfs-vs-bfs-ordering.md` | Q3: DFS vs BFS traversal order |
| `q4-alignment-direction-handling.md` | Q4: Right-biased alignment handling |
| `q5-stagger-history.md` | Q5: When stagger started working |
