# Arrow Direction Fix Implementation Plan

## Status: ✅ COMPLETE

**Completed:** 2026-01-26

**Commits:**
- `9c3a7ad` - fix(router): Match arrow direction with final segment orientation
- `c35b113` - fix(router): Use Z-shaped paths for TD/BT layouts to ensure vertical entry

## Overview

Fix arrow glyphs AND final segment orientation so edges enter targets from the expected direction:
- **TD/BT layouts**: Edges always enter from top/bottom with vertical segments (▼/▲)
- **LR/RL layouts**: Diagonal edges enter vertically (▼/▲), direct edges enter horizontally (►/◄)

## Problem

In `fan_in_lr.mmd`, three edges enter Target from different angles:

**Current (wrong):**
```
            └───▼      ← arrow points down but line is horizontal!
 ┌───────┐    ┌────────┐
 │ Src B │───►│ Target │
 └───────┘    └────────┘
            ┌───▲      ← arrow points up but line is horizontal!
```

**Expected (fixed):**
```
            ┌─────┐
            │     ▼    ← vertical line with down arrow
 ┌───────┐    ┌────────┐
 │ Src B │───►│ Target │  ← horizontal line with right arrow
 └───────┘    └────────┘
            │     ▲    ← vertical line with up arrow
            └─────┘
```

## Root Cause

Two issues:

1. **Arrow direction**: `entry_direction` was set using canonical layout direction, ignoring actual approach angle. (FIXED)

2. **Final segment orientation**: `build_orthogonal_path_for_direction()` always creates Z-shaped paths ending with the canonical direction (horizontal for LR/RL, vertical for TD/BT), even when the visual approach is perpendicular.

## Implementation Approach

### Part 1: Arrow Direction (DONE)

Added `entry_direction_from_segments()` that determines arrow direction from the penultimate segment (the "approach" segment) rather than using canonical layout direction.

### Part 2: Final Segment Orientation (TODO)

Modify `build_orthogonal_path_for_direction()` to end with a segment that matches the approach direction:

**Current LR/RL Z-path:** H → V → H (always ends horizontal)
**Fixed LR/RL paths:**
- With vertical displacement: H → V (ends vertical, for ▼/▲ arrows)
- No vertical displacement: H (ends horizontal, for ►/◄ arrows)

**Current TD/BT Z-path:** V → H → V (always ends vertical)
**Fixed TD/BT paths:**
- With horizontal displacement: V → H (ends horizontal, for ►/◄ arrows)
- No horizontal displacement: V (ends vertical, for ▼/▲ arrows)

### Code Change

In `build_orthogonal_path_for_direction()`:

```rust
// For LR/RL with vertical displacement (start.y != end.y):
// Current: H-V-H
// Fixed: H-V (horizontal to align x, then vertical to target)
vec![
    Segment::Horizontal { y: start.y, x_start: start.x, x_end: end.x },
    Segment::Vertical { x: end.x, y_start: start.y, y_end: end.y },
]

// For TD/BT with horizontal displacement (start.x != end.x):
// Current: V-H-V
// Fixed: V-H (vertical to align y, then horizontal to target)
vec![
    Segment::Vertical { x: start.x, y_start: start.y, y_end: end.y },
    Segment::Horizontal { y: end.y, x_start: start.x, x_end: end.x },
]
```

## Files to Modify

| File | Changes |
|------|---------|
| `src/render/router.rs` | Modify `build_orthogonal_path_for_direction()` |

## Testing Strategy

1. Run `fan_in_lr.mmd` and verify:
   - Src A → Target: vertical line ending with ▼
   - Src B → Target: horizontal line ending with ►
   - Src C → Target: vertical line ending with ▲
2. Test all 4 directions (TD, BT, LR, RL) with fan-in patterns
3. Verify backward edges still work correctly
4. Run full test suite for regression
