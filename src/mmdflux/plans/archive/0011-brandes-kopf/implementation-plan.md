# Option 4A: Brandes-Kopf Coordinate Assignment

## Status: ✅ COMPLETE

**Completed:** 2026-01-26

**Commits:**
- `4d8e06d` - Phase 1: Infrastructure (data structures, helpers, conflict detection)
- `9bd177c` - Phase 2: Vertical alignment
- `fe18dcf` - Phase 3: Horizontal compaction
- `e7dad61` - Phase 4: Balance and integration
- `c18ea05` - Phase 5: Testing and validation
- `253c099` - Cleanup: Remove unused test helpers

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Replace the simple layer-centering coordinate assignment with the Brandes-Kopf algorithm, achieving near-optimal x-coordinate placement that minimizes total edge length and bending. This provides ~95% Dagre parity for edge routing.

## Problem Statement

The current coordinate assignment (`src/dagre/position.rs`) uses simple layer centering:
- Each layer is centered within the canvas
- Nodes are spaced sequentially within each layer
- No consideration of edge lengths or bending

This causes edges with large horizontal offsets to take suboptimal paths because node positions don't account for edge connectivity.

## Solution

Implement the Brandes-Kopf algorithm which:
1. Computes 4 different alignments (ul, ur, dl, dr)
2. Each alignment tries to vertically align connected nodes
3. Selects the alignment with smallest total width
4. Returns balanced median of all 4 alignments

## Algorithm Overview

```
Input: Layered graph with nodes assigned to layers

1. Conflict Detection
   ├─ Type-1: Non-inner segment crosses inner segment
   └─ Type-2: Between dummy nodes of parallel long edges

2. For each of 4 alignments (ul, ur, dl, dr):
   ├─ Vertical Alignment: Create blocks of vertically aligned nodes
   │   ├─ Process layers in sweep direction (up or down)
   │   ├─ For each node, find median neighbor
   │   └─ Align with median if no conflict
   │
   └─ Horizontal Compaction: Assign x-coordinates
       ├─ Compute block widths
       ├─ Push blocks left/right based on bias
       └─ Respect separation constraints

3. Balance: Return median x of all 4 alignments for each node
```

## Architecture

```
src/dagre/
├── position.rs (existing - will be refactored)
├── bk.rs (NEW - Brandes-Kopf implementation)
│   ├── find_type1_conflicts()
│   ├── find_type2_conflicts()
│   ├── vertical_alignment()
│   ├── horizontal_compaction()
│   ├── balance()
│   └── position_x() (main entry point)
└── mod.rs (update to use new positioning)
```

## Key Data Structures

```rust
/// A block is a set of vertically aligned nodes
struct BlockAlignment {
    /// Maps each node to its block root
    root: HashMap<NodeId, NodeId>,
    /// Maps each node to the next node in its block
    align: HashMap<NodeId, NodeId>,
    /// Maps each block root to its class sink (for compaction)
    sink: HashMap<NodeId, NodeId>,
    /// Shift amount for each block
    shift: HashMap<NodeId, f64>,
    /// Final x coordinate for each node
    x: HashMap<NodeId, f64>,
}

/// Conflict between edges during alignment
struct Conflict {
    /// Conflicting edge from inner segment
    inner: (NodeId, NodeId),
    /// Conflicting edge from non-inner segment
    non_inner: (NodeId, NodeId),
}
```

## Files Changed

| File | Change |
|------|--------|
| New: `src/dagre/bk.rs` | Brandes-Kopf algorithm implementation |
| `src/dagre/position.rs` | Refactor to call BK, keep simple fallback |
| `src/dagre/mod.rs` | Export new module |
| `src/dagre/graph.rs` | May need additional accessors |

## Task Details

See [task-list.md](./task-list.md) for the full task breakdown. Key tasks:

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Module structure & data types | [tasks/1.1-bk-module-structures.md](./tasks/1.1-bk-module-structures.md) |
| 1.2 | Helper functions | [tasks/1.2-helper-functions.md](./tasks/1.2-helper-functions.md) |
| 1.3 | Conflict detection | [tasks/1.3-conflict-detection.md](./tasks/1.3-conflict-detection.md) |
| 2.1 | Vertical alignment | [tasks/2.1-vertical-alignment.md](./tasks/2.1-vertical-alignment.md) |
| 2.2 | Block chain management | [tasks/2.2-block-chain-management.md](./tasks/2.2-block-chain-management.md) |
| 3.1 | Horizontal compaction | [tasks/3.1-horizontal-compaction.md](./tasks/3.1-horizontal-compaction.md) |
| 4.1 | Balance & integration | [tasks/4.1-four-alignments.md](./tasks/4.1-four-alignments.md) |
| 5.1 | Testing & validation | [tasks/5.1-validation.md](./tasks/5.1-validation.md) |

## Research References

- [02-dagre-edge-routing.md](../../research/archive/0006-edge-routing-horizontal-offset/02-dagre-edge-routing.md) - Dagre's approach to edge routing
- [05-full-dagre-parity-analysis.md](../../research/archive/0006-edge-routing-horizontal-offset/05-full-dagre-parity-analysis.md) - Full parity analysis
- Original paper: Brandes & Köpf, "Fast and Simple Horizontal Coordinate Assignment"

## Complexity Estimate (Original → Actual)

- Conflict detection: ~100 lines → ~150 lines
- Vertical alignment: ~80 lines → ~200 lines
- Horizontal compaction: ~120 lines → ~250 lines
- Balance/selection: ~60 lines → ~200 lines
- **Total: ~360 lines → ~800 lines of new code**

The implementation was more complex than estimated due to:
- Direction-aware width calculations (TD/BT use width, LR/RL use height)
- Comprehensive test coverage (48 unit tests)
- Helper functions for layer/neighbor traversal

## Risk Assessment

**High complexity** - Algorithm has subtle correctness requirements:
- Block chain management must be cycle-free
- Conflict detection must handle all edge cases
- Compaction must respect separation constraints

**Mitigation:**
- Comprehensive unit tests for each phase
- Test against known dagre outputs
- Keep simple centering as fallback

## Success Criteria

1. ✅ All edges receive optimal or near-optimal x-coordinates
2. ⚠️ E→F "no" edge in complex.mmd - discovered graph structure limitation (see below)
3. ✅ All existing tests pass (27 integration tests, 26 fixtures)
4. ✅ No performance regression on typical diagrams

### Note on Success Criteria #2

Investigation revealed that the "More Data?" → "Output" edge crossing is structurally unavoidable:
- Output (F) has predecessors on opposite sides of the layout
- The 4 BK alignments split 2-2, so median places Output in the middle
- This causes both incoming edges to bend rather than one being straight

This is inherent to the median-based balancing approach. See task-list.md for potential improvements.
