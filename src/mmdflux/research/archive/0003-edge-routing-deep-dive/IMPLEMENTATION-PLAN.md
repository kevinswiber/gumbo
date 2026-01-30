# Implementation Plan: Edge Routing Architecture

## Overview

This plan implements three missing dagre mechanisms to fix edge routing issues:
1. **Dummy nodes for long edges** (normalize/denormalize)
2. **Edge labels as layout entities** (label dummies)
3. **Dynamic intersection calculation** (intersectRect)

**Estimated scope:** ~800-1000 lines of new/modified code across 4 phases.

---

## Phase 1: Infrastructure (Low Risk)

Add data structures without changing behavior.

### 1.1 Add DummyNode type to dagre module

**File:** `src/dagre/normalize.rs` (new file)

```rust
//! Edge normalization: Split long edges with dummy nodes.

/// Dummy node type identifier
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DummyType {
    /// Regular edge-routing dummy (zero size)
    Edge,
    /// Edge label dummy (has label dimensions)
    EdgeLabel,
}

/// A dummy node inserted for a long edge
#[derive(Debug, Clone)]
pub struct DummyNode {
    /// Original edge index this dummy belongs to
    pub edge_index: usize,
    /// Type of dummy
    pub dummy_type: DummyType,
    /// Position in the chain (0 = first dummy after source)
    pub chain_position: usize,
    /// Total dummies in this edge's chain
    pub chain_length: usize,
    /// Label position option (only for EdgeLabel type)
    pub label_pos: Option<LabelPos>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LabelPos {
    Left,
    Right,
    Center,
}
```

### 1.2 Extend LayoutGraph with dummy tracking

**File:** `src/dagre/graph.rs`

Add fields:
```rust
pub struct LayoutGraph {
    // ... existing fields ...

    /// Dummy node data (indexed by node index for dummy nodes)
    pub dummy_nodes: HashMap<usize, DummyNode>,

    /// First dummy index for each original edge (for chain traversal)
    pub dummy_chains: Vec<usize>,

    /// Original edge count before normalization
    pub original_edge_count: usize,
}
```

Add method:
```rust
impl LayoutGraph {
    pub fn add_dummy_node(
        &mut self,
        dummy: DummyNode,
        rank: i32,
        width: f64,
        height: f64,
    ) -> usize {
        // Create synthetic node ID
        // Add to node_ids, dimensions, ranks
        // Store in dummy_nodes map
        // Return index
    }

    pub fn is_dummy(&self, idx: usize) -> bool {
        self.dummy_nodes.contains_key(&idx)
    }
}
```

### 1.3 Add edge waypoints to Layout struct

**File:** `src/render/layout.rs`

Add field:
```rust
pub struct Layout {
    // ... existing fields ...

    /// Edge waypoints from dummy node positions
    /// Key: (from_id, to_id), Value: waypoint coordinates
    pub edge_waypoints: HashMap<(String, String), Vec<Point>>,

    /// Label positions from label dummies
    pub edge_labels: HashMap<(String, String), LabelPosition>,
}

pub struct LabelPosition {
    pub x: i32,
    pub y: i32,
    pub width: i32,
    pub height: i32,
}
```

### 1.4 Tests for Phase 1

```rust
#[test]
fn test_dummy_node_creation() {
    let mut graph = LayoutGraph::new();
    // Add some real nodes
    // Add dummy node
    // Verify dummy_nodes map populated
    // Verify is_dummy() returns correct values
}
```

---

## Phase 2: Normalization (Medium Risk)

Implement edge normalization that inserts dummy nodes.

### 2.1 Implement normalize::run()

**File:** `src/dagre/normalize.rs`

