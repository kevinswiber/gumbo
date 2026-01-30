# Finding: Negative Lookahead Needed for `end` Keyword

**Type:** discovery
**Task:** 1.2
**Date:** 2026-01-29

## Details

The PEG grammar's `subgraph_stmt` rule needs a negative lookahead to prevent `end` from being consumed as a `vertex_statement` inside the subgraph body. Without it, `end` matches `identifier` (which allows any alphabetic string), so the `((statement | comment) ~ NEWLINE?)*` loop consumes `end` as a node, and the `end_keyword` terminal never matches.

Solution: Added `subgraph_body_line` rule:
```pest
subgraph_body_line = { !(end_keyword ~ (NEWLINE | EOI)) ~ (statement | comment) }
```

The lookahead checks for `end` followed by a line boundary. This prevents false matches on identifiers like `endNode` or `ending`.

## Impact

The plan's grammar rules in task 1.2 did not account for this. Any future keyword-terminated blocks (e.g., nested subgraphs) will need similar negative lookahead patterns.

## Action Items

- None; resolved in implementation.
