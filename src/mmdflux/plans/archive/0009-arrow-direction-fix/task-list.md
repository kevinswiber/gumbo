# Arrow Direction Fix Task List

## Status: ✅ COMPLETE

## Phase 1: Arrow Direction Detection (DONE)
- [x] **1.1** Add `entry_direction_from_segments()` helper function to `router.rs`
- [x] **1.2** Update `route_edge_direct()` to use segment-based entry direction
- [x] **1.3** Update `route_edge_with_waypoints()` to use segment-based entry direction
- [x] **1.4** Verify backward edge functions still use correct fixed directions

## Phase 2: Final Segment Orientation (DONE)
- [x] **2.1** LR/RL: Change to L-shaped paths (H-V) for diagonal approaches
- [x] **2.2** TD/BT: Change to Z-shaped paths (V-H-V) for canonical top/bottom entry
- [x] **2.3** Update `entry_direction_from_segments()` to use last segment

## Phase 3: Testing (DONE)
- [x] **3.1** Test `fan_in_lr.mmd` - diagonal edges have ▼/▲, direct has ►
- [x] **3.2** Test `fan_in.mmd` (TD) - all edges have ▼
- [x] **3.3** Test `five_fan_in.mmd` (TD) - all 5 edges have ▼
- [x] **3.4** Test BT direction - all edges have ▲
- [x] **3.5** Test RL direction - diagonal edges have ▼/▲, direct has ◄
- [x] **3.6** Run full test suite (`cargo test`) - all tests pass

## Results

**TD layout (fan_in.mmd)** - All edges enter from top:
```
           │           │           │
           └───────┐   │   ┌───────┘
                   ▼   ▼   ▼
                  ┌────────┐
                  │ Target │
```

**LR layout (fan_in_lr.mmd)** - Diagonal edges enter vertically, direct enters horizontally:
```
         └──────┐
                │
                ▼
 ┌───────┐    ┌────────┐
 │ Src B │───►│ Target │
 └───────┘    └────────┘
                ▲
                │
         ┌──────┘
```

## Path Shapes by Layout

| Layout | Displacement | Path Shape | Final Segment | Arrow |
|--------|-------------|------------|---------------|-------|
| TD/BT  | Horizontal  | V-H-V (Z)  | Vertical      | ▼/▲   |
| TD/BT  | None        | V          | Vertical      | ▼/▲   |
| LR/RL  | Vertical    | H-V (L)    | Vertical      | ▼/▲   |
| LR/RL  | None        | H          | Horizontal    | ►/◄   |

## Commits

- `9c3a7ad` fix(router): Match arrow direction with final segment orientation
- `c35b113` fix(router): Use Z-shaped paths for TD/BT layouts to ensure vertical entry

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Arrow Direction | ✅ Complete | Arrow glyphs derived from final segment |
| 2 - Segment Orientation | ✅ Complete | TD/BT uses Z-shape, LR/RL uses L-shape (`9c3a7ad`, `c35b113`) |
| 3 - Testing | ✅ Complete | All tests pass |
