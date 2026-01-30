# Finding: MIN_ATTACHMENT_GAP enforcement is a safety net, not active correction

**Type:** discovery
**Task:** 2.1
**Date:** 2026-01-28

## Details

The MIN_ATTACHMENT_GAP forward-pass enforcement logic is mathematically redundant with the endpoint formula. When `range >= (count-1) * MIN_GAP`, the endpoint formula `(i * range) / (count - 1)` already guarantees minimum gaps >= MIN_GAP because `floor(range/(count-1)) >= MIN_GAP`.

When `range < (count-1) * MIN_GAP`, the gap physically cannot be enforced (not enough space), so the code correctly skips enforcement and uses graceful degradation.

The enforcement loop acts as a safety net for potential future formula changes, not as an active correction.

## Impact

The `very_narrow_fan_in.mmd` fixture (4 edges on narrow "Y" node) still shows doubled arrows because the face is too narrow for MIN_GAP enforcement. A future improvement could consider:
- Wider node rendering when many edges converge
- Edge bundling or stacking for narrow targets
- Reducing visible attachment points below edge count

## Action Items
- [ ] Consider filing an issue for narrow-face edge bundling as a future improvement
