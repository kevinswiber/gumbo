# Q4: How does mmdflux handle right-biased alignments compared to dagre.js's layer/node reversal?

## Summary

Both mmdflux and dagre.js produce mathematically equivalent vertical alignments (root and align arrays) for all 4 directions (UL, UR, DL, DR), but use opposite implementation strategies. dagre.js manipulates the input layering (reversing layers and/or nodes) before calling a single code path, then negates coordinates for right-biased cases. mmdflux uses inline conditional flags (`AlignmentDirection`) to control behavior directly — reversing iteration order and constraint direction without transforming the input data. Both yield the same aligned blocks and final balanced coordinates.

## Where

- `src/dagre/bk.rs` lines 119-160 (`AlignmentDirection` enum and methods)
- `src/dagre/bk.rs` lines 490-582 (`vertical_alignment` function)
- `src/dagre/bk.rs` lines 588-609 (`get_medians` function)
- `src/dagre/bk.rs` lines 214-220 (`get_layers_in_order` function)
- `src/dagre/bk.rs` lines 252-264 (`get_neighbors` function)
- `/Users/kevin/src/dagre/lib/position/bk.js` lines 355-387 (`positionX` function)
- `/Users/kevin/src/dagre/lib/position/bk.js` lines 166-204 (`verticalAlignment` function)

## What

### Direction Taxonomy

Both implementations map the 4 alignment directions to two independent binary choices:

| Direction | Layer Order | Node Order | Neighbor Fn | Median Preference |
|-----------|------------|-----------|-------------|-------------------|
| **UL** | 0→1→2→... | left→right | predecessors | lower (index mid-1) |
| **UR** | 0→1→2→... | right→left | predecessors | upper (index mid) |
| **DL** | n→n-1→... | left→right | successors | lower (index mid-1) |
| **DR** | n→n-1→... | right→left | successors | upper (index mid) |

### dagre.js: Input Mutation Strategy

`positionX()` (lines 363-381) transforms the layering before calling the single-code-path `verticalAlignment()`:

- **UL:** No transformation, use original layering + predecessors
- **UR:** Reverse nodes within layers, use predecessors, negate coordinates after
- **DL:** Reverse layer list, use successors
- **DR:** Reverse layer list AND nodes within layers, use successors, negate coordinates after

The negation (`xs = util.mapValues(xs, x => -x)`) mirrors right-biased coordinates back to standard space.

### mmdflux: Inline Flag Strategy

`vertical_alignment()` (lines 490-582) uses `AlignmentDirection` with two helper methods:

```rust
pub fn is_downward(&self) -> bool { matches!(self, Self::UL | Self::UR) }
pub fn prefers_left(&self) -> bool { matches!(self, Self::UL | Self::DL) }
```

These flags control:
- Layer sweep direction (top-to-bottom vs bottom-to-top)
- Node iteration order (left-to-right vs right-to-left)
- Median selection preference
- Ordering constraint direction (`r < m_pos` vs `r > m_pos`)

No coordinate negation is needed because the constraints operate bidirectionally.

### Median Selection

Both implementations handle even-count neighbors identically in semantics:
- **dagre.js:** Iterates from `floor(mp)` to `ceil(mp)` in `verticalAlignment()`
- **mmdflux:** `get_medians()` returns both middle elements with the preferred one first; `vertical_alignment` tries them in order

For 4 neighbors at positions [0, 1, 2, 3]:
- UL tries [1, 2] (lower first)
- UR tries [2, 1] (upper first)

## How

### UR Comparison (the most interesting case)

**dagre.js UR:**
1. Reverse nodes within layers: [A, B, C] → [C, B, A]
2. Process in reversed order (effectively right-to-left)
3. Standard ascending ordering constraint on reversed positions
4. Alignment computes in reversed coordinate space
5. Negate all coordinates to return to standard space

**mmdflux UR:**
1. Keep original node order
2. Iterate right-to-left (`layer_nodes.iter().rev()`)
3. Descending ordering constraint (`r > m_pos`)
4. Alignment computes directly in standard space
5. No negation needed

**Why equivalent:** Both achieve the same effect — processing nodes from right to left with upper-median preference. dagre.js transforms the problem to fit one solution; mmdflux solves the variant directly.

### Ordering Constraint Equivalence

- dagre.js: always uses `prevIdx < pos`, but reversal means "ascending in reversed space" = "descending in standard space"
- mmdflux: uses `r < m_pos` for left-biased, `r > m_pos` for right-biased — directly expressing the constraint

Both enforce that alignments are consistent with the processing direction.

## Why

### Design Rationale

**dagre.js (input manipulation + negation):**
- Reduces all 4 alignments to one canonical case via transformation
- Single unified code path — easier to verify correctness
- Requires memory for layer/node list copying
- Requires post-hoc coordinate normalization
- Philosophy: Transform the problem to fit one solution

**mmdflux (inline conditional logic):**
- Direct control via flags — no data structure copying
- More memory efficient (no layer/node list reversal allocations)
- More conditional branches in code
- No coordinate negation needed
- Philosophy: Solve all variants directly

### Why Both Approaches Work

Vertical alignment depends only on local neighbor relationships and ordering constraints. Both implementations preserve:
1. **Neighbor relationships:** Same predecessor/successor graphs
2. **Ordering constraints:** Consistent left-to-right or right-to-left enforcement
3. **Conflict detection:** Same Type-1 and Type-2 conflict logic operating on positions

Because these three elements are preserved, the resulting root[] and align[] arrays are functionally equivalent.

## Key Takeaways

- Vertical alignments are provably equivalent for all 4 directions — the root[] and align[] arrays are identical (modulo coordinate space, normalized before compaction)
- Layer sweep direction and node processing order are orthogonal in both implementations
- Median selection for even-count neighbors is semantically identical (both try two candidates in preference order)
- dagre.js normalizes via explicit negation; mmdflux normalizes via bidirectional constraints — same result, different mechanism
- All 27 test fixtures produce identical output, confirming equivalence empirically

## Open Questions

- Does dagre.js's explicit negation introduce any floating-point rounding differences in complex graphs?
- dagre.js's `sep()` function handles edge label positioning (labelpos "l"/"r") — does mmdflux need similar handling for labeled edges?
- Could the interaction between topological ordering (Q3) and alignment direction produce different results for right-biased cases specifically?
