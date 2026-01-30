# Subgraph Border Overlap Fix — Task List

## Status: ✅ COMPLETE

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Add `to_ascii_rect()` to TransformContext

- [x] **1.1** Add `to_ascii_rect()` with unit tests
  → [tasks/1.1-to-ascii-rect.md](./tasks/1.1-to-ascii-rect.md)

- [x] **1.2** Verify containment of member-node positions
  → [tasks/1.2-containment-check.md](./tasks/1.2-containment-check.md)

## Phase 2: Use dagre bounds in `convert_subgraph_bounds()`

- [x] **2.1** Test non-overlapping dagre bounds
  → [tasks/2.1-non-overlap-test.md](./tasks/2.1-non-overlap-test.md)

- [x] **2.2** Use post-hoc overlap resolution (diverted from dagre bounds)
  → [tasks/2.2-dagre-bounds-primary.md](./tasks/2.2-dagre-bounds-primary.md)

- [x] **2.3** Integration test for subgraph_edges.mmd
  → [tasks/2.3-integration-test.md](./tasks/2.3-integration-test.md)

## Phase 3: Protect title characters from edge overwrite

- [x] **3.1** Test title character protection
  → [tasks/3.1-title-protection-test.md](./tasks/3.1-title-protection-test.md)

- [x] **3.2** Implement `is_subgraph_title` flag and protection
  → [tasks/3.2-title-flag.md](./tasks/3.2-title-flag.md)

- [x] **3.3** Integration test for edge-title interaction
  → [tasks/3.3-edge-title-integration.md](./tasks/3.3-edge-title-integration.md)

## Phase 4: Integration verification and cleanup

- [x] **4.1** Run full test suite and fix regressions
  *(Run `cargo test` and `cargo test --test integration`, fix any failures)*

- [x] **4.2** Update integration test assertions
  → [tasks/4.2-update-assertions.md](./tasks/4.2-update-assertions.md)

- [x] **4.3** Clean up unused code
  *(Removed unused dagre_bounds/ctx/padding params from convert_subgraph_bounds, updated doc comments)*

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 — TransformContext | Complete | |
| 2 — dagre bounds | Complete | Diverted to post-hoc overlap resolution |
| 3 — Title protection | Complete | |
| 4 — Integration/cleanup | Complete | |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research 0021 Synthesis | [synthesis.md](../../research/0021-subgraph-border-overlap-deep-dive/synthesis.md) |
| Q4: Coordinate Fix | [q4-coordinate-transformation-fix.md](../../research/0021-subgraph-border-overlap-deep-dive/q4-coordinate-transformation-fix.md) |
| Issue 0005 | [issues.md](../../issues/0005-subgraph-border-overlap/issues.md) |
| Plan 0026 Finding | [dagre-to-draw-coordinate-mismatch.md](../0026-subgraph-padding-overlap/findings/dagre-to-draw-coordinate-mismatch.md) |
