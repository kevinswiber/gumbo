# Dagre Layout Module Design

This document outlines the design for a standalone Dagre-like layout module that can eventually be extracted as a separate crate.

## 1. Module Boundary Analysis

### Current mmdflux Structure

```
src/
├── parser/          # Mermaid-specific parsing
│   ├── grammar.pest # PEG grammar
│   ├── ast.rs       # AST types (Vertex, EdgeSpec, ShapeSpec)
│   └── flowchart.rs # Parser implementation
├── graph/           # Domain model
│   ├── diagram.rs   # Diagram container with Direction enum
│   ├── node.rs      # Node with Shape enum (Rectangle, Round, Diamond)
│   ├── edge.rs      # Edge with Stroke, Arrow enums
│   └── builder.rs   # AST-to-Diagram conversion
└── render/          # ASCII rendering
    ├── layout.rs    # Layout computation (LAYOUT LOGIC HERE)
    ├── router.rs    # Edge routing
    ├── shape.rs     # Node dimensions and rendering
    ├── canvas.rs    # 2D character grid
    ├── chars.rs     # Box-drawing character sets
    └── edge.rs      # Edge rendering
```

### What's mmdflux-Specific vs Generic Layout

| Component                      | mmdflux-Specific                | Generic Layout                               |
| ------------------------------ | ------------------------------- | -------------------------------------------- |
| `Direction` enum (TD/BT/LR/RL) | No                              | **Yes** - universal for hierarchical layouts |
| `Node` with Shape/Label        | Yes - rendering concerns        | No                                           |
| `Edge` with Stroke/Arrow       | Yes - rendering concerns        | No                                           |
| `topological_layers()`         | No                              | **Yes** - core algorithm                     |
| `compute_grid_positions()`     | No                              | **Yes** - layer assignment                   |
| `grid_to_draw_*()`             | Partial - coordinate conversion | Partial                                      |
| `NodeBounds`                   | Yes - specific dimensions       | No                                           |
| `Layout` struct                | Partial                         | Partial                                      |
| Edge routing                   | Yes - ASCII-specific            | No                                           |

### Key Insight

The current `layout.rs` implements a simplified Sugiyama-style algorithm:
1. **Topological layering** - assigns nodes to ranks based on dependencies
2. **Deterministic ordering** - sorts nodes within layers alphabetically
3. **Coordinate assignment** - converts grid to pixel/char positions
4. **Backward edge handling** - detects and routes cycles

**Missing from full Dagre/Sugiyama:**
- Proper cycle removal (Dagre uses DFS-based approach)
- Network simplex for optimal ranking
- Crossing minimization (barycenter/median heuristics)
- Brandes-Kopf coordinate assignment

---

## 2. Proposed Module Structure

```
dagre/
├── mod.rs           # Public API, re-exports
├── types.rs         # Shared types (NodeId, Direction, etc.)
├── graph.rs         # Graph representation (input/output)
├── acyclic.rs       # Cycle removal (Phase 1)
├── rank.rs          # Layer/rank assignment (Phase 2)
├── order.rs         # Crossing reduction (Phase 3)
├── position.rs      # Coordinate assignment (Phase 4)
└── util.rs          # Helper functions
```

### 2.1 `mod.rs` - Public API

```rust
//! Dagre-style hierarchical graph layout.
//!
//! Implements the Sugiyama framework:
//! 1. Cycle removal (make graph acyclic)
//! 2. Layer assignment (rank nodes)
//! 3. Crossing reduction (order nodes within layers)
//! 4. Coordinate assignment (x, y positions)

mod acyclic;
mod graph;
mod order;
mod position;
mod rank;
mod types;
mod util;

pub use graph::{DiGraph, LayoutGraph};
pub use types::{Direction, LayoutConfig, LayoutResult, NodeId, Point, Rect};

/// Main entry point for layout computation.
pub fn layout<N>(graph: &DiGraph<N>, config: &LayoutConfig) -> LayoutResult
where
    N: NodeMetrics,
{
    // Implementation calls each phase
}

/// Trait for providing node dimensions to the layout algorithm.
pub trait NodeMetrics {
    fn dimensions(&self, node_id: &NodeId) -> (f64, f64);
}
```

**Dependencies:**
- None (all internal)

**External dependencies:**
- None required, but can optionally use `petgraph`

### 2.2 `types.rs` - Shared Types

