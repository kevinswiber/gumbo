# mmdflux Ordering Algorithm Analysis

This document provides a detailed analysis of the ordering algorithm implementation in mmdflux, documenting exactly how it works and identifying gaps compared to Dagre.

## Table of Contents

1. [What: Purpose and Behavior](#what-purpose-and-behavior)
2. [Where: Key Functions](#where-key-functions)
3. [How: Algorithm Steps](#how-algorithm-steps)
4. [Why: What's Missing Compared to Dagre](#why-whats-missing-compared-to-dagre)

---

## What: Purpose and Behavior

### Purpose

The ordering algorithm (`src/dagre/order.rs`) implements **Phase 3** of the Sugiyama framework: crossing reduction. Its goal is to minimize edge crossings by finding an optimal ordering of nodes within each layer (rank).

From the module documentation (lines 1-3):

```rust
//! Phase 3: Reduce edge crossings by reordering nodes within ranks.
//!
//! Implements the barycenter heuristic with iterative sweeping.
```

### Current Behavior

The algorithm:
1. Takes nodes already assigned to ranks (layers)
2. Iteratively reorders nodes within each layer using the barycenter heuristic
3. Sweeps down and up through the layers to propagate ordering improvements
4. Stops when no further crossing reduction is achieved

### Inputs

- **`LayoutGraph`**: A mutable graph with:
  - `node_ids`: Vector of node identifiers
  - `edges`: Vector of `(from_index, to_index, original_edge_index)` tuples
  - `reversed_edges`: Set of edge indices that were reversed during cycle removal
  - `ranks`: Vector mapping node index to rank (layer)
  - `order`: Vector mapping node index to position within its layer

### Outputs

- Modified `graph.order` vector where `graph.order[node_index]` gives the position of that node within its rank
- Lower values = further left in the layer

### Invariants

- All nodes in the same rank have distinct order values (0, 1, 2, ...)
- Order values are consecutive within each layer (no gaps)
- The algorithm preserves the original rank assignments

---

## Where: Key Functions

### `run()` - Main Entry Point

**Location:** Lines 11-44

**Signature:**
```rust
pub fn run(graph: &mut LayoutGraph)
```

**Purpose:** Main entry point that orchestrates the crossing reduction algorithm.

**Key Algorithm Steps:**

```rust
pub fn run(graph: &mut LayoutGraph) {
    let layers = rank::by_rank(graph);                    // Line 12: Get nodes grouped by rank
    if layers.len() < 2 {                                 // Line 13-16: Early exit if no crossings possible
        return;
    }

    // Initialize order based on current layer positions   // Lines 18-23
    for layer in &layers {
        for (idx, &node) in layer.iter().enumerate() {
            graph.order[node] = idx;
        }
    }

    let edges = graph.effective_edges();                  // Line 26: Get edges with reversals applied
    let mut best_crossings = count_all_crossings(...);    // Line 29: Initial crossing count

    for _ in 0..MAX_ITERATIONS {                          // Line 31: Up to 24 iterations
        let prev_crossings = best_crossings;

        sweep_down(graph, &layers, &edges);               // Line 34: Top-to-bottom sweep
        sweep_up(graph, &layers, &edges);                 // Line 35: Bottom-to-top sweep

        best_crossings = count_all_crossings(...);        // Line 37: Recount crossings

        if best_crossings >= prev_crossings {             // Lines 40-42: Stop if no improvement
            break;
        }
    }
}
```

**Termination Logic:**
- Maximum 24 iterations (`MAX_ITERATIONS = 24`, line 8)
- Exits early if a full down+up sweep produces no crossing reduction

---

### `sweep_down()` - Top-to-Bottom Sweep

**Location:** Lines 46-52

**Signature:**
```rust
fn sweep_down(graph: &mut LayoutGraph, layers: &[Vec<usize>], edges: &[(usize, usize)])
```

**Purpose:** Process layers from top to bottom, using the layer above as the "fixed" reference.

**Implementation:**
```rust
fn sweep_down(graph: &mut LayoutGraph, layers: &[Vec<usize>], edges: &[(usize, usize)]) {
    for i in 1..layers.len() {
        let fixed = &layers[i - 1];    // Upper layer is fixed
        let free = &layers[i];          // Current layer is free to reorder
        reorder_layer(graph, fixed, free, edges, true);  // downward=true
    }
}
```

**Key Characteristics:**
- Iterates from layer 1 (second from top) to the bottom
- The layer above is "fixed" (its order is used to compute barycenters)
- The current layer is "free" (its nodes are reordered)
- Passes `downward=true` to `reorder_layer()`

---

### `sweep_up()` - Bottom-to-Top Sweep

**Location:** Lines 54-60

**Signature:**
```rust
fn sweep_up(graph: &mut LayoutGraph, layers: &[Vec<usize>], edges: &[(usize, usize)])
```

**Purpose:** Process layers from bottom to top, using the layer below as the "fixed" reference.

**Implementation:**
```rust
fn sweep_up(graph: &mut LayoutGraph, layers: &[Vec<usize>], edges: &[(usize, usize)]) {
    for i in (0..layers.len() - 1).rev() {
        let fixed = &layers[i + 1];    // Lower layer is fixed
        let free = &layers[i];          // Current layer is free to reorder
        reorder_layer(graph, fixed, free, edges, false);  // downward=false
    }
}
```

**Key Characteristics:**
- Iterates from layer n-2 (second from bottom) to the top
- The layer below is "fixed"
- The current layer is "free"
- Passes `downward=false` to `reorder_layer()`

---

### `reorder_layer()` - Layer Reordering Logic

**Location:** Lines 62-115

**Signature:**
```rust
fn reorder_layer(
    graph: &mut LayoutGraph,
    fixed: &[usize],
    free: &[usize],
    edges: &[(usize, usize)],
    downward: bool,
)
```

**Purpose:** Reorder nodes in the "free" layer based on barycenter values computed from the "fixed" layer.

**Key Algorithm Steps:**

1. **Calculate barycenters** (lines 71-102):
```rust
let mut barycenters: Vec<(usize, f64, usize)> = Vec::new();  // (node, barycenter, original_pos)

for (original_pos, &node) in free.iter().enumerate() {
    let neighbors: Vec<usize> = if downward {
        // Looking at predecessors (edges coming into this node from fixed layer)
        edges.iter()
            .filter(|&&(_, to)| to == node)
            .map(|&(from, _)| from)
            .filter(|n| fixed.contains(n))
            .collect()
    } else {
        // Looking at successors (edges going from this node to fixed layer)
        edges.iter()
            .filter(|&&(from, _)| from == node)
            .map(|&(_, to)| to)
            .filter(|n| fixed.contains(n))
            .collect()
    };

    let barycenter = if neighbors.is_empty() {
        graph.order[node] as f64  // Keep current position if no neighbors
    } else {
        let sum: f64 = neighbors.iter().map(|&n| graph.order[n] as f64).sum();
        sum / neighbors.len() as f64  // Average position of neighbors
    };

    barycenters.push((node, barycenter, original_pos));
}
```

2. **Sort by barycenter** (lines 104-109):
```rust
barycenters.sort_by(|a, b| {
    a.1.partial_cmp(&b.1)
        .unwrap_or(std::cmp::Ordering::Equal)
        .then_with(|| a.2.cmp(&b.2))  // Tie-breaking: use original position
});
```

3. **Update order** (lines 111-114):
```rust
for (new_pos, (node, _, _)) in barycenters.iter().enumerate() {
    graph.order[*node] = new_pos;
}
```

**Tie-Breaking Behavior:**

When two nodes have the same barycenter value:
- Uses `original_pos` (the node's position before this reordering)
- Always prefers the earlier position (left-bias)
- This is a **stable sort** that preserves relative order for ties

---

### `count_all_crossings()` - Total Crossing Count

**Location:** Lines 117-128

**Signature:**
```rust
fn count_all_crossings(
    graph: &LayoutGraph,
    layers: &[Vec<usize>],
    edges: &[(usize, usize)],
) -> usize
```

**Purpose:** Count total edge crossings across all adjacent layer pairs.

**Implementation:**
```rust
fn count_all_crossings(graph: &LayoutGraph, layers: &[Vec<usize>], edges: &[(usize, usize)]) -> usize {
    let mut total = 0;
    for i in 0..layers.len().saturating_sub(1) {
        total += count_crossings_between(graph, &layers[i], &layers[i + 1], edges);
    }
    total
}
```

---

### `count_crossings_between()` - Crossing Count Between Two Layers

**Location:** Lines 130-163

**Signature:**
```rust
fn count_crossings_between(
    graph: &LayoutGraph,
    layer1: &[usize],
    layer2: &[usize],
    edges: &[(usize, usize)],
) -> usize
```

**Purpose:** Count crossings between two adjacent layers using a simple O(e^2) algorithm.

**Implementation:**
```rust
fn count_crossings_between(
    graph: &LayoutGraph,
    layer1: &[usize],
    layer2: &[usize],
    edges: &[(usize, usize)],
) -> usize {
    // Collect edges between these layers with their positions
    let mut edge_positions: Vec<(usize, usize)> = Vec::new();

    for &(from, to) in edges {
        if layer1.contains(&from) && layer2.contains(&to) {
            edge_positions.push((graph.order[from], graph.order[to]));
        } else if layer1.contains(&to) && layer2.contains(&from) {
            edge_positions.push((graph.order[to], graph.order[from]));
        }
    }

    // Count crossings using simple O(e^2) algorithm
    let mut crossings = 0;
    for i in 0..edge_positions.len() {
        for j in i + 1..edge_positions.len() {
            let (u1, v1) = edge_positions[i];
            let (u2, v2) = edge_positions[j];

            // Edges cross if one goes up while the other goes down
            if (u1 < u2 && v1 > v2) || (u1 > u2 && v1 < v2) {
                crossings += 1;
            }
        }
    }

    crossings
}
```

**Algorithm:** Two edges (u1,v1) and (u2,v2) cross if and only if:
- `u1 < u2` and `v1 > v2`, OR
- `u1 > u2` and `v1 < v2`

This is the standard crossing detection formula for edges between two layers.

---

## How: Algorithm Steps

### Complete Flow

1. **Initialization**
   - Get nodes grouped by rank via `rank::by_rank(graph)`
   - Initialize `order` values sequentially within each layer (0, 1, 2, ...)
   - Get effective edges (with cycle reversals applied)

2. **Iteration Loop** (up to 24 times)
   - Record current crossing count
   - **Sweep Down:** For each layer from top to bottom:
     - Compute barycenter of each node based on positions of neighbors in layer above
     - Sort nodes by barycenter (stable sort, original position breaks ties)
     - Assign new order values
   - **Sweep Up:** For each layer from bottom to top:
     - Compute barycenter of each node based on positions of neighbors in layer below
     - Sort nodes by barycenter (stable sort, original position breaks ties)
     - Assign new order values
   - Count crossings after the full sweep
   - If no improvement, terminate early

3. **Output**
   - `graph.order` contains final positions

### Initial Order Determination

The initial order is determined by the sequence in which nodes appear in the `layers` vector returned by `rank::by_rank()`:

```rust
// From rank.rs, lines 86-95
pub fn by_rank(graph: &LayoutGraph) -> Vec<Vec<usize>> {
    let max_rank = graph.ranks.iter().max().copied().unwrap_or(0) as usize;
    let mut layers: Vec<Vec<usize>> = vec![Vec::new(); max_rank + 1];

    for (node, &rank) in graph.ranks.iter().enumerate() {
        layers[rank as usize].push(node);
    }

    layers
}
```

This means initial order is based on:
1. Node insertion order in the original graph
2. Which is typically the parse order from the Mermaid input

### Barycenter Calculation

For a node `v` in the free layer with neighbors `N(v)` in the fixed layer:

```
barycenter(v) = sum(order[n] for n in N(v)) / |N(v)|
```

If a node has no neighbors in the fixed layer, its barycenter is set to its current order position, which keeps it in place.

### Sorting Strategy

The sort uses Rust's stable sort with a two-level comparison:

```rust
barycenters.sort_by(|a, b| {
    a.1.partial_cmp(&b.1)                    // Primary: barycenter value
        .unwrap_or(std::cmp::Ordering::Equal)
        .then_with(|| a.2.cmp(&b.2))         // Secondary: original position
});
```

**Key point:** Ties are ALWAYS broken by preferring the earlier (left) position. There is no right-bias option.

---

## Why: What's Missing Compared to Dagre

Based on the analysis in `00-initial-analysis.md` and our code review, here are the identified gaps:

### Gap 1: Missing Bias Parameter

**Dagre's Approach:**
```javascript
function order(g, opts = {}) {
  for (let i = 0, lastBest = 0; lastBest < 4; ++i, ++lastBest) {
    sweepLayerGraphs(
      i % 2 ? downLayerGraphs : upLayerGraphs,
      i % 4 >= 2,  // biasRight: true for iterations 2,3
    );
    // ...
  }
}
```

Dagre alternates between left-bias (iterations 0,1) and right-bias (iterations 2,3).

**mmdflux's Approach (lines 105-109):**
```rust
barycenters.sort_by(|a, b| {
    a.1.partial_cmp(&b.1)
        .unwrap_or(std::cmp::Ordering::Equal)
        .then_with(|| a.2.cmp(&b.2))  // ALWAYS uses original position (left-bias)
});
```

mmdflux always uses the same tie-breaking direction. There is no `bias_right` parameter.

**Impact:** When nodes have equal barycenters, mmdflux always pushes them left, while Dagre explores both left and right placements to find lower-crossing configurations.

### Gap 2: No Multiple Ordering Attempts

**Dagre's Approach:**
- Runs 4 different bias configurations
- Keeps the configuration with the fewest crossings
- Continues until 4 iterations without improvement

**mmdflux's Approach (lines 31-43):**
```rust
for _ in 0..MAX_ITERATIONS {
    let prev_crossings = best_crossings;

    sweep_down(graph, &layers, &edges);
    sweep_up(graph, &layers, &edges);

    best_crossings = count_all_crossings(graph, &layers, &edges);

    if best_crossings >= prev_crossings {
        break;  // Stops on first plateau
    }
}
```

mmdflux:
- Runs the same algorithm repeatedly
- Stops immediately when no improvement is made
- Never tries alternative orderings

**Impact:** mmdflux may get stuck in a local minimum that Dagre would escape by trying different bias configurations.

### Gap 3: No Edge Weights

**Dagre's Approach:**
- Long edges carry their label weight through the barycenter calculation
- Important edges can influence the ordering more strongly

**mmdflux's Approach:**
- All edges are treated equally
- No weight consideration in barycenter calculation

```rust
// All neighbors contribute equally (lines 97-98)
let sum: f64 = neighbors.iter().map(|&n| graph.order[n] as f64).sum();
sum / neighbors.len() as f64
```

**Impact:** Labeled edges or semantically important edges have no priority in ordering decisions.

### Gap 4: Simple Initial Order

**Dagre's Approach:**
- Uses `initOrder()` which may consider graph structure
- Potentially uses DFS or connectivity analysis

**mmdflux's Approach (lines 18-23):**
```rust
for layer in &layers {
    for (idx, &node) in layer.iter().enumerate() {
        graph.order[node] = idx;
    }
}
```

Initial order is simply the enumeration order of nodes in each layer, which depends on:
1. Node insertion order
2. Parse order from Mermaid input

**Impact:** The starting point for optimization may be suboptimal, requiring more iterations to reach a good solution.

### Gap 5: No Best-Order Tracking

**Dagre's Approach:**
- Stores the best ordering found across all configurations
- Restores the best if later iterations don't improve

**mmdflux's Approach:**
- Only tracks `best_crossings` count
- Doesn't save the actual order that produced that count
- Each sweep directly modifies `graph.order`

```rust
let mut best_crossings = count_all_crossings(graph, &layers, &edges);  // Line 29

for _ in 0..MAX_ITERATIONS {
    // ... sweeps modify graph.order directly ...
    best_crossings = count_all_crossings(graph, &layers, &edges);

    if best_crossings >= prev_crossings {
        break;  // May have worse order than before the last sweep!
    }
}
```

**Impact:** The final order might actually be worse than an intermediate order if the last sweep didn't improve things. The algorithm stops when `best_crossings >= prev_crossings`, but by that point the order has already been changed.

### Gap 6: O(e^2) Crossing Count

**Dagre's Approach:**
- May use O(e log e) bilayer crossing counting

**mmdflux's Approach (lines 148-160):**
```rust
// Count crossings using simple O(e^2) algorithm
let mut crossings = 0;
for i in 0..edge_positions.len() {
    for j in i + 1..edge_positions.len() {
        // ...
    }
}
```

Uses a simple O(e^2) pairwise comparison.

**Impact:** Performance may degrade on dense graphs, though unlikely to affect correctness.

---

## Summary of Gaps

| Gap | Dagre Feature | mmdflux Status | Severity |
|-----|---------------|----------------|----------|
| 1 | Bias parameter | Missing | High |
| 2 | Multiple ordering attempts | Missing | High |
| 3 | Edge weights | Missing | Medium |
| 4 | Smart initial order | Missing | Low-Medium |
| 5 | Best-order tracking | Missing | Medium |
| 6 | Efficient crossing count | O(e^2) instead of O(e log e) | Low |

### Recommended Fixes (from 00-initial-analysis.md)

1. **Add `bias_right` parameter** to `reorder_layer()`:
   - When `bias_right=false`: break ties with `a.2.cmp(&b.2)` (left preference)
   - When `bias_right=true`: break ties with `b.2.cmp(&a.2)` (right preference)

2. **Run multiple ordering configurations**:
   - Try 4 configurations: left-bias down, left-bias up, right-bias down, right-bias up
   - Save and restore the best ordering across all attempts

3. **Track best order properly**:
   - Clone `graph.order` when a better crossing count is found
   - Restore the best order at the end

These changes would align mmdflux more closely with Dagre's approach and should produce better layouts for complex graphs like `complex.mmd`.

---

## Related Files

- `$HOME/src/mmdflux/src/dagre/order.rs` - Main ordering implementation (analyzed)
- `$HOME/src/mmdflux/src/dagre/rank.rs` - Provides `by_rank()` for layer grouping
- `$HOME/src/mmdflux/src/dagre/graph.rs` - `LayoutGraph` data structure
- `$HOME/src/mmdflux/src/dagre/normalize.rs` - Dummy node insertion for long edges
- `$HOME/src/mmdflux/src/dagre/mod.rs` - Pipeline orchestration (calls `order::run()` in Phase 3)
