# Label-as-Dummy-Node Implementation Plan

## Status: 🚧 IN PROGRESS

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Replace heuristic edge label placement with the algorithmically correct "label-as-dummy-node" approach used by Dagre.js. Edge labels participate in layout as first-class spatial objects — the layout engine reserves space for them, guaranteeing collision-free placement without post-hoc heuristics.

This work is done in a git worktree off `main` to isolate it from the current workstream, since it touches core layout pipeline code.

## Prior Work

- **Plan 0010** (`plans/archive/0010-edge-label-spacing/`) — Added heuristic edge character protection and global spacing adjustments. Identified that short edges lack label positions and that dagre's `makeSpaceForEdgeLabels` approach is the proper fix. Did NOT implement label-as-dummy-node.
- **Research 0017** (`research/0017-architecture-algorithm-audit/`) — Recommendation #5: "Adopt label-as-dummy-node for edge labels. Replace heuristic label placement with Dagre's approach of giving labels width/height during layout."
- **Research Q7** (`research/0017-architecture-algorithm-audit/q7-edge-routing-labels.md`) — Detailed comparison of Dagre.js label-as-dummy-node pipeline vs mmdflux heuristic placement.

## Current State

mmdflux already has partial infrastructure for label dummies:

1. **Data structures exist** in `src/dagre/normalize.rs`: `DummyType::EdgeLabel`, `DummyNode::edge_label()`, `DummyChain` with `label_dummy_index`, `EdgeLabelInfo`, `LabelPos`, `get_label_position()`
2. **Layout API exists** in `src/dagre/mod.rs`: `layout_with_labels()` accepts `edge_labels`
3. **Bridge layer exists** in `src/render/layout.rs`: `compute_layout_direct()` creates `EdgeLabelInfo`, passes to dagre, transforms results
4. **Render layer exists** in `src/render/edge.rs`: `render_all_edges_with_labels()` checks precomputed positions before falling back to heuristics

**What's missing:**

1. **Short edges (1-rank span) never get label dummies** — normalization only processes edges spanning >1 rank
2. **No `makeSpaceForEdgeLabels` equivalent** — no mechanism to force labeled short edges to span 2 ranks
3. **No per-edge `minlen` support** — the ranking algorithm hardcodes minimum edge length of 1
4. **Label positions often out of bounds** — coordinate transform produces positions that fail canvas bounds checks

## Implementation Approach

### Strategy: Targeted minlen (not global doubling)

Dagre.js doubles ALL edge minlens and halves ranksep. We use a targeted approach: only set `minlen=2` for edges with labels. This avoids penalizing unlabeled edges with extra spacing.

### Phase 0: Worktree Setup

Set up isolated git worktree for experimentation.

### Phase 1: Add Per-Edge `minlen` Support

Add `minlen` field to edges in the layout graph and update the longest-path ranking algorithm to respect it.

### Phase 2: Make Space for Edge Labels

Implement the equivalent of Dagre's `makeSpaceForEdgeLabels()`: set `minlen=2` for labeled edges before ranking, so the ranker creates a gap where a label dummy can be inserted.

### Phase 3: Verify Label Dummy Creation

With minlen=2 for labeled edges, formerly-short edges now span 2 ranks. The existing normalization code should create label dummy nodes at the midpoint rank. Verify this works for both short and long edges.

### Phase 4: Verify Coordinate Assignment and Denormalization

Confirm that Brandes-Kopf allocates space for label dummies (they have non-zero dimensions) and that denormalization extracts label positions correctly.

### Phase 5: Fix ASCII Coordinate Transform

Ensure label positions survive the dagre-to-ASCII coordinate transformation and land within canvas bounds.

### Phase 6: Update Edge Rendering

Wire precomputed label positions into the rendering pipeline, reducing reliance on heuristic fallbacks.

### Phase 7: Integration Testing and Cleanup

End-to-end testing with fixtures, edge case verification, and cleanup of superseded heuristic code.

## Files to Modify/Create

