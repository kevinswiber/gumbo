# Subgraph Border Overlap Fix — Implementation Plan

## Status: 🚧 IN PROGRESS

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Fix the subgraph border overlap issue (Issue 0005) by correctly using dagre's computed subgraph bounds instead of the member-node fallback. dagre already guarantees non-overlapping bounds through border nodes and nesting edges, but mmdflux discards these because the coordinate transformation (`to_ascii()`) doesn't match the node position formula. The fix adds a `to_ascii_rect()` method that applies the correct transformation, then uses dagre bounds as the primary source in `convert_subgraph_bounds()`. Additionally, title characters in embedded borders are protected from edge overwrite.

## Current State

- `convert_subgraph_bounds()` receives `_dagre_bounds` (unused) and `_ctx` (unused)
- Computes bounds from member-node draw positions with fixed 2-cell `border_padding`
- No inter-subgraph awareness — adjacent subgraphs overlap
- Plan 0026 Phase 1 attempted to use dagre bounds with `to_ascii()` but reverted due to coordinate mismatch
- Title characters can be overwritten by edges (only `is_node` prevents overwrite)

## Implementation Approach

### Core Fix: Coordinate Transformation

For a dagre `Rect` with center-based `(x, y, width, height)`:

**Step 1 — Scale using right-edge offset** (matching node formula at layout.rs ~line 303):
```
scaled_cx = ((rect.x + rect.width/2.0 - dagre_min_x) * scale_x).round()
scaled_cy = ((rect.y + rect.height/2.0 - dagre_min_y) * scale_y).round()
```

**Step 2 — Scale extent**:
```
scaled_w = (rect.width * scale_x).round()
scaled_h = (rect.height * scale_y).round()
```

**Step 3 — Apply overhang and compute top-left**:
```
center_x = scaled_cx + overhang_x
center_y = scaled_cy + overhang_y
draw_x = center_x - scaled_w/2 + padding + left_label_margin
draw_y = center_y - scaled_h/2 + padding
```

### Strategy: dagre bounds primary, member-node fallback

1. Look up subgraph ID in `dagre_bounds`
2. If found, transform via `ctx.to_ascii_rect()`
3. Apply title-width minimum and backward edge expansion
4. If not found, fall back to member-node approach

## Files to Modify/Create

| File | Changes |
|------|---------|
| `src/render/layout.rs` | Add `to_ascii_rect()` to `TransformContext`; rewrite `convert_subgraph_bounds()` to use dagre bounds |
| `src/render/canvas.rs` | Add `is_subgraph_title` to `Cell`; add `set_subgraph_title_char()`; protect title chars in `set_with_connection()` |
| `src/render/subgraph.rs` | Use `set_subgraph_title_char()` for title text characters |
| `tests/integration.rs` | Add non-overlap assertions for subgraph borders |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Add `to_ascii_rect()` with unit tests | [tasks/1.1-to-ascii-rect.md](./tasks/1.1-to-ascii-rect.md) |
| 1.2 | Verify containment of member-node positions | [tasks/1.2-containment-check.md](./tasks/1.2-containment-check.md) |
| 2.1 | Test non-overlapping dagre bounds | [tasks/2.1-non-overlap-test.md](./tasks/2.1-non-overlap-test.md) |
| 2.2 | Use dagre bounds in convert_subgraph_bounds() | [tasks/2.2-dagre-bounds-primary.md](./tasks/2.2-dagre-bounds-primary.md) |
| 2.3 | Integration test for subgraph_edges.mmd | [tasks/2.3-integration-test.md](./tasks/2.3-integration-test.md) |
| 3.1 | Test title character protection | [tasks/3.1-title-protection-test.md](./tasks/3.1-title-protection-test.md) |
| 3.2 | Implement is_subgraph_title flag | [tasks/3.2-title-flag.md](./tasks/3.2-title-flag.md) |
| 3.3 | Integration test for edge-title interaction | [tasks/3.3-edge-title-integration.md](./tasks/3.3-edge-title-integration.md) |
| 4.1 | Run full test suite and fix regressions | *(Inline — run `cargo test`)* |
| 4.2 | Update integration test assertions | [tasks/4.2-update-assertions.md](./tasks/4.2-update-assertions.md) |
| 4.3 | Clean up unused code | *(Inline — remove underscore prefixes, update doc comments)* |

## Research References

- [Research 0021 Synthesis](../../research/0021-subgraph-border-overlap-deep-dive/synthesis.md)
- [Q4: Coordinate Transformation Fix](../../research/0021-subgraph-border-overlap-deep-dive/q4-coordinate-transformation-fix.md)
- [Q3: mmdflux Current Behavior](../../research/0021-subgraph-border-overlap-deep-dive/q3-mmdflux-current-behavior.md)
- [Issue 0005](../../issues/0005-subgraph-border-overlap/issues.md)
- [Plan 0026 Phase 1 Finding](../0026-subgraph-padding-overlap/findings/dagre-to-draw-coordinate-mismatch.md)

## Testing Strategy

All tasks follow strict TDD (Red/Green/Refactor). Key test categories:
- **Unit tests**: `to_ascii_rect()` correctness, containment verification, title protection
- **Integration tests**: Non-overlapping borders for `subgraph_edges.mmd`, title preservation, existing fixture regression

## Risks and Mitigations

1. **Rounding artifacts** — `.round()` can cause 1-pixel shifts. Mitigation: verify dagre bounds contain all member nodes, expand if needed.
2. **Backward edge expansion interaction** — dagre bounds may already be wide enough. Mitigation: keep expansion logic but only apply when needed.
3. **LR/RL layouts** — Coordinate axes swap. Mitigation: test with `multi_subgraph.mmd` (LR layout).