```rust
/// Unique identifier for a node.
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct NodeId(pub String);

impl From<&str> for NodeId {
    fn from(s: &str) -> Self {
        NodeId(s.to_string())
    }
}

/// Direction of the hierarchical layout.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum Direction {
    #[default]
    TopBottom,   // TB/TD
    BottomTop,   // BT
    LeftRight,   // LR
    RightLeft,   // RL
}

impl Direction {
    /// Is this a vertical (TB/BT) or horizontal (LR/RL) layout?
    pub fn is_vertical(&self) -> bool {
        matches!(self, Direction::TopBottom | Direction::BottomTop)
    }

    /// Is this a reversed direction (BT or RL)?
    pub fn is_reversed(&self) -> bool {
        matches!(self, Direction::BottomTop | Direction::RightLeft)
    }
}

/// A 2D point with floating-point coordinates.
#[derive(Debug, Clone, Copy, PartialEq, Default)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}

/// A rectangle (bounding box).
#[derive(Debug, Clone, Copy, PartialEq, Default)]
pub struct Rect {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

impl Rect {
    pub fn center(&self) -> Point {
        Point {
            x: self.x + self.width / 2.0,
            y: self.y + self.height / 2.0,
        }
    }
}

/// Configuration options for the layout algorithm.
#[derive(Debug, Clone)]
pub struct LayoutConfig {
    /// Layout direction.
    pub direction: Direction,

    /// Horizontal spacing between nodes (or vertical for LR/RL).
    pub node_sep: f64,

    /// Vertical spacing between ranks (or horizontal for LR/RL).
    pub rank_sep: f64,

    /// Spacing between edge paths.
    pub edge_sep: f64,

    /// Padding around the entire diagram.
    pub margin: f64,

    /// Alignment within ranks: "UL", "UR", "DL", "DR" (default: centered).
    pub align: Option<String>,

    /// Whether to apply layout optimization for acyclic graphs.
    pub acyclic: bool,
}

impl Default for LayoutConfig {
    fn default() -> Self {
        Self {
            direction: Direction::default(),
            node_sep: 50.0,
            rank_sep: 50.0,
            edge_sep: 10.0,
            margin: 10.0,
            align: None,
            acyclic: true,
        }
    }
}

/// Result of the layout computation.
#[derive(Debug, Clone)]
pub struct LayoutResult {
    /// Bounding boxes for each node (positioned).
    pub nodes: HashMap<NodeId, Rect>,

    /// Edge paths as sequences of points.
    pub edges: Vec<EdgeLayout>,

    /// Total width of the layout.
    pub width: f64,

    /// Total height of the layout.
    pub height: f64,
}

/// Layout information for a single edge.
#[derive(Debug, Clone)]
pub struct EdgeLayout {
    /// Source node.
    pub from: NodeId,
    /// Target node.
    pub to: NodeId,
    /// Path points (for rendering as polyline or spline).
    pub points: Vec<Point>,
    /// Original edge index (for preserving metadata).
    pub index: usize,
}
```

**Dependencies:**
- `std::collections::HashMap`

### 2.3 `graph.rs` - Graph Representation

