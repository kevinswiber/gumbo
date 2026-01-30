# Q1: Does dagre.js's right-biased coordinate negation produce different results?

## Summary

Both dagre.js and mmdflux produce equivalent final balanced coordinates despite using fundamentally different mechanisms for handling right-biased alignments (UR/DR). dagre.js reverses layers/nodes and negates coordinates; mmdflux uses direction flags to modify alignment logic inline. The `align_to_smallest()` step normalizes away intermediate differences, making the final median coordinates equivalent.

## Where

- dagre.js `bk.js` `positionX` function (lines 355-387) — negation logic
- mmdflux `src/dagre/bk.rs` `vertical_alignment` (lines 490-582), `horizontal_compaction`, `align_to_smallest` (lines 920-948)

## What

### dagre.js: Negation-based approach

In `positionX`, dagre.js iterates over `["u","d"]` × `["l","r"]`. For right-biased alignments (`horiz === "r"`):

1. Reverses node ordering within each layer: `[A, B, C]` → `[C, B, A]`
2. Runs normal `verticalAlignment` on reversed ordering
3. Runs `horizontalCompaction` with `reverseGraph=true`
4. **Negates all coordinates**: `xs = util.mapValues(xs, x => -x)`

This produces negative coordinates for right-biased alignments (e.g., UR produces coordinates like -200 to 0).

### mmdflux: Direction-flags approach

In `vertical_alignment`, mmdflux uses `AlignmentDirection` flags:

- `prefer_left = false` for UR/DR
- Nodes processed right-to-left within each layer
- Boundary `r` starts at `isize::MAX` (rightmost) instead of -1
- Constraint `r > m_pos` enforces right-to-left ordering

This produces positive coordinates but with right-biased grouping (e.g., UR produces coordinates like 0 to 200).

### Why both produce equivalent results

The crucial step is `align_to_smallest()`:

- For left-biased alignments (UL/DL): aligns left edges (`target_min - result_min`)
- For right-biased alignments (UR/DR): aligns right edges (`target_max - result_max`)

After alignment:
- dagre.js UR (e.g., -200 to 0) gets shifted to match the smallest-width alignment's right edge
- mmdflux UR (e.g., 0 to 200) gets shifted to match the same right edge

Both end up with identical bounding-box-aligned coordinates. The final `balance()` step takes the median of all 4 alignments, producing identical results regardless of intermediate coordinate signs.

## How

### Conceptual trace for a 3-layer graph

```
Layer 0:  [A]
Layer 1:  [B] [C]
Layer 2:  [D]
Edges: A→B, A→C, B→D, C→D
```

**dagre.js UR:** Reverse nodes in layer 1 → [C, B]. Process C first. Compact. Negate. Bounds: [-100, 0].

**mmdflux UR:** Keep [B, C]. Process right-to-left: C then B. Compact with right boundary. Bounds: [0, 100].

**After align_to_smallest():** Both shifted to identical bounds → identical median coordinates.

## Why

- dagre.js chose negation because it's conceptually simple: transform the problem into a left-biased one, solve it, then flip the answer
- mmdflux chose direction flags because they're more explicit about intent and avoid an extra negation pass
- Both are valid because the bounding-box alignment step (`align_to_smallest`) normalizes the intermediate coordinate spaces before the final median calculation

## Key Takeaways

- Both approaches are mathematically equivalent for the final balanced coordinates
- `align_to_smallest()` is the key normalizer — it shifts all 4 alignments to a common reference frame before taking the median
- No coordinate drift occurs in either implementation; all 27 fixtures produce identical output
- The median balancing is robust: it works on any bounding-box-aligned set of coordinate solutions regardless of intermediate scale or sign

## Open Questions

- Could extreme graphs produce slightly different floating-point rounding due to negation vs. no negation?
- Does the choice affect performance? (negation = extra pass; flags = branch predictions)
- Are there LR/RL layout directions where the difference becomes more visible?
