# Dagre Algorithm and Layered Graph Drawing Theory

This document provides a comprehensive overview of the theoretical foundations behind the Dagre layout algorithm and the Sugiyama framework for hierarchical graph drawing.

## Overview

Dagre is a JavaScript library for laying out directed graphs. It implements the **Sugiyama framework** (also known as layered graph drawing or hierarchical graph drawing), which was first developed by Kozo Sugiyama, Shojiro Tagawa, and Mitsuhiko Toda in their 1981 paper "Methods for Visual Understanding of Hierarchical System Structures."

The Dagre implementation specifically draws from:
- **Gansner et al.** "A Technique for Drawing Directed Graphs" (IEEE TSE 1993) - The primary reference
- **Brandes and Kopf** "Fast and Simple Horizontal Coordinate Assignment" (2002)
- **Junger and Mutzel** "2-Layer Straightline Crossing Minimization" (1997)

## The Sugiyama Framework

The Sugiyama method structures hierarchical graph layout into four sequential phases:

```
Input Graph -> Cycle Removal -> Layer Assignment -> Crossing Reduction -> Coordinate Assignment -> Output
```

Each phase addresses a specific aspect of the layout problem, and the output of one phase becomes the input to the next.

---

## Phase 1: Cycle Removal (Make Acyclic)

### Purpose
Transform a potentially cyclic directed graph into a directed acyclic graph (DAG) by temporarily reversing certain edges.

### The Problem
Finding the minimum feedback arc set (the smallest set of edges whose removal makes the graph acyclic) is **NP-complete** - one of Karp's original 21 NP-complete problems.

### Algorithms

#### Greedy Feedback Arc Set (Eades et al., 1993)
The most common practical approach:

1. Initialize empty lists `Sl` (left) and `Sr` (right)
2. While graph G is not empty:
   - While G contains a sink, remove it and prepend to `Sr`
   - While G contains a source, remove it and append to `Sl`
   - If G is not empty, choose node `u` with maximum `outdegree - indegree`, remove and append to `Sl`
3. Concatenate `Sl` and `Sr` to get vertex ordering
4. Edges going "backward" in this ordering form the feedback arc set

**Time Complexity:** O(|V| + |E|) - linear in graph size

#### DFS-Based Cycle Detection
Alternative approach used by some implementations:
- Perform depth-first search
- Mark edges that point to vertices already on the recursion stack
- These back edges form the feedback arc set

### After Cycle Removal
The identified edges are temporarily reversed, not removed. After layout is complete, they are drawn in their original direction (often as curved backward edges).

---

## Phase 2: Layer Assignment (Ranking)

### Purpose
Assign each vertex to a discrete layer (y-coordinate), ensuring all edges point from higher to lower layers.

### Goals
- Minimize total number of layers (graph height)
- Minimize edges spanning multiple layers
- Balance vertices across layers

### Algorithms

#### Longest Path Algorithm
The simplest approach with optimal height:

```
for each vertex v in topological order:
    layer[v] = 1 + max(layer[u] for all predecessors u of v)
    if v has no predecessors: layer[v] = 0
```

**Time Complexity:** O(|V| + |E|)

**Properties:**
- Produces minimum possible number of layers
- May create wide layers
- Fast and simple to implement

#### Network Simplex Algorithm
More sophisticated approach used by Dagre (default ranker):

1. Construct an initial feasible spanning tree
2. Iteratively improve by:
   - Finding edges with negative cut values
   - Replacing tree edges with non-tree edges
   - Recomputing ranks
3. Continue until optimal (no negative cut values)

**Time Complexity:** O(|V| * |E|) worst case, but typically much faster in practice

**Properties:**
- Minimizes total edge length (sum of |layer[v] - layer[u]| for all edges)
- Generally produces more balanced layouts
- 200-300x faster than general simplex for this problem

#### Coffman-Graham Algorithm
For width-constrained layouts:

- Limits maximum vertices per layer to W
- Uses at most 2 - 2/W times optimal number of layers
- Optimal for W = 2

**Time Complexity:** O(|V|^2)

### Dummy Vertices
After layer assignment, edges spanning multiple layers are replaced with chains of dummy vertices:

```
Original:  A -----> D  (spans 3 layers)

With dummies:  A -> d1 -> d2 -> D
```

This ensures all edges connect adjacent layers, simplifying crossing reduction.

---

## Phase 3: Crossing Reduction (Vertex Ordering)

### Purpose
Determine the left-to-right ordering of vertices within each layer to minimize edge crossings.

### The Problem
Both the one-sided problem (one layer fixed) and two-sided problem are **NP-hard**.

### Algorithms

