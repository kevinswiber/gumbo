# Future Recommendations

## Deferred Work

### 1. Remove Old Stagger Pipeline

**What:** Delete `compute_layout_dagre()`, `compute_stagger_positions()`,
`map_cross_axis()`, `rank_cross_anchors` construction, and `global_scale`
computation from `src/render/layout.rs`. Update all tests that reference
`compute_layout_dagre` to use `compute_layout_direct` instead.

**Why deferred:** 15+ test references to the old pipeline made removal a
significant scope expansion during plan 0019.

**Estimated scope:** ~300 lines of dead code removal, ~15 test updates.

**Approach:** Create a new plan that:
1. Lists every test referencing `compute_layout_dagre`
2. For each test, determine if it should be updated, removed, or rewritten
3. Remove old code and update tests in a single commit
4. Verify all tests pass

### 2. Clean Up Layout Struct (Task 9.2)

**What:** Remove `grid_positions` from the `Layout` struct. It's populated by
`compute_layout_dagre` but never read downstream by any rendering code.

**Why deferred:** Can't remove the field while the old pipeline code still exists,
since it populates it.

**Dependency:** Complete recommendation #1 first.

### 3. Consider Removing Snapshot Generation Test

**What:** The `generate_baseline_snapshots` test function writes 26 files and is
marked `#[ignore]`. It's a utility, not a real test.

**Options:**
- Keep as-is (pragmatic, works fine with `#[ignore]`)
- Move to a separate binary or script
- Convert to a `cargo xtask` command

## Observations for Future Plans

### 4. Plan Test Code Should Reference Actual Types

Future plans that include test code snippets should verify struct fields against
the actual source code. The `arrow_start`/`arrow_end` error in this plan wasted
a small amount of time and could have been caught during planning.

**Recommendation:** When the planning agent writes test code that constructs
domain types, it should read the type definition and include a verification note
in the task file (e.g., "Verified: Edge struct has field `arrow: Arrow` per
`src/graph/edge.rs:15`").

### 5. Fixture Selection Should Be Verified

When a plan specifies a fixture for testing a specific property (e.g., "use
fixture X to test multi-node layers"), the planning agent should verify that the
fixture actually exhibits that property.

**Recommendation:** Include a "fixture verification" note in task files:
```markdown
## Fixture Verification
- `fan_out.mmd` produces layers: {rank 0: [A], rank 1: [B, C, D]}
- B, C, D have distinct x positions: [x1, x2, x3]
```

### 6. Scope Old Code Removal During Planning

When a plan replaces an existing system, the planning phase should explicitly
count references to the old code and estimate the removal effort. This plan
assumed removal would be straightforward but didn't count the test references.

### 7. Bidirectional Arrow Support

The user asked about `arrow_start` support for `A<-->B` edges during Phase 4.
This would require:
- Grammar change in `grammar.pest` to support `<-->` connector
- AST change to represent bidirectional arrows
- Edge struct change to `arrow_start: Arrow, arrow_end: Arrow`
- Rendering changes for double-headed arrows

This is a feature request, not a bug fix, and should be tracked separately.

### 8. Research Open Questions Were Non-Issues

Two research open questions — rounding precision at small scales and cascading
collision repair drift — turned out to be non-issues in practice. This suggests
the research was appropriately conservative in flagging potential concerns, but
future plans can treat similar "possible concern" notes as low-priority risks
rather than blocking issues.

## Architecture Notes

### 9. Direct Pipeline Is More Maintainable

The direct pipeline has a simpler mental model than the stagger pipeline:
- **Stagger:** dagre coords → grid indices → draw coords (3 coordinate spaces)
- **Direct:** dagre coords → ASCII coords (2 coordinate spaces)

Future layout changes should be made to `compute_layout_direct` only. The old
pipeline should not receive new features.

### 10. Collision Repair Is the Key Innovation

The collision repair step is what makes the direct pipeline work. Without it,
integer rounding could cause node overlaps. The repair is simple (sort by
position, enforce minimum spacing with cascading pushes) but essential.

If future layout changes cause collision repair to be insufficient (e.g., nodes
that need 2D repair, not just 1D per-layer), the repair function would need to
be extended. Currently it only operates on the cross-axis within each layer.
