# Finding: Title Node Must Be a Child of the Compound

**Type:** diversion
**Task:** 2.1 / 3.1
**Date:** 2026-01-29

## Details
The plan's Task 2.1 implementation code did not set `lg.parents[title_idx] = Some(compound_idx)` for the title dummy node. This caused `apply_compound_constraints()` to not find the title node as a child of the compound, so border placement logic couldn't correctly order `left < title < right` at the title rank.

## Impact
The fix was straightforward: add `lg.parents[title_idx] = Some(compound_idx)` right after creating the title node in `nesting::run()`. This mirrors how `add_segments()` sets parent for border_left/border_right nodes.

## Action Items
- [x] Fixed in Phase 3 implementation
