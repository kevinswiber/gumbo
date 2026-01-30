# Rust Graph Layout Libraries Research

This document surveys existing Rust implementations of graph layout algorithms, evaluating their potential use for mmdflux.

## Summary Table

| Crate         | Layout Type           | Maintained     | Downloads/mo | Use for mmdflux?     |
| ------------- | --------------------- | -------------- | ------------ | -------------------- |
| rust-sugiyama | Hierarchical/Sugiyama | Yes (Sep 2025) | 248          | **Best candidate**   |
| layout-rs     | Graphviz-style        | Yes (Apr 2025) | 12,792       | Study algorithms     |
| dagre-rs      | Hierarchical/Dagre    | New (Oct 2025) | Low          | Watch development    |
| dagre_rust    | Dagre port            | No (Apr 2023)  | 48           | Not recommended      |
| ascii-dag     | ASCII DAG rendering   | Yes (Jan 2026) | 45           | Direct competitor    |
| fdg-sim       | Force-directed        | No (Dec 2022)  | 238          | Not for hierarchical |
| egui_graphs   | Interactive viz       | Active         | N/A          | Different purpose    |
| petgraph      | Data structures only  | Yes            | Very high    | Already used widely  |

---

## Hierarchical/Layered Layout Libraries

### 1. rust-sugiyama

**Repository:** https://github.com/paddison/rust-sugiyama
**Crate:** https://crates.io/crates/rust-sugiyama
**Version:** 0.4.0 (Sep 21, 2025)
**License:** MIT
**Downloads:** ~248/month

#### Description

A Rust implementation of Sugiyama's algorithm for calculating coordinates of directed graphs. This is the most complete hierarchical layout implementation in pure Rust.

#### Algorithm Implementation

Implements all phases of the Sugiyama algorithm:

1. **Cycle Removal** - Uses petgraph's `greedy_feedback_arc_set` function, then reverses edges
2. **Rank Assignment** - Follows Gansner et al.'s "A Technique for Drawing Directed Graphs" paper. Creates optimal feasible tree for rank assignment.
3. **Crossing Reduction** - Weighted median heuristic (default) or barycenter heuristic. Uses Bilayer Cross Count from Barth, Mutzel, and Juenger.
4. **Coordinate Assignment** - Brandes and Koepf's algorithm

**Note for mmdflux:** rust-sugiyama uses greedy FAS, but mmdflux uses DFS-based cycle removal to match Dagre's default behavior (which Mermaid.js uses). Dagre only uses greedy FAS when explicitly configured with `acyclicer: "greedy"`.

#### API

```rust
use rust_sugiyama::{from_edges, from_graph, from_vertices_and_edges};

// Simple edge list
let coords = from_edges(&[(0, 1), (1, 2), (0, 2)]);

// With explicit vertices and sizes
let vertices = vec![(0, (10.0, 5.0)), (1, (10.0, 5.0))];
let edges = vec![(0, 1)];
let coords = from_vertices_and_edges(&vertices, &edges);

// From petgraph StableDiGraph
use petgraph::stable_graph::StableDiGraph;
let graph: StableDiGraph<(), ()> = ...;
let coords = from_graph(&graph);
```

#### Configuration

```rust
use rust_sugiyama::Config;

let config = Config::builder()
    .vertex_spacing(10)  // Gap between vertices
    .minimum_length(1)   // Minimum edge length
    .dummy_vertices(true) // Include dummy vertices
    .crossing_minimization(CrossingMinimization::WeightedMedian)
    .transpose(true)
    .build();
```

#### Assessment for mmdflux

**Pros:**
- Most complete Sugiyama implementation in Rust
- Well-documented algorithm choices with academic references
- Configurable (spacing, crossing reduction method)
- Uses petgraph for graph representation
- Actively maintained

**Cons:**
- Returns coordinates only, not ASCII rendering
- Would need adaptation for mmdflux's ASCII canvas
- May not handle backward edges the way we want

**Recommendation:** Study this implementation for algorithm improvements. Could potentially use as a library for layout computation, then handle ASCII rendering ourselves.

---

### 2. dagre-rs

**Repository:** https://github.com/tangleguard/dagre-rs
**Crate:** https://crates.io/crates/dagre-rs
**Version:** 0.1.0 (Oct 22, 2025)
**License:** Custom
**Downloads:** Low (very new)

#### Description

An independent Rust implementation of the Dagre.js layout algorithm (Sugiyama method). Not affiliated with original Dagre.js authors.

#### Status

- Very early stage (11 commits as of creation)
- No formal releases yet
- Single open issue
- 5 GitHub stars

