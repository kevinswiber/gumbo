# Simplified Sugiyama Layout Module Implementation Plan

## Status: 🚧 IN PROGRESS

## Overview

Implement a standalone `src/dagre/` module that provides hierarchical graph layout using the Simplified Sugiyama algorithm. The module will be WASM-compatible, extractable as a separate crate later, and have no cross-dependencies with mmdflux internals.

**Key decisions:**
- Use petgraph (`StableDiGraph`) for graph data structures
- Simplified Sugiyama (not full Dagre): longest-path ranking, barycenter crossing reduction
- Grid-based coordinates (discrete `usize`, not continuous `f64`)
- Greedy FAS for cycle handling (same as Dagre, via petgraph)

## Current State

The existing `src/render/layout.rs` contains:
- `topological_layers()` - Basic topological sort with alphabetical tiebreaking
- `compute_grid_positions()` - Layer/position assignment
- `grid_to_draw_*()` - Coordinate assignment for vertical/horizontal layouts
- `assign_backward_edge_lanes()` - Back-edge detection (after layout)

**Problems with current implementation:**
1. Back-edges detected after ranking, not before (causes wrong source identification)
2. Alphabetical tiebreaking instead of declaration order
3. No crossing reduction (nodes sorted alphabetically within layers)

## Detailed Design Reference

See `research/archive/0001-dagre-layout/module-design.md` for comprehensive implementation details including:

- **Complete code scaffolding** for each module (types.rs, graph.rs, acyclic.rs, rank.rs, order.rs, position.rs, util.rs)
- **API design patterns** with input/output examples
- **Type definitions** with full implementations (NodeId, Direction, Point, Rect, LayoutConfig, LayoutResult)
- **Shared types strategy** - what lives in dagre vs mmdflux
- **Migration path** - step-by-step with adapter code examples

The code in module-design.md should be used as a starting point, adapting as needed during implementation.

## Implementation Approach

### Module Structure

```
src/dagre/
├── mod.rs        # Public API: layout() function and re-exports
├── types.rs      # Direction, LayoutConfig, LayoutResult, NodeId, GridPos, Rect
├── graph.rs      # LayoutGraph wrapper around petgraph::StableDiGraph
├── acyclic.rs    # Phase 1: Greedy FAS via petgraph
├── rank.rs       # Phase 2: Longest-path layer assignment
├── order.rs      # Phase 3: Barycenter crossing reduction with sweeps
└── position.rs   # Phase 4: Grid-based coordinate assignment
```

### Data Flow

```
Input: LayoutGraph (built from nodes/edges)
    │
    ├─► Phase 1: acyclic::run()
    │   - Greedy FAS via petgraph::algo::greedy_feedback_arc_set
    │   - Same algorithm as Dagre
    │
    ├─► Phase 2: rank::run()
    │   - Longest-path: source nodes at layer 0
    │   - Respects back-edge exclusion
    │
    ├─► Phase 3: order::run()
    │   - Barycenter heuristic with 4-8 sweeps
    │   - Stable sort preserves input order for ties
    │
    └─► Phase 4: position::run()
        - Grid-based centering
        - Discrete coordinates

Output: LayoutResult { nodes, grid_positions, backward_edges, dimensions }
```

### Public API

```rust
// Main entry point
pub fn layout<N>(graph: &DiGraph<N>, config: &LayoutConfig) -> LayoutResult
where
    N: NodeMetrics;

// Trait for node dimensions
pub trait NodeMetrics {
    fn dimensions(&self, node_id: &NodeId) -> (f64, f64);
}

// Core types (see module-design.md for full implementations)
pub struct NodeId(pub String);
pub enum Direction { TopBottom, BottomTop, LeftRight, RightLeft }
pub struct Point { pub x: f64, pub y: f64 }
pub struct Rect { pub x: f64, pub y: f64, pub width: f64, pub height: f64 }
pub struct LayoutConfig { pub direction: Direction, pub node_sep: f64, pub rank_sep: f64, ... }
pub struct LayoutResult { pub nodes: HashMap<NodeId, Rect>, pub edges: Vec<EdgeLayout>, ... }
```

### Usage Example

```rust
use dagre::{DiGraph, layout, LayoutConfig, Direction};

let mut graph = DiGraph::new();
graph.add_node("A", NodeData { width: 10.0, height: 3.0 });
graph.add_node("B", NodeData { width: 10.0, height: 3.0 });
graph.add_edge("A", "B");

let config = LayoutConfig {
    direction: Direction::TopBottom,
    node_sep: 4.0,
    rank_sep: 3.0,
    ..Default::default()
};

let result = layout(&graph, &config);
// result.nodes contains positioned Rects for each node
```

## Files to Modify/Create

### New Files (src/dagre/)

| File | Purpose |
|------|---------|
| `mod.rs` | Public API, re-exports, main `layout()` function |
| `types.rs` | `NodeId`, `Direction`, `GridPos`, `Rect`, `LayoutConfig`, `LayoutResult` |
| `graph.rs` | `LayoutGraph<N>` wrapping `StableDiGraph` |
| `acyclic.rs` | Phase 1: Greedy FAS via petgraph |
| `rank.rs` | Phase 2: Longest-path layer assignment |
| `order.rs` | Phase 3: Barycenter crossing reduction |
| `position.rs` | Phase 4: Grid-based coordinate assignment |

### Modified Files

| File | Changes |
|------|---------|
| `Cargo.toml` | Add `petgraph = "0.6"` dependency |
| `src/lib.rs` | Add `pub mod dagre;` |
| `src/render/layout.rs` | Create adapter to use dagre module |

## Implementation Phases

### Phase A: Foundation (~2-3 hours)
- Create module structure
- Implement types.rs
- Implement graph.rs with LayoutGraph
- Add petgraph dependency
- Unit tests for graph operations

### Phase B: Core Algorithm (~4-6 hours)
- Implement acyclic.rs (back-edge detection)
- Implement rank.rs (longest-path)
- Implement order.rs (barycenter)
- Unit tests for each phase

### Phase C: Coordinate Assignment (~3-4 hours)
- Implement position.rs (vertical layout)
- Add horizontal layout (LR/RL)
- Handle reversed directions (BT/RL)
- Unit tests

### Phase D: Integration (~2-3 hours)
- Create adapter in render/layout.rs
- Run existing integration tests
- Fix regressions

### Phase E: Testing & Polish (~2-3 hours)
- Comprehensive unit tests
- Test all fixture files
- Document public API

## Testing Strategy

### Unit Tests
- `acyclic.rs`: Back-edge detection with cycles, DAGs, self-loops
- `rank.rs`: Layer assignment with linear, diamond, cycle graphs
- `order.rs`: Crossing reduction improves ordering
- `position.rs`: Valid coordinates, no overlaps

### Integration Tests
- All existing fixtures must render correctly
- Compare http_request.mmd output (Client should be at top)
- Test all four directions (TD, BT, LR, RL)

### Manual Verification
- Visual inspection of rendered diagrams
- Compare with Mermaid.js output for reference

## Differences from Mermaid's Dagre

See `research/archive/0001-dagre-layout/mmdflux-vs-dagre-differences.md` for detailed comparison.

Key differences:
- **Cycle handling:** Same (Greedy FAS)
- **Ranking:** Longest-path vs Network Simplex
- **Crossing reduction:** Barycenter only vs Barycenter + Transpose
- **Coordinates:** Discrete grid vs Continuous f64

## Future Enhancements (Not in Scope)

1. Transpose optimization for crossing reduction
2. Network simplex ranking for balanced layouts
3. Extract as separate `dagre-layout` crate
4. Subgraph/cluster support