```rust
/// Run edge normalization.
/// After this, all edges span exactly 1 rank.
pub fn run(graph: &mut LayoutGraph) {
    graph.original_edge_count = graph.edges.len();
    graph.dummy_chains.clear();

    let edges: Vec<_> = graph.edges.clone();
    graph.edges.clear();

    for (orig_idx, (from, to)) in edges.iter().enumerate() {
        normalize_edge(graph, orig_idx, *from, *to);
    }
}

fn normalize_edge(graph: &mut LayoutGraph, orig_idx: usize, from: usize, to: usize) {
    let from_rank = graph.ranks[from];
    let to_rank = graph.ranks[to];
    let span = (to_rank - from_rank).abs();

    // Short edge: keep as-is
    if span <= 1 {
        graph.edges.push((from, to));
        return;
    }

    // Long edge: insert dummy chain
    let chain_length = (span - 1) as usize;
    let direction = if to_rank > from_rank { 1 } else { -1 };
    let label_rank = calculate_label_rank(from_rank, to_rank);

    let mut prev_node = from;
    for i in 0..chain_length {
        let dummy_rank = from_rank + (i as i32 + 1) * direction;
        let is_label_rank = dummy_rank == label_rank;

        // Determine width/height (0 for regular, label size for label dummy)
        let (width, height) = if is_label_rank {
            get_edge_label_dimensions(graph, orig_idx)
        } else {
            (0.0, 0.0)
        };

        let dummy = DummyNode {
            edge_index: orig_idx,
            dummy_type: if is_label_rank { DummyType::EdgeLabel } else { DummyType::Edge },
            chain_position: i,
            chain_length,
            label_pos: if is_label_rank { get_label_pos(graph, orig_idx) } else { None },
        };

        let dummy_idx = graph.add_dummy_node(dummy, dummy_rank, width, height);

        // Track first dummy in chain
        if i == 0 {
            graph.dummy_chains.push(dummy_idx);
        }

        // Connect prev → dummy
        graph.edges.push((prev_node, dummy_idx));
        prev_node = dummy_idx;
    }

    // Connect last dummy → target
    graph.edges.push((prev_node, to));
}

fn calculate_label_rank(from_rank: i32, to_rank: i32) -> i32 {
    (from_rank + to_rank) / 2
}
```

### 2.2 Implement denormalize()

**File:** `src/dagre/normalize.rs`

```rust
/// Denormalize: Convert dummy positions to edge waypoints.
/// Called after coordinate assignment.
pub fn denormalize(graph: &LayoutGraph) -> DenormalizeResult {
    let mut edge_waypoints: HashMap<usize, Vec<Point>> = HashMap::new();
    let mut label_positions: HashMap<usize, LabelPosition> = HashMap::new();

    for &first_dummy_idx in &graph.dummy_chains {
        let first_dummy = &graph.dummy_nodes[&first_dummy_idx];
        let edge_idx = first_dummy.edge_index;

        let mut waypoints = Vec::new();
        let mut current_idx = first_dummy_idx;

        // Walk the chain via edges
        while let Some(dummy) = graph.dummy_nodes.get(&current_idx) {
            let pos = graph.positions[current_idx];
            waypoints.push(pos);

            // Check for label dummy
            if dummy.dummy_type == DummyType::EdgeLabel {
                label_positions.insert(edge_idx, LabelPosition {
                    x: pos.x as i32,
                    y: pos.y as i32,
                    width: graph.dimensions[current_idx].0 as i32,
                    height: graph.dimensions[current_idx].1 as i32,
                });
            }

            // Find successor (next in chain)
            current_idx = find_successor(graph, current_idx)?;
        }

        edge_waypoints.insert(edge_idx, waypoints);
    }

    DenormalizeResult { edge_waypoints, label_positions }
}
```

### 2.3 Integrate into layout pipeline

**File:** `src/dagre/mod.rs`

```rust
pub fn layout(...) -> LayoutResult {
    // ... existing setup ...

    // Phase 1: Make acyclic
    acyclic::run(&mut lg);

    // Phase 2: Rank assignment
    rank::run(&mut lg);
    rank::normalize(&mut lg);

    // Phase 2.5: NORMALIZE EDGES (NEW)
    normalize::run(&mut lg);

    // Phase 3: Crossing reduction (now includes dummies)
    order::run(&mut lg);

    // Phase 4: Coordinate assignment (dummies get positions)
    position::run(&mut lg, config);

    // Phase 4.5: DENORMALIZE (NEW)
    let denorm = normalize::denormalize(&lg);

    // Build result with waypoints
    LayoutResult {
        // ... existing fields ...
        edge_waypoints: denorm.edge_waypoints,
        label_positions: denorm.label_positions,
    }
}
```

### 2.4 Tests for Phase 2

