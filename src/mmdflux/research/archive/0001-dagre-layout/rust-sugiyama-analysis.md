# rust-sugiyama Deep Dive Analysis

This document provides a comprehensive analysis of the rust-sugiyama library implementation.

## 1. Project Structure

```
$HOME/src/rust-sugiyama/src/
├── lib.rs                          # Main library entry points (3 public APIs)
├── configure.rs                    # Configuration system with env vars
├── util/mod.rs                     # Utility functions (DFS, radix sort, etc.)
└── algorithm/
    ├── mod.rs                      # 4-phase pipeline orchestration
    ├── p0_cycle_removal/mod.rs     # Phase 0: Cycle removal (greedy FAS)
    ├── p1_layering/
    │   ├── mod.rs                  # Phase 1: Ranking/layering
    │   ├── ranking.rs              # Network simplex rank assignment
    │   ├── cut_values.rs           # Cut value calculations for tree edges
    │   ├── low_lim.rs              # Low/Lim DFS values for tree structure
    │   └── tests.rs                # Test suite for layering
    ├── p2_reduce_crossings/
    │   ├── mod.rs                  # Phase 2: Crossing minimization
    │   └── tests.rs                # Test suite
    └── p3_calculate_coordinates/
        ├── mod.rs                  # Phase 3: Brandes-Köpf coordinate assignment
        └── tests.rs                # Test suite
```

**Lines of Code:**
- lib.rs: ~420 lines
- configure.rs: ~232 lines
- algorithm/mod.rs: ~365 lines
- p1_layering/: ~600 lines combined
- p2_reduce_crossings/: ~495 lines
- p3_calculate_coordinates/: ~410 lines
- **Total: ~2500 lines**

---

## 2. Algorithm Implementation Details

### Phase 0: Cycle Removal

**File:** `src/algorithm/p0_cycle_removal/mod.rs` (44 lines)

**rust-sugiyama Implementation:**
- Uses petgraph's `greedy_feedback_arc_set()` function
- Greedy feedback arc set is a heuristic that identifies edges to reverse
- Process:
  1. Checks if graph is cyclic using `is_cyclic_directed()`
  2. Gets FAS via `greedy_feedback_arc_set()`
  3. Reverses each edge in the FAS (adds new edge in opposite direction, removes old)
  4. Validates result is acyclic

**Complexity:** O(V + E) for heuristic approximation

**Note for mmdflux:** mmdflux uses DFS-based cycle removal instead of greedy FAS to match Dagre's default behavior (which Mermaid.js uses). Dagre only uses greedy FAS when `acyclicer: "greedy"` is explicitly set.

### Phase 1: Network Simplex Ranking

**Files:**
- `p1_layering/mod.rs` (142 lines)
- `p1_layering/ranking.rs` (205 lines)
- `p1_layering/cut_values.rs` (194 lines)
- `p1_layering/low_lim.rs` (68 lines)

**Paper:** "A Technique for Drawing Directed Graphs" by Gansner et al. (1993)

**Four Ranking Methods:**

1. **Original:** Calls `move_vertices_up()` then `move_vertices_down()`
2. **MinimizeEdgeLength (Network Simplex):** Core algorithm - DEFAULT
3. **Up:** Sets each vertex to max(incoming neighbor ranks) + minimum_length
4. **Down:** Sets each vertex to min(outgoing neighbor ranks) - minimum_length

**Network Simplex Steps:**
1. `feasible_tree()`: Builds tight tree with zero slack edges
2. Tight tree construction via DFS
3. Find non-tree edge with negative cut value
4. Find entering edge with minimum slack
5. Exchange edges and recalculate
6. Repeat until no negative cut values exist

**Cut Value Formula:**
```
edge_weight + inc.non_tree_sum - inc.cut_sum
+ inc.tree_sum - out.non_tree_sum + out.cut_sum - out.tree_sum
```

### Phase 2: Crossing Minimization

**File:** `src/algorithm/p2_reduce_crossings/mod.rs` (495 lines)

**Dummy Vertices:**
- `insert_dummy_vertices()`: Adds dummy nodes for long edges
- `remove_dummy_vertices()`: Removes dummies after ordering

**Crossing Reduction Methods:**

1. **Barycenter:**
   ```rust
   position = avg(neighbor_positions)
   ```

2. **Median:** Weighted median of neighbor positions with special handling for edge cases

**Bilayer Crossing Count:**
- Uses "Simple and Efficient Bilayer Cross Counting" algorithm
- Radix sort on edge endpoint positions
- Accumulator tree algorithm for O(E log V) complexity

**Bilayer Sweep:**
- Forward and backward sweeps (alternating directions)
- Optional transpose heuristic
- Stops after 4 sweeps without improvement

### Phase 3: Brandes-Köpf Coordinate Assignment

