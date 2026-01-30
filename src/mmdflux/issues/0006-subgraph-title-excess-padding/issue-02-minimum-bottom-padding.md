# Issue 02: Missing Minimum Bottom Padding in Subgraphs

**Severity:** Low
**Category:** Layout / Spacing
**Status:** Open
**Affected fixtures:** `subgraph_edges.mmd`, `backward_in_subgraph.mmd`, `simple_subgraph.mmd`

## Description

Subgraph bottom borders sometimes sit flush against the last content node (0 blank lines), while other cases have 1 line. There should be a consistent minimum of 1 blank line between the last content node and the bottom border, without adding more than 1 when not needed.

## Reproduction

```bash
cargo run -- tests/fixtures/subgraph_edges.mmd
```

The "Input" subgraph shows:

```
│┌────────┐    ┌──────┐ │
││ Config │    │ Data │ │
└└────────┘────└──────┘─┘
```

The bottom border `└...┘` is immediately below the node bottom borders `└────────┘`, with no blank line of padding.

## Expected behavior

```
│┌────────┐    ┌──────┐ │
││ Config │    │ Data │ │
│└────────┘    └──────┘ │
│                       │      <- 1 blank line minimum
└───────────────────────┘
```

## Root cause hypothesis

`convert_subgraph_bounds()` uses a fixed `border_padding = 2` on all sides, but the dagre layout positions nodes such that the effective bottom gap varies. The padding is applied symmetrically (top and bottom both get 2), but the actual rendered gap depends on how dagre positions the border_bottom dummy node relative to the last content node.

When nodes are tightly packed vertically, the 2-cell padding may not produce a visible blank line because the node box itself consumes some of that space.

## Possible fixes

- Ensure `border_padding` produces at least 1 visible blank line below the last node's bottom border
- Adjust the bottom padding calculation to account for node box height

## Cross-References

- **`src/render/layout.rs`:** `convert_subgraph_bounds()` around line 830
