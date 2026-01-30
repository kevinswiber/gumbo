# Issues: Compound Graph Node Stagger

## Date: 2026-01-29

Nodes inside a subgraph that form a straight vertical (or horizontal) chain render with staggered positions instead of being aligned. Identified during Phase D implementation of plan 0023.

**Source:** Plan 0023 Phase D implementation, direct observation

---

## Issue Index

| # | Issue | Severity | Category | File |
|---|-------|----------|----------|------|
| 1 | Border nodes cause horizontal stagger in BK compaction | Medium | Layout / BK algorithm | [issue-01](issue-01-border-node-stagger.md) |

---

## Categories

### A. BK Algorithm / Compound Graph Interaction (Issue 1)

Border segment nodes participate in the BK block graph as regular nodes, creating separation constraints that spread apart nodes which should be vertically aligned.

---

## Cross-References

- **Plan 0023:** `plans/0023-compound-graph-subgraphs/` — subgraph rendering implementation
- **Research 0015:** `research/0015-bk-block-graph-divergence/q2-border-type-guard.md` — identified borderType guard as compound-graph-only; noted future implementation need
- **Research 0016:** `research/0016-compound-graph-subgraphs/` — compound graph pipeline design
