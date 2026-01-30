# Dummy Node Architecture for mmdflux

## Executive Summary

The mmdflux dagre module implements the Sugiyama framework but is **missing the dummy node insertion step** that makes dagre's edge routing work correctly. This document describes what dummy nodes are, why they're essential, and how to implement them in mmdflux.

---

## What Are Dummy Nodes?

In the Sugiyama framework, after nodes are assigned to ranks (layers), **long edges** (edges spanning more than one rank) must be handled specially. The solution is to insert **dummy nodes** at each intermediate rank.

### Example

Consider this graph:
```
graph TD
    A --> B
    A --> C
    B --> D
    C --> D
    A --> D   ← This edge spans 2 ranks!
```

After rank assignment:
```
Rank 0: [A]
Rank 1: [B, C]
Rank 2: [D]
```

The edge `A → D` spans from rank 0 to rank 2, skipping rank 1. Without dummy nodes, this edge would need to route around B and C somehow. With dummy nodes:

```
Rank 0: [A]
Rank 1: [B, C, A_D_dummy]  ← Dummy node inserted for A→D edge
Rank 2: [D]

New edges:
  A → A_D_dummy (short edge, 1 rank)
  A_D_dummy → D (short edge, 1 rank)
```

The dummy node `A_D_dummy` has zero visual size but participates in:
1. **Crossing reduction** - Gets ordered within its layer to minimize crossings
2. **Coordinate assignment** - Gets an X position like any other node
3. **Edge waypoint generation** - Its position becomes a waypoint in the original edge's path

---

## Why Dummy Nodes Fix Multiple Issues

### Issue 3: Overlapping Edges at Node Top

**Current problem:** Forward edge enters "More Data?" from top; backward edge exits from top. Both use center attachment point → collision.

**With dummy nodes:** The backward edge would have a dummy node at intermediate ranks. During crossing reduction, this dummy would be positioned to avoid crossing the forward edge. The backward edge would then route through this dummy's position, naturally avoiding the forward edge's path.

### Issue 4: Edge Routing Through Nodes

**Current problem:** The "no" edge from "More Data?" to "Output" passes through "Cleanup" because there's no awareness of intermediate nodes.

**With dummy nodes:** The edge would have a dummy node at Cleanup's rank. The ordering algorithm would position this dummy to the left or right of Cleanup (minimizing crossings). The edge would then route through that position, automatically avoiding Cleanup.

### Other Benefits

- **Labels on isolated segments** - Labels can be placed at dummy node positions
- **Consistent edge spacing** - Edges naturally space out based on dummy positions
- **Deterministic routing** - No need for post-hoc collision detection
- **Future-proof** - Works for arbitrarily complex graphs

---

## Current mmdflux Architecture

### What Exists

```
src/dagre/
├── mod.rs      # layout() entry point
├── acyclic.rs  # Phase 1: Cycle removal (feedback arc set)
├── rank.rs     # Phase 2: Rank assignment (longest path)
├── order.rs    # Phase 3: Crossing reduction (barycenter)
├── position.rs # Phase 4: Coordinate assignment
├── graph.rs    # LayoutGraph internal representation
└── types.rs    # Public types (LayoutResult, etc.)
```

### What's Missing

Between Phase 2 (rank) and Phase 3 (order), there should be a **normalization step** that:
1. Identifies edges spanning more than 1 rank
2. Creates dummy nodes at intermediate ranks
3. Replaces long edges with chains of short edges

This is what the real dagre's `lib/normalize.js` does.

---

## Proposed Implementation

### 1. New File: `src/dagre/normalize.rs`

