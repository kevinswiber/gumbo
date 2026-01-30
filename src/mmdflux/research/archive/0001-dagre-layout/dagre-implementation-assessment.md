# Dagre Algorithm Implementation Assessment

This document synthesizes research on the Dagre algorithm and assesses the feasibility of implementing it in Rust for mmdflux.

## Executive Summary

**Question:** Should we implement the full Dagre/Sugiyama algorithm, or use the simpler declaration-order fix from plan 0004?

**Recommendation:** **Implement a simplified Sugiyama algorithm** - a middle ground between the minimal fix and full Dagre. This provides correct layouts while keeping complexity manageable.

---

## The Dagre/Sugiyama Algorithm

The Sugiyama framework has four phases:

| Phase                    | Purpose                 | Dagre Algorithm            | Complexity |
| ------------------------ | ----------------------- | -------------------------- | ---------- |
| 1. Cycle Removal         | Make graph acyclic      | DFS-based feedback arc set | O(V+E)     |
| 2. Layer Assignment      | Assign y-coordinates    | Network Simplex            | O(V×E)     |
| 3. Crossing Reduction    | Minimize edge crossings | Barycenter heuristic       | O(K×(V+E)) |
| 4. Coordinate Assignment | Assign x-coordinates    | Brandes-Köpf               | O(V+E)     |

---

## Implementation Complexity Assessment

### Phase 1: Cycle Removal - **Easy** (Already have this)

mmdflux already detects back-edges in `assign_backward_edge_lanes()`. We just need to:
- Move detection earlier (before topological sort)
- Temporarily exclude back-edges from in-degree computation

**Lines of code:** ~30-50
**Risk:** Low

### Phase 2: Layer Assignment - **Medium**

**Option A: Longest Path (Simple)**
- What we have now, essentially
- O(V+E), easy to implement
- Pushes nodes to bottom, can create wide layers

**Option B: Network Simplex (Dagre default)**
- Minimizes total edge length
- More balanced layouts
- ~400 lines in Dagre, complex tree data structures
- O(V×E) worst case

**Recommendation:** Start with longest path (we have it), consider network simplex later if layouts are unbalanced.

**Lines of code:** 0 additional for longest path, ~200-300 for network simplex
**Risk:** Low for longest path, Medium for network simplex

### Phase 3: Crossing Reduction - **Medium-Hard**

This is where Dagre differs most from our current approach.

**Current mmdflux:** Sorts nodes alphabetically within layers
**Dagre:** Multiple iterations of barycenter/median heuristic

Implementation requires:
1. Build layer graphs for adjacent layers
2. Compute barycenter for each node
3. Sort by barycenter
4. Repeat sweeping up and down
5. Count crossings to pick best ordering

**Lines of code:** ~150-250
**Risk:** Medium (algorithm is well-documented)

### Phase 4: Coordinate Assignment - **Medium**

**Current mmdflux:** Centers nodes within layers, uses grid coordinates
**Dagre:** Brandes-Köpf algorithm for compact x-coordinates

For ASCII output, our grid-based approach may actually be better than Brandes-Köpf. We need discrete positions, not continuous coordinates.

**Recommendation:** Keep current grid-based positioning, but improve node centering based on edge connections.

**Lines of code:** ~50-100 modifications
**Risk:** Low

---

## Existing Rust Libraries

| Library           | Could Use? | Notes                                                        |
| ----------------- | ---------- | ------------------------------------------------------------ |
| **rust-sugiyama** | Yes        | Complete Sugiyama, could use for layout then render to ASCII |
| **ascii-dag**     | Study      | Direct competitor, similar goals                             |
| **petgraph**      | Yes        | Could replace our graph data structures                      |

### Using rust-sugiyama

**Pros:**
- Battle-tested Sugiyama implementation
- Network simplex ranking
- Barycenter/median crossing reduction
- Brandes-Köpf positioning

**Cons:**
- Returns continuous coordinates, we need grid positions
- Doesn't understand our node shapes
- Would need significant adaptation layer
- Adds dependency

### Building Our Own

**Pros:**
- Tailored for ASCII output
- Grid-native coordinates
- Can optimize for our specific needs
- No dependencies

**Cons:**
- More development effort
- Risk of bugs in complex algorithms

---

## Comparison: Three Approaches

### Approach 1: Minimal Fix (Plan 0004)

**What:** Use IndexMap for declaration order, use declaration order as tiebreaker

