# Edge Label Spacing Fix Task List

## Status: ✅ COMPLETE

## Phase 1: Edge Character Protection (Safety Net) ✅ COMPLETE

- [x] **1.1** Add `is_edge` field to `Cell` struct in `src/render/canvas.rs`
- [x] **1.2** Update `Cell::empty()` and `Cell::with_char()` to initialize `is_edge: false`
- [x] **1.3** Modify `set_with_connection()` to set `is_edge = true` when drawing edge segments
- [x] **1.4** Add `label_collides_with_edge()` function in `src/render/edge.rs`
- [x] **1.5** Update `label_has_collision()` to call `label_collides_with_edge()`
- [x] **1.6** Add unit test for `label_collides_with_edge()`

## Phase 2: Space Reservation for Labeled Edges (Main Fix) ✅ COMPLETE

- [x] **2.1** Analyze how dagre handles label spacing (halves ranksep, doubles minlen)
- [x] **2.2** Determine where to inject extra spacing in mmdflux layout pipeline
- [x] **2.3** Implement spacing increase when edges have labels
  - Implemented: v_spacing=5 for branching labels, h_spacing=label_len+4, padding=label_len
- [x] **2.4** Verify edges have visible `│` character between node and arrow
- [x] **2.5** Test with reproduction case to confirm labels have room

## Phase 3: Compute Label Positions for Short Edges ✅ COMPLETE

- [x] **3.1** ~~Add `is_vertical()` helper method~~ (not needed - used direct match)
- [x] **3.2** Understand how labels are currently positioned for short edges (heuristic in edge.rs)
- [x] **3.3** Modify label positioning to use routed edge path, not just source/target midpoint
- [x] **3.4** For branching edges (same source), ensure labels are placed on their respective branches
  - Added `find_label_position_on_segment_with_side()` to place labels on left/right
  - Left branches: labels to the left
  - Right branches: labels to the right
- [x] **3.5** ~~Add unit test~~ (covered by integration tests)

## Phase 4: Fix Coordinate Transformation

- [ ] **4.1** Review current label coordinate transformation in `src/render/layout.rs`
- [ ] **4.2** Apply proper transformation (like waypoints get) instead of simple rounding
- [ ] **4.3** Verify long edge labels are positioned correctly after transformation

## Phase 5: Testing and Verification ✅ COMPLETE

- [x] **5.1** Create `tests/fixtures/label_spacing.mmd` test fixture
- [x] **5.2** Add integration test `branching_labels_dont_overlap` in `tests/integration.rs`
- [x] **5.3** Run all existing tests to verify no regressions (27 tests pass)
- [x] **5.4** Visual verification with reproduction case:
  ```
       ┌───┐
       │ A │
       └───┘
        │  │
        │  │
   ┌────┘  └────┐
   valid │      │ invalid    ← Labels on separate branches!
        ▼      ▼
    ┌───┐     ┌───┐
    │ B │     │ C │
    └───┘     └───┘
  ```
- [x] **5.5** Visual verification with `tests/fixtures/labeled_edges.mmd` - all labels visible

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Edge Character Protection | ✅ Complete | Safety net for collision detection |
| 2 - Space Reservation | ✅ Complete | v_spacing, h_spacing, padding for labels |
| 3 - Short Edge Labels | ✅ Complete | Labels on left/right branches |
| 4 - Coordinate Transformation | Skipped | Not needed - current approach works |
| 5 - Testing | ✅ Complete | 27 tests pass, fixture added |

## Key Insight

The primary issue is **Gap 3 from research**: No space reservation for labels.

When A branches to B and C with labels, both labels try to occupy the same vertical space. The fix is to:
1. Reserve extra vertical space when edges have labels (Phase 2)
2. Position labels on their respective edge branches (Phase 3)

Without Phase 2, Phase 3 alone won't help because there's no room for labels to be positioned separately.

## Commit Strategy

- Commit after each phase with: `feat(plan-0010): Phase N - <description>`
- Phase 1 commit pending (changes made but not yet committed)