```rust
//! Edge normalization: Split long edges with dummy nodes.
//!
//! Long edges (spanning multiple ranks) are replaced with chains of
//! short edges connected by dummy nodes. This enables:
//! - Crossing reduction to consider edge routing
//! - Natural edge waypoint generation
//! - Collision-free edge paths

use super::graph::LayoutGraph;

/// A dummy node inserted for a long edge.
#[derive(Debug, Clone)]
pub struct DummyNode {
    /// The original edge index this dummy belongs to
    pub edge_index: usize,
    /// Position in the chain (0 = first dummy after source)
    pub chain_position: usize,
    /// Total dummies in this edge's chain
    pub chain_length: usize,
    /// Width (always 0 for routing purposes)
    pub width: f64,
    /// Height (always 0 for routing purposes)
    pub height: f64,
}

/// Run edge normalization.
///
/// After this:
/// - All edges span exactly 1 rank
/// - graph.dummy_nodes contains dummy node data
/// - graph.original_edges preserved for later reconstruction
pub fn run(graph: &mut LayoutGraph) {
    let edges = graph.effective_edges();
    let mut new_edges: Vec<(usize, usize, usize)> = Vec::new();
    let mut dummies: Vec<DummyNode> = Vec::new();

    for (orig_idx, &(from, to)) in edges.iter().enumerate() {
        let from_rank = graph.ranks[from];
        let to_rank = graph.ranks[to];
        let span = (to_rank - from_rank).abs();

        if span <= 1 {
            // Short edge: keep as-is
            new_edges.push((from, to, orig_idx));
            continue;
        }

        // Long edge: insert dummy nodes
        let chain_length = (span - 1) as usize;
        let direction = if to_rank > from_rank { 1 } else { -1 };

        let mut prev_node = from;
        for i in 0..chain_length {
            // Create dummy node
            let dummy_idx = graph.add_dummy_node(DummyNode {
                edge_index: orig_idx,
                chain_position: i,
                chain_length,
                width: 0.0,
                height: 0.0,
            });

            // Set dummy rank
            graph.ranks.push(from_rank + (i as i32 + 1) * direction);

            // Connect prev → dummy
            new_edges.push((prev_node, dummy_idx, orig_idx));
            prev_node = dummy_idx;
        }

        // Connect last dummy → target
        new_edges.push((prev_node, to, orig_idx));
    }

    graph.edges = new_edges;
}

/// Denormalize: Convert dummy positions back to edge waypoints.
///
/// Called after coordinate assignment to build edge.points arrays.
pub fn denormalize(graph: &LayoutGraph) -> Vec<Vec<(f64, f64)>> {
    // Group dummy nodes by original edge
    // Build waypoint lists from dummy positions
    // Return edge_index → points mapping
    todo!()
}
```

### 2. Modifications to `src/dagre/graph.rs`

```rust
pub struct LayoutGraph {
    // Existing fields...
    pub node_ids: Vec<NodeId>,
    pub node_index: HashMap<NodeId, usize>,
    pub edges: Vec<(usize, usize, usize)>,
    pub ranks: Vec<i32>,
    pub positions: Vec<Point>,
    pub dimensions: Vec<(f64, f64)>,
    pub orders: Vec<usize>,
    pub reversed_edges: HashSet<usize>,

    // New fields for dummy nodes
    pub dummy_nodes: Vec<DummyNode>,
    pub is_dummy: Vec<bool>,  // Quick lookup: is node[i] a dummy?
    pub original_edge_count: usize,  // Number of real edges before normalization
}

impl LayoutGraph {
    /// Add a dummy node, returning its index.
    pub fn add_dummy_node(&mut self, dummy: DummyNode) -> usize {
        let idx = self.node_ids.len();

        // Create synthetic node ID
        let dummy_id = NodeId(format!(
            "_d{}_{}",
            dummy.edge_index,
            dummy.chain_position
        ));

        self.node_ids.push(dummy_id.clone());
        self.node_index.insert(dummy_id, idx);
        self.dimensions.push((dummy.width, dummy.height));
        self.positions.push(Point::default());
        self.orders.push(0);  // Will be set by crossing reduction
        self.is_dummy.push(true);
        self.dummy_nodes.push(dummy);

        idx
    }
}
```

### 3. Modifications to `src/dagre/mod.rs`