**Effort:** ~2-4 hours
**Lines changed:** ~50

**Pros:**
- Minimal change
- Low risk
- Fixes the immediate problem

**Cons:**
- Doesn't minimize edge crossings
- Layouts may still look suboptimal for complex graphs
- Declaration order isn't always the best layout order

### Approach 2: Simplified Sugiyama (Recommended)

**What:** Implement phases 1 and 3 properly, keep simple layer assignment and grid positioning

1. Proper back-edge detection (move earlier)
2. Longest-path layer assignment (keep current)
3. Barycenter crossing reduction (new)
4. Grid-based positioning (keep current, minor improvements)

**Effort:** ~1-2 days
**Lines changed:** ~200-300

**Pros:**
- Correct handling of cycles
- Minimizes edge crossings
- Works well for ASCII output
- No external dependencies
- Moderate complexity

**Cons:**
- More effort than minimal fix
- Won't be as optimal as full Dagre for complex graphs

### Approach 3: Full Dagre Implementation

**What:** Implement all four phases with Dagre's algorithms

1. DFS-based cycle removal
2. Network Simplex ranking
3. Barycenter + transpose crossing reduction
4. Brandes-Köpf positioning (adapted for grid)

**Effort:** ~1-2 weeks
**Lines changed:** ~800-1200

**Pros:**
- Optimal layouts
- Matches Mermaid.js output closely
- Industry-standard algorithm

**Cons:**
- Significant effort
- Complex algorithms to implement correctly
- May be overkill for ASCII output
- Brandes-Köpf designed for continuous coordinates

### Approach 4: Use rust-sugiyama

**What:** Replace layout computation with rust-sugiyama, adapt output to grid

**Effort:** ~2-3 days
**Lines changed:** ~150-250 + dependency

**Pros:**
- Proven implementation
- Less code to maintain
- Full Sugiyama algorithm

**Cons:**
- New dependency
- Coordinate adaptation layer needed
- Less control over algorithm details

---

## Recommendation

**Approach 2: Simplified Sugiyama** is the best balance of effort vs. quality.

### Implementation Plan

#### Phase 1: Back-Edge Detection (builds on Plan 0004)
1. Use IndexMap for declaration order preservation
2. Identify back-edges before topological sort
3. Exclude back-edges from in-degree computation
4. Use declaration order as secondary tiebreaker

#### Phase 2: Barycenter Crossing Reduction
1. After layer assignment, iterate to minimize crossings
2. For each layer (sweeping down then up):
   - Compute barycenter for each node from neighbors in previous layer
   - Sort nodes by barycenter
3. Repeat 4-8 times or until no improvement
4. Track best ordering by crossing count

#### Phase 3: Minor Positioning Improvements
1. When multiple nodes in a layer, consider edge positions
2. Try to align nodes with their primary connections

### Expected Results

For the http_request example:
- Client at top (correct source identification)
- Minimal edge crossings in the Process/Reject layer
- Clean routing for the back-edge

---

## Files to Study

Before implementation, study these for algorithm details:

1. **rust-sugiyama** - `src/crossing_reduction.rs`
2. **Dagre** - `lib/order/barycenter.js`, `lib/order/cross-count.js`
3. **ascii-dag** - Their crossing reduction approach

---

## Decision Matrix

| Criterion         | Plan 0004 | Simplified Sugiyama | Full Dagre       | rust-sugiyama    |
| ----------------- | --------- | ------------------- | ---------------- | ---------------- |
| Effort            | Low       | Medium              | High             | Medium           |
| Layout Quality    | Fair      | Good                | Excellent        | Excellent        |
| Maintenance       | Easy      | Moderate            | Hard             | Easy (external)  |
| Dependencies      | None      | None                | None             | +1 crate         |
| ASCII Suitability | Good      | Good                | Needs adaptation | Needs adaptation |
| Risk              | Low       | Low-Medium          | Medium-High      | Low              |

**Recommended:** Simplified Sugiyama (Approach 2)

---

## Next Steps

1. **Decide on approach** - Get user input on preferred direction
2. **If Simplified Sugiyama:**
   - Start with Plan 0004 (IndexMap + back-edge detection)
   - Add barycenter crossing reduction
   - Test with complex diagrams
3. **If using rust-sugiyama:**
   - Prototype integration
   - Build coordinate adaptation layer
   - Compare output quality