```rust
use std::collections::{HashMap, HashSet};
use crate::types::NodeId;

/// A directed graph for layout.
///
/// Generic over node data `N` which can store application-specific info.
#[derive(Debug, Clone)]
pub struct DiGraph<N> {
    nodes: HashMap<NodeId, N>,
    edges: Vec<(NodeId, NodeId)>,

    // Adjacency lists for efficient traversal
    successors: HashMap<NodeId, Vec<NodeId>>,
    predecessors: HashMap<NodeId, Vec<NodeId>>,
}

impl<N> DiGraph<N> {
    pub fn new() -> Self {
        Self {
            nodes: HashMap::new(),
            edges: Vec::new(),
            successors: HashMap::new(),
            predecessors: HashMap::new(),
        }
    }

    pub fn add_node(&mut self, id: impl Into<NodeId>, data: N) {
        let id = id.into();
        self.successors.entry(id.clone()).or_default();
        self.predecessors.entry(id.clone()).or_default();
        self.nodes.insert(id, data);
    }

    pub fn add_edge(&mut self, from: impl Into<NodeId>, to: impl Into<NodeId>) {
        let from = from.into();
        let to = to.into();
        self.edges.push((from.clone(), to.clone()));
        self.successors.entry(from.clone()).or_default().push(to.clone());
        self.predecessors.entry(to).or_default().push(from);
    }

    pub fn node_ids(&self) -> impl Iterator<Item = &NodeId> {
        self.nodes.keys()
    }

    pub fn node_count(&self) -> usize {
        self.nodes.len()
    }

    pub fn edge_count(&self) -> usize {
        self.edges.len()
    }

    pub fn edges(&self) -> &[(NodeId, NodeId)] {
        &self.edges
    }

    pub fn successors(&self, id: &NodeId) -> &[NodeId] {
        self.successors.get(id).map(|v| v.as_slice()).unwrap_or(&[])
    }

    pub fn predecessors(&self, id: &NodeId) -> &[NodeId] {
        self.predecessors.get(id).map(|v| v.as_slice()).unwrap_or(&[])
    }

    pub fn in_degree(&self, id: &NodeId) -> usize {
        self.predecessors.get(id).map(|v| v.len()).unwrap_or(0)
    }

    pub fn out_degree(&self, id: &NodeId) -> usize {
        self.successors.get(id).map(|v| v.len()).unwrap_or(0)
    }

    pub fn get_node(&self, id: &NodeId) -> Option<&N> {
        self.nodes.get(id)
    }
}

/// Internal graph representation with additional layout metadata.
#[derive(Debug)]
pub(crate) struct LayoutGraph {
    /// Node IDs in the graph.
    pub node_ids: Vec<NodeId>,

    /// Edges as (from_index, to_index, original_edge_index).
    pub edges: Vec<(usize, usize, usize)>,

    /// Node index lookup.
    pub node_index: HashMap<NodeId, usize>,

    /// Reversed edges (for cycle removal).
    pub reversed_edges: HashSet<usize>,

    /// Rank (layer) assigned to each node.
    pub ranks: Vec<i32>,

    /// Order within rank for each node.
    pub order: Vec<usize>,

    /// Final positions.
    pub positions: Vec<Point>,

    /// Node dimensions.
    pub dimensions: Vec<(f64, f64)>,
}

impl LayoutGraph {
    pub fn from_digraph<N, F>(graph: &DiGraph<N>, get_dimensions: F) -> Self
    where
        F: Fn(&NodeId, &N) -> (f64, f64),
    {
        let node_ids: Vec<_> = graph.node_ids().cloned().collect();
        let node_index: HashMap<_, _> = node_ids
            .iter()
            .enumerate()
            .map(|(i, id)| (id.clone(), i))
            .collect();

        let edges: Vec<_> = graph.edges()
            .iter()
            .enumerate()
            .map(|(i, (from, to))| {
                (node_index[from], node_index[to], i)
            })
            .collect();

        let dimensions: Vec<_> = node_ids
            .iter()
            .map(|id| get_dimensions(id, graph.get_node(id).unwrap()))
            .collect();

        let n = node_ids.len();

        Self {
            node_ids,
            edges,
            node_index,
            reversed_edges: HashSet::new(),
            ranks: vec![0; n],
            order: (0..n).collect(),
            positions: vec![Point::default(); n],
            dimensions,
        }
    }
}
```

**Dependencies:**
- `types.rs`

### 2.4 `acyclic.rs` - Cycle Removal

```rust
//! Phase 1: Make the graph acyclic by identifying back-edges.
//!
//! Uses a DFS-based approach to identify back-edges - edges that point
//! to ancestors in the DFS tree. This preserves the natural forward flow
//! of the graph better than minimum feedback arc set algorithms.
//!
//! This matches Dagre's default behavior (used by Mermaid.js).

use std::collections::HashSet;
use super::graph::LayoutGraph;

/// Identify back-edges that need to be reversed for acyclicity.
/// Marks edges in the LayoutGraph's reversed_edges set.
pub fn run(graph: &mut LayoutGraph) {
    let n = graph.node_ids.len();
    if n == 0 {
        return;
    }

    // Build adjacency list
    let mut adj: Vec<Vec<(usize, usize)>> = vec![Vec::new(); n];
    for (edge_idx, &(from, to, _)) in graph.edges.iter().enumerate() {
        adj[from].push((edge_idx, to));
    }

    // DFS state
    let mut visited = vec![false; n];
    let mut in_stack = vec![false; n];
    let mut back_edges: HashSet<usize> = HashSet::new();

    // Run DFS from each unvisited node
    for start in 0..n {
        if !visited[start] {
            dfs_find_back_edges(start, &adj, &mut visited, &mut in_stack, &mut back_edges);
        }
    }

    graph.reversed_edges = back_edges;
}

fn dfs_find_back_edges(
    node: usize,
    adj: &[Vec<(usize, usize)>],
    visited: &mut [bool],
    in_stack: &mut [bool],
    back_edges: &mut HashSet<usize>,
) {
    visited[node] = true;
    in_stack[node] = true;

    for &(edge_idx, target) in &adj[node] {
        if !visited[target] {
            dfs_find_back_edges(target, adj, visited, in_stack, back_edges);
        } else if in_stack[target] {
            back_edges.insert(edge_idx);
        }
    }

    in_stack[node] = false;
}
```