```rust
#[test]
fn test_normalize_long_edge() {
    // Edge from rank 0 to rank 3 → 2 dummies at ranks 1 and 2
    let mut graph = create_graph_with_long_edge();
    normalize::run(&mut graph);

    assert_eq!(graph.dummy_chains.len(), 1);
    assert_eq!(count_dummies(&graph), 2);
    // Verify all edges span exactly 1 rank
}

#[test]
fn test_normalize_preserves_short_edges() {
    // Edge spanning 1 rank should not create dummies
    let mut graph = create_graph_with_short_edges();
    normalize::run(&mut graph);

    assert!(graph.dummy_chains.is_empty());
}

#[test]
fn test_denormalize_produces_waypoints() {
    // After position assignment, waypoints match dummy positions
    let mut graph = create_graph_with_long_edge();
    normalize::run(&mut graph);
    order::run(&mut graph);
    position::run(&mut graph, &config);

    let result = normalize::denormalize(&graph);
    assert!(!result.edge_waypoints.is_empty());
}

#[test]
fn test_label_dummy_has_dimensions() {
    // Edge label dummy should have non-zero dimensions
    let mut graph = create_graph_with_labeled_edge();
    normalize::run(&mut graph);

    let label_dummy = find_label_dummy(&graph);
    assert!(graph.dimensions[label_dummy].0 > 0.0);
}
```

---

## Phase 3: Intersection Calculation (Medium Risk)

Implement dynamic edge attachment points.

### 3.1 Add intersect module

**File:** `src/render/intersect.rs` (new file)

```rust
//! Dynamic intersection calculation for edge attachment points.

use crate::graph::Shape;

/// Calculate where a line from `point` to rectangle center crosses the boundary.
pub fn intersect_rect(rect: &Rect, point: Point) -> Point {
    let x = rect.center_x() as f64;
    let y = rect.center_y() as f64;
    let dx = point.x as f64 - x;
    let dy = point.y as f64 - y;
    let w = rect.width as f64 / 2.0;
    let h = rect.height as f64 / 2.0;

    if dx == 0.0 && dy == 0.0 {
        // Point is at center; fall back to bottom
        return Point { x: rect.center_x(), y: rect.bottom() };
    }

    let (sx, sy) = if dy.abs() * w > dx.abs() * h {
        // Top or bottom edge
        let h = if dy < 0.0 { -h } else { h };
        (h * dx / dy, h)
    } else {
        // Left or right edge
        let w = if dx < 0.0 { -w } else { w };
        (w, w * dy / dx)
    };

    Point {
        x: (x + sx).round() as i32,
        y: (y + sy).round() as i32,
    }
}

/// Calculate intersection for diamond shape.
pub fn intersect_diamond(rect: &Rect, point: Point) -> Point {
    let x = rect.center_x() as f64;
    let y = rect.center_y() as f64;
    let dx = point.x as f64 - x;
    let dy = point.y as f64 - y;
    let w = rect.width as f64 / 2.0;
    let h = rect.height as f64 / 2.0;

    if dx == 0.0 && dy == 0.0 {
        return Point { x: rect.center_x(), y: rect.bottom() };
    }

    // Diamond: |dx|/w + |dy|/h = 1 on boundary
    let t = 1.0 / (dx.abs() / w + dy.abs() / h);

    Point {
        x: (x + t * dx).round() as i32,
        y: (y + t * dy).round() as i32,
    }
}

/// Shape-aware intersection dispatch.
pub fn intersect_node(node: &NodeRect, point: Point, shape: Shape) -> Point {
    let rect = node.to_rect();
    match shape {
        Shape::Rectangle | Shape::Round => intersect_rect(&rect, point),
        Shape::Diamond => intersect_diamond(&rect, point),
    }
}
```

### 3.2 Integrate with router

**File:** `src/render/router.rs`

Modify `route_edge()` to use intersection calculation:

```rust
pub fn route_edge(edge: &Edge, layout: &Layout, ...) -> Option<RoutedEdge> {
    let source = layout.get_node(&edge.from)?;
    let target = layout.get_node(&edge.to)?;

    // Get waypoints from layout (from dummy positions)
    let waypoints = layout.edge_waypoints
        .get(&(edge.from.clone(), edge.to.clone()))
        .cloned()
        .unwrap_or_default();

    // Calculate attachment points using intersection
    let first_wp = waypoints.first().copied().unwrap_or(target.center());
    let last_wp = waypoints.last().copied().unwrap_or(source.center());

    let source_attach = intersect::intersect_node(&source, first_wp, source.shape);
    let target_attach = intersect::intersect_node(&target, last_wp, target.shape);

    // Build orthogonal path
    let path = build_orthogonal_path(source_attach, &waypoints, target_attach);

    // Determine arrow direction from final segment
    let arrow_direction = path.last_direction();

    Some(RoutedEdge {
        edge: edge.clone(),
        segments: path.segments,
        arrow_direction,
        // ...
    })
}
```

