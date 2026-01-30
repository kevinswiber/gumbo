# Petgraph Library Analysis

This document analyzes petgraph's data structures and algorithms relevant for implementing a Dagre-like layout.

## 1. Graph Data Structures

### Available Types

| Type | Storage | Best For | Index Stability |
|------|---------|----------|-----------------|
| `Graph` / `DiGraph` | Adjacency list | General use | Indices change on deletion |
| `StableGraph` / `StableDiGraph` | Adjacency list + free list | Layout algorithms | Stable across removals |
| `GraphMap` | Hash table | Node IDs as keys | N/A (uses keys) |
| `MatrixGraph` | Adjacency matrix | Dense graphs | Stable |
| `Csr` | Compressed sparse row | Read-heavy, immutable | Stable |

### Best for Layout: StableDiGraph

**Reason:** Sugiyama algorithm modifies the graph (adding/removing dummy nodes) and needs stable indices.

**How it works:**
- Wraps regular Graph with Option-wrapped nodes
- Free lists track vacancies from removals
- Slight memory overhead but crucial for multi-phase algorithms

**rust-sugiyama uses `StableDiGraph` exclusively.**

---

## 2. Relevant Algorithms Already Implemented

### Topological Sort & Cycle Detection

```rust
// Topological sort - O(V+E)
toposort<G>(g, space) -> Result<Vec<NodeId>, Cycle<NodeId>>
// Iterative DFS, returns error on cycles

// Cycle detection - O(V+E)
is_cyclic_directed<G>(g) -> bool
// Recursive DFS, detects back edges
```

### Feedback Arc Set

```rust
// Greedy FAS - O(V+E)
greedy_feedback_arc_set<G>(g) -> Iterator<EdgeRef>
// Implements Eades, Lin, Smyth 1993 heuristic
// Returns edges to remove for acyclicity
```

**Note:** While petgraph provides `greedy_feedback_arc_set`, mmdflux uses custom DFS-based cycle detection to match Dagre's default behavior. Mermaid.js uses Dagre's DFS-based FAS (the default), not the greedy variant.

### DFS/BFS Traversals

```rust
// Visitor-based DFS
depth_first_search(graph, starts, visitor)

// Events during traversal
enum DfsEvent {
    Discover(N, Time),
    TreeEdge(N, N),
    BackEdge(N, N),      // Indicates cycle!
    CrossForwardEdge(N, N),
    Finish(N, Time),
}

// Control traversal
enum Control { Continue, Prune, Break(B) }
```

### Other Useful Algorithms

- `tarjan_scc`, `kosaraju_scc` - Strongly connected components
- `dijkstra_map`, `bellman_ford` - Shortest paths (less relevant for layout)
- `condensation` - Contract SCCs into single nodes

---

## 3. API Patterns

### Index Types

```rust
pub unsafe trait IndexType: Copy + Default + Hash + Ord + 'static {
    fn new(x: usize) -> Self;
    fn index(&self) -> usize;
    fn max() -> Self;
}
// Supports u8, u16, u32, usize (default is u32)
```

`NodeIndex<Ix>` and `EdgeIndex<Ix>` are wrapper types.

### Graph Traits (visit module)

```rust
// Iterate node IDs
trait IntoNodeIdentifiers { ... }

// Iterate neighbors in direction
trait IntoNeighborsDirected { ... }

// Iterate edges with metadata
trait IntoEdgeReferences { ... }

// Convert between types and indices
trait NodeIndexable { ... }

// Provides visit maps for traversal tracking
trait Visitable { ... }
```

### Graph Modification

```rust
trait Build {
    fn add_node(&mut self, weight: N) -> NodeIndex;
    fn add_edge(&mut self, a: NodeIndex, b: NodeIndex, weight: E) -> EdgeIndex;
}

// Node removal cascades to remove connected edges
fn remove_node(&mut self, n: NodeIndex) -> Option<N>
fn remove_edge(&mut self, e: EdgeIndex) -> Option<E>
```

---

