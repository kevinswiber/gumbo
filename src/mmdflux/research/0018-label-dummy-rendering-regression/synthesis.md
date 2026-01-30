# Research Synthesis: Label-as-Dummy-Node Rendering Regression

## Summary

The label-dummy branch's rendering regression stems from a **fundamental design mismatch**: it applies `minlen=2` only to labeled edges, while dagre.js's `makeSpaceForEdgeLabels` applies it globally to ALL edges and halves `ranksep`. The global approach creates a critical invariant—all rank differences are even—that downstream Sugiyama phases depend on. The selective approach breaks this invariant, producing asymmetric rank spacing, empty ranks, waypoint misalignment, and coordinate desync between the layout and render layers. Four distinct visual defects result: diamond text corruption, massive vertical expansion, phantom vertical columns from backward edges, and edge misalignment from waypoint-induced Z-paths.

## Key Findings

### Finding 1: The global minlen transformation is essential, not optional

dagre.js doubles ALL edge minlen and halves ranksep as a coordinated pair. This creates a uniform "intermediate rank grid" where every edge spans an even number of ranks, guaranteeing that the midpoint formula `(w.rank - v.rank) / 2 + v.rank` always produces an integer. All downstream phases—normalization, ordering, positioning—depend on this uniformity. The mmdflux label-dummy branch only doubles labeled edges, breaking this invariant and producing mixed rank spacing (some gaps of 1, some of 2), empty ranks with only dummy nodes, and fractional or inconsistent label positions.

### Finding 2: The render layer contradicts the layout layer

The label-dummy branch implements label-as-dummy-node in dagre (Approach A: labels are structural) but then **discards** the precomputed positions in the render layer, replacing them with a gap-midpoint heuristic (Approach B: labels are annotations). The `transform_label_positions_direct()` function receives `WaypointWithRank` with rank information from dagre but ignores the rank entirely, computing `(src_bottom + tgt_top) / 2` instead. Meanwhile, waypoints correctly use rank-based snapping to `layer_starts`. This creates an inconsistency: edge paths and labels are computed using different coordinate systems.

### Finding 3: Backward edges are catastrophically affected

The backward edge (Error→Setup "retry") is the single worst-affected element. In the main branch, backward edges get compact synthetic waypoints that route around nodes. In the label-dummy branch, the backward edge goes through dagre normalization (because minlen inflation makes it span multiple ranks after reversal), receiving dagre-assigned waypoints that create a tall vertical column spanning the full diagram height. Additionally, the edge's arrow (`▲`) is drawn with `canvas.set()` which unconditionally overwrites node content—a latent z-order bug that only manifests when edge paths cross node territories.

### Finding 4: Every labeled edge doubles the diagram height

With `minlen=2` on all labeled edges, the rank count roughly doubles. For `labeled_edges.mmd` where 5/5 edges have labels, the diagram goes from ~5 ranks to ~9+ ranks, expanding from 29 lines to 51+ lines (83% increase). Each extra rank adds approximately 6 rows of vertical space. The label dummies also get independent x-positions from the BK algorithm, creating horizontal jogs on edges that should be straight vertical lines.

## Recommendations

1. **Implement the global approach** — Double ALL edge minlen (not just labeled ones) and halve ranksep, matching dagre.js exactly. This is the only way to maintain the invariants that downstream phases depend on. The alternative—modifying every downstream phase to handle mixed minlen—would be far more complex and fragile.

2. **Halve ranksep to compensate** — When doubling all edge minlen, also halve ranksep so that the final visual spacing remains similar. Without this, the diagram would be 2x taller with no benefit.

3. **Trust dagre's label positions in the render layer** — Remove the gap-midpoint heuristic override in `transform_label_positions_direct()` and use the dagre-computed label dummy positions directly (with rank-based snapping to `layer_starts`, same as waypoints). The current approach defeats the purpose of label-as-dummy-node.

4. **Exclude backward edges from label-dummy normalization** — Backward edges should continue using synthetic waypoints for compact routing. If they go through dagre normalization with inflated ranks, they create massive vertical columns. Consider stripping dagre waypoints from backward edges before routing, or preventing normalization from processing them.

5. **Fix the arrow z-order bug** — `draw_arrow_with_entry()` should check `canvas.is_node()` before overwriting a cell, similar to how other drawing functions protect node content. This is a latent bug on the main branch that the label-dummy approach exposes.

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | dagre `mod.rs` (`make_space_for_edge_labels`), `rank.rs` (minlen handling), `normalize.rs` (dummy insertion), render `layout.rs` (`transform_label_positions_direct`), `router.rs` (backward edge routing), `edge.rs` (arrow drawing) |
| **What** | Selective minlen=2 breaks uniform rank spacing invariant; render layer discards precomputed positions; backward edges get inflated dagre waypoints; arrow drawing overwrites node content |
| **How** | Ranking produces asymmetric gaps (0,2,4,5 instead of 0,2,4,6,8); normalization creates isolated dummy ranks; BK assigns independent x-positions to dummies; render layer computes gap midpoints instead of using dagre positions |
| **Why** | dagre.js's global approach is a coordinated transformation (minlen×2 + ranksep÷2) that maintains invariants; the selective approach was simpler to implement but violates assumptions baked into every downstream phase |

## Open Questions

- Can ranksep halving be implemented independently, or does mmdflux's ASCII rendering model (fixed character grid) make this difficult? The render layer uses integer `v_spacing` and `h_spacing` values, not float ranksep.
- Should the global approach use the existing `edge_minlens` field or modify the graph config (ranksep) directly like dagre.js?
- How does the global minlen=2 approach interact with the already-doubled backward edges (which get minlen=2 from reversal)?
- Would a conditional approach work: apply global minlen=2 only when any edge has a label, otherwise use minlen=1? This would avoid inflating label-free diagrams.

## Next Steps

- [ ] Implement global `make_space_for_edge_labels`: double ALL edge minlen, halve ranksep
- [ ] Update `transform_label_positions_direct` to use rank-based snapping (same as waypoints)
- [ ] Add backward edge exclusion from dagre normalization or strip dagre waypoints before routing
- [ ] Fix arrow z-order bug in `draw_arrow_with_entry()`
- [ ] Re-test `labeled_edges.mmd` and all other fixtures after changes

## Source Files

| File | Question |
|------|----------|
| `q1-dagre-make-space-analysis.md` | Q1: dagre.js makeSpaceForEdgeLabels analysis |
| `q2-pipeline-invariant-analysis.md` | Q2: Pipeline invariant analysis |
| `q3-render-layer-analysis.md` | Q3: Render layer analysis |
| `q4-visual-defect-diagnosis.md` | Q4: Visual defect diagnosis |
