# Finding: Canvas Trimming Interacts with Waypoint Bounds Checking

## Summary

Phase 1's canvas vertical trimming (stripping empty leading/trailing rows) exposed a pre-existing bug where waypoint collision nudging could push waypoints outside canvas bounds.

## Details

In `compute_layout_dagre()`, when a waypoint collides with a node bounding box in an LR layout, the code nudges it past the bottom edge:

```rust
wp.1 = bounds.y + bounds.height + 1;  // layout.rs:541
```

With the original large `node_sep=50.0`, the canvas was always tall enough to absorb this nudge. After reducing `node_sep` for LR/RL (task 2.2), the canvas became more compact, and the nudged waypoint could land at `y = height` (one past the last valid row).

## Fix Applied

Added clamping after the collision nudge loop (layout.rs:549-550):

```rust
wp.0 = wp.0.min(width.saturating_sub(1));
wp.1 = wp.1.min(height.saturating_sub(1));
```

## Lesson

Changes to spacing parameters can expose boundary conditions in downstream code. The waypoint collision nudging assumed unbounded canvas space. When tightening layout parameters, always check that coordinates remain within bounds.
