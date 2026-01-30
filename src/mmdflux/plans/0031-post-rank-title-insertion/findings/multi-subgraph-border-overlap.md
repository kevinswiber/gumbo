# Finding: Multi-Subgraph Border Overlap

**Type:** discovery
**Task:** 5.1
**Date:** 2026-01-29

## Details

When two subgraphs have a cross-edge (e.g., A in sg1 connects to C in sg2), the subgraph borders overlap with nodes from the adjacent subgraph at the boundary. This is visible as garbled characters where border lines intersect node boxes.

Example: `A --> C` where A is in sg1 and C is in sg2 produces overlapping borders at C's position because sg1's bottom border is at the same row as C's top border.

This is a **pre-existing** issue unrelated to the title rank insertion. The title rank insertion works correctly - titled subgraphs get proper vertical space for their title. But the fundamental border overlap between adjacent subgraphs remains.

## Impact

- Multi-subgraph integration test was adjusted to use `B --> C` (bottom-to-top cross-edge) which gives better vertical separation
- The original collision scenario (title overwritten by edge) is resolved for single subgraphs
- Multi-subgraph title rendering works when subgraphs don't border-overlap

## Action Items

- [ ] Investigate subgraph border overlap resolution for adjacent subgraphs with cross-edges
