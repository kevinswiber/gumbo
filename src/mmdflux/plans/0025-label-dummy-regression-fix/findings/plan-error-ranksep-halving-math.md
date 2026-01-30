# Finding: Ranksep halving formula was mathematically incorrect

**Type:** plan-error
**Task:** 1.2
**Date:** 2026-01-29

## Details

The plan specified "halve ranksep in scale factor computation" by passing `rank_sep / 2.0` to `compute_ascii_scale_factors()`. This doesn't correctly compensate for doubled rank gaps.

The scale formula is: `scale = (max_h + spacing) / (max_h + rank_sep)`. With doubled ranks, dagre positions nodes `2 * rank_sep` apart. For the ASCII gap to remain the same:

```
2 * rank_sep * scale_new = rank_sep * scale_old
=> scale_new = scale_old / 2
=> (max_h + s) / (max_h + eff_rs) = (1/2) * (max_h + s) / (max_h + rank_sep)
=> eff_rs = max_h + 2 * rank_sep
```

With `rank_sep / 2 = 25`, `max_h = 3`: scale = 6/28 = 0.214. Gap = 100 * 0.214 = 21.4 (too large).
With `eff_rs = 103`: scale = 6/106 = 0.0566. Gap = 100 * 0.0566 = 5.66 (matches original gap of 50 * 0.113).

## Impact

Required a `ranks_doubled: bool` parameter on `compute_ascii_scale_factors()` instead of the simpler `rank_sep / 2.0` approach. The function now computes the correct effective rank_sep internally using the max primary dimension.

## Action Items

- [x] Fixed in Phase 1 implementation
