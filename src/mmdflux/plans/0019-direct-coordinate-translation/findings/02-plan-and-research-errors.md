# Plan and Research Errors

## Plan Errors

### 1. Edge Struct Field Mismatch in Test Code

**Location:** Task files for Phase 4 (waypoint transform) and Phase 5 (label transform).

**Error:** Plan's test code used:
```rust
arrow_start: Arrow::None,
arrow_end: Arrow::Normal,
```

**Reality:** The `Edge` struct has a single `arrow: Arrow` field, not separate
`arrow_start`/`arrow_end` fields. The current parser and grammar only support
unidirectional arrows.

**Fix applied:** Replaced with `arrow: Arrow::Normal` in all test code.

**Root cause:** The plan was written with an assumed richer Edge model. This suggests
the plan was designed partially from memory rather than by reading the actual struct
definition. The planning agent should have read `src/graph/edge.rs` to verify the
Edge struct fields.

**Follow-up:** The user noticed this and asked whether we should add `arrow_start`
support for bidirectional edges (`A<-->B`). Decision: defer as a separate feature,
since the Mermaid grammar doesn't currently support `<-->`.

### 2. Wrong Fixture for Backward-Edge Stagger Test

**Location:** Task 7.1 (`tasks/7.1-backward-edge-overlap.md`).

**Error:** Plan specified `multiple_cycles.mmd` as the test fixture for verifying
backward-edge stagger preservation.

**Reality:** `multiple_cycles.mmd` contains:
```
graph TD
    A[Start] --> B[Process]
    B --> C[End]
    C --> A
    C --> B
```
This produces a layout where A, B, C are each in their own rank/layer. Each layer
has exactly one node, so there's no cross-axis stagger to preserve — all nodes
having the same x-center is correct behavior.

**Fix applied:** Changed to `fan_out.mmd`:
```
graph TD
    A --> B
    A --> C
    A --> D
```
Here B, C, D share a layer and dagre assigns them distinct x positions, making this
a valid test for cross-axis stagger preservation.

**Root cause:** The plan assumed `multiple_cycles.mmd` had multiple nodes per layer
because it has cycles (backward edges). But cycles don't imply multiple nodes per
layer — they create edges that go against the rank direction, not necessarily
same-rank node placement.

### 3. Assembly Function Size Underestimate

**Error:** Plan estimated `compute_layout_direct()` at ~50 lines.

**Actual:** ~250 lines.

**Root cause:** The plan focused on the mathematical transformation steps (scale,
round, repair) but underestimated the dagre result extraction, Layout struct
population, and edge case handling code needed for a complete function.

### 4. Net Code Change Estimate

**Error:** Plan estimated "net reduction of ~300 lines" based on removing old code.

**Actual:** Net increase of ~430 lines (no old code removed).

This was a cascade from the old-code-retention deviation, not an error in the
per-function estimates.

## Research Errors / Inaccuracies

### 5. Research Open Question: Rounding Precision at Small Scales

**Source:** `research/0012-edge-sep-pipeline-comparison/q5-direct-translation-design.md`

The research flagged "rounding precision at small scales" as an open question,
worrying that integer rounding after scaling might cause position collisions or
misalignment for small diagrams.

**Finding:** This was a non-issue in practice. The collision repair step
(Phase 3) handles any rounding-induced overlaps, and none of the 26 test fixtures
showed rounding-related problems. The per-axis scale factors are always >= 1.0
because ASCII cells are never smaller than dagre's float coordinates, so rounding
errors are bounded to ±1 cell.

### 6. Research Open Question: Cascading Collision Repair Drift

**Source:** `research/0012-edge-sep-pipeline-comparison/q5-direct-translation-design.md`

The research noted that cascading collision pushes could cause "drift" where
nodes accumulate displacement away from their ideal positions, potentially
expanding the canvas beyond what's necessary.

**Finding:** Not observed in practice across 26 fixtures. The collision repair
operates within layers (nodes sharing the same rank), and typical diagrams have
few nodes per layer (1-3). With so few nodes, cascading doesn't accumulate
significant drift. The repair also sorts by cross-axis position before processing,
which minimizes unnecessary pushes.

### 7. Research: Stagger Pipeline Characterization Was Accurate

**Source:** `research/0012-edge-sep-pipeline-comparison/synthesis.md`

The research accurately characterized the stagger pipeline as:
- Converting float coordinates to integer grid positions (losing relative spacing)
- Then expanding grid positions to draw coordinates with uniform spacing
- Resulting in layouts that don't respect dagre's proportional node placement

The direct pipeline's visual regression comparison confirmed this: all 26 fixtures
produced different (slightly more compact) output, validating the research's claim
that the stagger pipeline over-expands spacing.

### 8. Research: Scale Factor Formula Worked as Designed

**Source:** `research/0012-edge-sep-pipeline-comparison/q5-direct-translation-design.md`

The research proposed:
- `scale_y = (max_h + v_spacing) / (max_h + rank_sep)` for vertical axis
- `scale_x = (avg_w + h_spacing) / (avg_w + node_sep)` for horizontal axis

These formulas were implemented exactly as specified and worked correctly on all
26 fixtures without modification. The per-axis approach (rather than a single
global scale) was the right call — it allows vertical and horizontal spacing to
be tuned independently.
