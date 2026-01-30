# Research: Attachment Point Spreading Revisited

## Status: ARCHIVED

**Archived:** 2026-01-28

---

## Goal

Re-evaluate the attachment point spreading problem after stagger preservation (plan 0016) was implemented. Determine which overlap cases still exist, whether the prior research (0009) findings are still accurate, and whether plan 0015's approach is still the right fix — or if a different approach is warranted.

## Context

**Prior research:** Research 0009 identified that multiple edges sharing the same attachment point on a node causes visual overlap in ASCII output. It found that dagre's spreading is emergent (from dummy nodes, ordering, edgesep) and recommended a post-routing attachment spreading pass (plan 0015).

**What changed since then:** Plan 0016 (stagger preservation) was implemented. This preserves dagre's cross-axis stagger information through the coordinate transform, which the prior research identified as "self-inflicted" loss. The stagger-preservation-analysis.md predicted this would fix the most visible overlap cases for TD/BT backward edges.

**Current symptom:** `double_skip.mmd` (graph TD: A→B, B→C, C→D, A→C, A→D) shows overlapping arrows entering Step 2 and End — two arrows arrive at nearly the same position on the target node's top face.

**Prior research files copied to:** `prior-research/` subdirectory for reference.

## Questions

### Q1: What overlap cases still exist after stagger preservation?

**Where:** mmdflux codebase — render all existing test fixtures and the specific problem cases
**What:** Which fixtures show edge overlap? Categorize each overlap: same-face forward-forward, forward-backward, backward-backward. Capture the actual rendered output for each case.
**How:** Run `cargo run -q -- <fixture>` for: `double_skip.mmd`, `skip_edge_collision.mmd`, `stacked_fan_in.mmd`, `multiple_cycles.mmd`, `fan_in.mmd`, `fan_out.mmd`, `five_fan_in.mmd`, `narrow_fan_in.mmd`, `diamond_fan.mmd`, `complex.mmd`, `ci_pipeline.mmd`. Compare mmdflux output to mermaid's expected rendering (from the prior research or by examining the diagram structure). Focus on identifying overlapping arrows (`▼▼`, `▲▲`, `►►`, `◄◄`) and edges that share the same cell.
**Why:** Need to know the actual scope of remaining problems before deciding on a fix approach.

**Output file:** `q1-current-overlap-inventory.md`

---

### Q2: What did stagger preservation actually fix, and what did the prior research get right/wrong?

**Where:** Prior research files in `prior-research/`, especially `SYNTHESIS.md` and `stagger-preservation-analysis.md`. Also the current `compute_stagger_positions()` in `src/render/layout.rs`.
**What:** Compare the predictions in the stagger-preservation-analysis.md against actual current behavior. Which predicted fixes materialized? Which didn't? Are the 5 gaps identified in SYNTHESIS.md still relevant?
**How:** Read the prior research predictions, then cross-reference with Q1's inventory. Read the actual `compute_stagger_positions()` implementation to verify it matches what the research proposed.
**Why:** Validates whether plan 0015 needs adjustment or is still accurate as-designed.

**Output file:** `q2-prior-research-validation.md`

---

### Q3: What does dagre actually compute for the overlapping cases?

**Where:** The dagre source in `/Users/kevin/src/dagre`, the mermaid source in `/Users/kevin/src/mermaid`, and mmdflux's dagre module at `src/dagre/`
**What:** For `double_skip.mmd` specifically: What node positions does dagre compute? What waypoints does it produce for A→C and A→D? What are the dummy node x/y positions? What does `assignNodeIntersects()` compute for attachment points? How do these differ from what mmdflux computes?
**How:** Trace through the dagre layout algorithm for this specific graph. Look at `src/dagre/normalize.rs` (how long edges get dummy nodes), `src/dagre/order.rs` (how dummy nodes are ordered), `src/dagre/position.rs` / `src/dagre/bk.rs` (what x-coordinates dummy nodes get). If possible, add temporary debug output to dump dagre's raw positions. Also examine the original JS dagre's `position-assignment` and `normalize` to compare.
**Why:** Understanding what dagre computes tells us whether the information needed for spreading already exists in the layout output but is lost during coordinate transform, or whether it was never sufficient for ASCII rendering.

**Output file:** `q3-dagre-computation-trace.md`

---

### Q4: What's the right fix — plan 0015's approach or something different?

**Where:** `plans/0015-attachment-point-spreading/implementation-plan.md`, the prior research synthesis, and findings from Q1-Q3
**What:** Evaluate plan 0015's post-routing spreading approach against alternatives: (a) better coordinate transform that preserves more dagre information, (b) synthetic waypoint offsets, (c) port-based allocation (original plan 0008 idea), (d) the plan 0015 approach as-is. Consider whether stagger preservation already provides enough information that a simpler fix would work.
**How:** Synthesize Q1-Q3 findings. For each approach, assess: does it fix all remaining overlap cases? Does it break cases that currently work? How complex is it? Does it align with how dagre/mermaid solve this?
**Why:** Need to decide whether to proceed with plan 0015 as-is, modify it, or take a different approach entirely before investing implementation effort.

**Output file:** `q4-fix-approach-evaluation.md`

---

## Sources

| Source | Location | Used by |
|--------|----------|---------|
| Prior research (0009) | `prior-research/*.md` | Q1, Q2, Q4 |
| mmdflux render pipeline | `src/render/{router,layout,intersect,edge}.rs` | Q1, Q2, Q3 |
| mmdflux dagre module | `src/dagre/*.rs` | Q3 |
| JS dagre source | `/Users/kevin/src/dagre` | Q3 |
| JS mermaid source | `/Users/kevin/src/mermaid` | Q3 |
| Plan 0015 | `plans/0015-attachment-point-spreading/` | Q2, Q4 |
| Test fixtures | `tests/fixtures/*.mmd` | Q1 |

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-current-overlap-inventory.md` | Q1: Current overlap cases | Complete |
| `q2-prior-research-validation.md` | Q2: Prior research validation | Complete |
| `q3-dagre-computation-trace.md` | Q3: Dagre computation trace | Complete |
| `q4-fix-approach-evaluation.md` | Q4: Fix approach evaluation | Complete |
| `synthesis.md` | Combined findings | Complete |
