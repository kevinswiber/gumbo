# Test Insights

## 1. TDD Red-Green-Refactor Worked Well for Math-Heavy Code

The strict TDD approach (stub returning dummy value → write failing tests → implement
minimum code) worked particularly well for the scale factor, collision repair, and
transformation functions. These are pure functions with clear inputs and outputs,
making them ideal for test-first development.

The "red" phase caught several issues before they could compound:
- Scale factor tests immediately validated the formula correctness
- Collision repair tests confirmed cascading behavior
- Waypoint transform tests verified layer-snapping logic

## 2. Fixture Choice Matters More Than Expected

The Phase 7 fixture mistake (using `multiple_cycles.mmd` for stagger preservation)
highlights that understanding what a fixture *actually produces* is critical. The
fixture name suggested it would have interesting multi-node-per-layer structure,
but in reality it's a linear chain with backward edges.

**Lesson:** When writing tests that depend on layout properties (e.g., "multiple
nodes in the same layer"), verify the fixture produces that property by inspecting
the dagre output, not by assuming from the diagram structure.

## 3. Snapshot Testing Is Valuable but Has Maintenance Cost

The 26 baseline snapshots in `tests/snapshots/` served two purposes:
1. Phase 8 regression detection (comparing old vs new)
2. Ongoing change detection (any future pipeline change will diff against snapshots)

However, regenerating all 26 snapshots was needed twice:
- Once during Phase 1 (initial baseline with old pipeline)
- Once during Phase 9.1 (new baseline with new pipeline)

**Lesson:** Snapshot tests are great for catching unintended changes but require
regeneration whenever intentional changes are made. The `generate_baseline_snapshots`
test function makes this easy, but it's important to remember to regenerate after
any rendering change.

## 4. Integration Tests Complement Unit Tests

The unit tests in `layout.rs` test individual functions (scale factors, collision
repair, etc.) in isolation with synthetic inputs. The integration tests in
`integration.rs` test the full pipeline with real `.mmd` fixtures.

Both caught different issues:
- Unit tests caught formula errors immediately
- Integration tests caught real-world layout problems (like canvas dimension issues)

The `direct_no_node_overlaps` integration test is particularly valuable — it
verifies the collision repair works end-to-end on real diagrams, not just
synthetic inputs.

## 5. Test Helpers Reduce Boilerplate

Adding `parse_and_build()`, `layout_fixture()`, and `render_with_layout()` helpers
significantly reduced test boilerplate. Future tests can use these to quickly set
up test scenarios without duplicating fixture loading and diagram building code.

## 6. Diagnostic Tests Are Useful During Development

The `compare_old_vs_new_all_fixtures` test was written as a diagnostic tool during
Phase 8, not as a permanent regression test. It prints both outputs for manual
inspection rather than asserting equality.

This pattern — write a diagnostic test to understand behavior, then write targeted
assertion tests for specific properties — worked well. The diagnostic test could
be removed or annotated with `#[ignore]` after the comparison phase is complete.

## 7. Old Pipeline Tests Provide Safety Net

Retaining the old `compute_layout_dagre` code means its existing tests still run
and pass. This provides confidence that:
- The old code isn't accidentally broken by new code additions
- Future refactoring can compare both pipelines if needed
- The old pipeline can be switched back to if a critical regression is found

The downside is maintaining two code paths, but the safety net value justified
keeping them during the transition period.

## 8. Edge Struct Tests Need Real Struct Inspection

The `arrow_start`/`arrow_end` test code error (see `02-plan-and-research-errors.md`)
happened because test code was written from assumptions about the Edge struct rather
than from reading the actual definition. When writing tests for functions that take
domain types, always read the type definition first.

## 9. Test Count Progression

| Phase | Tests Added | Running Total |
|-------|-------------|---------------|
| Baseline | 0 | 334 |
| Phase 2 (scale factors) | 4 | 338 |
| Phase 3 (collision repair) | 6 | 344 |
| Phase 4 (waypoint transform) | 4 | 348 |
| Phase 5 (label transform) | 4 | 352 |
| Phase 6 (assembly) | 5 | 357 |
| Phase 7 (backward edge) | 2 | 359 |
| Phase 8 (visual regression) | 1 | 360 |
| Phase 9 (switch) | 0 | 360 |

Note: Some tests were added as `#[ignore]` (snapshot generation, diagnostic
comparison) and aren't counted in the regular test run of 354 passing tests.
