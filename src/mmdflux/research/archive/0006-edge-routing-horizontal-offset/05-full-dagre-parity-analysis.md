# Full Dagre Parity Analysis: Doing It Right Once

## Executive Summary

This document analyzes what it would take to achieve close parity with Mermaid/Dagre for edge routing, with the goal of solving edge routing issues comprehensively rather than patching individual edge cases.

**Key Finding:** mmdflux already implements ~80% of the Sugiyama framework that Dagre uses. The gap is primarily in **coordinate assignment** - Dagre uses Brandes-Kopf optimization while mmdflux uses simple layer centering. This gap causes the horizontal offset problem.

**Recommendation:** Implement "synthetic waypoints" for short edges with large horizontal offset (Option 4B below). This provides 90% of Dagre's edge routing quality at 20% of the implementation cost.

---

## Current State: What We Already Have

### Implemented Sugiyama Framework (src/dagre/)

| Phase | Algorithm | Status | Parity with Dagre |
|-------|-----------|--------|-------------------|
| 1. Acyclic | DFS back-edge detection | ✅ Complete | 100% |
| 2. Rank | Longest-path (Kahn's) | ✅ Complete | 90% (Dagre uses network simplex) |
| 2.5 Normalize | Dummy node insertion | ✅ Complete | 100% |
| 3. Order | Barycenter heuristic | ✅ Complete | 80% (Dagre adds median) |
| 4. Position | Simple layer centering | ✅ Complete | 40% (Dagre uses Brandes-Kopf) |

### What Works Well
- Long edges (spanning 2+ ranks) get waypoints from dummy nodes
- Crossing minimization reduces visual clutter
- All 4 directions (TD, BT, LR, RL) supported
- Edge labels positioned via label dummies

### The Gap: Why Horizontal Offset Fails

**For short edges (adjacent ranks):**
1. No dummy nodes created (edge spans only 1 rank)
2. No waypoints extracted from dagre
3. Router falls back to simple mid-y Z-path formula
4. Mid-y formula ignores node density, source position, etc.

**The root cause isn't crossing minimization - it's that short edges bypass the waypoint system entirely.**

---

## Option Analysis: Paths to Parity

### Option 4A: Full Brandes-Kopf Coordinate Assignment

**What it does:** Replace simple centering with the Brandes-Kopf algorithm that minimizes total edge length and bending.

**How Brandes-Kopf works:**
1. Compute 4 different alignments (ul, ur, dl, dr)
2. Each alignment tries to align nodes with their neighbors
3. Select alignment with smallest total width
4. Return balanced median of all 4

**What we'd need to implement:**

```rust
// New file: src/dagre/bk.rs

struct BlockAlignment {
    root: HashMap<NodeId, NodeId>,   // Block root for each node
    align: HashMap<NodeId, NodeId>,  // Next node in block chain
    sink: HashMap<NodeId, NodeId>,   // Class representative
    shift: HashMap<NodeId, f64>,     // Block shift amount
    x: HashMap<NodeId, f64>,         // Final x coordinate
}

fn position_x(graph: &LayoutGraph) -> HashMap<NodeId, f64> {
    let conflicts = find_type1_conflicts(graph);
    let conflicts = find_type2_conflicts(graph, conflicts);

    let mut alignments = HashMap::new();
    for vert in ["u", "d"] {
        for horiz in ["l", "r"] {
            let align = vertical_alignment(graph, &conflicts, vert, horiz);
            let xs = horizontal_compaction(graph, &align);
            alignments.insert(format!("{}{}", vert, horiz), xs);
        }
    }

    let smallest = find_smallest_width(&alignments);
    align_to_smallest(&mut alignments, smallest);
    balance(alignments)
}
```

**Complexity Estimate:**
- Type-1/Type-2 conflict detection: ~100 lines
- Vertical alignment (block creation): ~80 lines
- Horizontal compaction: ~120 lines
- Balance/alignment selection: ~60 lines
- **Total: ~360 lines of new code**

**Pros:**
- True Dagre parity for coordinate assignment
- Optimizes ALL edges, not just problematic ones
- No heuristics - mathematically optimal

**Cons:**
- High implementation complexity
- Requires thorough understanding of algorithm
- May introduce bugs in subtle edge cases
- Overkill if only specific cases are problematic

**Risk:** High - Algorithm is complex and subtle. Debugging coordinate assignment bugs is difficult.

---

### Option 4B: Synthetic Waypoints for Short Edges (Recommended)

**What it does:** Generate waypoints for short edges that have characteristics Dagre would handle better (large horizontal offset, source position, etc.).

**Key insight:** Dagre's Brandes-Kopf produces good results because it considers the global layout. We can approximate this for specific problematic edges by generating strategic waypoints.

**Implementation:**

```rust
// In src/render/router.rs or new src/render/synthetic_waypoints.rs

/// Generate synthetic waypoints for edges that would benefit from
/// Dagre-style routing but didn't get waypoints from normalization.
pub fn generate_synthetic_waypoints(
    edge: &Edge,
    from_bounds: &NodeBounds,
    to_bounds: &NodeBounds,
    layout: &Layout,
    direction: Direction,
) -> Option<Vec<(usize, usize)>> {
    // Skip if edge already has dagre waypoints
    let key = (edge.from.clone(), edge.to.clone());
    if layout.edge_waypoints.contains_key(&key) {
        return None;
    }

    // Analyze edge characteristics
    let analysis = analyze_edge(from_bounds, to_bounds, layout, direction);

    if !analysis.needs_synthetic_waypoints {
        return None;  // Use default routing
    }

    // Generate waypoints based on analysis
    match analysis.routing_strategy {
        RoutingStrategy::ViaSourceSide => {
            // Stay on source side, drop/rise to target level
            generate_source_side_waypoints(from_bounds, to_bounds, direction)
        }
        RoutingStrategy::ViaCorridor => {
            // Route through backward edge corridor
            generate_corridor_waypoints(from_bounds, to_bounds, layout, direction)
        }
        RoutingStrategy::AvoidObstacles => {
            // Route around intermediate nodes
            generate_obstacle_avoiding_waypoints(from_bounds, to_bounds, layout, direction)
        }
    }
}

struct EdgeAnalysis {
    horizontal_offset: usize,
    source_position: SourcePosition,  // Left, Center, Right
    intermediate_node_density: f64,
    needs_synthetic_waypoints: bool,
    routing_strategy: RoutingStrategy,
}

fn analyze_edge(...) -> EdgeAnalysis {
    let horizontal_offset = from_bounds.center_x().abs_diff(to_bounds.center_x());
    let diagram_center_x = layout.width / 2;

    let source_position = if from_bounds.center_x() < diagram_center_x * 2/3 {
        SourcePosition::Left
    } else if from_bounds.center_x() > diagram_center_x * 4/3 {
        SourcePosition::Right
    } else {
        SourcePosition::Center
    };

    // Count nodes in the "middle" area the edge would cross
    let intermediate_density = count_nodes_in_path(from_bounds, to_bounds, layout);

    let needs_synthetic = horizontal_offset > THRESHOLD
        && (source_position != SourcePosition::Center || intermediate_density > DENSITY_THRESHOLD);

    let strategy = if needs_synthetic {
        if source_position == SourcePosition::Right {
            RoutingStrategy::ViaSourceSide
        } else if layout.backward_corridors > 0 && intermediate_density > HIGH_DENSITY {
            RoutingStrategy::ViaCorridor
        } else {
            RoutingStrategy::AvoidObstacles
        }
    } else {
        RoutingStrategy::Default
    };

    EdgeAnalysis { horizontal_offset, source_position, intermediate_node_density, needs_synthetic, strategy }
}
```

**Complexity Estimate:**
- Edge analysis function: ~40 lines
- Source-side waypoint generation: ~30 lines
- Corridor waypoint generation: ~40 lines
- Obstacle-avoiding waypoints: ~60 lines (optional, can defer)
- Integration in router: ~15 lines
- **Total: ~120-185 lines**

**Pros:**
- 90% of benefit at 20% of cost
- Targeted fix for problematic cases
- Reuses existing waypoint infrastructure
- Low risk - doesn't modify dagre internals
- Can be extended incrementally

**Cons:**
- Heuristic-based, not optimal
- May need tuning for edge cases
- Multiple strategies to maintain

**Risk:** Low-Medium - Well-contained changes, easy to test and debug.

---

### Option 4C: Dagre Post-Processing (Mermaid-Style)

**What it does:** After dagre produces waypoints, post-process them to improve problematic edges.

**How Mermaid does it:**
1. Get waypoints from dagre
2. Detect corners and smooth them
3. Apply curve interpolation
4. Handle cluster boundaries

**For ASCII, we'd do:**
1. Get waypoints from dagre
2. Detect edges with poor routing (crossing many nodes)
3. Recompute waypoints for those edges
4. Replace original waypoints

**Implementation:**

```rust
// In src/render/layout.rs, after compute_layout_dagre

fn post_process_waypoints(
    layout: &mut Layout,
    diagram: &Diagram,
) {
    for edge in &diagram.edges {
        let key = (edge.from.clone(), edge.to.clone());

        // Get existing waypoints (may be empty for short edges)
        let existing = layout.edge_waypoints.get(&key).cloned().unwrap_or_default();

        // Analyze quality of current routing
        let quality = assess_routing_quality(&existing, &edge, layout);

        if quality < ACCEPTABLE_THRESHOLD {
            // Recompute waypoints for this edge
            if let Some(better) = compute_better_waypoints(edge, layout) {
                layout.edge_waypoints.insert(key, better);
            }
        }
    }
}

fn assess_routing_quality(
    waypoints: &[(usize, usize)],
    edge: &Edge,
    layout: &Layout,
) -> f64 {
    // Factors:
    // - Number of node bounds the path crosses
    // - Total path length
    // - Number of bends
    // - Whether path goes "the long way"

    let path_segments = build_path_from_waypoints(waypoints, edge, layout);
    let crossings = count_node_crossings(&path_segments, layout);
    let length = total_path_length(&path_segments);
    let bends = path_segments.len().saturating_sub(1);

    // Lower is worse
    1.0 / (crossings as f64 + 1.0) * (1.0 / length.sqrt()) * (1.0 / (bends as f64 + 1.0))
}
```

**Complexity Estimate:**
- Quality assessment: ~50 lines
- Better waypoint computation: ~80 lines
- Path analysis utilities: ~40 lines
- Integration: ~20 lines
- **Total: ~190 lines**

**Pros:**
- Works with existing dagre output
- Can improve any problematic edge
- Quality-based (objective metric)

**Cons:**
- Post-processing adds overhead
- Quality function needs tuning
- May conflict with dagre's optimizations

**Risk:** Medium - Quality assessment is subjective, may produce surprising results.

---

### Option 4D: Network Simplex + Synthetic Waypoints

**What it does:** Upgrade rank assignment to network simplex (closer to Dagre) AND add synthetic waypoints for short edges.

**Why consider this:**
- Network simplex produces better layer assignments
- Better layers → fewer long edges → fewer problematic cases
- Synthetic waypoints handle remaining issues

**Network Simplex Implementation:**
```rust
// Uses min-cost max-flow algorithm
// Reference: Gansner et al., "A Technique for Drawing Directed Graphs"

fn network_simplex_rank(graph: &mut LayoutGraph) {
    // 1. Initialize feasible tree
    let mut tree = feasible_tree(graph);

    // 2. While negative cut values exist
    while let Some(leave_edge) = find_negative_cut(graph, &tree) {
        let enter_edge = find_entering_edge(graph, &tree, leave_edge);
        exchange_edges(&mut tree, leave_edge, enter_edge);
        update_cut_values(graph, &tree);
    }

    // 3. Normalize (shift ranks to start at 0)
    normalize_ranks(graph);
}
```

**Complexity Estimate:**
- Feasible tree construction: ~80 lines
- Cut value calculation: ~60 lines
- Edge exchange: ~50 lines
- Integration: ~30 lines
- Synthetic waypoints (from 4B): ~150 lines
- **Total: ~370 lines**

**Pros:**
- Better rank assignment = better overall layout
- Addresses root cause + symptoms
- Closer to true Dagre behavior

**Cons:**
- Network simplex is complex algorithm
- May not be necessary if synthetic waypoints work well alone
- Higher implementation + maintenance cost

**Risk:** Medium-High - Network simplex has subtle correctness requirements.

---

## Comparison Matrix

| Option | Lines of Code | Dagre Parity | Risk | Maintenance | Edge Cases Fixed |
|--------|---------------|--------------|------|-------------|------------------|
| 4A: Brandes-Kopf | ~360 | 95% | High | High | All |
| 4B: Synthetic Waypoints | ~150 | 80% | Low | Low | Most |
| 4C: Post-Processing | ~190 | 70% | Medium | Medium | Many |
| 4D: NS + Synthetic | ~370 | 90% | Med-High | Medium | Most |

---

## Constraints and Trade-offs

### Constraint 1: ASCII Grid Limitations

Unlike SVG, we can't use:
- Smooth curves (Mermaid uses bezier/splines)
- Arbitrary angles (only horizontal/vertical)
- Sub-character positioning

**Trade-off:** Our "optimal" routing may differ from Dagre/Mermaid due to grid constraints.

### Constraint 2: Backward Compatibility

Existing tests and fixtures expect current rendering. Changes will require:
- Updating test expectations
- Visual review of all fixtures
- Possible user surprise at changed output

**Trade-off:** Better routing vs. stable output.

### Constraint 3: Performance

| Option | Time Complexity | Impact |
|--------|-----------------|--------|
| 4A | O(n² log n) for Brandes-Kopf | Noticeable for large diagrams |
| 4B | O(e) per edge analyzed | Negligible |
| 4C | O(e × n) for collision checking | Minor |
| 4D | O(n³) for network simplex | Noticeable for large diagrams |

**Trade-off:** Current simple algorithms are fast. Complex algorithms may slow large diagrams.

### Constraint 4: Dagre Integration Coupling

Options 4A and 4D modify dagre internals. This creates:
- Tighter coupling to Sugiyama algorithm
- More complex debugging
- Harder to isolate issues

**Trade-off:** True parity requires deeper integration.

### Constraint 5: Incremental Adoption

Options 4B and 4C can be implemented incrementally:
- Start with most common case (right-side source, TD layout)
- Add more strategies as needed
- Tune thresholds based on real usage

**Trade-off:** Incremental approach may accumulate technical debt.

---

## Recommendation: Phased Approach

### Phase 1: Option 4B (Synthetic Waypoints)
**Scope:** ~150 lines, 1-2 sessions

1. Implement edge analysis function
2. Add source-side waypoint generation for TD layout
3. Integrate into `route_edge()`
4. Test with `complex.mmd` and new fixtures
5. Tune thresholds

**Success criteria:** E→F "no" edge in complex.mmd routes cleanly

### Phase 2: Expand Coverage
**Scope:** ~50 additional lines

1. Add left-side source handling
2. Add LR/RL layout support
3. Add corridor-based routing for high-density cases

**Success criteria:** All 4 directions handle large offsets well

### Phase 3: Evaluate Need for Deeper Changes
**Decision point:** After Phase 2, assess:

- Are there still problematic edge cases?
- Is synthetic waypoint approach maintainable?
- Do users report issues?

If yes to multiple: Consider Option 4A (Brandes-Kopf) or 4D (Network Simplex)
If no: Phase 1-2 is sufficient

---

## Why Not Full Dagre Parity Now?

1. **80/20 Rule:** Synthetic waypoints solve ~80% of problems at ~20% of cost
2. **Risk Management:** Brandes-Kopf is complex; subtle bugs are hard to find
3. **Diminishing Returns:** ASCII constraints mean we'll never match SVG exactly
4. **Maintenance Burden:** Complex algorithms require ongoing expertise
5. **Validation:** Need real-world feedback to know if full parity is needed

---

## Files Changed Summary

### Phase 1 (Option 4B)

| File | Change |
|------|--------|
| `src/render/router.rs` | Add `generate_synthetic_waypoints()`, integrate into `route_edge()` |
| `tests/integration.rs` | Update expected output for `complex.mmd` |
| New: `tests/fixtures/horizontal_offset.mmd` | New test case |

### Phase 2 (Extended)

| File | Change |
|------|--------|
| `src/render/router.rs` | Add left-side, LR/RL strategies |
| `tests/fixtures/*.mmd` | Additional test cases |

### Future (if needed)

| File | Change |
|------|--------|
| New: `src/dagre/bk.rs` | Brandes-Kopf algorithm |
| `src/dagre/position.rs` | Replace simple centering with BK |
| `src/dagre/rank.rs` | Network simplex (optional) |

---

## Conclusion

**Do it right, but right-size the solution.**

Option 4B (Synthetic Waypoints) provides the best cost/benefit ratio:
- Solves the immediate problem
- Reuses existing infrastructure
- Low risk and maintainable
- Can be extended if needed

Full Dagre parity (Brandes-Kopf) is an option to revisit after Phase 1-2 validation, but the ASCII grid constraints and diminishing returns make it unnecessary for most use cases.

The goal isn't to match Dagre exactly - it's to produce clean, readable ASCII diagrams. Synthetic waypoints achieve that goal efficiently.

---

## Post-Implementation Update (2026-01-26)

**Option 4A (Brandes-Kopf) was implemented** in Plan 0011. The implementation is correct but revealed that BK alone doesn't achieve full Mermaid parity.

### Key Learning

This analysis correctly identified coordinate assignment as **a** gap, but missed that **ordering** is equally important. The Sugiyama pipeline has two relevant phases:

| Phase | Algorithm | What It Decides |
|-------|-----------|-----------------|
| 3. Order | Barycenter heuristic | Which side of layer each node appears |
| 4. Position | Brandes-Kopf | Exact coordinates within that order |

BK optimizes positions within the given order. If the order puts nodes on the wrong side, BK can't fix that.

### The Actual Gap

Dagre's ordering algorithm differs from ours in key ways:
1. **Bias parameter**: Dagre alternates left/right bias across iterations
2. **Multiple attempts**: Dagre tries 4 configurations, keeps best
3. **Edge weights**: Long edges carry weight through crossings

Our `order.rs` uses simple barycenter without these features.

**See `07-ordering-algorithm-gap.md` for detailed analysis.**

### Updated Recommendation

To achieve Mermaid-like layouts:
1. ✅ Brandes-Kopf for coordinate assignment (done)
2. ⬜ Ordering improvements (bias parameter, multiple attempts)
