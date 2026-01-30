# Research: BK Block Graph Compaction — Why dagre.js Differs and Whether It Matters

## Status: SYNTHESIZED

---

## Goal

Understand why dagre.js implements two-pass block graph compaction in its BK
horizontal coordinate assignment, identify concrete behavioral differences from
mmdflux's implementation, and determine whether mmdflux achieves equivalent
results through a different mechanism or is missing something.

## Context

Plan 0022 replaced mmdflux's recursive `place_block` with a two-pass block graph
algorithm matching dagre.js's `buildBlockGraph` + `horizontalCompaction`. The
result was functionally identical — all 27 fixtures produced the same output.
Pass 2 (reverse topological order, pull-right) was proven mathematically to be
a no-op for DAGs.

However, the exploration revealed several concrete differences between the two
implementations that could matter in specific scenarios:

1. dagre.js has a **borderType guard** in Pass 2 that skips border nodes
2. dagre.js **negates coordinates** for right-biased alignments (UR/DR)
3. dagre.js's `sep()` function handles **edge label positioning** (labelpos l/r)
4. dagre.js uses **DFS post-order** traversal vs mmdflux's Kahn's BFS

We need to understand each difference — is it meaningful, or is it dead code /
compound-graph-only logic that doesn't apply to simple flowcharts?

## Questions

### Q1: Does dagre.js's right-biased coordinate negation produce different results?

**Where:** dagre.js `bk.js` lines 355-387 (`positionX`), mmdflux `bk.rs` `position_x` and `align_to_smallest`
**What:** In dagre.js, right-biased alignments (UR/DR) reverse the layer ordering,
reverse node ordering within layers, then negate the resulting coordinates. mmdflux
handles right-biased alignments differently — possibly via direction flags in
`vertical_alignment` and `horizontal_compaction`. We need to determine if both
approaches produce equivalent final balanced coordinates.
**How:** Trace both implementations through a concrete example (double_skip graph)
for the UR alignment. Compare the intermediate coordinates before and after the
negation/mirroring step. Build a small test if needed.
**Why:** If the coordinate mirroring changes the median balance, the final
x-coordinates could differ between implementations, producing different stagger
patterns.

**Output file:** `q1-right-bias-negation.md`

---

### Q2: What does the borderType guard in Pass 2 actually do?

**Where:** dagre.js `bk.js` lines 238-261 (Pass 2 in `horizontalCompaction`),
dagre.js compound graph handling
**What:** Pass 2 in dagre.js has the condition
`if (min !== Number.POSITIVE_INFINITY && node.borderType !== borderType)`.
This skips pull-right for nodes with a specific `borderType`. We need to determine:
(a) What is `borderType`? When is it set on nodes?
(b) Is it only relevant for compound graphs (subgraphs)?
(c) Can it ever affect simple flowcharts without compound nodes?
(d) If compound-graph-only, is Pass 2 a complete no-op for simple graphs?
**How:** Search dagre.js source for all references to `borderType`, trace where it
gets set, and determine if any simple flowchart node can have a borderType.
**Why:** If borderType is compound-graph-only, then Pass 2 is confirmed as a no-op
for all graphs mmdflux handles, and we can stop worrying about it.

**Output file:** `q2-border-type-guard.md`

---

### Q3: Does the DFS vs BFS traversal order matter for block graph compaction?

**Where:** dagre.js `bk.js` lines 216-236 (`iterate` function), mmdflux `bk.rs`
`BlockGraph::topological_order` (Kahn's algorithm)
**What:** dagre.js uses a stack-based DFS post-order traversal for both passes.
mmdflux uses Kahn's algorithm (BFS-based topological sort). For DAGs, both produce
valid topological orderings, but different ones. We need to determine if the
specific ordering matters for the compaction result.
**How:** Analyze mathematically whether the compaction result depends on the specific
topological ordering chosen, or only on the DAG structure. If theoretically possible,
construct a counterexample where DFS vs BFS orderings produce different coordinates.
**Why:** If ordering doesn't matter, the implementations are provably equivalent
for Pass 1. If it does matter, we need to match dagre.js's traversal order.

**Output file:** `q3-dfs-vs-bfs-ordering.md`

---

### Q4: How does mmdflux handle right-biased alignments compared to dagre.js's layer/node reversal?

**Where:** mmdflux `bk.rs` `vertical_alignment`, `AlignmentDirection`, `get_neighbors`,
`get_medians`; dagre.js `bk.js` `positionX` lines 363-378
**What:** dagre.js reverses the layer list for downward alignments and reverses
node ordering within layers for right-biased alignments, then uses the same code
path. mmdflux uses `AlignmentDirection` flags to change behavior inline. We need
to verify that both approaches produce the same vertical alignment (root/align
arrays) for all 4 directions.
**How:** Trace both implementations through the double_skip graph for all 4
alignment directions. Compare the root[] and align[] arrays produced by each.
Focus on UR and DR where dagre.js reverses ordering.
**Why:** If the vertical alignments differ, the horizontal compaction inputs differ,
and the final coordinates will differ regardless of the compaction algorithm.

**Output file:** `q4-alignment-direction-handling.md`

---

### Q5: When did mmdflux's stagger start working, and what change enabled it?

**Where:** mmdflux git history, specifically plans 0016-0022, the dagre module
implementation history
**What:** The issue #2 sample output showed no stagger, but main now produces
correct stagger. We need to find which commit/plan introduced the working stagger.
Was it a BK algorithm fix, a normalize step fix, an ordering fix, or something else?
**How:** Use git log/bisect on double_skip.mmd output to find when stagger first
appeared. Check plan notes and findings for mentions of stagger fixes.
**Why:** Understanding what actually fixed the stagger helps us assess whether it's
a robust fix or an accidental side effect that could regress.

**Output file:** `q5-stagger-history.md`

---

## Sources

| Source | Location | Used by |
|--------|----------|---------|
| dagre.js BK implementation | `/Users/kevin/src/dagre/lib/position/bk.js` | Q1, Q2, Q3, Q4 |
| mmdflux BK implementation | `src/dagre/bk.rs` | Q1, Q3, Q4 |
| dagre.js compound graph code | `/Users/kevin/src/dagre/lib/` | Q2 |
| Plan 0022 findings | `plans/0022-bk-block-graph-compaction/findings/` | Q1, Q3 |
| Prior BK research | `research/0014-remaining-visual-issues/q2-bk-block-graph.md` | Q1, Q3 |
| Prior stagger research | `research/0013-visual-comparison-fixes/q2-bk-stagger-mechanism.md` | Q4, Q5 |
| BK-to-final-coords research | `research/0012-edge-sep-pipeline-comparison/q1-dagre-bk-to-final-coords.md` | Q1, Q4 |
| Issue #2 | `issues/0002-visual-comparison-issues/issues/issue-02-skip-edge-stagger-missing.md` | Q5 |
| mmdflux git history | `git log` | Q5 |

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-right-bias-negation.md` | Q1: Right-biased coordinate negation | Complete |
| `q2-border-type-guard.md` | Q2: borderType guard in Pass 2 | Complete |
| `q3-dfs-vs-bfs-ordering.md` | Q3: DFS vs BFS traversal order | Complete |
| `q4-alignment-direction-handling.md` | Q4: Right-biased alignment handling | Complete |
| `q5-stagger-history.md` | Q5: When stagger started working | Complete |
| `synthesis.md` | Combined findings | Complete |