#### Assessment for mmdflux

**Recommendation:** Too immature currently. Worth monitoring as it develops, since dagre.js is what Mermaid uses for layout.

---

### 3. dagre_rust

**Repository:** https://github.com/r3alst/dagre-rust
**Crate:** https://crates.io/crates/dagre_rust
**Version:** 0.0.5 (Apr 12, 2023)
**License:** Apache-2.0
**Downloads:** ~48/month

#### Description

A Rust port of the JavaScript graphlib library for DAG manipulation. Uses `graphlib_rust` as a dependency.

#### Assessment for mmdflux

**Recommendation:** Not recommended. Unmaintained since April 2023, uses outdated dependencies, and appears incomplete.

---

## ASCII/Terminal Rendering Libraries

### 4. ascii-dag

**Repository:** N/A (not found)
**Crate:** https://crates.io/crates/ascii-dag
**Version:** 0.7.1 (Jan 17, 2026)
**License:** MIT OR Apache-2.0
**Downloads:** ~45/month

#### Description

Zero-dependency, `no_std` compatible ASCII DAG renderer. Implements Sugiyama hierarchical layout and renders to ASCII art.

#### Features

- Zero dependencies (embeddable)
- Sugiyama hierarchical layout algorithm
- Cycle detection
- Handles diamonds, cycles, skip-level edges
- ~46-55KB WASM binary size
- Performance: renders 1000+ nodes in milliseconds

#### API

```rust
use ascii_dag::DAG;

// Builder API
let mut dag = DAG::new();
dag.add_node(1, "Parse");
dag.add_node(2, "Build");
dag.add_edge(1, 2);
let output = dag.render();

// Batch construction
let dag = DAG::from_edges(
    &[(1, "A"), (2, "B"), (3, "C")],
    &[(1, 2), (2, 3)]
);
println!("{}", dag.render());

// Layout IR for custom rendering
let ir = dag.compute_layout();
println!("Canvas: {}x{}", ir.width(), ir.height());

// Cycle detection
if dag.has_cycle() {
    println!("Graph contains cycles");
}
```

#### Assessment for mmdflux

**Pros:**
- Direct competitor - solves similar problem
- Zero dependencies
- Implements Sugiyama algorithm
- Active development

**Cons:**
- May have different design goals
- Simpler node shapes (just labels)

**Recommendation:** Study as a reference implementation. Compare rendering approach and algorithm choices.

---

## Graphviz-Style Layout Libraries

### 5. layout-rs

**Repository:** https://github.com/nadavrot/layout
**Crate:** https://crates.io/crates/layout-rs
**Version:** 0.1.3 (Apr 24, 2025)
**License:** MIT
**Downloads:** ~12,792/month

#### Description

A pure Rust implementation of Graphviz-style graph layout. Parses DOT files and renders to SVG. Does not require external Graphviz binaries.

#### Features

- DOT file parsing to AST
- SVG rendering
- Multiple node shapes
- Edge crossing elimination optimization
- Unicode/emoji/RTL text support
- Record structures (nested nodes)
- Debug-mode visualization

#### API

```rust
use layout::gv;

// Parse DOT
let contents = "digraph { a -> b [label=\"foo\"]; }";
let mut parser = gv::DotParser::new(&contents);
match parser.process() {
    Ok(g) => gv::dump_ast(&g),
    Err(err) => parser.print_error(),
}

// Programmatic graph building also supported via VisualGraph
```

#### CLI Usage

```bash
cargo run --bin layout ./input.dot -o output.svg
```

#### Assessment for mmdflux

**Pros:**
- Pure Rust, no external dependencies
- Well-maintained with significant downloads
- Implements real layout algorithms
- Good code quality (722 GitHub stars)

**Cons:**
- Outputs SVG, not ASCII
- Different algorithm family (Graphviz-style vs pure Sugiyama)

**Recommendation:** Study for algorithm implementation details, especially edge crossing elimination and coordinate assignment.

---

### 6. graphviz-rust

**Crate:** https://crates.io/crates/graphviz-rust
**Version:** 0.9.6 (Sep 21, 2025)
**License:** Custom
**Downloads:** ~122,057/month

#### Description

A Rust interface to DOT format and Graphviz commands. Parses/generates DOT and can invoke external Graphviz binaries.

#### Features

- Parse DOT strings to graph structures
- Export graphs to DOT format
- Execute Graphviz commands (svg, png, pdf output)
- Macro-based graph construction

#### Assessment for mmdflux

