# Port-Based Edge Attachment Task List

## Status: ❌ CANCELLED

## Phase 1: Port Counting Infrastructure
- [ ] **1.1** Add `NodePorts` and `EdgeRef` structs to `layout.rs`
- [ ] **1.2** Add `edge_ports: HashMap<String, NodePorts>` field to `Layout` struct
- [ ] **1.3** Implement `count_edge_ports()` function to populate port data during layout
- [ ] **1.4** Integrate port counting into `compute_layout()`
- [ ] **1.5** Integrate port counting into `compute_layout_dagre()`

## Phase 2: Port Position Methods
- [ ] **2.1** Add `port()` method to `NodeBounds` in `shape.rs`
- [ ] **2.2** Handle horizontal distribution (top/bottom sides)
- [ ] **2.3** Handle vertical distribution (left/right sides)
- [ ] **2.4** Add unit tests for port position calculation
- [ ] **2.5** Add diamond shape handling (reduced port range)

## Phase 3: Router Integration
- [ ] **3.1** Add `get_edge_port_info()` helper method to `Layout`
- [ ] **3.2** Modify `route_edge_direct()` to use port positions
- [ ] **3.3** Modify `route_edge_with_waypoints()` to use port positions
- [ ] **3.4** Update `attachment_point()` function to support port-based mode
- [ ] **3.5** Ensure backward edges still use right/bottom side (preserve Solution 1)

## Phase 4: Edge Ordering
- [ ] **4.1** Implement deterministic edge ordering within each port side
- [ ] **4.2** Order by peer node position (left-to-right for TD/BT, top-to-bottom for LR/RL)
- [ ] **4.3** Add tests for edge ordering consistency

## Phase 5: Testing
- [x] **5.1** Create test fixtures demonstrating collision issues (see `baseline-renders.md`)
  - `tests/fixtures/fan_in.mmd` - 3 sources to 1 target
  - `tests/fixtures/fan_out.mmd` - 1 source to 3 targets
  - `tests/fixtures/stacked_fan_in.mmd` - long edge hidden by short edges
  - `tests/fixtures/skip_edge_collision.mmd` - skip edge overlaps with path
  - `tests/fixtures/double_skip.mmd` - multiple skip edges stack
- [ ] **5.2** Add integration test for forward-forward collision resolution
- [ ] **5.3** Test all 4 directions (TD, BT, LR, RL)
- [ ] **5.4** Verify existing fixtures still render correctly (regression)
- [ ] **5.5** Compare renders against `baseline-renders.md` to verify improvement

## Baseline Documentation

**IMPORTANT**: See `baseline-renders.md` in this directory for "before" renders of collision cases.
After implementation, re-render these fixtures and compare to verify the fix works.

Key collision fixtures to check:
- `stacked_fan_in.mmd` - Top→Bot edge should be visible (currently hidden)
- `skip_edge_collision.mmd` - A→D should use separate port from A→B
- `double_skip.mmd` - Multiple skip edges should use distinct ports

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Port Counting Infrastructure | Not Started | |
| 2 - Port Position Methods | Not Started | |
| 3 - Router Integration | Not Started | |
| 4 - Edge Ordering | Not Started | |
| 5 - Testing | In Progress | Baseline fixtures created |