**Dependencies:**
- `graph.rs`

**Note:** Earlier versions of this design used petgraph's `greedy_feedback_arc_set`, but DFS-based detection better matches Dagre's default behavior (which Mermaid.js uses).

### 2.5 `rank.rs` - Layer Assignment

```rust
//! Phase 2: Assign nodes to ranks (layers).
//!
//! Uses a simplified longest-path algorithm. For optimal results,
//! network simplex would be used (Dagre's approach).

use std::collections::VecDeque;
use crate::graph::LayoutGraph;

/// Assign ranks to nodes using longest-path algorithm.
pub fn run(graph: &mut LayoutGraph) {
    let n = graph.node_ids.len();

    // Apply edge reversals temporarily
    let edges: Vec<_> = graph.edges.iter().map(|&(from, to, _)| {
        if graph.reversed_edges.contains(&graph.edges.iter().position(|e| e == &(from, to, 0)).unwrap_or(0)) {
            (to, from)
        } else {
            (from, to)
        }
    }).collect();

    // Build adjacency and compute in-degrees
    let mut in_degree = vec![0usize; n];
    let mut successors: Vec<Vec<usize>> = vec![Vec::new(); n];

    for &(from, to) in &edges {
        successors[from].push(to);
        in_degree[to] += 1;
    }

    // Kahn's algorithm with rank tracking
    let mut queue: VecDeque<usize> = VecDeque::new();
    let mut ranks = vec![0i32; n];

    // Start with nodes that have no predecessors
    for node in 0..n {
        if in_degree[node] == 0 {
            queue.push_back(node);
            ranks[node] = 0;
        }
    }

    while let Some(node) = queue.pop_front() {
        for &succ in &successors[node] {
            // Each successor is at least one rank below
            ranks[succ] = ranks[succ].max(ranks[node] + 1);

            in_degree[succ] -= 1;
            if in_degree[succ] == 0 {
                queue.push_back(succ);
            }
        }
    }

    graph.ranks = ranks;
}

/// Normalize ranks so minimum is 0.
pub fn normalize(graph: &mut LayoutGraph) {
    if let Some(min) = graph.ranks.iter().min() {
        let min = *min;
        for rank in &mut graph.ranks {
            *rank -= min;
        }
    }
}

/// Get nodes grouped by rank.
pub fn by_rank(graph: &LayoutGraph) -> Vec<Vec<usize>> {
    let max_rank = graph.ranks.iter().max().copied().unwrap_or(0) as usize;
    let mut layers: Vec<Vec<usize>> = vec![Vec::new(); max_rank + 1];

    for (node, &rank) in graph.ranks.iter().enumerate() {
        layers[rank as usize].push(node);
    }

    layers
}
```

**Dependencies:**
- `graph.rs`

### 2.6 `order.rs` - Crossing Reduction

