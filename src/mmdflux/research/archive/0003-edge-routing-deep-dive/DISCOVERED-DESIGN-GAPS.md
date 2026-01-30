# Discovered Design Gaps

This document tracks design gaps discovered after the initial implementation, distinct from intentional deviations documented in `IMPLEMENTATION-DEVIATIONS.md`.

---

## Gap 1: Waypoint Coordinate Transformation

**Discovered:** 2026-01-26
**Status:** Fix planned in `plans/0007-waypoint-coordinate-transform/`

### The Problem

Waypoints from dagre's normalization are in dagre's internal coordinate system but are being used directly in the ASCII draw coordinate system without transformation. This causes edges spanning multiple ranks (like E→F in complex.mmd) to render incorrectly with segments going off-screen.

**Evidence:**
- Node E ("More Data?") draw position: (38, 19) in ASCII coordinates
- Waypoint from dagre: (112, 223) in dagre coordinates
- These are completely different scales (dagre uses `node_sep=50.0`, `rank_sep=50.0`)

**Current buggy code in `layout.rs:379-389`:**
```rust
for (edge_idx, waypoints) in &result.edge_waypoints {
    if let Some(edge) = diagram.edges.get(*edge_idx) {
        let key = (edge.from.clone(), edge.to.clone());
        let converted: Vec<(usize, usize)> = waypoints
            .iter()
            .map(|p| (p.x.round() as usize, p.y.round() as usize))  // BUG: Just rounding!
            .collect();
        edge_waypoints_converted.insert(key, converted);
    }
}
```

### Why This Was Missed

The original `IMPLEMENTATION-PLAN.md` (Phase 4.1, lines 558-559) specified:

```rust
// Convert waypoints to Layout format
let edge_waypoints = convert_waypoints(&result.edge_waypoints, &id_map);
```

But it **never specified what the conversion entails**. The plan assumed "convert to Layout format" was self-explanatory, without acknowledging the coordinate system transformation needed.

The plan correctly anticipated coordinate transformations for real nodes (via `grid_to_draw_vertical/horizontal()`), but waypoints were treated as a simple pass-through operation.

### What Should Have Been in the Plan

The original plan should have explicitly stated:

1. Dagre computes dummy node positions using its internal spacing (`node_sep=50.0`, `rank_sep=50.0`)
2. These coordinates are fundamentally different from ASCII draw coordinates
3. `convert_waypoints()` needs to transform from dagre space → ASCII space using the same logic as node position transformation
4. Waypoints need rank information preserved from normalization to compute proper layer coordinates

### The Fix

Extend `denormalize()` to return rank information with each waypoint, then transform waypoints using layer positions in `compute_layout_dagre()`. See `plans/0007-waypoint-coordinate-transform/` for full implementation plan.

### Lessons Learned

1. **Coordinate system boundaries need explicit documentation.** Any data crossing from dagre's coordinate space to ASCII draw space should be flagged in the plan.

2. **"Convert" is not a specification.** When a plan says "convert X to Y format," it should explicitly list what the conversion does, especially when coordinate systems are involved.

3. **Test with multi-rank edges.** The bug was latent because most test fixtures use short edges (span 1 rank). Long edges that span multiple ranks exercise the waypoint path and would have caught this earlier.

---

## Template for Future Gaps

### Gap N: [Title]

**Discovered:** YYYY-MM-DD
**Status:** [Investigating | Fix planned in `plans/NNNN-...` | Fixed in commit XXX]

### The Problem

[Description of the issue]

### Why This Was Missed

[Analysis of what the original plan said or didn't say]

### What Should Have Been in the Plan

[What explicit specification would have prevented this]

### The Fix

[Solution or reference to fix plan]

### Lessons Learned

[Takeaways for future planning]
