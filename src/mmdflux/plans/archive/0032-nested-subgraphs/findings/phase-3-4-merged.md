# Finding: Phase 3 and 4 Implemented Together

**Type:** diversion
**Task:** 3.2, 4.1, 4.2
**Date:** 2026-01-29

## Details
Phase 3 (inside-out bounds computation) and Phase 4 (nested-aware overlap resolution) had to be implemented together. The overlap resolution function was trimming parent/child bounds against each other, which broke the containment invariant needed by Phase 3.

The `is_ancestor()` helper and the nested-pair skip in `resolve_subgraph_overlap` were prerequisites for the Phase 3 containment tests to pass.

## Impact
No negative impact — the phases were naturally coupled. The plan could have structured them as a single phase.

## Action Items
- None
