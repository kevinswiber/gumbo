# Dagre Layout Research Tracker

## Status: RESEARCH COMPLETE - READY FOR PLANNING

## Goal

Research and design a standalone Dagre/Sugiyama layout implementation for mmdflux that:
- Can be extracted as a separate crate later
- Has no cross-dependencies with mmdflux internals
- Is WASM-compatible for JavaScript/TypeScript use
- Provides correct hierarchical graph layouts

---

## Research Completed

| Topic                         | File                                 | Status | Key Findings                              |
| ----------------------------- | ------------------------------------ | ------ | ----------------------------------------- |
| Dagre JS source analysis      | `dagre-source-analysis.md`           | Done   | 4 phases, ~1500 LOC total                 |
| Sugiyama algorithm theory     | `dagre-algorithm-theory.md`          | Done   | Academic refs, complexity analysis        |
| Mermaid-Dagre integration     | `mermaid-dagre-integration.md`       | Done   | Config options, dummy nodes, data flow    |
| Rust graph libraries survey   | `rust-graph-layout-libraries.md`     | Done   | rust-sugiyama best, ascii-dag competitor  |
| Initial assessment            | `dagre-implementation-assessment.md` | Done   | Recommended simplified Sugiyama           |
| rust-sugiyama deep dive       | `rust-sugiyama-analysis.md`          | Done   | ~2500 LOC, full network simplex           |
| petgraph analysis             | `petgraph-analysis.md`               | Done   | StableGraph best for layout algorithms    |
| WASM compatibility            | `wasm-compatibility.md`              | Done   | All deps WASM-safe                        |
| Module design                 | `module-design.md`                   | Done   | Standalone dagre/ module structure        |
| Full vs Simplified comparison | `implementation-comparison.md`       | Done   | Simplified recommended for ASCII          |
| **mmdflux vs Dagre differences** | `mmdflux-vs-dagre-differences.md` | Done | Debugging guide for layout differences |

---

## Key Findings Summary

### Algorithm Complexity

| Phase                    | Simplified      | Full Dagre        |
| ------------------------ | --------------- | ----------------- |
| 1. Cycle Removal         | 50-80 LOC       | 100-150 LOC       |
| 2. Layer Assignment      | 30-50 LOC       | 300-400 LOC       |
| 3. Crossing Reduction    | 100-150 LOC     | 300-400 LOC       |
| 4. Coordinate Assignment | 50-100 LOC      | 400-500 LOC       |
| **Total**                | **250-400 LOC** | **1100-1500 LOC** |

### WASM Compatibility

| Library       | WASM-Safe? | Notes                      |
| ------------- | ---------- | -------------------------- |
| petgraph      | Yes        | no_std + alloc supported   |
| indexmap      | Yes        | First-class no_std support |
| rust-sugiyama | Needs mods | std::time, std::env used   |

### Dependency Strategy

**Recommended:** Use petgraph for graph data structures
- `StableDiGraph` handles index stability during modifications
- Provides useful traversal algorithms (DFS, topological sort)
- WASM-compatible
- Well-tested foundation

**Note:** We use custom DFS-based cycle removal (matching Dagre's default), not petgraph's `greedy_feedback_arc_set`.

---

## Recommendations

### Approach: Simplified Sugiyama with Barycenter Enhancement

1. **Phase 1 (Cycle Removal):** DFS-based FAS (matches Dagre's default behavior)
2. **Phase 2 (Layer Assignment):** Longest-path algorithm (simple, fast)
3. **Phase 3 (Crossing Reduction):** Barycenter heuristic with 4-8 iterations
4. **Phase 4 (Coordinate Assignment):** Grid-based centering (perfect for ASCII)

**Rationale:**
- ASCII output uses discrete grid positions anyway
- Smaller WASM binary for web deployment
- Typical Mermaid flowcharts are small (5-50 nodes)
- Can upgrade to network simplex/Brandes-Köpf later if needed

### Module Structure

```
src/dagre/
├── mod.rs        # Public API
├── types.rs      # Direction, Point, Rect, LayoutConfig
├── graph.rs      # DiGraph wrapper (optionally uses petgraph)
├── acyclic.rs    # Phase 1: Cycle removal
├── rank.rs       # Phase 2: Layer assignment
├── order.rs      # Phase 3: Crossing reduction
└── position.rs   # Phase 4: Coordinate assignment
```

### Migration Path

1. Create `src/dagre/` module in mmdflux
2. Port existing layout logic from `render/layout.rs`
3. Add barycenter crossing reduction
4. Create adapter in `render/layout.rs` to use new module
5. Extract as separate crate when stable

---

## Files in This Directory

| File                                 | Purpose                               |
| ------------------------------------ | ------------------------------------- |
| `TRACKER.md`                         | This tracker                          |
| `dagre-source-analysis.md`           | Dagre JS source code analysis         |
| `dagre-algorithm-theory.md`          | Sugiyama theoretical foundations      |
| `dagre-implementation-assessment.md` | Implementation options comparison     |
| `mermaid-dagre-integration.md`       | How Mermaid uses Dagre                |
| `rust-graph-layout-libraries.md`     | Survey of Rust layout libraries       |
| `rust-sugiyama-analysis.md`          | Deep dive into rust-sugiyama          |
| `petgraph-analysis.md`               | petgraph data structures & algorithms |
| `wasm-compatibility.md`              | WASM compatibility analysis           |
| `module-design.md`                   | Standalone module design              |
| `implementation-comparison.md`       | Simplified vs Full Dagre comparison   |
| `mmdflux-vs-dagre-differences.md`    | Differences from Mermaid's Dagre      |

---

## Decisions Made

1. **Approach:** Simplified Sugiyama (can upgrade later)
2. **petgraph dependency:** Yes - use for graph data structures
3. **Target:** WASM-compatible, extractable as separate crate

## Next Steps

1. **Create implementation plan** for Simplified Sugiyama approach
2. **Define shared types** between dagre module and mmdflux
3. **Start implementation** in `src/dagre/` module
