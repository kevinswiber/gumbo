# Q4: How do float-to-ASCII coordinate mappings produce centering jogs?

## Summary

The centering jog occurs because of a float-to-integer conversion mismatch between the layout engine and attachment point calculation. When two nodes of different widths share the same dagre float x-center, the direct rounding of the float center produces different integer center positions for each node. Attachment points calculated from `NodeBounds.center_x()` (which uses integer division) differ by 1 cell, producing the characteristic jog instead of a straight vertical edge.

## Where

**Files investigated:**
- `src/render/layout.rs` (lines 333-357): Node position calculation from dagre float centers
- `src/render/shape.rs` (lines 19-26): `NodeBounds.center_x/center_y` using integer division
- `src/render/intersect.rs` (lines 137-164): `intersect_rect()` using `bounds.center_x()` as float
- `src/render/intersect.rs` (lines 237-262): `calculate_attachment_points()` entry point
- `src/render/router.rs` (lines 300-347): `resolve_attachment_points()` for TD/BT layouts
- `tests/fixtures/simple.mmd`: Test case with Start (9 wide) -> End (7 wide)

## What

### The Float-to-Integer Conversion Chain

1. **Dagre assigns float x-centers** — Both "Start" and "End" receive the same dagre x-center (e.g., 40.0)

2. **Layout engine rounds to ASCII center_x** (layout.rs:340):
   ```rust
   let center_x = ((rect.x + rect.width / 2.0 - dagre_min_x) * scale_x).round() as usize;
   ```
   For "Start" (dagre width ~9) and "End" (dagre width ~7):
   - Start: `(40 + 4.5) * 1.0).round()` = 44.5 -> 44 or 45
   - End: `(40 + 3.5) * 1.0).round()` = 43.5 -> 43 or 44

   **Different rounded centers** even though dagre intended alignment.

3. **Layout engine computes top-left position** (layout.rs:343):
   ```rust
   let x = center_x.saturating_sub(w / 2) + padding;
   ```

4. **NodeBounds created with integer positions** — stores (x, width) pairs

5. **Attachment point uses NodeBounds.center_x()** (shape.rs:19-20):
   ```rust
   pub fn center_x(&self) -> usize {
       self.x + self.width / 2  // INTEGER DIVISION
   }
   ```
   - Start: `40 + 9/2 = 40 + 4 = 44`
   - End: `40 + 7/2 = 40 + 3 = 43`

   **1-cell mismatch** from integer division on different widths.

### Exact Math for simple.mmd

Given Start (width=9) and End (width=7) both at dagre float center 40.0:

```
Start bounds: {x: 40, width: 9}  → center_x() = 40 + 4 = 44
End bounds:   {x: 40, width: 7}  → center_x() = 40 + 3 = 43
```

Source attachment at x=44, target attachment at x=43 → 1-cell offset → orthogonal jog.

## How

The mismatch occurs in two layers:

1. **Layout engine** rounds float centers to integers, but different widths produce different rounding results for the same dagre center
2. **Shape module** recalculates centers using integer division (`x + width / 2`), losing the rounding information from the layout engine

For nodes with widths differing by 2 (e.g., 7 and 9), rounding `.5` values produces exactly +/-0.5 differences, translating to +/-1 cell offset in integer space.

The jog is systematic: odd-width nodes lose the 0.5 offset in integer division, while even-width nodes don't. Nodes with different width parities always diverge.

## Why

**Root cause:** A fundamental mismatch between float and integer coordinate systems:
- Dagre works in floats: centers computed as `x + width/2.0`
- ASCII grid requires integers: positions are discrete character columns
- Rounding is width-dependent: the same float center rounds differently for different widths
- `NodeBounds.center_x()` uses integer division, truncating the fractional part

**The mismatch compounds:** Layout engine rounds assuming float semantics, but attachment calculation assumes integer semantics. The rounding information (which float center this node was aligned to) is lost once NodeBounds stores only integer x and width.

## Key Takeaways

- The jog is a **quantization artifact**: nodes with different widths aligned in dagre's float space don't remain aligned in ASCII integer space
- The 1-cell offset is systematic for nodes differing by 2 in width (e.g., 7 vs 9)
- All layout directions (TD, BT, LR, RL) are affected since attachment calculation uses `NodeBounds.center_x/y()`
- The fix should either: (a) preserve the original float center in NodeBounds for attachment calculation, (b) snap attachment points to a common column for aligned nodes, or (c) compute attachment x from the stored float center rather than re-deriving it via integer division
- This is likely a small fix with high visual impact since it affects the simplest diagrams (simple.mmd, bottom_top.mmd)

## Open Questions

- Should `NodeBounds` store the original float center alongside integer bounds?
- Could attachment point calculation use a "snap to nearest grid line" approach for nearly-aligned nodes?
- What rounding strategy best preserves float center alignment? (floor-to-even, always-floor, store-float?)
- Does collision repair after positioning further affect alignment?
- Are there cases where the jog is actually correct (nodes at genuinely different x-centers)?