```rust
mod normalize;  // Add new module

pub fn layout<N, F>(graph: &DiGraph<N>, config: &LayoutConfig, get_dimensions: F) -> LayoutResult
where
    F: Fn(&NodeId, &N) -> (f64, f64),
{
    let mut lg = LayoutGraph::from_digraph(graph, get_dimensions);

    // Phase 1: Make graph acyclic
    if config.acyclic {
        acyclic::run(&mut lg);
    }

    // Phase 2: Assign ranks
    rank::run(&mut lg);
    rank::normalize(&mut lg);

    // Phase 2.5: NORMALIZE EDGES (NEW!)
    normalize::run(&mut lg);

    // Phase 3: Reduce crossings (now includes dummy nodes)
    order::run(&mut lg);

    // Phase 4: Assign coordinates (dummy nodes get positions too)
    position::run(&mut lg, config);

    // Phase 4.5: DENORMALIZE (NEW!)
    // Convert dummy positions to edge waypoints
    let edge_waypoints = normalize::denormalize(&lg);

    // Build result with waypoints
    // ...
}
```

### 4. Modifications to `src/dagre/order.rs`

The crossing reduction code needs to treat dummy nodes like regular nodes. The main change is ensuring `order::run()` includes dummy nodes when iterating layers.

```rust
pub fn run(graph: &mut LayoutGraph) {
    // Group nodes by rank (now includes dummy nodes)
    let mut layers = rank::by_rank(graph);

    // Crossing reduction iterations
    for iteration in 0..24 {
        for layer_idx in layer_order(iteration) {
            // Process layer including dummies
            let adjacent_layer = get_adjacent_layer(&layers, layer_idx, iteration);
            order_layer(graph, &mut layers[layer_idx], &adjacent_layer);
        }
    }

    // Assign final orders
    assign_orders(graph, &layers);
}
```

### 5. Modifications to `src/dagre/position.rs`

Coordinate assignment needs to handle dummy nodes, which have zero width/height:

```rust
fn assign_x_coordinates(graph: &mut LayoutGraph, config: &LayoutConfig) {
    // Existing logic, but dummy nodes naturally get zero width
    // so they just become waypoints in their layer
}
```

### 6. Modifications to `src/render/layout.rs`

`compute_layout_dagre()` needs to use the new edge waypoints:

```rust
pub fn compute_layout_dagre(diagram: &Diagram, config: &LayoutConfig) -> Layout {
    // ... existing setup ...

    let result = dagre::layout(&dgraph, &dagre_config, |_, dims| {
        (dims.0 as f64, dims.1 as f64)
    });

    // NEW: Store edge waypoints for routing
    let edge_waypoints: HashMap<(String, String), Vec<Point>> = result.edges
        .iter()
        .map(|edge| {
            ((edge.from.clone(), edge.to.clone()), edge.points.clone())
        })
        .collect();

    Layout {
        // ... existing fields ...
        edge_waypoints,  // NEW FIELD
    }
}
```

### 7. Modifications to `src/render/router.rs`

Forward edge routing uses the precomputed waypoints:

