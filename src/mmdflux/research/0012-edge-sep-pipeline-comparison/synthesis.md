# Research Synthesis: Edge Sep Pipeline — mmdflux vs Dagre.js vs Mermaid

## Summary

mmdflux's `compute_stagger_positions()` pipeline is the root cause of edge_sep ineffectiveness. Both dagre.js and Mermaid use dagre's output coordinates directly — dagre.js preserves edge_sep through every transformation step (all are uniform translations/swaps), and Mermaid applies only a minor subgraph-title Y-offset before SVG rendering. mmdflux, by contrast, inserts a 6-step pipeline that discards dagre's cross-axis float positions and re-derives them through grid assignment and a proportional formula that divides by `nodesep` regardless of node type. This formula is provably wrong for layers containing dummy nodes, producing errors of 25–70%. The recommended fix is to replace the stagger pipeline with direct coordinate translation (scale + round + collision repair), reducing ~400 lines to ~100 and natively preserving edge_sep.

## Key Findings

### Finding 1: dagre.js preserves edge_sep end-to-end

The dagre.js pipeline applies only uniform transformations after BK compaction: `alignCoordinates()` adds a constant delta, `coordinateSystem.undo()` swaps/reverses axes, and `translateGraph()` shifts all coordinates by the same amount. No step applies proportional scaling, grid snapping, or any transformation that could neutralize the per-node edge_sep/node_sep distinction embedded in BK's output. The edge_sep value flows directly from `sep()` (bk.js:408-409) into block graph edge weights, through compaction, into final node.x/node.y. (Q1)

### Finding 2: Mermaid uses dagre coordinates directly with no post-processing

Mermaid does not pass `edgesep` to dagre for flowchart rendering at all (only ER diagrams set `edgesep: 100`). It uses dagre's default of 20. After dagre runs, Mermaid applies only a subgraph-title Y-axis margin offset and SVG transform generation. There is no grid snapping, no proportional scaling, no stagger mapping. Coordinates are floating-point throughout. (Q2)

### Finding 3: mmdflux's stagger pipeline is a coordinate-space bridge — partly necessary, partly artifact

The stagger mapping serves a legitimate purpose: bridging dagre's continuous float coordinates to ASCII's integer character grid. The layer grouping, per-rank anchor construction, and piecewise waypoint interpolation provide accurate edge routing. However, the pipeline also re-implements layer grouping that dagre already computed (redundant), uses a two-pass grid positioning system (could be simplified), and relies on empirical heuristics without formal derivation. The core issue isn't that the bridge exists — it's that the bridge is lossy. (Q3)

### Finding 4: The stagger formula is provably wrong for dummy-heavy layers

`compute_stagger_positions()` uses `target_stagger = dagre_range / nodesep * (spacing + 2.0)`, dividing by `nodesep` regardless of whether a layer contains dummy nodes. Since dagre's BK packs dummy nodes at `edge_sep` (30–40% of `nodesep`), this formula over-estimates the number of "nodesep gaps" in the range, producing a target stagger that's 25–70% too small. Worked examples with 2 real + 3 dummy nodes show the formula computing 14 chars when the correct value is 24 (71% error for TD/BT) and 19 when the correct value is 24 (26% error for LR/RL). (Q4)

### Finding 5: Direct translation is feasible and simpler

A 3-step pipeline (scale → round → collision repair) can replace the current 6-step pipeline. Per-axis scale factors account for the terminal character aspect ratio. Collision repair handles integer rounding by pushing overlapping nodes apart. This approach natively preserves edge_sep because uniform scaling preserves the ratio between edge_sep and node_sep gaps. Waypoint transformation becomes trivial (apply same scale factors) instead of requiring per-rank anchor interpolation. Estimated reduction: ~400 lines → ~100 lines. (Q5)

## Recommendations

1. **Replace the stagger pipeline with direct coordinate translation.** This is the primary recommendation. Instead of discarding dagre's cross-axis positions and re-deriving them, apply scale factors directly to dagre's float output, round to integers, and repair collisions. This preserves edge_sep natively, simplifies the code, and aligns mmdflux with how dagre.js and Mermaid consume dagre output.

