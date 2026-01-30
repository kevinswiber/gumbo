# Research Synthesis: Subgraph Direction Inheritance

## Summary

Mermaid intentionally defaults subgraphs to TD regardless of the graph-level direction, as a design choice for space-efficient alternating layouts. mmdflux intentionally deviates from this by inheriting the graph-level direction for subgraphs. This matches user expectations (as evidenced by many Mermaid bug reports) and Mermaid's own opt-in `flowchart.inheritDir: true` config option (merged April 2025).

## Intentional Deviation

**mmdflux behavior:** Subgraphs inherit the graph-level direction (e.g., `graph LR` → subgraphs layout LR).

**Mermaid default behavior:** Subgraphs always default to TD regardless of graph-level direction.

**Rationale for deviation:** mmdflux's behavior matches what most users intuitively expect. The Mermaid community has filed at least 6 separate issues about this, and Mermaid ultimately added `flowchart.inheritDir` as an opt-in to provide the behavior mmdflux uses by default.

**Future consideration:** If strict Mermaid compatibility is needed, mmdflux could add a config option to use TD as the subgraph default, mirroring Mermaid's `flowchart.inheritDir` flag (but inverted — mmdflux would default to `true`).

## Key Findings

### Mermaid's Design is Intentional but Controversial

Maintainer @ashishjain0512 confirmed the TD default was a "conscious decision" for alternating direction layouts. However, the community response (6+ duplicate bug reports, 48+ comments on [#2509](https://github.com/mermaid-js/mermaid/issues/2509)) shows this is widely seen as unintuitive.

### Two Distinct Issues in Mermaid

1. **No direction inheritance (by design):** Subgraphs default to TD. Now configurable via `flowchart.inheritDir` ([PR #6470](https://github.com/mermaid-js/mermaid/pull/6470)).
2. **Direction ignored for non-isolated subgraphs (bug):** Even explicit `direction LR` is ignored when subgraph nodes connect externally ([#2509](https://github.com/mermaid-js/mermaid/issues/2509)). Open since Nov 2021.

## Where/What/How/Why Summary

| Aspect | Key Points |
|--------|------------|
| **Where** | Mermaid GitHub: [PR #6435](https://github.com/mermaid-js/mermaid/pull/6435), [PR #6470](https://github.com/mermaid-js/mermaid/pull/6470), [#2509](https://github.com/mermaid-js/mermaid/issues/2509), [#6428](https://github.com/mermaid-js/mermaid/issues/6428) |
| **What** | Subgraphs default to TD; `inheritDir` opt-in added April 2025 |
| **How** | Hardcoded TD default in subgraph rendering; `direction` keyword for explicit override |
| **Why** | Space efficiency via alternating layouts; most users find this counterintuitive |

## Recommendations

1. **Keep current behavior** — mmdflux's direction inheritance is the more intuitive default and matches `inheritDir: true`.
2. **Document as intentional deviation** — Note this in any compatibility documentation.
3. **Future: support `direction` keyword** — Allow per-subgraph direction overrides for full Mermaid compatibility.
4. **Future: config option** — Could offer a flag to match Mermaid's TD default if strict compatibility is needed.

## References

| Reference | URL |
|-----------|-----|
| Original `direction` keyword PR | [PR #2271](https://github.com/mermaid-js/mermaid/pull/2271) |
| Direction ignored for non-isolated subgraphs | [Issue #2509](https://github.com/mermaid-js/mermaid/issues/2509) |
| "Subgraphs default to TD" bug report | [Issue #6428](https://github.com/mermaid-js/mermaid/issues/6428) |
| Rejected fix (inheritance as default) | [PR #6435](https://github.com/mermaid-js/mermaid/pull/6435) |
| Merged `inheritDir` config option | [PR #6470](https://github.com/mermaid-js/mermaid/pull/6470) |
| `inheritDir` documentation (pending) | [PR #6665](https://github.com/mermaid-js/mermaid/pull/6665) |
| Direction inconsistency reports | [#4648](https://github.com/mermaid-js/mermaid/issues/4648), [#6438](https://github.com/mermaid-js/mermaid/issues/6438) |

## Source Files

| File | Question |
|------|----------|
| `q1-mermaid-direction-behavior.md` | Q1: Mermaid's direction default |
