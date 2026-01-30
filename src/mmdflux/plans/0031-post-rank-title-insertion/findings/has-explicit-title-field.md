# Finding: Added has_explicit_title to AST and Graph

**Type:** diversion
**Task:** 4.2
**Date:** 2026-01-29

## Details

The plan assumed `sg.title.is_empty()` could distinguish titled from untitled subgraphs. However, the parser defaults `title` to the subgraph ID when no bracket title is provided (`subgraph sg1` gets `title = "sg1"`). This means `title.is_empty()` is never true.

Added `has_explicit_title: bool` to both `SubgraphSpec` (AST) and `Subgraph` (graph) to properly distinguish `subgraph sg1[Title]` (explicit) from `subgraph sg1` (implicit).

## Impact

- Parser, AST, builder, and diagram structs all gained a new field
- The `set_has_title()` call and `title_extra` padding are gated on `has_explicit_title`
- Existing test constructors were updated with appropriate values

## Action Items

- None - the change is backward-compatible and correctly integrated