**Recommendation:** Not useful for mmdflux. This is a wrapper around external Graphviz, not a pure Rust layout implementation.

---

## Force-Directed Layout Libraries

### 7. fdg-sim

**Repository:** https://github.com/grantshandy/fdg
**Crate:** https://crates.io/crates/fdg-sim
**Version:** 0.9.1 (Dec 17, 2022)
**License:** MIT
**Downloads:** ~238/month

#### Description

A flexible force-directed graph simulation framework. Implements Fruchterman-Reingold algorithm.

#### Features

- Fruchterman-Reingold (1991) algorithm
- N-dimensional support (not limited to 2D)
- Works with petgraph graphs
- Centering force
- GML format support (optional)
- JSON serialization (optional)

#### API

```rust
use fdg_sim::{ForceGraph, Simulation, SimulationParameters};
use petgraph::Graph;

let graph: Graph<(), ()> = ...;
let mut force_graph: ForceGraph<f32, 2, (), ()> = fdg::init_force_graph_uniform(graph, 10.0);
FruchtermanReingold::default().apply_many(&mut force_graph, 100);
Center::default().apply(&mut force_graph);
```

#### Assessment for mmdflux

**Recommendation:** Not suitable. Force-directed layout is not appropriate for flowchart diagrams where hierarchical structure matters. Also unmaintained since 2022.

---

### 8. egui_graphs

**Repository:** https://github.com/blitzarx1/egui_graphs
**Version:** Pre-1.0 (Active)
**License:** MIT
**Stars:** 643

#### Description

Interactive graph visualization widget for egui framework. Combines petgraph data structures with egui rendering.

#### Layout Algorithms

1. **Random Layout** - Quick scatter positioning
2. **Hierarchical Layout** - Layered ranking system
3. **Force-Directed Layout** - Fruchterman-Reingold with extensions

#### Assessment for mmdflux

**Recommendation:** Not directly applicable. This is for GUI applications, not terminal/ASCII output. The hierarchical layout implementation could be studied.

---

## Foundation Libraries

### 9. petgraph

**Repository:** https://github.com/petgraph/petgraph
**Crate:** https://crates.io/crates/petgraph
**Version:** 0.8.2
**License:** MIT/Apache-2.0
**Downloads:** Very high (2.1M+ total)

#### Description

The standard Rust library for graph data structures and algorithms. Most other graph layout crates use petgraph internally.

#### Features

- Multiple graph types (Graph, StableGraph, GraphMap, MatrixGraph)
- Standard algorithms (DFS, BFS, Dijkstra, Bellman-Ford, etc.)
- DOT format export/import
- Serialization support
- Parallel iterators (optional rayon)

#### Algorithms Included

- Shortest paths (Dijkstra, Bellman-Ford, A*)
- Minimum spanning tree
- Strongly connected components
- Topological sort
- Graph isomorphism
- Feedback arc set (for cycle removal)

#### Assessment for mmdflux

**Recommendation:** Consider using petgraph as the internal graph representation. It provides cycle detection, topological sort, and other algorithms we need. Many layout crates build on top of it.

---

## Recommendations for mmdflux

### Short Term: Study and Learn

1. **rust-sugiyama** - Best reference for Sugiyama algorithm implementation in Rust
2. **ascii-dag** - Direct comparison for ASCII rendering approach
3. **layout-rs** - Study edge crossing elimination and coordinate assignment

### Medium Term: Potential Integration

1. **rust-sugiyama** could potentially be used for layout computation
   - Would need to adapt output coordinates to our grid system
   - Handles the complex Sugiyama phases well

2. **petgraph** could replace our internal graph representation
   - Provides algorithms we already implement (topological sort, etc.)
   - Industry-standard, well-tested

### Long Term: Monitor

1. **dagre-rs** - If it matures, could become the best option since it targets the same algorithm as Mermaid's dagre.js

### Key Insights

1. **No perfect solution exists** - Most Rust layout libraries output coordinates for SVG/GUI rendering, not ASCII
2. **Sugiyama algorithm is well-supported** - Multiple implementations available
3. **ASCII rendering is our unique value** - The coordinate-to-ASCII translation is where mmdflux differentiates
4. **Edge routing is underserved** - Most libraries focus on node positioning, not detailed edge routing

### Code Examples to Study

**rust-sugiyama crossing reduction:**
- Weighted median heuristic
- Bilayer cross count algorithm
- Transpose optimization

**layout-rs coordinate assignment:**
- Compact representation
- Edge crossing elimination

**ascii-dag rendering:**
- Grid-based layout
- Character selection for connections
