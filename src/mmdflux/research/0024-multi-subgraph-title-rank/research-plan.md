# Research: Multi-Subgraph Title Rank Collision

## Status: SYNTHESIZED

---

## Goal

Find a viable approach to prevent subgraph title-arrow collisions that works correctly with multiple subgraphs at different vertical positions. The current structural approach (title dummy nodes in the nesting chain) breaks when multiple subgraphs get title nodes at the same dagre rank.

## Context

Plan 0030 implemented Phases 1-3: storage fields, title dummy node insertion in `nesting::run()`, and ordering fixes for single-child ranks. Phase 4 (wiring `set_has_title()` in the render layer) revealed a fundamental flaw: all title dummy nodes rank at 1 (one hop from root) regardless of their subgraph's vertical position, causing border segment collision across subgraphs.

See: `plans/0030-subgraph-title-rank/findings/multi-subgraph-rank-collision.md`

The original issue: cross-subgraph edges entering a titled subgraph from above can route through the title row, overwriting the title text. Example: `D[External] --> A` where A is inside `subgraph sg1[Processing]`.

## Questions

### Q1: Render-only title space approach

**Where:** `src/render/layout.rs` (convert_subgraph_bounds, compute_layout_direct), `src/render/router.rs` (route_edge, route_backward_edge), `src/render/edge.rs`
**What:** Can we add title_extra padding purely in the render layer without dagre structural changes? Specifically: (a) If convert_subgraph_bounds adds 2 extra rows above titled subgraphs, does the edge router avoid the title row? (b) How does the router determine where edges cross subgraph borders? (c) Do dagre waypoints already clear the title row, or do they pass through it?
**How:** Trace the edge routing path for a cross-subgraph edge (e.g., External→A where A is in a titled subgraph). Map dagre waypoints to draw coordinates. Determine if adding padding to the subgraph bounds is sufficient or if waypoints need adjustment.
**Why:** A render-only approach avoids the multi-subgraph rank collision entirely. If it works, it's far simpler than fixing the structural approach.

**Output file:** `q1-render-only-approach.md`

---

### Q2: Post-rank title rank reassignment

**Where:** `src/dagre/nesting.rs` (assign_rank_minmax), `src/dagre/rank.rs` (run, normalize), `src/dagre/mod.rs` (layout pipeline)
**What:** After rank::run() completes, can we post-process title node ranks to push each title rank just above its subgraph's content? For example, if sg2's content is at rank 4, reassign title_sg2 to rank 3 (or min_content_rank - 1). Investigate: (a) Is there a pipeline stage where we know both the title nodes and their subgraph content ranks? (b) Can ranks be safely reassigned after Kahn's algorithm without breaking other invariants? (c) What happens to border_top ranks if the title rank shifts?
**How:** Read rank::run() and rank::normalize() to understand rank invariants. Check what downstream phases assume about rank ordering. Prototype a rank-reassignment step.
**Why:** This preserves the structural title-rank approach while fixing the multi-subgraph collision. If rank reassignment is safe, it's the most targeted fix.

**Output file:** `q2-post-rank-reassignment.md`

---

### Q3: Alternative nesting topology (bt → title → children)

**Where:** `src/dagre/nesting.rs` (run), `src/dagre/order.rs` (apply_compound_constraints), `src/dagre/border.rs` (add_segments)
**What:** Instead of `root → title → border_top → children → border_bottom`, use `root → border_top → title → children → border_bottom`. This places the title one rank below border_top, constrained by the subgraph's own nesting chain rather than root. Investigate: (a) Does this prevent the rank collision? (b) Does the title rank still provide the structural space needed? (c) How does this affect assign_rank_minmax and add_segments? (d) Does the ordering still work with title between border_top and children?
**How:** Trace the nesting chain through ranking, border creation, and ordering for both single- and multi-subgraph cases. Compare rank assignments.
**Why:** This was one of the alternative approaches identified in the finding. It keeps the structural approach but changes the topology to avoid the collision.

**Output file:** `q3-alternative-nesting-topology.md`

---

### Q4: How does dagre-js handle compound node titles?

**Where:** dagre-js source (https://github.com/dagrejs/dagre), graphlib source, mermaid.js source
**What:** Does the original dagre-js implementation have any concept of compound node titles or title space? How does mermaid.js render subgraph titles without title-edge collision? Does it use structural (layout-level) or render-level approaches?
**How:** Search dagre-js for "title", "label", "compound", "border" in the nesting/ordering code. Look at mermaid.js subgraph rendering for title collision handling.
**Why:** Understanding how the reference implementation handles this provides design guidance and may reveal approaches we haven't considered.

**Output file:** `q4-dagre-js-compound-titles.md`

---

## Sources

| Source | Location | Used by |
|--------|----------|---------|
| Nesting module | `src/dagre/nesting.rs` | Q2, Q3 |
| Rank module | `src/dagre/rank.rs` | Q2 |
| Border module | `src/dagre/border.rs` | Q3 |
| Order module | `src/dagre/order.rs` | Q3 |
| Render layout | `src/render/layout.rs` | Q1 |
| Edge router | `src/render/router.rs` | Q1 |
| Edge renderer | `src/render/edge.rs` | Q1 |
| Layout pipeline | `src/dagre/mod.rs` | Q2, Q3 |
| Multi-subgraph finding | `plans/0030-subgraph-title-rank/findings/multi-subgraph-rank-collision.md` | All |
| dagre-js | https://github.com/dagrejs/dagre | Q4 |
| mermaid.js | https://github.com/mermaid-js/mermaid | Q4 |

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-render-only-approach.md` | Q1: Render-only title space approach | Complete |
| `q2-post-rank-reassignment.md` | Q2: Post-rank title rank reassignment | Complete |
| `q3-alternative-nesting-topology.md` | Q3: Alternative nesting topology | Complete |
| `q4-dagre-js-compound-titles.md` | Q4: How does dagre-js handle compound titles? | Complete |
| `q5-post-rank-title-insertion.md` | Q5: Post-rank title node insertion | Complete |
| `synthesis.md` | Combined findings and recommendation | Complete (revised with Q5) |
