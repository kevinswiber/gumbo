# Continuation Prompt for Edge Routing Architecture Research

Copy this prompt to continue research in a fresh session:

---

## Prompt

I'm working on mmdflux, an ASCII renderer for Mermaid flowcharts. We've completed initial research on edge routing issues and determined that incremental patches lead to whack-a-mole. Instead, we need to implement three missing mechanisms from dagre.

**Research Directory:** `research/edge-routing-deep-dive/`

**Start by reading these files in order:**
1. `ARCHITECTURE-VISION.md` - Overview of the three missing mechanisms and how they interact
2. `RESEARCH-TRACKER.md` - Status of completed research and next steps
3. `DUMMY-NODES-ARCHITECTURE.md` - Detailed plan for dummy node implementation (partial)

**The three missing mechanisms are:**

1. **Dummy nodes for long edges** (`lib/normalize.js` in dagre)
   - Edges spanning multiple ranks get split with zero-size dummy nodes
   - Dummy nodes participate in crossing reduction
   - Their positions become edge waypoints

2. **Edge labels as layout entities** (`lib/normalize.js` in dagre)
   - Labels become dummy nodes with width/height = label dimensions
   - Placed at midpoint rank of the edge
   - Supports labelpos: "l" (left), "r" (right), "c" (center)

3. **Dynamic intersection calculation** (`lib/util.js` in dagre)
   - `intersectRect(rect, point)` computes where edge crosses node boundary
   - Different approach angles → different attachment points
   - Eliminates need for fixed center attachment points

**Your research tasks:**

1. **Deep dive into dagre's normalize.js**
   - Read: https://github.com/dagrejs/dagre/blob/master/lib/normalize.js
   - Document the exact algorithm for `run()` (normalization) and `undo()` (denormalization)
   - Understand how label dummies are created with `dummy: "edge-label"`
   - Write findings to `normalize-deep-dive.md`

2. **Deep dive into dagre's util.js intersectRect**
   - Read: https://github.com/dagrejs/dagre/blob/master/lib/util.js
   - Document the intersection algorithm
   - Analyze how it handles different node shapes
   - Write findings to `intersection-deep-dive.md`

3. **Analyze ASCII adaptation requirements**
   - What happens when continuous coordinates are rounded to integer grid?
   - How do we handle ties (multiple edges rounding to same cell)?
   - What minimum spacing prevents collisions?
   - Write findings to `ascii-adaptation.md`

4. **Update ARCHITECTURE-VISION.md**
   - Fill in answers to the "Open Research Questions" section
   - Refine the implementation plan based on findings

5. **Create implementation plan**
   - When research is complete, create `IMPLEMENTATION-PLAN.md`
   - Ordered list of code changes with dependencies
   - Test cases for each phase
   - This should be ready for `/plan` when approved

**Key dagre files to examine:**
- `lib/normalize.js` - Dummy node creation and removal
- `lib/util.js` - `intersectRect`, `addDummyNode`, `simplify`
- `lib/order/index.js` - How crossing reduction handles dummies
- `lib/position/bk.js` - Coordinate assignment with dummies

**mmdflux files for reference:**
- `src/dagre/` - Existing dagre module (has rank, order, position - missing normalize)
- `src/render/layout.rs` - Where layout integrates with dagre
- `src/render/router.rs` - Current routing (needs waypoint support)

**Do not implement yet** - this is research only. Write findings to markdown files. When research is complete and we have a clear implementation plan, we'll use `/plan` to create the implementation.

---

## Context Summary

**What we learned from initial research (4 parallel agents):**

- **Issue 1 (Missing Arrow):** Render order bug. Arrows drawn before all segments; later segments overwrite. Simple fix: draw arrows in separate pass after all segments.

- **Issue 2 (Label Collision):** Labels placed on congested segment instead of isolated corridor. Real fix: labels should be layout entities like in dagre.

- **Issue 3 (Overlapping Edges):** Fixed center attachment points cause collisions. Real fix: dynamic intersection calculation + dummy nodes for natural separation.

- **Issue 4 (Edge Through Node):** No awareness of intermediate nodes. Real fix: dummy nodes at intermediate ranks get ordered to avoid collisions.

**Why patches don't work:**

We've been playing whack-a-mole. Backward edges originally exited from the right side, which had problems. We changed to top exit, which created Issues 1-4. Each proposed patch creates new edge cases. The right solution is implementing the mechanisms dagre uses.

**mmdflux's dagre module already has:**
- Cycle removal (acyclic.rs)
- Rank assignment (rank.rs)
- Crossing reduction (order.rs)
- Coordinate assignment (position.rs)

**mmdflux's dagre module is missing:**
- Edge normalization (dummy nodes)
- Label dummy nodes
- Intersection calculation
- Edge waypoint generation from dummy positions
