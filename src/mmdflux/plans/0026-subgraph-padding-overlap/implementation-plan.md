# Subgraph Padding, Border, and Title Rendering Fixes

## Status: 🚧 IN PROGRESS

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Fix 10 visual defects in subgraph rendering by replacing the hardcoded bounds computation with dagre-derived bounds, adding title-width-aware sizing, embedding titles in the top border line, and improving edge-border interactions.

All work is in the `/Users/kevin/src/mmdflux-subgraphs/` worktree.

## Current State

Research `0019-subgraph-padding-overlap` identified a fundamental architectural disconnect: dagre computes compound node bounds via border nodes, but `convert_subgraph_bounds()` in `src/render/layout.rs` (lines 696-749) ignores these bounds (the `_dagre_bounds` parameter), instead recomputing from member-node draw positions with hardcoded 2-cell padding. This causes:

- Inter-subgraph border collisions (Issues 5, 6, 10)
- Title clipping and overflow (Issues 1, 3, 8)
- Title-content collisions (Issues 2, 3, 10)
- Edges punching through borders (Issues 4, 9)
- Backward edges escaping subgraph boundaries (Issue 7)

## Design Decisions

**Embedded title in border**: Render titles as `┌─ Title ─┐` instead of floating above the box. This eliminates y=0 clipping, title-content collisions, and reduces vertical space.

**Dagre bounds via TransformContext**: Transform the dagre `Rect` (center-based coordinates) through `TransformContext::to_ascii()` to get draw-coordinate bounds. This preserves dagre's inter-subgraph spacing guarantees.

**Title width enforcement**: After transforming dagre bounds, ensure `border_width >= title.len() + 4` (corners + spaces), expanding symmetrically if needed.

## Implementation Approach

### Phase 1: Use Dagre Bounds via TransformContext
Replace hardcoded member-node bounding box with dagre's border-node-derived bounds, fixing inter-subgraph spacing.

### Phase 2: Embed Title in Top Border Line
Replace floating title with `┌─ Title ─┐` embedded style, fixing y=0 clipping and title collisions. Enforce title-width-aware border sizing.

### Phase 3: Integration Test Updates
Update all subgraph integration tests for the new rendering format. Add non-overlap assertions.

### Phase 4: Edge-Border Crossing Cleanup
When edges cross subgraph borders, produce proper junction characters instead of corrupted output.

### Phase 5: Backward Edge Containment
Expand subgraph bounds to contain backward edge routing paths.

## Files to Modify/Create

| File | Changes |
|------|---------|
| `src/render/layout.rs` | Core bounds computation in `convert_subgraph_bounds()`, title width enforcement |
| `src/render/subgraph.rs` | Embedded title rendering, remove floating title |
| `src/render/canvas.rs` | Border-aware connection merging in `set_with_connection()` |
| `src/render/chars.rs` | New `infer_connections()` method |
| `src/render/mod.rs` | No structural changes, but edge-border interaction verification |
| `tests/integration.rs` | Updated assertions, new overlap tests |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Test dagre bounds produce correct spacing | [tasks/1.1-test-dagre-bounds.md](./tasks/1.1-test-dagre-bounds.md) |
| 1.2 | Implement dagre bounds transformation | [tasks/1.2-implement-dagre-bounds.md](./tasks/1.2-implement-dagre-bounds.md) |
| 1.3 | Clean up unused parameters | *(Covered in 1.2 refactor)* |
| 2.1 | Test embedded title rendering | [tasks/2.1-test-embedded-title.md](./tasks/2.1-test-embedded-title.md) |
| 2.2 | Implement embedded title rendering | [tasks/2.2-implement-embedded-title.md](./tasks/2.2-implement-embedded-title.md) |
| 2.3 | Test title width influences border width | [tasks/2.3-test-title-width.md](./tasks/2.3-test-title-width.md) |
| 2.4 | Enforce title width minimum in bounds | [tasks/2.4-implement-title-width.md](./tasks/2.4-implement-title-width.md) |
| 2.5 | Remove title_height from bounds computation | *(Covered in 2.4 refactor)* |
| 3.1 | Update integration tests for new format | [tasks/3.1-update-integration-tests.md](./tasks/3.1-update-integration-tests.md) |
| 3.2 | Fix remaining test failures | *(Covered in 3.1)* |
| 3.3 | Full test suite verification | *(Covered in 3.1 refactor)* |
| 4.1 | Test edge-border crossing produces junctions | [tasks/4.1-test-edge-border-crossing.md](./tasks/4.1-test-edge-border-crossing.md) |
| 4.2 | Implement border-aware connection merging | [tasks/4.2-implement-edge-border-merging.md](./tasks/4.2-implement-edge-border-merging.md) |
| 4.3 | Add infer_connections to CharSet | *(Covered in 4.2)* |
| 4.4 | Test infer_connections | *(Covered in 4.1)* |
| 5.1 | Test backward edge stays within subgraph | [tasks/5.1-test-backward-containment.md](./tasks/5.1-test-backward-containment.md) |
| 5.2 | Expand bounds for backward edge routing | [tasks/5.2-implement-backward-containment.md](./tasks/5.2-implement-backward-containment.md) |
| 5.3 | Pass direction/edges to convert_subgraph_bounds | *(Covered in 5.2 refactor)* |

## Research References

- [Synthesis](../../research/0019-subgraph-padding-overlap/synthesis.md)
- [Q1: Bounds calculation](../../research/0019-subgraph-padding-overlap/q1-bounds-calculation.md)
- [Q2: Title rendering](../../research/0019-subgraph-padding-overlap/q2-title-rendering.md)
- [Q3: Overlap inventory](../../research/0019-subgraph-padding-overlap/q3-overlap-inventory.md)
- [Q4: dagre.js compound sizing](../../research/0019-subgraph-padding-overlap/q4-dagre-compound-sizing.md)
- [Q5: Mermaid subgraph rendering](../../research/0019-subgraph-padding-overlap/q5-mermaid-subgraph-rendering.md)

## Testing Strategy

All tasks follow strict TDD (Red/Green/Refactor). Key test categories:
- **Unit tests**: bounds computation, title rendering, connection inference
- **Integration tests**: full render output for subgraph fixtures
- **Non-overlap assertions**: programmatic verification that subgraph borders don't collide

## Risks and Mitigations

1. **Dagre bounds may be too tight or too wide**: Keep member-node fallback and add minimum padding floor
2. **Embedded title changes visual appearance**: Phase 3 dedicates to updating all assertions
3. **`infer_connections()` may miss characters**: Returns `Connections::none()` for unrecognized chars (safe default)
4. **Backward edge expansion may make subgraphs too wide**: Only expand when backward edges actually exist within the subgraph
