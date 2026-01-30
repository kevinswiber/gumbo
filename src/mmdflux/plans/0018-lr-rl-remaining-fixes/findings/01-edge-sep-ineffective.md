# Finding: edge_sep Has No Visible Effect on LR/RL Output

## Summary

The `edge_sep` parameter was added to `BKConfig` and `LayoutConfig`, and dummy-aware separation was implemented in `place_block()`. Unit tests confirm the BK compaction *does* use different separation values for dummy vs real nodes. However, **the rendered output for LR/RL layouts did not visibly change**.

## Root Cause Analysis

The dagre layout (BK compaction) operates in an abstract coordinate space. Its output is **not directly used for pixel/char positioning**. Instead, the pipeline works like this:

```
dagre coords -> group into layers -> sort by cross-axis position -> grid positions -> draw coordinates
```

The critical translation happens in `compute_layout_dagre()` (`layout.rs:256-398`):

1. **Dagre produces floating-point center coordinates** for each node.
2. **Nodes are grouped into layers** by their primary coordinate (line 274-290).
3. **Nodes are sorted within each layer** by their secondary (cross-axis) coordinate (line 293-307).
4. **Grid positions are computed** from the layer/order structure (line 310).
5. **Draw coordinates are computed** using `compute_stagger_positions()` which maps dagre cross-axis positions to character positions using `v_spacing` (default 3) and `nodesep`.

The `nodesep` value flows into `compute_stagger_positions()` (line 379) where it influences the scaling from dagre coordinates to draw coordinates. But the actual inter-node gaps are primarily determined by:
- `v_spacing` (default 3 for LR/RL cross-axis)
- Node dimensions
- The stagger algorithm's proportional mapping

## What edge_sep Actually Does

In the BK compaction phase (`bk.rs:place_block()`), `edge_sep` controls how tightly dummy nodes (edge waypoints from long-edge normalization) are packed relative to each other. With the old code, dummy nodes used `node_sep` (50.0 for TD, 6.0 for LR after task 2.2), which is the same as real nodes. Now dummy-dummy pairs use `edge_sep` (20.0 for TD, 2.4 for LR).

This *should* cause long edges that pass through intermediate layers to be routed closer together, reducing wasted space. But this effect is subtle and only manifests when:
- Multiple long edges pass through the same layer
- Those edges have dummy nodes in adjacent positions within the layer

## What Needs Investigation

1. **Does `nodesep` in `compute_stagger_positions()` need to be replaced with edge_sep for dummy waypoints?** Currently `nodesep` is passed as a single value. The stagger computation doesn't distinguish dummy from real nodes.

2. **Is the dagre-to-draw mapping losing the edge_sep benefit?** The proportional mapping in `compute_stagger_positions()` (lines 1060-1100) scales dagre cross-axis positions to character positions. If the scaling factor makes dummy spacing equivalent to real spacing in char coordinates, the edge_sep change is invisible.

3. **Construct a test case with multiple long edges through the same layer.** The current test fixtures (`double_skip.mmd`, `skip_edge_collision.mmd`) may show the effect. Render before/after comparison needed.

4. **Direction-aware node_sep may mask the edge_sep effect.** Task 2.2 reduced LR `node_sep` from 50.0 to ~6.0 (2x avg height). With `edge_sep` at ~2.4 (0.8x avg height), the ratio is different, but the absolute values are both small. The BK compaction may produce layouts where the difference is lost in rounding to integer char coordinates.

## Recommended Next Steps

- Create a dedicated test fixture with crossing long edges in LR layout
- Add debug logging to `compute_stagger_positions()` to trace dagre-to-draw mapping
- Consider whether the stagger computation should be dummy-aware (pass separate edge_sep)
- Compare visual output of `double_skip.mmd` and `skip_edge_collision.mmd` in LR direction
- May need to research how dagre.js translates edgesep through to final coordinates