```rust
//! Phase 3: Reduce edge crossings by reordering nodes within ranks.
//!
//! Implements the barycenter heuristic with iterative sweeping.

use crate::graph::LayoutGraph;
use crate::rank;

const MAX_ITERATIONS: usize = 24;

/// Run crossing reduction using barycenter heuristic.
pub fn run(graph: &mut LayoutGraph) {
    let layers = rank::by_rank(graph);
    if layers.len() < 2 {
        return;
    }

    // Initialize order based on current layer positions
    for (pos, layer) in layers.iter().enumerate() {
        for (idx, &node) in layer.iter().enumerate() {
            graph.order[node] = idx;
        }
    }

    // Sweep up and down to minimize crossings
    for iter in 0..MAX_ITERATIONS {
        let down_crossings = sweep_down(graph, &layers);
        let up_crossings = sweep_up(graph, &layers);

        // Stop if no improvement
        if down_crossings == 0 && up_crossings == 0 {
            break;
        }
    }
}

fn sweep_down(graph: &mut LayoutGraph, layers: &[Vec<usize>]) -> usize {
    let mut total_crossings = 0;

    for i in 1..layers.len() {
        let fixed = &layers[i - 1];
        let free = &layers[i];

        total_crossings += reorder_layer(graph, fixed, free, true);
    }

    total_crossings
}

fn sweep_up(graph: &mut LayoutGraph, layers: &[Vec<usize>]) -> usize {
    let mut total_crossings = 0;

    for i in (0..layers.len() - 1).rev() {
        let fixed = &layers[i + 1];
        let free = &layers[i];

        total_crossings += reorder_layer(graph, fixed, free, false);
    }

    total_crossings
}

/// Reorder nodes in `free` layer based on barycenter of connections to `fixed` layer.
fn reorder_layer(
    graph: &mut LayoutGraph,
    fixed: &[usize],
    free: &[usize],
    downward: bool,
) -> usize {
    // Build edge lookup
    let edges: Vec<(usize, usize)> = graph.edges
        .iter()
        .map(|&(from, to, _)| (from, to))
        .collect();

    // Calculate barycenter for each node in free layer
    let mut barycenters: Vec<(usize, f64)> = Vec::new();

    for &node in free {
        let neighbors: Vec<usize> = if downward {
            // Looking at predecessors (nodes in fixed layer that point to this node)
            edges.iter()
                .filter(|&&(_, to)| to == node)
                .map(|&(from, _)| from)
                .filter(|n| fixed.contains(n))
                .collect()
        } else {
            // Looking at successors (nodes in fixed layer that this node points to)
            edges.iter()
                .filter(|&&(from, _)| from == node)
                .map(|&(_, to)| to)
                .filter(|n| fixed.contains(n))
                .collect()
        };

        if neighbors.is_empty() {
            // Keep current position
            barycenters.push((node, graph.order[node] as f64));
        } else {
            // Average position of neighbors
            let sum: f64 = neighbors.iter()
                .map(|&n| graph.order[n] as f64)
                .sum();
            barycenters.push((node, sum / neighbors.len() as f64));
        }
    }

    // Sort by barycenter
    barycenters.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());

    // Update order
    for (new_pos, (node, _)) in barycenters.iter().enumerate() {
        graph.order[*node] = new_pos;
    }

    // Count crossings (simplified)
    count_crossings(graph, fixed, free, downward)
}

fn count_crossings(
    graph: &LayoutGraph,
    layer1: &[usize],
    layer2: &[usize],
    _downward: bool,
) -> usize {
    // Simplified crossing count
    let mut crossings = 0;

    let edges: Vec<(usize, usize)> = graph.edges
        .iter()
        .filter(|&&(from, to, _)| {
            (layer1.contains(&from) && layer2.contains(&to)) ||
            (layer1.contains(&to) && layer2.contains(&from))
        })
        .map(|&(from, to, _)| (graph.order[from], graph.order[to]))
        .collect();

    for i in 0..edges.len() {
        for j in i + 1..edges.len() {
            let (u1, v1) = edges[i];
            let (u2, v2) = edges[j];

            // Edges cross if one goes up while the other goes down
            if (u1 < u2 && v1 > v2) || (u1 > u2 && v1 < v2) {
                crossings += 1;
            }
        }
    }

    crossings
}
```

**Dependencies:**
- `graph.rs`
- `rank.rs`

### 2.7 `position.rs` - Coordinate Assignment