### 3.3 Orthogonal path conversion

**File:** `src/render/router.rs`

```rust
fn build_orthogonal_path(
    start: Point,
    waypoints: &[Point],
    end: Point,
) -> Path {
    let mut segments = Vec::new();
    let mut current = start;

    for &wp in waypoints {
        segments.extend(orthogonalize(current, wp));
        current = wp;
    }

    segments.extend(orthogonalize(current, end));

    Path { segments }
}

fn orthogonalize(from: Point, to: Point) -> Vec<Segment> {
    if from.x == to.x {
        // Vertical
        vec![Segment::Vertical { x: from.x, y1: from.y, y2: to.y }]
    } else if from.y == to.y {
        // Horizontal
        vec![Segment::Horizontal { y: from.y, x1: from.x, x2: to.x }]
    } else {
        // Diagonal → Z-path
        let mid_y = (from.y + to.y) / 2;
        vec![
            Segment::Vertical { x: from.x, y1: from.y, y2: mid_y },
            Segment::Horizontal { y: mid_y, x1: from.x, x2: to.x },
            Segment::Vertical { x: to.x, y1: mid_y, y2: to.y },
        ]
    }
}
```

### 3.4 Tests for Phase 3

```rust
#[test]
fn test_intersect_rect_top() {
    let rect = Rect { x: 10, y: 10, width: 8, height: 4 };
    let point = Point { x: 14, y: 0 }; // Above center
    let result = intersect_rect(&rect, point);
    assert_eq!(result.y, 10); // Top edge
}

#[test]
fn test_intersect_rect_right() {
    let rect = Rect { x: 10, y: 10, width: 8, height: 4 };
    let point = Point { x: 30, y: 12 }; // Right of center
    let result = intersect_rect(&rect, point);
    assert_eq!(result.x, 18); // Right edge
}

#[test]
fn test_intersect_diamond() {
    let rect = Rect { x: 10, y: 10, width: 10, height: 6 };
    let point = Point { x: 20, y: 13 }; // Right side
    let result = intersect_diamond(&rect, point);
    // Should be on diamond boundary
}

#[test]
fn test_orthogonalize_diagonal() {
    let from = Point { x: 0, y: 0 };
    let to = Point { x: 10, y: 10 };
    let segments = orthogonalize(from, to);
    assert_eq!(segments.len(), 3); // V-H-V or H-V-H
}
```

---

## Phase 4: Integration & Testing (Higher Risk)

Wire everything together and verify with real diagrams.

### 4.1 Update compute_layout_dagre()

**File:** `src/render/layout.rs`

```rust
pub fn compute_layout_dagre(diagram: &Diagram, config: &LayoutConfig) -> Layout {
    // ... existing setup ...

    // Pre-calculate label dimensions for edges
    let edge_labels = calculate_edge_label_dimensions(diagram);

    let result = dagre::layout(&dgraph, &dagre_config, &edge_labels, ...);

    // Convert waypoints to Layout format
    let edge_waypoints = convert_waypoints(&result.edge_waypoints, &id_map);
    let label_positions = convert_labels(&result.label_positions, &id_map);

    Layout {
        // ... existing fields ...
        edge_waypoints,
        label_positions,
    }
}

fn calculate_edge_label_dimensions(diagram: &Diagram) -> HashMap<EdgeId, (f64, f64)> {
    diagram.edges.iter()
        .filter_map(|e| {
            e.label.as_ref().map(|label| {
                let width = label.len() as f64;
                let height = 1.0;
                ((e.from.clone(), e.to.clone()), (width, height))
            })
        })
        .collect()
}
```

### 4.2 Update edge rendering

**File:** `src/render/edge.rs`

Use pre-computed label positions:

```rust
pub fn render_edge(edge: &RoutedEdge, layout: &Layout, canvas: &mut Canvas) {
    // Render segments
    for segment in &edge.segments {
        render_segment(segment, canvas);
    }

    // Render label at pre-computed position
    if let Some(label_pos) = layout.label_positions.get(&edge.id()) {
        render_label(&edge.label, label_pos, canvas);
    }
}
```

### 4.3 Integration tests