```rust
pub fn route_edge(...) -> Option<RoutedEdge> {
    // Check for precomputed waypoints
    if let Some(waypoints) = layout.edge_waypoints.get(&(edge.from.clone(), edge.to.clone())) {
        return route_with_waypoints(edge, waypoints, layout);
    }

    // Fall back to geometric routing for backward edges or missing waypoints
    // ...
}

fn route_with_waypoints(
    edge: &Edge,
    waypoints: &[Point],
    layout: &Layout,
) -> Option<RoutedEdge> {
    // Convert waypoint coordinates to segments
    let mut segments = Vec::new();

    for window in waypoints.windows(2) {
        let from = window[0];
        let to = window[1];

        if from.x == to.x {
            segments.push(Segment::Vertical {
                x: from.x as usize,
                y_start: from.y as usize,
                y_end: to.y as usize,
            });
        } else if from.y == to.y {
            segments.push(Segment::Horizontal {
                y: from.y as usize,
                x_start: from.x as usize,
                x_end: to.x as usize,
            });
        } else {
            // Waypoint-to-waypoint requires bending
            // Use Z-path through midpoint
            let mid_y = (from.y + to.y) / 2.0;
            segments.push(Segment::Vertical {
                x: from.x as usize,
                y_start: from.y as usize,
                y_end: mid_y as usize
            });
            segments.push(Segment::Horizontal {
                y: mid_y as usize,
                x_start: from.x as usize,
                x_end: to.x as usize
            });
            segments.push(Segment::Vertical {
                x: to.x as usize,
                y_start: mid_y as usize,
                y_end: to.y as usize
            });
        }
    }

    Some(RoutedEdge { edge, segments, ... })
}
```

---

## Migration Strategy

### Phase 1: Add Infrastructure (Low Risk)

1. Add `normalize.rs` with `DummyNode` struct
2. Add dummy node fields to `LayoutGraph`
3. Add `edge_waypoints` field to `Layout`
4. No behavioral changes yet

### Phase 2: Implement Normalization (Medium Risk)

1. Implement `normalize::run()`
2. Implement `normalize::denormalize()`
3. Call from `layout()` but don't use waypoints yet
4. Add tests to verify dummy nodes are created correctly

### Phase 3: Integrate with Routing (Higher Risk)

1. Modify `route_edge()` to use waypoints when available
2. Test with `complex.mmd` and cycle fixtures
3. Verify issues 3 and 4 are fixed

### Phase 4: Clean Up

1. Remove workarounds from `route_backward_edge_vertical()`
2. Remove corridor-based routing for backward edges (may keep as fallback)
3. Simplify attachment point logic

---

## Testing Strategy

### Unit Tests for Normalization

```rust
#[test]
fn test_normalize_long_edge() {
    // Edge spanning 3 ranks should create 2 dummy nodes
    let mut graph = create_test_graph();
    // A (rank 0) → D (rank 3)

    normalize::run(&mut graph);

    assert_eq!(graph.dummy_nodes.len(), 2);
    // Check ranks: rank 1 and rank 2
    // Check edge count: 3 short edges instead of 1 long
}

#[test]
fn test_normalize_short_edges_unchanged() {
    // Edges spanning 1 rank should not create dummies
}

#[test]
fn test_denormalize_produces_waypoints() {
    // After coordinate assignment, waypoints should match dummy positions
}
```

### Integration Tests

```rust
#[test]
fn test_complex_mmd_no_edge_through_node() {
    // Render complex.mmd and verify the "no" edge doesn't
    // share any cells with the Cleanup node
}

#[test]
fn test_overlapping_edges_separated() {
    // Forward and backward edges to same node should
    // use different attachment positions
}
```

---

## Estimated Effort

| Component | Lines of Code | Complexity |
|-----------|---------------|------------|
| `normalize.rs` | ~150 | Medium |
| `graph.rs` changes | ~50 | Low |
| `mod.rs` changes | ~20 | Low |
| `order.rs` changes | ~30 | Low |
| `position.rs` changes | ~20 | Low |
| `layout.rs` changes | ~40 | Medium |
| `router.rs` changes | ~100 | Medium |
| Tests | ~200 | Low |
| **Total** | **~610** | **Medium** |

This is a significant but manageable change. The core algorithm (dummy node insertion) is well-documented in dagre's source and academic papers on the Sugiyama method.

---

## Conclusion

Implementing dummy nodes will:

1. **Fix Issues 3 & 4** properly, without workarounds
2. **Future-proof** edge routing for complex diagrams
3. **Simplify** the router by removing collision detection hacks
4. **Align** mmdflux with how dagre actually works

The implementation is contained within the dagre module and layout/router, with minimal impact on other parts of the codebase. The migration can be done incrementally with each phase testable independently.