#### Barycenter Heuristic
Most commonly used in practice:

```
for each vertex v in layer L:
    position[v] = average(position[u] for all neighbors u in adjacent layer)
sort vertices in L by position
```

**Properties:**
- Simple to implement
- O(|V| + |E|) per iteration
- Best performance on sparse graphs
- No proven approximation bound for general graphs

#### Median Heuristic
Alternative to barycenter:

```
for each vertex v in layer L:
    position[v] = median(position[u] for all neighbors u in adjacent layer)
sort vertices in L by position
```

**Properties:**
- 3-approximation ratio proven (Eades and Wormald, 1994)
- Better theoretical guarantees
- Also produces compact arc lengths

#### Layer-by-Layer Sweep
Both heuristics are applied in a sweep pattern:

```
repeat K times (typically 23-24 iterations):
    sweep down: for each layer from top to bottom
        reorder using barycenter/median from layer above
    sweep up: for each layer from bottom to top
        reorder using barycenter/median from layer below
```

#### Transpose Improvement
After each sweep, try swapping adjacent vertices:

```
for each pair of adjacent vertices (u, v) in each layer:
    if swapping reduces crossings:
        swap u and v
```

### Counting Crossings
The **Bilayer Cross Count** algorithm efficiently counts crossings between two layers:

**Time Complexity:** O(|E| log |V_small|) where V_small is the smaller layer

Reference: Barth, Mutzel, Junger "Simple and Efficient Bilayer Cross Counting"

---

## Phase 4: Coordinate Assignment (Positioning)

### Purpose
Assign exact x-coordinates to vertices while maintaining the ordering from Phase 3.

### Goals
- Minimize total edge length
- Keep edges as straight as possible
- Avoid unnecessary bends
- Produce compact drawings

### Algorithms

#### Brandes-Kopf Algorithm
Used by Dagre and rust-sugiyama:

1. **Block Construction:** Group vertically-aligned vertices into blocks
2. **Class Assignment:** Partition blocks into classes
3. **Compaction:** Compute coordinates for each block, then for each class

**Time Complexity:** O(|V| + |E|) - linear

**Properties:**
- At most 2 bends per edge
- Guarantees integral coordinates when minimum separation is even
- Four variants (UL, UR, DL, DR) are computed; median is typically used

#### Gansner's Priority Method
Original approach from the 1993 paper:
- Constructs auxiliary graph
- Uses network simplex to optimize
- More flexible but slower

### Edge Routing
After vertex positioning:
- Straight lines for simple edges
- Splines or polylines for edges with bends
- Dummy vertices become bend points

---

## Overall Complexity Analysis

| Phase                 | Algorithm                        | Time Complexity        | Space            |
| --------------------- | -------------------------------- | ---------------------- | ---------------- |
| Cycle Removal         | DFS-based FAS (Dagre default)    | O(\|V\| + \|E\|)       | O(\|V\|)         |
| Layer Assignment      | Longest Path                     | O(\|V\| + \|E\|)       | O(\|V\|)         |
| Layer Assignment      | Network Simplex                  | O(\|V\| * \|E\|)       | O(\|V\| + \|E\|) |
| Crossing Reduction    | Barycenter/Median (K iterations) | O(K * (\|V\| + \|E\|)) | O(\|V\|)         |
| Coordinate Assignment | Brandes-Kopf                     | O(\|V\| + \|E\|)       | O(\|V\|)         |

**Overall worst case:** O(|V| * |E| * log|E|) with network simplex
**Practical implementations:** O((|V| + |E|) * log|E|) with efficient dummy handling

The extensive use of dummy vertices can blow up |V| and |E| significantly for graphs with many long edges, which is why efficient implementations work to minimize dummy vertex count.

---

## Key Academic References

### Foundational Papers

1. **Sugiyama, Tagawa, Toda (1981)**
   "Methods for Visual Understanding of Hierarchical System Structures"
   IEEE Trans. SMC 11(2):109-125
   *The original framework*

