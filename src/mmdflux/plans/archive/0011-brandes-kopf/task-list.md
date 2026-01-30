# Option 4A: Brandes-Kopf Coordinate Assignment - Task List

## Status: ✅ COMPLETE

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Infrastructure

- [x] **1.1** Create `src/dagre/bk.rs` module with data structures
  → [tasks/1.1-bk-module-structures.md](./tasks/1.1-bk-module-structures.md)

- [x] **1.2** Add helper functions for layer/neighbor traversal
  → [tasks/1.2-helper-functions.md](./tasks/1.2-helper-functions.md)

- [x] **1.3** Implement conflict detection (Type-1 and Type-2)
  → [tasks/1.3-conflict-detection.md](./tasks/1.3-conflict-detection.md)

## Phase 2: Vertical Alignment

- [x] **2.1** Implement `vertical_alignment()` for single direction/bias
  → [tasks/2.1-vertical-alignment.md](./tasks/2.1-vertical-alignment.md)

- [x] **2.2** Add block chain management (root, align pointers)
  → [tasks/2.2-block-chain-management.md](./tasks/2.2-block-chain-management.md)

- [x] **2.3** Add median neighbor calculation
  *(Covered in 2.1)*

- [x] **2.4** Unit tests for vertical alignment
  *(Covered in 2.1)*

## Phase 3: Horizontal Compaction

- [x] **3.1** Implement block width calculation
  → [tasks/3.1-horizontal-compaction.md](./tasks/3.1-horizontal-compaction.md)

- [x] **3.2** Implement `place_block()` for single block positioning
  *(Covered in 3.1)*

- [x] **3.3** Implement full `horizontal_compaction()`
  *(Covered in 3.1)*

- [x] **3.4** Unit tests for compaction
  *(Covered in 3.1)*

## Phase 4: Balance and Integration

- [x] **4.1** Implement 4-alignment computation (ul, ur, dl, dr)
  → [tasks/4.1-four-alignments.md](./tasks/4.1-four-alignments.md)

- [x] **4.2** Implement smallest-width selection
  *(Covered in 4.1)*

- [x] **4.3** Implement `balance()` to compute final coordinates
  *(Covered in 4.1)*

- [x] **4.4** Integrate with `position.rs`
  → Modified `assign_vertical()` and `assign_horizontal()` to use `position_x()`

## Phase 5: Testing and Validation

- [x] **5.1** Run `complex.mmd` and verify improved layout
  → [tasks/5.1-validation.md](./tasks/5.1-validation.md)

- [x] **5.2** Run all integration tests, update expectations
  *(All 27 integration tests pass)*

- [x] **5.3** Visual review of all fixtures
  *(All 26 fixtures render correctly)*

- [x] **5.4** Performance benchmarking
  *(Tests run quickly, no performance regression observed)*

---

## Progress Tracking

| Phase | Status | Commit | Notes |
|-------|--------|--------|-------|
| 1 - Infrastructure | Complete | `4d8e06d` | Data structures, helpers, conflict detection |
| 2 - Vertical Alignment | Complete | `9bd177c` | vertical_alignment(), block management, tests |
| 3 - Horizontal Compaction | Complete | `fe18dcf` | horizontal_compaction(), place_block(), tests |
| 4 - Balance/Integration | Complete | `e7dad61` | position_x(), balance(), all 4 alignments |
| 5 - Testing/Integration | Complete | `c18ea05` | Integrated with position.rs, all tests pass |
| Cleanup | Complete | `253c099` | Removed unused test helper functions |

## Known Limitations

The BK algorithm computes 4 different alignments and returns their median. This works well for most graphs but can produce suboptimal results when a node has predecessors on opposite sides of the layout:

- Example: In `complex.mmd`, Output has edges from both "More Data?" (right) and "Cleanup" (left)
- The algorithm balances between alignments, placing Output in the middle
- This causes both incoming edges to bend rather than one being straight

This is inherent to the median-based balancing approach. Potential improvements:
- Use smallest-width alignment instead of median
- Weight alignments by edge importance (e.g., labeled edges)
- Allow configuration to prefer specific alignment directions

## Final Statistics

- **Lines added**: ~800 lines in `src/dagre/bk.rs`
- **Tests**: 48 unit tests for BK algorithm
- **Integration**: Modified `position.rs` to use BK for coordinate assignment

## Dependencies

- Requires understanding of Sugiyama framework
- Requires access to layer ordering from `order.rs`
- Requires dummy node information from `normalize.rs`

---

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Dagre Edge Routing | [research/archive/0006-edge-routing-horizontal-offset/02-dagre-edge-routing.md](../../research/archive/0006-edge-routing-horizontal-offset/02-dagre-edge-routing.md) |
| Research: Full Parity Analysis | [research/archive/0006-edge-routing-horizontal-offset/05-full-dagre-parity-analysis.md](../../research/archive/0006-edge-routing-horizontal-offset/05-full-dagre-parity-analysis.md) |
| Existing dagre module | [src/dagre/](../../src/dagre/) |