| File | Changes |
|------|---------|
| `src/dagre/graph.rs` | Add `edge_minlens` field to `LayoutGraph` |
| `src/dagre/rank.rs` | Respect per-edge `minlen` in longest-path ranking |
| `src/dagre/mod.rs` | Add `make_space_for_edge_labels()`, wire into pipeline |
| `src/dagre/normalize.rs` | Verify/fix label dummy creation for short-to-long edges |
| `src/render/layout.rs` | Fix label position coordinate transform |
| `src/render/edge.rs` | Prefer precomputed label positions, simplify heuristics |
| `src/render/mod.rs` | Update `layout_config_for_diagram()` margin heuristics |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 0.1 | Create git worktree | [tasks/0.1-worktree-setup.md](./tasks/0.1-worktree-setup.md) |
| 1.1 | Add `minlen` field to `LayoutGraph` edges | [tasks/1.1-minlen-field.md](./tasks/1.1-minlen-field.md) |
| 1.2 | Update longest-path ranking to respect `minlen` | [tasks/1.2-ranking-minlen.md](./tasks/1.2-ranking-minlen.md) |
| 2.1 | Implement `make_space_for_edge_labels()` | [tasks/2.1-make-space.md](./tasks/2.1-make-space.md) |
| 2.2 | Wire into layout pipeline | [tasks/2.2-pipeline-wiring.md](./tasks/2.2-pipeline-wiring.md) |
| 3.1 | Verify label dummies for formerly-short edges | [tasks/3.1-verify-short-edge-dummies.md](./tasks/3.1-verify-short-edge-dummies.md) |
| 3.2 | Verify label dummies for already-long edges | [tasks/3.2-verify-long-edge-dummies.md](./tasks/3.2-verify-long-edge-dummies.md) |
| 4.1 | Verify BK handles label dummy dimensions | [tasks/4.1-verify-bk-dimensions.md](./tasks/4.1-verify-bk-dimensions.md) |
| 4.2 | Verify denormalization extracts label positions | [tasks/4.2-verify-denorm-positions.md](./tasks/4.2-verify-denorm-positions.md) |
| 5.1 | Fix ASCII coordinate transform for labels | [tasks/5.1-fix-coordinate-transform.md](./tasks/5.1-fix-coordinate-transform.md) |
| 6.1 | Prefer precomputed label positions in rendering | [tasks/6.1-precomputed-rendering.md](./tasks/6.1-precomputed-rendering.md) |
| 6.2 | Handle edge routing with label waypoints | [tasks/6.2-routing-label-waypoints.md](./tasks/6.2-routing-label-waypoints.md) |
| 7.1 | Integration tests with existing fixtures | [tasks/7.1-fixture-tests.md](./tasks/7.1-fixture-tests.md) |
| 7.2 | Edge case testing | [tasks/7.2-edge-cases.md](./tasks/7.2-edge-cases.md) |
| 7.3 | Simplify heuristic fallback code | [tasks/7.3-simplify-heuristics.md](./tasks/7.3-simplify-heuristics.md) |

## Research References

- [Research 0017 Synthesis](../../research/0017-architecture-algorithm-audit/synthesis.md) — Architecture audit recommending label-as-dummy-node
- [Q7: Edge Routing & Labels](../../research/0017-architecture-algorithm-audit/q7-edge-routing-labels.md) — Detailed comparison of Dagre.js vs mmdflux label handling
- [Plan 0010: Edge Label Spacing](../archive/0010-edge-label-spacing/implementation-plan.md) — Prior heuristic approach (superseded by this plan)

## Dependencies

**No dependencies on other research recommendations.** This plan is independent of:
- Network simplex ranking (#1) — longest-path ranking can support `minlen` trivially
- Self-edge handling (#2) — orthogonal concern
- Compound graph support (#3) — deferred
- Cross counting upgrade (#4) — orthogonal concern

The `minlen` support added in Phase 1 is a prerequisite for network simplex ranking, so this plan lays useful groundwork.

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Increased layout height for labeled edges | Medium — labeled edges span 2 ranks instead of 1 | Only increase minlen for labeled edges (targeted, not global) |
| Coordinate transform mismatch | High — labels could land outside canvas | Phase 5 specifically addresses this with tests |
| Unlabeled edge visual changes | Low — mixed graphs may lay out differently | Test with mixed labeled/unlabeled fixtures |
| Backward edges with labels | Medium — reversed edges complicate label rank calculation | Existing normalization handles direction; verify with tests |

## Testing Strategy

All tasks follow TDD (Red/Green/Refactor). Testing is layered:
- **Unit tests**: Each phase tests the specific module being changed
- **Integration tests**: Phase 7 runs full pipeline end-to-end on fixtures
- **Snapshot comparison**: Compare rendered output before/after for visual regression
- **Edge cases**: Long labels, multiple labeled edges, labeled backward edges, LR/RL directions