```rust
//! Phase 4: Assign x, y coordinates to nodes.
//!
//! Implements a simplified Brandes-Kopf style algorithm.

use crate::graph::LayoutGraph;
use crate::types::{Direction, LayoutConfig, Point};
use crate::rank;

/// Assign positions to all nodes.
pub fn run(graph: &mut LayoutGraph, config: &LayoutConfig) {
    let layers = rank::by_rank(graph);

    // Sort each layer by the computed order
    let sorted_layers: Vec<Vec<usize>> = layers
        .iter()
        .map(|layer| {
            let mut sorted = layer.clone();
            sorted.sort_by_key(|&n| graph.order[n]);
            sorted
        })
        .collect();

    // Assign coordinates based on direction
    match config.direction {
        Direction::TopBottom | Direction::BottomTop => {
            assign_vertical(graph, &sorted_layers, config);
        }
        Direction::LeftRight | Direction::RightLeft => {
            assign_horizontal(graph, &sorted_layers, config);
        }
    }

    // Reverse coordinates if needed
    if config.direction.is_reversed() {
        reverse_positions(graph, config);
    }
}

fn assign_vertical(
    graph: &mut LayoutGraph,
    layers: &[Vec<usize>],
    config: &LayoutConfig,
) {
    // Calculate max width per layer for centering
    let layer_widths: Vec<f64> = layers
        .iter()
        .map(|layer| {
            let content: f64 = layer.iter()
                .map(|&n| graph.dimensions[n].0)
                .sum();
            let spacing = if layer.len() > 1 {
                (layer.len() - 1) as f64 * config.node_sep
            } else {
                0.0
            };
            content + spacing
        })
        .collect();

    let max_width = layer_widths.iter().cloned().fold(0.0, f64::max);

    // Assign Y based on rank, X based on order within layer
    let mut y = config.margin;

    for (rank, layer) in layers.iter().enumerate() {
        let layer_width = layer_widths[rank];
        let start_x = config.margin + (max_width - layer_width) / 2.0;

        let mut x = start_x;
        for &node in layer {
            let (w, h) = graph.dimensions[node];
            graph.positions[node] = Point { x, y };
            x += w + config.node_sep;
        }

        // Y advances by max height in this layer
        let max_height = layer.iter()
            .map(|&n| graph.dimensions[n].1)
            .fold(0.0, f64::max);
        y += max_height + config.rank_sep;
    }
}

fn assign_horizontal(
    graph: &mut LayoutGraph,
    layers: &[Vec<usize>],
    config: &LayoutConfig,
) {
    // Calculate max height per layer for centering
    let layer_heights: Vec<f64> = layers
        .iter()
        .map(|layer| {
            let content: f64 = layer.iter()
                .map(|&n| graph.dimensions[n].1)
                .sum();
            let spacing = if layer.len() > 1 {
                (layer.len() - 1) as f64 * config.node_sep
            } else {
                0.0
            };
            content + spacing
        })
        .collect();

    let max_height = layer_heights.iter().cloned().fold(0.0, f64::max);

    // Assign X based on rank, Y based on order within layer
    let mut x = config.margin;

    for (rank, layer) in layers.iter().enumerate() {
        let layer_height = layer_heights[rank];
        let start_y = config.margin + (max_height - layer_height) / 2.0;

        let mut y = start_y;
        for &node in layer {
            let (w, h) = graph.dimensions[node];
            graph.positions[node] = Point { x, y };
            y += h + config.node_sep;
        }

        // X advances by max width in this layer
        let max_width = layer.iter()
            .map(|&n| graph.dimensions[n].0)
            .fold(0.0, f64::max);
        x += max_width + config.rank_sep;
    }
}

fn reverse_positions(graph: &mut LayoutGraph, config: &LayoutConfig) {
    // Find bounds
    let max_x = graph.positions.iter()
        .zip(graph.dimensions.iter())
        .map(|(p, (w, _))| p.x + w)
        .fold(0.0, f64::max);
    let max_y = graph.positions.iter()
        .zip(graph.dimensions.iter())
        .map(|(p, (_, h))| p.y + h)
        .fold(0.0, f64::max);

    // Flip coordinates
    match config.direction {
        Direction::BottomTop => {
            for (pos, (_, h)) in graph.positions.iter_mut().zip(graph.dimensions.iter()) {
                pos.y = max_y - pos.y - h;
            }
        }
        Direction::RightLeft => {
            for (pos, (w, _)) in graph.positions.iter_mut().zip(graph.dimensions.iter()) {
                pos.x = max_x - pos.x - w;
            }
        }
        _ => {}
    }
}

/// Calculate the total layout dimensions.
pub fn calculate_dimensions(graph: &LayoutGraph, config: &LayoutConfig) -> (f64, f64) {
    let max_x = graph.positions.iter()
        .zip(graph.dimensions.iter())
        .map(|(p, (w, _))| p.x + w)
        .fold(0.0, f64::max);
    let max_y = graph.positions.iter()
        .zip(graph.dimensions.iter())
        .map(|(p, (_, h))| p.y + h)
        .fold(0.0, f64::max);

    (max_x + config.margin, max_y + config.margin)
}
```

**Dependencies:**
- `graph.rs`
- `types.rs`
- `rank.rs`

### 2.8 `graph.rs` - petgraph Integration

The `LayoutGraph` needs a method to convert to petgraph for cycle removal:

```rust
impl LayoutGraph {
    /// Convert to petgraph StableDiGraph for algorithm use.
    pub fn to_petgraph(&self) -> StableDiGraph<usize, usize> {
        let mut pg = StableDiGraph::new();

        // Add nodes (using index as weight)
        let node_indices: Vec<_> = (0..self.node_ids.len())
            .map(|i| pg.add_node(i))
            .collect();

        // Add edges (using edge index as weight)
        for (edge_idx, &(from, to, _)) in self.edges.iter().enumerate() {
            pg.add_edge(node_indices[from], node_indices[to], edge_idx);
        }

        pg
    }
}
```

### 2.9 `util.rs` - Helper Functions

