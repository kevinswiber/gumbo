# Q2: How does the title rank affect border segments and ordering?

## Summary

Border segments (`border::add_segments()`) will automatically create left/right border nodes at the title rank since it falls within [min_rank, max_rank]. However, `apply_compound_constraints()` in ordering skips border positioning when a rank has fewer than 2 children — and the title rank typically has only the title dummy as a child. This creates a structural mismatch: border nodes exist at the title rank but lack ordering constraints, potentially causing horizontal misalignment.

## Where

- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/border.rs` (lines 12-65): `add_segments()` creates left/right border nodes for every rank in [min_r, max_r]
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/order.rs` (lines 307-435): `apply_compound_constraints()` groups children contiguously, places left/right borders at extremes
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/graph.rs` (lines 126-131, 193-196): `BorderType` enum and border node storage

## What

### Border segment creation

`add_segments()` iterates `for rank in min_r..=max_r`:
- Creates `_bl_{compound}_{rank}` (left) and `_br_{compound}_{rank}` (right) via `add_nesting_node()`
- Assigns rank, parent, and BorderType
- Links consecutive borders vertically with weight 1.0 edges
- No special handling for ranks with only dummy nodes

With the title rank included in the span, border_left and border_right nodes are created at the title rank automatically.

### Ordering constraints

`apply_compound_constraints()` for each compound at each rank:
1. Finds child positions: nodes whose parent is this compound
2. **If < 2 children: skips** (lines 336, 376) — no contiguity or border placement
3. If 2+ children: makes them contiguous, places left border at leftmost, right border at rightmost

### The structural mismatch

At the title rank:
- **1 child** exists (the title dummy node)
- `child_positions.len() < 2` → constraint logic skips entirely
- Border nodes at this rank are created but not positioned relative to the title dummy
- They may drift to arbitrary horizontal positions based on DFS init_order or barycenter heuristics

### Vertical edge linking mitigates but doesn't solve

Consecutive borders are linked vertically (border.rs lines 57-60):
- Left border at title_rank → left border at content_rank
- This pulls title-rank borders toward adjacent rank borders
- But without explicit ordering at the title rank, alignment is not guaranteed

## How

### Impact analysis

1. **Border nodes exist at title rank** — created automatically, no code changes needed
2. **Ordering is unconstrained** — the `< 2 children` check bypasses border placement
3. **Vertical links provide soft constraint** — border alignment across ranks is approximate
4. **Subgraph bounds may be wrong** — if title-rank borders drift, `remove_nodes()` computes incorrect x-bounds at that rank

### Potential fixes

**Option A: Treat title dummy as requiring border placement**
- Modify `apply_compound_constraints()` to handle the `== 1 child` case
- Place left border before the single child, right border after

**Option B: Skip border creation at title rank**
- In `add_segments()`, detect the title rank and skip border node creation
- Let vertical linking of adjacent ranks define the bounds

**Option C: Give the title node special ordering treatment**
- Create a `BorderType::Title` variant
- Handle it in ordering with explicit left-title-right constraint

## Why

- The `< 2 children` skip is a valid optimization for normal ranks (single-child subgraphs at a rank don't need contiguity enforcement)
- The title rank breaks this assumption because it's structurally required to have only 1 child
- Vertical border linking provides partial alignment but is insufficient for guaranteed correctness
- The bounding box extraction in `remove_nodes()` depends on correctly positioned borders at all ranks

## Key Takeaways

- Border nodes ARE created at the title rank automatically — no changes to `add_segments()` needed
- Ordering constraints are NOT applied at the title rank due to the `< 2 children` skip
- Vertical edge linking provides soft horizontal alignment but doesn't guarantee correctness
- The fix likely needs either: (a) handling `== 1 child` in ordering, or (b) skipping title-rank borders entirely
- Subgraph width correctness depends on resolving this mismatch

## Open Questions

- Does the vertical edge linking provide sufficient constraint in practice (empirical testing needed)?
- Should the `< 2 children` check be changed to `< 1 child` for ranks known to be title ranks?
- If border nodes at the title rank are skipped, how does `remove_nodes()` compute the bounding box at that rank?
- Does the title node need to be treated as a border-like node (part of infrastructure) rather than a child?