2. **Gansner, Koutsofios, North, Vo (1993)**
   "A Technique for Drawing Directed Graphs"
   IEEE Trans. Software Engineering 19(3):214-230
   [PDF](https://www.graphviz.org/documentation/TSE93.pdf)
   *The primary reference for Dagre; introduces network simplex ranking*

### Algorithm-Specific Papers

3. **Brandes, Kopf (2002)**
   "Fast and Simple Horizontal Coordinate Assignment"
   Graph Drawing (LNCS 2265):31-44
   [SpringerLink](https://link.springer.com/chapter/10.1007/3-540-45848-4_3)
   *Linear-time coordinate assignment*

4. **Junger, Mutzel (1997)**
   "2-Layer Straightline Crossing Minimization: Performance of Exact and Heuristic Algorithms"
   Journal of Graph Algorithms and Applications 1(1):1-25
   [JGAA](https://jgaa.info/index.php/jgaa/article/view/paper1)
   *Comprehensive comparison of crossing minimization methods*

5. **Eades, Lin, Smyth (1993)**
   "A Fast and Effective Heuristic for the Feedback Arc Set Problem"
   Information Processing Letters 47:319-323
   *Greedy feedback arc set algorithm*

6. **Barth, Mutzel, Junger (2002)**
   "Simple and Efficient Bilayer Cross Counting"
   Graph Drawing (LNCS 2528):130-141
   *O(|E| log |V|) crossing counting*

7. **Coffman, Graham (1972)**
   "Optimal Scheduling for Two-Processor Systems"
   Acta Informatica 1:200-213
   *Width-constrained layer assignment*

### Surveys and Handbooks

8. **Healy, Nikolov (2013)**
   "Hierarchical Drawing Algorithms"
   Handbook of Graph Drawing and Visualization, Chapter 13
   [Brown CS](https://cs.brown.edu/people/rtamassi/gdhandbook/chapters/hierarchical.pdf)
   *Comprehensive survey of the field*

---

## Rust Implementations

### ascii-dag
- **Crate:** [crates.io/crates/ascii-dag](https://crates.io/crates/ascii-dag)
- **GitHub:** [AshutoshMahala/ascii-dag](https://github.com/AshutoshMahala/ascii-dag)
- **Features:**
  - Sugiyama layout with median crossing reduction
  - Zero dependencies, no_std compatible
  - Optimized for terminal/ASCII output
  - ~5ms for 1000 nodes
  - Handles cycles, diamonds, skip-level edges

### rust-sugiyama
- **Crate:** [crates.io/crates/rust-sugiyama](https://crates.io/crates/rust-sugiyama)
- **Features:**
  - Built on petgraph
  - Cycle removal via petgraph's `greedy_feedback_arc_set`
  - Network simplex ranking (Gansner et al.)
  - Weighted median or barycenter crossing reduction
  - Brandes-Kopf coordinate assignment

**Note:** mmdflux uses DFS-based cycle removal instead (matching Dagre's default, which Mermaid.js uses), not the greedy FAS approach used by rust-sugiyama.
  - Preserves node indices

### petgraph
- **Crate:** [crates.io/crates/petgraph](https://crates.io/crates/petgraph)
- **GitHub:** [petgraph/petgraph](https://github.com/petgraph/petgraph)
- **Features:**
  - Core graph data structures
  - Topological sorting
  - Feedback arc set (greedy)
  - DOT format export for Graphviz visualization
  - No built-in layout algorithms, but good foundation

### egui_graphs
- **GitHub:** [blitzarx1/egui_graphs](https://github.com/blitzarx1/egui_graphs)
- **Features:**
  - Interactive visualization widget for egui
  - Hierarchical (layered) layout option
  - Force-directed layouts
  - Built on petgraph

### daggy
- **Crate:** [crates.io/crates/daggy](https://crates.io/crates/daggy)
- **Features:**
  - DAG-specific wrapper around petgraph
  - Enforces acyclicity at the type level
  - No layout algorithms, but useful for DAG operations

---

## Dagre-Specific Configuration

Dagre exposes these key configuration options:

| Option      | Default           | Description                                                        |
| ----------- | ----------------- | ------------------------------------------------------------------ |
| `rankdir`   | `TB`              | Layout direction: TB, BT, LR, RL                                   |
| `nodesep`   | 50                | Horizontal separation between nodes (pixels)                       |
| `ranksep`   | 50                | Vertical separation between ranks (pixels)                         |
| `edgesep`   | 10                | Horizontal separation between edges (pixels)                       |
| `ranker`    | `network-simplex` | Ranking algorithm: `network-simplex`, `tight-tree`, `longest-path` |
| `acyclicer` | `undefined` (DFS) | Cycle removal: DFS (default) or `"greedy"` (optional heuristic)    |

---

## Summary

The Dagre/Sugiyama approach to graph layout is well-suited for:
- Directed acyclic graphs (DAGs)
- Flowcharts and workflows
- Call graphs and dependency trees
- Any graph with inherent hierarchy

The four-phase approach (cycle removal, layer assignment, crossing reduction, coordinate assignment) allows each subproblem to be addressed independently, with heuristics trading off optimality for speed. For most practical graphs, the combination of DFS-based cycle removal (Dagre's default), network simplex ranking, barycenter crossing reduction, and Brandes-Kopf positioning produces readable layouts efficiently.
