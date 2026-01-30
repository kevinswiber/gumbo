# Declaration Order Layout Fix - Task List

## Status: ❌ CANCELLED

**Reason:** Superseded by dagre module implementation (plan 0005)

## Phase 1: Add IndexMap Dependency
- [ ] **1.1** Add `indexmap = "2"` to Cargo.toml dependencies

## Phase 2: Preserve Declaration Order in Diagram
- [ ] **2.1** Change `Diagram.nodes` from `HashMap<String, Node>` to `IndexMap<String, Node>`
- [ ] **2.2** Update imports in `src/graph/diagram.rs`
- [ ] **2.3** Verify `Diagram` API remains unchanged (IndexMap has same interface)

## Phase 3: Update Topological Sort Algorithm
- [ ] **3.1** Build declaration order map from IndexMap iteration order
- [ ] **3.2** Identify back-edges using declaration order comparison
- [ ] **3.3** Exclude back-edges when computing initial in-degrees
- [ ] **3.4** Change cycle-breaking tiebreaker from alphabetical to declaration order
- [ ] **3.5** Sort layers by declaration order instead of alphabetically

## Phase 4: Update Tests
- [ ] **4.1** Update `test_layout_handles_cycle` to verify declaration order
- [ ] **4.2** Add `test_topological_layers_cycle_respects_declaration_order` test
- [ ] **4.3** Run all existing tests to verify backward compatibility

## Phase 5: Verification
- [ ] **5.1** Verify `http_request.mmd` renders with Client at top
- [ ] **5.2** Run `cargo clippy` and fix any warnings
- [ ] **5.3** Run `cargo fmt` to ensure consistent formatting

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Add Dependency | Not Started | |
| 2 - Preserve Order | Not Started | |
| 3 - Update Algorithm | Not Started | |
| 4 - Update Tests | Not Started | |
| 5 - Verification | Not Started | |
