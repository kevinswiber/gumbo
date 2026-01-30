# Issue 01: Excess Top Padding in Titled Subgraphs

**Severity:** Medium
**Category:** Layout / Spacing
**Status:** Open
**Affected fixtures:** `subgraph_edges.mmd`, `backward_in_subgraph.mmd`, `simple_subgraph.mmd`

## Description

Titled subgraphs render with 3 blank lines between the title border and the first content node. This creates excessive whitespace that wastes vertical space and looks unbalanced compared to untitled subgraphs.

## Reproduction

```bash
cargo run -- tests/fixtures/simple_subgraph.mmd
```

Produces:

```
┌─ Process ─┐
│           │      <- blank line 1
│           │      <- blank line 2
│           │      <- blank line 3
│ ┌───────┐ │
│ │ Start │ │
```

The same pattern appears in `subgraph_edges.mmd` and `backward_in_subgraph.mmd`.

## Expected behavior

1 blank line between the title border and the first content node:

```
┌─ Process ─┐
│           │      <- 1 blank line for breathing room
│ ┌───────┐ │
│ │ Start │ │
```

## Root cause hypothesis

Two sources of top padding accumulate:

1. **`title_extra = 2`** in `convert_subgraph_bounds()` (`src/render/layout.rs`) — added by plan 0031 to extend the border upward for titled subgraphs
2. **`border_padding = 2`** — the existing fixed padding applied to all subgraph boundaries
3. **Dagre title rank** — `insert_title_nodes()` places a title dummy node at `border_top_rank - 1`, which the dagre layout allocates vertical space for via the rank separation

These three sources together produce ~3 rows of blank space above the first content node. The `title_extra` and the dagre title rank may be double-counting — the title rank already provides structural separation, so the render-layer `title_extra` may be redundant or needs to be reduced.

## Possible fixes

- Reduce `title_extra` from 2 to 0 or 1 (since the dagre title rank already provides separation)
- Reduce `border_padding` for the top side only when a title is present
- Adjust the dagre rank separation for title ranks specifically

## Cross-References

- **Plan 0031:** Phase 4, task 4.2 — introduced `title_extra` padding
- **`src/render/layout.rs`:** `convert_subgraph_bounds()` around line 831
- **`src/dagre/nesting.rs`:** `insert_title_nodes()` around line 105