**File:** `src/algorithm/p3_calculate_coordinates/mod.rs` (410 lines)

**Paper:** "Fast and Simple Horizontal Coordinate Assignment" by Brandes and Köpf (2001)

**Key Steps:**
1. Mark Type 1 Conflicts (edge-dummy vertex crossings)
2. Create Vertical Alignments (groups vertices into blocks)
3. Horizontal Compaction (computes block widths, places blocks)
4. Four Layout Directions (Down, Up, Right, Left)
5. Final Coordinate Selection: `(v[1] + v[2]) / 2.0` (average of two medians)

---

## 3. Data Structures

**Vertex Structure:**
```rust
pub(super) struct Vertex {
    id: usize,                    // Original vertex ID
    size: (f64, f64),             // Width, height
    rank: i32,                    // Layer assignment
    pos: usize,                   // Position in layer
    low: u32,                     // DFS low value
    lim: u32,                     // DFS lim value
    parent: Option<NodeIndex>,    // Tree parent
    is_tree_vertex: bool,         // In feasible tree?
    is_dummy: bool,               // Dummy vertex for long edges
    root: NodeIndex,              // Block root (p3)
    align: NodeIndex,             // Alignment in block (p3)
    shift: f64,                   // Block shift (p3)
    sink: NodeIndex,              // Sink of block (p3)
    block_max_vertex_width: f64,  // Max width in block (p3)
}
```

**Edge Structure:**
```rust
pub(super) struct Edge {
    weight: i32,                  // Edge weight
    cut_value: Option<i32>,       // Cut value for ranking
    is_tree_edge: bool,           // In feasible tree?
    has_type_1_conflict: bool,    // Type 1 conflict (p3)
}
```

**Graph Type:** `StableDiGraph<Vertex, Edge>` from petgraph

---

## 4. API Design

**Public Entry Points:**

1. **from_edges:**
   ```rust
   fn from_edges(edges: &[(u32, u32)], config: &Config) -> Layouts<usize>
   ```

2. **from_graph:**
   ```rust
   fn from_graph<V, E>(
       graph: &StableDiGraph<V, E>,
       vertex_size: &impl Fn(NodeIndex, &V) -> (f64, f64),
       config: &Config,
   ) -> Layouts<NodeIndex>
   ```

3. **from_vertices_and_edges:**
   ```rust
   fn from_vertices_and_edges<'a>(
       vertices: &'a [(u32, (f64, f64))],
       edges: &'a [(u32, u32)],
       config: &Config,
   ) -> Layouts<usize>
   ```

**Configuration Options:**
- `minimum_length: u32` (default: 1)
- `vertex_spacing: f64` (default: 10.0)
- `dummy_vertices: bool` (default: true)
- `ranking_type: RankingType` (default: MinimizeEdgeLength)
- `c_minimization: CrossingMinimization` (default: Barycenter)
- `transpose: bool` (default: true)
- `dummy_size: f64` (default: 1.0)

**Output Format:**
```rust
type Layout = (Vec<(usize, (f64, f64))>, f64, f64);
// (list of (vertex_id, (x, y)), width, height)

type Layouts<T> = Vec<(Vec<(T, (f64, f64))>, f64, f64)>;
// For each connected component
```

---

## 5. Code Quality Assessment

**Test Coverage:**
- ~15 tests per phase module
- Integration tests in lib.rs
- Test fixtures and GraphBuilder utility

**Documentation:**
- Module-level docs present
- Paper references cited at module level
- Moderate inline comments

**Performance:**
- Benchmarks for up to 4000 edges: ~100-500ms

**Strengths:**
- Clear phase separation
- Generic over vertex/edge types
- Configuration flexibility
- Connected component handling

**Weaknesses:**
- Many `unwrap()` calls
- Limited inline documentation
- Some dead code

---

## 6. Integration with Petgraph

**Petgraph Version:** 0.8.1

**Used Functions:**
- `StableDiGraph::from_edges()`, `map()`, `filter_map()`
- `neighbors_directed()`, `edges_directed()`
- `node_indices()`, `edge_indices()`
- `retain_nodes()`
- `petgraph::algo::toposort()`
- `petgraph::algo::is_cyclic_directed()`
- `petgraph::algo::greedy_feedback_arc_set()`

**Why StableGraph:**
- Stable node indices across modifications
- Efficient arbitrary edge removal
- In-place structural mutations

---

## 7. Key Takeaways for mmdflux

1. **Algorithm complexity:** Full Network Simplex is ~600 lines just for ranking
2. **StableGraph essential:** Graph modifications during layout require stable indices
3. **Configurable phases:** Each phase can use different algorithms (barycenter vs median)
4. **Coordinates are continuous:** Output is f64, not discrete grid positions
5. **Dummy vertices matter:** Long edges need intermediate nodes for proper crossing minimization