```rust
//! Utility functions for the layout algorithm.

use crate::graph::LayoutGraph;
use crate::types::{EdgeLayout, Point};

/// Create edge layouts from the positioned graph.
pub fn create_edge_layouts(graph: &LayoutGraph) -> Vec<EdgeLayout> {
    graph.edges
        .iter()
        .map(|&(from, to, orig_idx)| {
            let from_pos = graph.positions[from];
            let to_pos = graph.positions[to];
            let from_dim = graph.dimensions[from];
            let to_dim = graph.dimensions[to];

            // Simple direct path (center to center)
            let from_center = Point {
                x: from_pos.x + from_dim.0 / 2.0,
                y: from_pos.y + from_dim.1 / 2.0,
            };
            let to_center = Point {
                x: to_pos.x + to_dim.0 / 2.0,
                y: to_pos.y + to_dim.1 / 2.0,
            };

            EdgeLayout {
                from: graph.node_ids[from].clone(),
                to: graph.node_ids[to].clone(),
                points: vec![from_center, to_center],
                index: orig_idx,
            }
        })
        .collect()
}
```

**Dependencies:**
- `graph.rs`
- `types.rs`

---

## 3. API Design

### Input: How the User Provides a Graph

```rust
use dagre::{DiGraph, layout, LayoutConfig, NodeMetrics};

// Option 1: Direct construction
let mut graph: DiGraph<MyNodeData> = DiGraph::new();
graph.add_node("A", MyNodeData { width: 100.0, height: 50.0 });
graph.add_node("B", MyNodeData { width: 100.0, height: 50.0 });
graph.add_edge("A", "B");

// Option 2: From petgraph (with feature flag)
let graph = DiGraph::from_petgraph(&pg);

// Provide dimensions via trait
impl NodeMetrics for MyNodeData {
    fn dimensions(&self, _: &NodeId) -> (f64, f64) {
        (self.width, self.height)
    }
}
```

### Output: Layout Result

```rust
let config = LayoutConfig::default();
let result = layout(&graph, &config);

// Access node positions
for (node_id, rect) in &result.nodes {
    println!("{}: ({}, {}) {}x{}",
        node_id.0, rect.x, rect.y, rect.width, rect.height);
}

// Access edge paths
for edge in &result.edges {
    println!("{} -> {}: {:?}", edge.from.0, edge.to.0, edge.points);
}

// Total dimensions
println!("Layout: {}x{}", result.width, result.height);
```

### Configuration Options

```rust
let config = LayoutConfig {
    direction: Direction::LeftRight,
    node_sep: 30.0,    // Gap between nodes in same rank
    rank_sep: 60.0,    // Gap between ranks
    edge_sep: 10.0,    // Gap between parallel edges
    margin: 20.0,      // Padding around diagram
    align: Some("UL".to_string()), // Alignment mode
    acyclic: true,     // Enable cycle removal
};
```

---

## 4. Shared Types Strategy

### Types to Share Between dagre and mmdflux

| Type        | Location       | Rationale                    |
| ----------- | -------------- | ---------------------------- |
| `Direction` | `dagre::types` | Core to layout, used by both |
| `Point`     | `dagre::types` | Generic coordinate type      |
| `Rect`      | `dagre::types` | Generic bounding box         |
| `NodeId`    | `dagre::types` | Opaque identifier            |

### Types That Stay in mmdflux

| Type              | Location          | Rationale                        |
| ----------------- | ----------------- | -------------------------------- |
| `Shape`           | `mmdflux::graph`  | Rendering-specific               |
| `Stroke`, `Arrow` | `mmdflux::graph`  | Rendering-specific               |
| `NodeBounds`      | `mmdflux::render` | ASCII-specific attachment points |
| `CharSet`         | `mmdflux::render` | ASCII-specific                   |

### Adapter Pattern

mmdflux would create an adapter layer:

```rust
// In mmdflux::render::layout.rs

use dagre::{DiGraph as DagreGraph, LayoutConfig as DagreConfig, NodeMetrics};

impl NodeMetrics for Node {
    fn dimensions(&self, _: &dagre::NodeId) -> (f64, f64) {
        let (w, h) = shape::node_dimensions(self);
        (w as f64, h as f64)
    }
}

pub fn compute_layout(diagram: &Diagram, config: &LayoutConfig) -> Layout {
    // Convert mmdflux Diagram to dagre DiGraph
    let mut dgraph = DagreGraph::new();
    for (id, node) in &diagram.nodes {
        dgraph.add_node(id.as_str(), node.clone());
    }
    for edge in &diagram.edges {
        dgraph.add_edge(&edge.from, &edge.to);
    }

    // Convert config
    let dconfig = DagreConfig {
        direction: convert_direction(diagram.direction),
        node_sep: config.h_spacing as f64,
        rank_sep: config.v_spacing as f64,
        ..Default::default()
    };

    // Run layout
    let result = dagre::layout(&dgraph, &dconfig);

    // Convert result back to mmdflux Layout
    convert_result(result, config)
}
```

