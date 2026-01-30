# Option 4B Implementation Results: Synthetic Waypoints

## Status: ❌ FAILED

**Attempted:** 2026-01-26
**Result:** Reverted after testing showed regressions

---

## What Was Implemented

### Approach

A variant of Option 4 (Waypoint-Based Routing) called "Synthetic Waypoints" that:

1. **Analyzed edges** to detect when synthetic waypoints might help:
   - Calculated horizontal offset between source and target centers
   - Determined if source was on left/right/center of diagram
   - Only applied to TD/BT layouts with offset > 20 pixels

2. **Generated waypoints** for qualifying edges:
   - Single waypoint at `(source_x, target_y - 3)`
   - This kept the edge on the source's side before turning toward target

3. **Integrated into `route_edge()`** decision flow:
   - After backward edge check
   - After dagre waypoint check
   - Before direct routing fallback

### Code Added

```rust
/// Analysis of an edge to determine if it needs synthetic waypoints.
struct EdgeAnalysis {
    horizontal_offset: usize,
    source_position: SourcePosition,  // Left, Center, Right
    needs_synthetic_waypoints: bool,
}

fn analyze_edge(...) -> EdgeAnalysis { ... }
fn generate_synthetic_waypoints(...) -> Option<Vec<(usize, usize)>> { ... }
fn generate_td_waypoints(...) -> Option<Vec<(usize, usize)>> { ... }
fn generate_bt_waypoints(...) -> Option<Vec<(usize, usize)>> { ... }
```

Total: ~520 lines including 16 unit tests and 2 integration tests.

---

## Why It Failed

### The Problem

When tested on `complex.mmd`, the synthetic waypoints made the diagram **worse**, not better.

### Before (Default Mid-Y Routing)

```
      ┌───────────┐           ┌──────────────┐           ┌────────────┐
      │ Log Error │           │ Notify Admin │           < More Data? >
      └───────────┘           └──────────────┘           └────────────┘
            ┌────┼────────────────────┼─────────────────────┘
            │    │                    │
            │    └───────────────┐    │
            │                    │    │
            │                    ▼    ▼
            │                    ┌─────────┐
            │                    │ Cleanup │
            │                    └─────────┘
```

The edges converge naturally at a horizontal line, then fan into Cleanup.

### After (Synthetic Waypoints)

```
      ┌───────────┐           ┌──────────────┐           ┌────────────┐
      │ Log Error │           │ Notify Admin │           < More Data? >
      └───────────┘           └──────────────┘           └────────────┘
            ├─────────────────────────┼─────────────────────┘
            │                         │
            │                         │
            ├────────────────────┐    │
            │                    ▼    ▼
            │                    ┌─────────┐
            │                    │ Cleanup │
```

The Log Error → Cleanup edge now goes down on the far left, then has to cross back over to reach Cleanup, creating visual confusion.

### Root Cause

The synthetic waypoint approach has a fundamental flaw: **it doesn't account for what happens after the waypoint**.

When an edge uses a synthetic waypoint to stay on one side:
1. It goes down vertically on that side ✓
2. Then it needs to turn and cross horizontally to the target ✗
3. This horizontal crossing often **overlaps other edges** that are also going to the same target

The "ideal" routing shown in the research documents assumed the target would also be on the side, but in practice:
- Multiple edges often converge on a central target
- The synthetic waypoint just delays the crossing, making it happen at a worse location
- The default mid-Y approach actually handles convergence better by crossing at the midpoint

---

## Key Learnings

### 1. Edge Routing Is a Global Problem

You can't optimize individual edges in isolation. The routing of one edge affects how others look. The mid-Y approach works because it creates a natural "convergence zone" at the midpoint between layers.

### 2. The Problem Statement Was Partially Wrong

The original analysis identified the E→F edge in `complex.mmd` as problematic. But looking more carefully:
- The E→F edge isn't actually that bad with mid-Y routing
- The real complexity comes from multiple edges converging
- The synthetic waypoint "fix" made the convergence worse

### 3. Dagre's Approach Is Holistic

Dagre doesn't just route individual edges - it:
1. Inserts dummy nodes to break long edges
2. Optimizes dummy positions to minimize crossings globally
3. Uses four alignment passes to find the best overall layout

A simple heuristic can't replicate this.

### 4. ASCII Art Has Different Constraints Than SVG

SVG/graphical rendering can use curves and transparency to handle overlapping paths. ASCII art has no such luxury - every character cell can only show one thing. This makes edge overlap much more visually confusing.

---

## What Would Work Better

### Option A: Accept Current Behavior

The mid-Y Z-shaped routing is actually reasonable for most cases. The "problem" in complex.mmd may not be worth the complexity of solving.

### Option B: Full Dagre Normalization

If we want truly optimal routing, we'd need to:
1. Use dagre's dummy node system for ALL multi-layer edges
2. Let dagre's crossing minimization optimize dummy positions
3. Extract waypoints from the dummy positions

This is a significant undertaking but would give routing on par with graphical Mermaid.

### Option C: Collision Detection (Not Side Preference)

Option 2 from the synthesis (Collision-Aware Routing) might work better than Option 1/4 because:
- It detects actual problems rather than using heuristics
- It can fall back to default routing when alternatives would be worse
- It considers the actual diagram state, not just edge endpoints

However, this would need careful implementation to avoid infinite loops or performance issues.

---

## Files That Were Changed (Now Reverted)

- `src/render/router.rs` - Added synthetic waypoint logic
- `tests/fixtures/horizontal_offset.mmd` - Test fixture (deleted)

All changes were reverted with `git reset --hard`.

---

## Conclusion

The synthetic waypoints approach was a reasonable hypothesis but failed in practice. The key insight is that edge routing in dense diagrams is a **global optimization problem**, not a collection of local decisions. Simple heuristics that optimize individual edges can make the overall diagram worse.

The current mid-Y routing, while not perfect, handles edge convergence reasonably well. Any improvement would need to consider the diagram holistically, similar to how dagre's normalization and ordering phases work together.