2. **Keep direction-aware dagre config.** The current adaptive `node_sep`/`edge_sep` computation for LR/RL (based on average node height) is still necessary. It makes dagre's coordinate space closer to ASCII space, reducing scaling distortion.

3. **If direct translation is too risky, fix the stagger formula as a stopgap.** A dummy-aware formula would compute actual average separation per layer gap instead of assuming `nodesep`. This requires knowing which nodes are dummy at stagger time — either pass this through from dagre or recompute from graph structure. This is a smaller change but doesn't address the fundamental complexity.

4. **Preserve the per-rank anchor mechanism for edge routing** if direct translation makes waypoint transformation too imprecise. The piecewise linear interpolation provides accurate routing for long edges. However, if uniform scaling proves sufficient for waypoints, the ~80 lines of anchor/interpolation code can be eliminated.

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | dagre.js: `bk.js:sep()` → `position/index.js` → `coordinate-system.js` → `layout.js:translateGraph()`. Mermaid: `dagre/index.js:recursiveRender()` → `nodes.ts:positionNode()`. mmdflux: `layout.rs:compute_stagger_positions()` (line 1103 is the lossy formula). |
| **What** | dagre.js preserves edge_sep through uniform transforms. Mermaid uses coords directly. mmdflux discards cross-axis positions via grid assignment and applies a proportional formula that ignores dummy/real distinction. |
| **How** | The formula `dagre_range / nodesep * (spacing + 2.0)` assumes all gaps are `nodesep`-sized. For layers with dummy nodes (packed at `edge_sep`), this over-estimates gap count, producing under-sized stagger (25–70% too small). |
| **Why** | mmdflux needs the bridge because ASCII has integer coordinates. But the bridge doesn't need to be lossy — a scale+round+repair approach preserves dagre's ratios while adapting to the character grid. The current pipeline appears to be an artifact of an earlier grid-based design that predated dagre integration. |

## Open Questions

- **Rounding precision at small scales.** When dagre spaces nodes by 50 units and the scale factor is ~0.1, the difference between edge_sep=20 and node_sep=50 maps to ~2 vs ~5 characters. Rounding could reduce this to 2 vs 4 or 2 vs 5. Is 1-character granularity sufficient to convey the visual distinction?

- **Cascading collision repair.** If pushing node B right to avoid A causes B to collide with C, the repair cascades. How far can positions drift from dagre's intent before the layout quality degrades?

- **Should dagre config be tuned for ASCII-scale coordinates?** Setting `node_sep=4, edge_sep=2, rank_sep=6` would produce coordinates already near ASCII scale, making scale factors close to 1.0 and reducing rounding issues. But BK's internal precision with such small values is untested.

- **Edge label placement.** Labels have their own dummy nodes. Direct translation would automatically space labels via edge_sep, but labels need minimum width for readability. Does this conflict with tight edge_sep scaling?

## Next Steps

- [ ] Implement direct coordinate translation as a new code path in `layout.rs`
- [ ] Compare output quality against current stagger-based pipeline on all test fixtures
- [ ] Evaluate whether per-rank anchor interpolation is still needed for waypoints or if uniform scaling suffices
- [ ] Create an implementation plan via `/plan:create` referencing this research

## Source Files

| File | Question |
|------|----------|
| `q1-dagre-bk-to-final-coords.md` | Q1: How dagre.js translates BK output to final coordinates |
| `q2-mermaid-post-dagre-transforms.md` | Q2: Mermaid's post-dagre coordinate transformations |
| `q3-mmdflux-stagger-vs-direct.md` | Q3: mmdflux's stagger mapping vs direct translation |
| `q4-stagger-edge-sep-awareness.md` | Q4: Stagger mapping edge_sep awareness |
| `q5-direct-translation-design.md` | Q5: Direct dagre-to-ASCII translation design |