---

## 5. Dependency Strategy

### External Crates

| Crate | Purpose | Required? | WASM-Friendly? |
| ----- | ------- | --------- | -------------- |
| None  | -       | -         | Yes            |

The module should have **zero required dependencies** for maximum portability.

### Optional Features

```toml
[features]
default = []
petgraph = ["dep:petgraph"]  # Integration with petgraph
serde = ["dep:serde"]        # Serialization

[dependencies]
petgraph = { version = "0.6", optional = true }
serde = { version = "1.0", optional = true, features = ["derive"] }
```

### WASM Compatibility

To keep the module WASM-friendly:

1. **No file I/O** - all input/output via function parameters
2. **No threads** - single-threaded algorithm
3. **No system dependencies** - pure Rust
4. **Use f64** - instead of usize for coordinates (JavaScript interop)
5. **Avoid large allocations** - stream-friendly where possible

### Feature Flags for mmdflux Integration

```toml
[dependencies]
dagre = { path = "../dagre", features = [] }
```

---

## 6. Migration Path

### Step 1: Create the dagre Module (In-Tree)

First, create the module within mmdflux:

```
src/
├── dagre/           # NEW
│   ├── mod.rs
│   ├── types.rs
│   ├── graph.rs
│   ├── acyclic.rs
│   ├── rank.rs
│   ├── order.rs
│   ├── position.rs
│   └── util.rs
├── graph/
├── parser/
└── render/
```

### Step 2: Implement Core Algorithm

Port functionality from `render/layout.rs`:

1. **`topological_layers()`** -> `rank.rs`
2. **`compute_grid_positions()`** -> `rank.rs` + `order.rs`
3. **`grid_to_draw_*()`** -> `position.rs`
4. **`assign_backward_edge_lanes()`** -> `acyclic.rs`

### Step 3: Create Adapter Layer

Modify `render/layout.rs` to use the new dagre module:

```rust
// Before:
pub fn compute_layout(diagram: &Diagram, config: &LayoutConfig) -> Layout {
    let layers = topological_layers(diagram);
    // ... lots of code ...
}

// After:
pub fn compute_layout(diagram: &Diagram, config: &LayoutConfig) -> Layout {
    // Use dagre for core layout
    let dgraph = diagram_to_dagre(diagram);
    let result = crate::dagre::layout(&dgraph, &to_dagre_config(config));

    // Post-process for ASCII specifics
    dagre_to_layout(result, diagram, config)
}
```

### Step 4: Add Missing Features

Enhance the dagre module with full Sugiyama features:

- [ ] Network simplex ranking (currently longest-path)
- [ ] Proper crossing minimization (currently barycenter only)
- [ ] Brandes-Kopf coordinate assignment
- [ ] Edge routing with bend points
- [ ] Subgraph/cluster support

### Step 5: Extract as Separate Crate

Once stable:

```bash
# Create new crate
cargo new --lib dagre-layout
cp -r src/dagre/* ../dagre-layout/src/

# Update mmdflux Cargo.toml
# dagre = { path = "../dagre-layout" }
```

### Changes to Existing Code

| File                   | Changes                                 |
| ---------------------- | --------------------------------------- |
| `src/lib.rs`           | Add `pub mod dagre;`                    |
| `src/render/layout.rs` | Replace implementation with dagre calls |
| `src/render/router.rs` | Minor updates to use dagre types        |
| `src/graph/diagram.rs` | Keep as-is (mmdflux-specific)           |
| `Cargo.toml`           | None initially (in-tree module)         |

### Testing Strategy

1. Keep existing integration tests working throughout migration
2. Add unit tests for each dagre module
3. Create snapshot tests comparing old vs new layout output
4. Ensure deterministic output for CI stability

---

## Summary

The proposed dagre module provides:

1. **Clean separation** - Generic layout logic vs mmdflux-specific rendering
2. **Standard API** - `DiGraph` + `LayoutConfig` -> `LayoutResult`
3. **Zero dependencies** - Pure Rust, WASM-compatible
4. **Gradual migration** - Start in-tree, extract later
5. **Full Sugiyama** - Cycle removal, ranking, ordering, positioning

The module can be developed incrementally while keeping mmdflux working at every step.
