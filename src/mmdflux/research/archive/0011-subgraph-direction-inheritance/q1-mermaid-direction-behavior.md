# Q1: Is Mermaid's Subgraph Direction Default Intentional?

## Summary

Yes. Mermaid intentionally defaults subgraphs to TD regardless of the graph-level direction. A maintainer explicitly confirmed this was a "conscious decision" to alternate directions at each nesting level for space efficiency. As of April 2025, an opt-in `flowchart.inheritDir` config option was merged to allow direction inheritance.

## Where

- [PR #2271](https://github.com/mermaid-js/mermaid/pull/2271) — Original `direction` keyword implementation by @knsv (Oct 2021)
- [Issue #1682](https://github.com/mermaid-js/mermaid/issues/1682) — Original feature request for subgraph direction support (Sept 2020)
- [Issue #2509](https://github.com/mermaid-js/mermaid/issues/2509) — "Subgraph direction not applying" when subgraphs interact (Nov 2021, still open, 48+ comments)
- [Issue #6428](https://github.com/mermaid-js/mermaid/issues/6428) — "Subgraphs Always Default to TD, Ignoring Global Direction" (March 2025)
- [Issue #4648](https://github.com/mermaid-js/mermaid/issues/4648) — "Direction in subgraphs inconsistent"
- [Issue #6438](https://github.com/mermaid-js/mermaid/issues/6438) — "Direction inside subgraphs is ignored"
- [PR #6435](https://github.com/mermaid-js/mermaid/pull/6435) — Rejected PR to make inheritance the default (March 2025)
- [PR #6470](https://github.com/mermaid-js/mermaid/pull/6470) — Merged PR adding opt-in `flowchart.inheritDir` config (April 2025)
- [PR #6665](https://github.com/mermaid-js/mermaid/pull/6665) — Documentation PR for `inheritDir` (June 2025, still open)

## What

### The Default Behavior

Subgraphs without an explicit `direction` keyword always default to TD, regardless of the graph-level direction (`graph LR`, `graph RL`, etc.). This is not inheritance — it's a hardcoded default.

### Maintainer Confirmation

Maintainer @ashishjain0512 stated in [PR #6435](https://github.com/mermaid-js/mermaid/pull/6435):

> "However, it was a conscious decision to have it implemented in the current state, where each nested layer of sub-graph alternates the directions to utilize space and let the diagram grow both vertically and horizontally."

The PR to make inheritance the default was rejected because it would break existing diagrams.

### The `inheritDir` Config Option

[PR #6470](https://github.com/mermaid-js/mermaid/pull/6470) (merged April 2025) added `flowchart.inheritDir`:
- Default: `false` (preserves existing TD default)
- When `true`: subgraphs without explicit `direction` inherit the graph-level direction

### A Separate Bug: Cross-Subgraph Edges

[Issue #2509](https://github.com/mermaid-js/mermaid/issues/2509) documents a separate problem: even when you explicitly set `direction LR` inside a subgraph, if nodes in that subgraph connect to nodes outside it, the direction may be ignored. @knsv confirmed: "the direction only works when the subgraph is 'isolated'." This bug remains open since November 2021, labeled "Approved" and "Contributor needed."

## How

The timeline of Mermaid's subgraph direction handling:

1. **Sept 2020:** Feature request for subgraph direction support ([#1682](https://github.com/mermaid-js/mermaid/issues/1682))
2. **Oct 2021:** @knsv merged `direction` keyword for subgraphs ([PR #2271](https://github.com/mermaid-js/mermaid/pull/2271)). Subgraphs without explicit `direction` default to TD.
3. **Nov 2021:** Users report `direction` doesn't work when subgraphs interact ([#2509](https://github.com/mermaid-js/mermaid/issues/2509)). Still open.
4. **2022–2024:** Multiple duplicate issues filed ([#2286](https://github.com/mermaid-js/mermaid/issues/2286), [#3096](https://github.com/mermaid-js/mermaid/issues/3096), [#4648](https://github.com/mermaid-js/mermaid/issues/4648), [#4738](https://github.com/mermaid-js/mermaid/issues/4738))
5. **March 2025:** Explicit bug report about TD default ([#6428](https://github.com/mermaid-js/mermaid/issues/6428)). Fix PR rejected; maintainer confirms intentional design ([PR #6435](https://github.com/mermaid-js/mermaid/pull/6435)).
6. **April 2025:** Opt-in `flowchart.inheritDir` config merged ([PR #6470](https://github.com/mermaid-js/mermaid/pull/6470))
7. **June 2025:** Documentation PR for `inheritDir` still under review ([PR #6665](https://github.com/mermaid-js/mermaid/pull/6665))

## Why

The design rationale for TD default is **space efficiency**: alternating directions at each nesting level lets diagrams grow both vertically and horizontally rather than stretching in a single direction.

However, this is counterintuitive to most users. The volume of bug reports (at least 6 separate issues) shows that users expect subgraphs to inherit the graph-level direction. This led to the `inheritDir` opt-in being merged.

## Key Takeaways

- Mermaid's TD default for subgraphs is intentional, designed for space-efficient alternating layouts
- The community largely finds this counterintuitive (many duplicate bug reports)
- Mermaid now offers `flowchart.inheritDir: true` as an opt-in to match the intuitive behavior
- There is also a separate longstanding bug where explicit `direction` is ignored for non-isolated subgraphs

## Open Questions

- Should mmdflux eventually support the `direction` keyword per-subgraph?
- Should mmdflux offer a config option to match Mermaid's TD-default behavior for strict compatibility?