```rust
#[test]
fn test_complex_mmd_no_edge_through_node() {
    let output = render_fixture("complex.mmd");

    // The "no" edge should not share cells with Cleanup node
    let cleanup_cells = find_node_cells(&output, "Cleanup");
    let no_edge_cells = find_edge_cells(&output, "no");

    assert!(cleanup_cells.is_disjoint(&no_edge_cells));
}

#[test]
fn test_overlapping_edges_separated() {
    let output = render_fixture("complex.mmd");

    // Forward edge to "More Data?" and backward edge from it
    // should use different attachment points
    let forward_attach = find_attachment(&output, "Process", "More Data?");
    let backward_attach = find_attachment(&output, "More Data?", "Input");

    assert_ne!(forward_attach, backward_attach);
}

#[test]
fn test_label_not_colliding() {
    let output = render_fixture("complex.mmd");

    // "yes" label should be on isolated segment
    let yes_pos = find_label_position(&output, "yes");
    let edge_chars_at_pos = count_edge_chars_near(&output, yes_pos);

    assert_eq!(edge_chars_at_pos, 1); // Only the edge it labels
}

#[test]
fn test_all_fixtures_render_without_panic() {
    for fixture in glob("tests/fixtures/*.mmd") {
        let result = std::panic::catch_unwind(|| render_fixture(&fixture));
        assert!(result.is_ok(), "Fixture {} panicked", fixture);
    }
}
```

### 4.4 Visual regression tests

Create expected output files for key fixtures and compare:

```rust
#[test]
fn test_complex_mmd_visual_regression() {
    let output = render_fixture("complex.mmd");
    let expected = include_str!("expected/complex.txt");

    // Allow some flexibility for minor changes
    assert_similar(&output, &expected, 0.95); // 95% similarity
}
```

---

## Phase 5: Cleanup (Low Risk)

Remove workarounds and simplify code.

### 5.1 Remove corridor-based backward edge routing

The corridor system in `route_backward_edge_vertical()` can be simplified now that dummy nodes provide waypoints.

### 5.2 Remove fixed center attachment points

The `shape.rs` functions like `top()`, `bottom()` that return fixed center points can be deprecated in favor of `intersect_node()`.

### 5.3 Simplify collision detection

With dummy nodes handling separation, post-hoc collision detection in the router becomes a safety net rather than primary mechanism.

---

## Risk Mitigation

### Feature Flag

Add a config option to enable/disable new edge routing:

```rust
pub struct LayoutConfig {
    // ... existing fields ...

    /// Use dummy node normalization for edge routing
    pub use_normalize: bool,  // default: true
}
```

This allows rolling back if issues are discovered.

### Incremental Rollout

1. Phase 1: Infrastructure only (no behavior change)
2. Phase 2: Normalization behind feature flag
3. Phase 3: Intersection calculation (can coexist with old routing)
4. Phase 4: Full integration with extensive testing
5. Phase 5: Cleanup after stabilization

---

## Success Criteria

The implementation is complete when:

1. [ ] All existing tests pass
2. [ ] `complex.mmd` renders without Issues 2, 3, 4
3. [ ] Edge labels are placed on isolated segments
4. [ ] Multiple edges to same node use different attachment points
5. [ ] No edges route through intermediate nodes
6. [ ] All fixtures in `tests/fixtures/` render correctly
7. [ ] No performance regression (render time within 2x of current)

---

## Files Changed Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `src/dagre/normalize.rs` | New | Dummy node normalization |
| `src/dagre/graph.rs` | Modified | Dummy node tracking |
| `src/dagre/mod.rs` | Modified | Pipeline integration |
| `src/dagre/types.rs` | Modified | Result types for waypoints |
| `src/render/intersect.rs` | New | Intersection calculation |
| `src/render/router.rs` | Modified | Waypoint-based routing |
| `src/render/layout.rs` | Modified | Waypoint/label storage |
| `src/render/edge.rs` | Modified | Label rendering |
| `tests/integration.rs` | Modified | New test cases |

---

## Ready for Implementation

This plan is ready for `/plan` approval. When approved:

1. Create implementation plan in `plans/` directory
2. Implement Phase 1 (infrastructure)
3. Implement Phase 2 (normalization) with tests
4. Implement Phase 3 (intersection) with tests
5. Implement Phase 4 (integration) with visual verification
6. Phase 5 (cleanup) after stabilization
