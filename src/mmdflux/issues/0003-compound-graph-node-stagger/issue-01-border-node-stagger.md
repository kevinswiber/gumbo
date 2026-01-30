# Issue 01: Border nodes cause horizontal stagger in BK compaction

**Severity:** Medium
**Category:** Layout / BK algorithm
**Status:** Open
**Affected fixtures:** `simple_subgraph`, `multi_subgraph`, `subgraph_edges`

## Description

Nodes inside a subgraph that form a straight vertical chain are rendered with increasing horizontal offset (stagger) instead of being vertically aligned. A chain like `A[Start] --> B[Middle]` inside a subgraph produces nodes at x=1, x=10 instead of roughly the same x.

The same chain without a subgraph renders correctly aligned.

## Reproduction

```bash
# Staggered (subgraph):
echo -e "graph TD\nsubgraph sg1[Process]\nA[Start] --> B[Middle]\nend\nB --> C[End]" | cargo run -q

# Aligned (no subgraph):
echo -e "graph TD\nA[Start]-->B[Middle]-->C[End]" | cargo run -q
```

Subgraph output shows Start/Middle/End staggered rightward:
```
Group
┌───────────│───┐
│           │   │
│           ▼   │
│         ┌───┐ │
│         │ A │ │
│         └───┘ │
│         │     │
│     ┌───┘     │
│     ▼         │
│ ┌───┐         │
│ │ B │         │
│ └───┘         │
└───────────────┘
```

## Expected behavior

Nodes in a straight chain should be vertically aligned regardless of subgraph membership, similar to the plain (no-subgraph) output.

## Root cause

The stagger originates in dagre's raw floating-point coordinates, not the render pipeline. Dagre produces x=12.2, x=58.5, x=86.8 for what should be an aligned chain.

The compound graph pipeline adds **border segment nodes** (left/right at each rank within the subgraph). These interact with the Brandes-Kopf horizontal coordinate assignment:

1. **Border segments created** (`border.rs`): For sg1 spanning ranks 0-1, four border nodes are added (`_bl_sg1_0`, `_br_sg1_0`, `_bl_sg1_1`, `_br_sg1_1`).

2. **Compound ordering constraints** (`order.rs:apply_compound_constraints`): After barycenter crossing minimization, layers are reordered so children are contiguous with border nodes bracketing them: `[border_left, A, border_right]`.

3. **Block graph separation** (`bk.rs:build_block_graph`): Adjacent nodes in different blocks get separation edges. Border nodes form their own blocks, so `border_left → A` and `A → border_right` each get separation constraints. These force horizontal spacing even for nodes that should align.

4. **Pass 2 pull-right** (`bk.rs:horizontal_compaction_with_direction`): The borderType guard (task 3.2) prevents border nodes from crossing boundaries, but does not prevent real nodes from being pulled apart by their separation constraints with border nodes.

The existing borderType guard from research 0015 / task 3.2 addresses a *different* problem (borders crossing subgraph boundaries). This issue is about borders *spreading apart* the real nodes within the subgraph.

## Potential fixes

1. **Suppress border-child separation edges in block graph**: In `build_block_graph`, skip creating separation edges when adjacent nodes are a border node and a child of the same compound. This prevents borders from creating horizontal pressure on real nodes.

2. **Align compound children during vertical alignment**: In the vertical alignment phase of BK, give extra weight to keeping nodes connected by edges within the same compound aligned to the same block root.

3. **Post-compaction alignment correction**: After BK compaction, detect nodes within a compound that are connected by edges and share the same median neighbor, then snap them to a common x-coordinate.

## Cross-References

- **Plan 0023:** `plans/0023-compound-graph-subgraphs/` — task 3.2 implemented the borderType guard
- **Research 0015 Q2:** `research/0015-bk-block-graph-divergence/q2-border-type-guard.md` — identified the guard's purpose and predicted it would be needed for compound graphs; the guard is necessary but not sufficient
- **Research 0016:** `research/0016-compound-graph-subgraphs/` — compound pipeline design
- **Code locations:**
  - `src/dagre/border.rs` — border segment creation
  - `src/dagre/order.rs:apply_compound_constraints` — post-sweep reordering
  - `src/dagre/bk.rs:build_block_graph` — separation edge creation
  - `src/dagre/bk.rs:horizontal_compaction_with_direction` — Pass 2 with borderType guard