## 4. WASM Compatibility

### Dependencies

All WASM-safe:
- `fixedbitset` - Core bit set
- `hashbrown` - Pure Rust hashmap
- `indexmap` - Pure Rust ordered map

**No platform-specific or OS-dependent code.**

### Feature Configuration

```toml
[features]
std = ["indexmap/std"]  # Opt-in for std library
# Can be disabled with no_std + alloc
```

- Petgraph builds with `no_std` + `alloc`
- All algorithms compile to WASM
- Serialization (`serde-1`) and rayon require std, but core functionality doesn't

### Proof of WASM Support

The [petgraph-wasm](https://github.com/urbdyn/petgraph-wasm) project demonstrates it works in practice.

---

## 5. Integration Considerations

### How rust-sugiyama Uses petgraph

```rust
// Create graph
let graph: StableDiGraph<Vertex, Edge> = StableDiGraph::from_edges(&edges);

// Map external IDs
let mut id_map = HashMap::new();
for &v in vertices {
    let node_idx = graph.add_node(Vertex::new(v, size));
    id_map.insert(v, node_idx);
}

// Four-phase algorithm operates on graph
// P0: Cycle removal (mmdflux uses DFS-based, matching Dagre default)
// P1: Ranking (layer assignment)
// P2: Crossing reduction (ordering)
// P3: Coordinate calculation
```

### For mmdflux Integration

**Pros of using petgraph:**
- Battle-tested, production-grade
- StableGraph solves the "layout modification" problem
- Visitor patterns handle DFS/BFS beautifully
- WASM-compatible out of the box
- Strong foundation for future extensions

**Note:** While petgraph's `greedy_feedback_arc_set` exists, mmdflux uses custom DFS-based cycle removal to match Dagre's default behavior (which Mermaid.js uses).

**Cons:**
- Need to convert between mmdflux `Diagram` ↔ petgraph `StableDiGraph`
- Extra dependency (though small, pure Rust)
- Mermaid IDs are strings; petgraph uses numeric indices (need mapping)
- Learning curve on visitor patterns

### What petgraph Provides for Each Sugiyama Phase

| Phase | Algorithm | petgraph Support |
|-------|-----------|------------------|
| 0 | Cycle Removal | Custom DFS (matches Dagre default); petgraph's `greedy_feedback_arc_set` available but not used |
| 1 | Ranking/Layering | DFS visitor - Build on top |
| 2 | Crossing Reduction | DFS/ordering - Build on top |
| 3 | Coordinate Calculation | DFS/tree traversal - Build on top |

**Key insight:** petgraph is *data structure + basic algorithms*, not a *layout* library. We use it as infrastructure and build layout logic on top. For cycle removal, we use custom DFS to match Dagre's default behavior.

---

## 6. Recommendation for mmdflux

### Option A: Use petgraph (Recommended)

```rust
// Add to Cargo.toml
[dependencies]
petgraph = { version = "0.8", default-features = false }

// In dagre module
use petgraph::stable_graph::StableDiGraph;
use petgraph::algo::is_cyclic_directed;
// Note: We use custom DFS cycle removal, not greedy_feedback_arc_set
```

**Benefits:**
- StableGraph handles index stability
- Well-tested foundation
- WASM-ready
- Useful traversal algorithms available

### Option B: Custom Graph Types

Keep mmdflux's current `Diagram` with `HashMap<String, Node>`.

**Benefits:**
- No new dependencies
- String IDs work directly
- Simpler mental model

**Drawbacks:**
- Must implement cycle detection ourselves
- Must handle index stability ourselves
- Reinventing the wheel

### Hybrid Approach

Use petgraph internally in the dagre module, but expose a simpler API:

```rust
// Public API uses simple types
pub fn layout(nodes: &[NodeDef], edges: &[(usize, usize)]) -> LayoutResult

// Internal implementation uses petgraph
fn layout_internal(graph: &StableDiGraph<...>) -> ...
```

This gives us petgraph's power without exposing it in the public API.
