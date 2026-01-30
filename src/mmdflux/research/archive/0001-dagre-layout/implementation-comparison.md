# Implementation Comparison: Simplified Sugiyama vs Full Dagre

This document provides a detailed side-by-side comparison of implementing a "Simplified Sugiyama" approach versus the "Full Dagre" algorithm for mmdflux's layout engine.

---

## Phase 1: Cycle Removal

### Both Dagre (Default) and mmdflux: DFS-Based Back-Edge Detection

**Algorithm:** Perform depth-first search; edges pointing to ancestors in the DFS tree are back-edges.

**Important:** Dagre's default behavior (used by Mermaid.js) is DFS-based FAS, not greedy FAS. The greedy algorithm is only used when `acyclicer: "greedy"` is explicitly set, which Mermaid does not do.

**Pseudocode:**
```rust
fn detect_back_edges(diagram: &Diagram) -> HashSet<(String, String)> {
    let mut back_edges = HashSet::new();
    let mut visited = HashSet::new();
    let mut in_stack = HashSet::new();

    fn dfs(
        node: &str,
        diagram: &Diagram,
        visited: &mut HashSet<String>,
        in_stack: &mut HashSet<String>,
        back_edges: &mut HashSet<(String, String)>,
    ) {
        visited.insert(node.to_string());
        in_stack.insert(node.to_string());

        for edge in diagram.edges_from(node) {
            if in_stack.contains(&edge.to) {
                // Back-edge detected
                back_edges.insert((edge.from.clone(), edge.to.clone()));
            } else if !visited.contains(&edge.to) {
                dfs(&edge.to, diagram, visited, in_stack, back_edges);
            }
        }

        in_stack.remove(node);
    }

    for node_id in diagram.nodes.keys() {
        if !visited.contains(node_id) {
            dfs(node_id, diagram, &mut visited, &mut in_stack, &mut back_edges);
        }
    }

    back_edges
}
```

**Characteristics:**
- Lines of code: ~50-80
- Time complexity: O(V + E)
- Simple to understand and debug
- May not find optimal (minimum) feedback arc set
- Good enough for typical flowcharts with few cycles

**Pros:**
- Very fast
- Easy to implement
- Works well for small to medium graphs

**Cons:**
- Non-optimal edge selection for complex graphs with many cycles
- Ordering of nodes affects which edges are reversed

---

### Optional: Greedy Feedback Arc Set (Eades et al., 1993)

**Note:** This is Dagre's *optional* algorithm, enabled only with `acyclicer: "greedy"`. Mermaid.js does NOT use this - it uses DFS-based FAS (the default).

**Algorithm:** Iteratively remove sources and sinks, placing them in ordered lists. When neither exists, select the node with maximum (out-degree - in-degree).

**Characteristics:**
- Lines of code: ~100-150
- Time complexity: O(V + E)
- Produces smaller feedback arc sets in some cases
- Based on well-studied heuristic

**When to consider:**
- Only if DFS-based FAS produces suboptimal results for specific graph patterns
- Currently not needed for Mermaid compatibility (Mermaid uses DFS default)

---

## Phase 2: Layer Assignment

### Simplified: Longest Path Algorithm

**Algorithm:** Process nodes in topological order. Each node's layer = 1 + max(layer of all predecessors).

**Pseudocode:**
```rust
fn longest_path_layering(diagram: &Diagram) -> HashMap<String, usize> {
    let mut layers: HashMap<String, usize> = HashMap::new();
    let topo_order = topological_sort(diagram);

    for node_id in topo_order {
        let predecessors: Vec<_> = diagram.edges.iter()
            .filter(|e| e.to == node_id)
            .map(|e| &e.from)
            .collect();

        let layer = if predecessors.is_empty() {
            0
        } else {
            predecessors.iter()
                .map(|pred| layers[*pred] + 1)
                .max()
                .unwrap()
        };

        layers.insert(node_id.clone(), layer);
    }

    layers
}
```

**Characteristics:**
- Lines of code: ~30-50
- Time complexity: O(V + E)
- Produces minimum number of layers
- May create very wide bottom layers

**Pros:**
- Very simple to implement
- Optimal height (minimum layers)
- Fast execution

**Cons:**
- Tends to push nodes down, creating wide bottom ranks
- Does not minimize total edge length
- May produce unbalanced layouts

---

### Full Dagre: Network Simplex Algorithm

**Algorithm:** Start with longest-path ranking, construct a feasible tight spanning tree, then iteratively exchange tree edges with non-tree edges to minimize total edge length.

**Key Data Structures:**
```rust
struct TreeNode {
    rank: i32,          // Layer assignment
    low: i32,           // Low DFS number in tree
    lim: i32,           // Limit DFS number (subtree size)
    parent: Option<NodeIndex>,
    is_tree_vertex: bool,
}

struct TreeEdge {
    is_tree_edge: bool,
    cut_value: Option<i32>,  // Used for optimization
}
```

**Key Functions:**

#### feasibleTree
```rust
fn feasible_tree(graph: &mut Graph) {
    // Start with longest-path ranking
    init_rank_longest_path(graph);

    // Build tight spanning tree
    let tree_root = graph.nodes().next().unwrap();
    while tight_tree_size(graph, tree_root) < graph.node_count() {
        // Find non-tight edge incident to tree with minimum slack
        let edge = find_min_slack_incident_edge(graph);
        let delta = slack(graph, edge);

        // Adjust ranks to make edge tight
        if graph[edge.head].is_tree_vertex {
            delta = -delta;
        }
        for node in tree_vertices(graph) {
            graph[node].rank += delta;
        }
    }

    init_low_lim_values(graph);
    init_cut_values(graph);
}
```

#### initCutValues
```rust
fn init_cut_values(tree: &mut Graph, graph: &Graph) {
    // Process in postorder (leaves first)
    for node in postorder(tree) {
        if let Some(parent) = tree[node].parent {
            let cut_value = calc_cut_value(tree, graph, node);
            tree.edge_mut(node, parent).cut_value = Some(cut_value);
        }
    }
}

fn calc_cut_value(tree: &Graph, graph: &Graph, child: NodeIndex) -> i32 {
    let parent = tree[child].parent.unwrap();
    let child_is_tail = graph.has_edge(child, parent);
    let graph_edge_weight = graph.edge_weight(child, parent).unwrap_or(1);

    let mut cut_value = graph_edge_weight;

    // For all edges incident to child (except to parent)
    for edge in graph.edges(child) {
        let other = edge.other_endpoint(child);
        if other != parent {
            let points_to_head = (edge.source == child) == child_is_tail;
            let weight = edge.weight;

            cut_value += if points_to_head { weight } else { -weight };

            // If other node is in tree connected to child
            if tree.has_edge(child, other) {
                let other_cut = tree.edge(child, other).cut_value.unwrap();
                cut_value += if points_to_head { -other_cut } else { other_cut };
            }
        }
    }

    cut_value
}
```

#### leaveEdge / enterEdge
```rust
fn leave_edge(tree: &Graph) -> Option<EdgeIndex> {
    // Find tree edge with negative cut value
    tree.edges()
        .find(|e| tree[*e].cut_value.map_or(false, |cv| cv < 0))
}

fn enter_edge(tree: &Graph, graph: &Graph, leaving: EdgeIndex) -> EdgeIndex {
    let (v, w) = tree.edge_endpoints(leaving);
    let (tail_label, flip) = if tree[v].lim > tree[w].lim {
        (tree[w], true)
    } else {
        (tree[v], false)
    };

    // Find non-tree edge going from head component to tail component
    // with minimum slack
    graph.edges()
        .filter(|e| !tree[*e].is_tree_edge)
        .filter(|e| {
            let (ev, ew) = graph.edge_endpoints(*e);
            let v_in_tail = is_descendant(tree, ev, &tail_label) == flip;
            let w_in_tail = is_descendant(tree, ew, &tail_label) == flip;
            v_in_tail != w_in_tail  // One in each component
        })
        .min_by_key(|e| slack(graph, *e))
        .unwrap()
}

fn is_descendant(tree: &Graph, node: NodeIndex, root: &TreeNode) -> bool {
    let label = &tree[node];
    root.low <= label.lim && label.lim <= root.lim
}
```

#### exchangeEdges
```rust
fn exchange_edges(tree: &mut Graph, graph: &mut Graph, leaving: EdgeIndex, entering: EdgeIndex) {
    // Swap edges in tree
    tree[leaving].is_tree_edge = false;
    tree[entering].is_tree_edge = true;

    // Recompute affected values
    update_low_lim_values(tree, entering);
    update_cut_values(tree, graph, leaving, entering);
    update_ranks(tree, graph);
}
```

**Main Loop:**
```rust
fn network_simplex(graph: &mut Graph) {
    feasible_tree(graph);

    while let Some(leaving) = leave_edge(graph) {
        let entering = enter_edge(graph, leaving);
        exchange_edges(graph, leaving, entering);
    }

    normalize_ranks(graph);  // Shift so minimum rank = 0
}
```

**Characteristics:**
- Lines of code: ~300-400
- Time complexity: O(V * E) worst case, typically much faster
- Minimizes sum of edge lengths (rank[w] - rank[v])
- Produces more balanced layouts

**Pros:**
- Optimal for minimizing edge length
- More visually balanced results
- Well-documented in academic literature

**Cons:**
- Significantly more complex
- Requires tree data structures (low/lim values)
- More difficult to debug

---

## Phase 3: Crossing Reduction

### Simplified: Basic Barycenter (2-4 iterations)

**Algorithm:** For each layer, compute the average position of each node's neighbors in the adjacent fixed layer. Sort nodes by this average.

**Pseudocode:**
```rust
fn reduce_crossings_simple(
    layers: &mut Vec<Vec<String>>,
    diagram: &Diagram,
    iterations: usize,  // 2-4 recommended
) {
    let mut positions: HashMap<String, usize> = HashMap::new();

    // Initialize positions
    for layer in layers.iter() {
        for (pos, node) in layer.iter().enumerate() {
            positions.insert(node.clone(), pos);
        }
    }

    for _ in 0..iterations {
        // Sweep down: fix layer i, reorder layer i+1
        for i in 0..layers.len() - 1 {
            reorder_layer_by_barycenter(
                &mut layers[i + 1],
                &layers[i],
                diagram,
                &mut positions,
                true,  // down
            );
        }

        // Sweep up: fix layer i, reorder layer i-1
        for i in (1..layers.len()).rev() {
            reorder_layer_by_barycenter(
                &mut layers[i - 1],
                &layers[i],
                diagram,
                &mut positions,
                false,  // up
            );
        }
    }
}

fn reorder_layer_by_barycenter(
    layer: &mut Vec<String>,
    fixed_layer: &[String],
    diagram: &Diagram,
    positions: &mut HashMap<String, usize>,
    down: bool,
) {
    // Compute barycenter for each node
    let mut barycenters: Vec<(String, f64)> = layer.iter().map(|node| {
        let neighbors: Vec<_> = if down {
            // Get predecessors (in fixed layer above)
            diagram.edges.iter()
                .filter(|e| e.to == *node && fixed_layer.contains(&e.from))
                .map(|e| positions[&e.from] as f64)
                .collect()
        } else {
            // Get successors (in fixed layer below)
            diagram.edges.iter()
                .filter(|e| e.from == *node && fixed_layer.contains(&e.to))
                .map(|e| positions[&e.to] as f64)
                .collect()
        };

        let bary = if neighbors.is_empty() {
            positions[node] as f64  // Keep current position
        } else {
            neighbors.iter().sum::<f64>() / neighbors.len() as f64
        };

        (node.clone(), bary)
    }).collect();

    // Sort by barycenter
    barycenters.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap());

    // Update layer and positions
    *layer = barycenters.iter().map(|(n, _)| n.clone()).collect();
    for (pos, node) in layer.iter().enumerate() {
        positions.insert(node.clone(), pos);
    }
}
```

**Characteristics:**
- Lines of code: ~100-150
- Time complexity: O(K * (V + E)) for K iterations
- Simple averaging heuristic
- No approximation guarantee

**Pros:**
- Easy to implement
- Fast execution
- Works well for sparse graphs
- Good practical results

**Cons:**
- May converge to local minimum
- No theoretical guarantees
- Limited effectiveness on dense graphs

---

### Full Dagre: Multi-Sweep with Transpose

**Algorithm:** Multiple iterations of barycenter/median heuristic with transpose optimization. Track best ordering by crossing count.

**Additional Components:**

#### Bilayer Cross Count (Barth et al., 2002)
```rust
fn bilayer_cross_count(
    north_layer: &[String],
    south_layer: &[String],
    positions: &HashMap<String, usize>,
    diagram: &Diagram,
) -> usize {
    // Sort south endpoints of edges by north position
    let mut south_positions: Vec<usize> = Vec::new();
    for north_node in north_layer {
        let mut edges_from_north: Vec<usize> = diagram.edges.iter()
            .filter(|e| e.from == *north_node && south_layer.contains(&e.to))
            .map(|e| positions[&e.to])
            .collect();
        edges_from_north.sort();
        south_positions.extend(edges_from_north);
    }

    // Count inversions using accumulator tree
    let tree_size = next_power_of_two(south_layer.len());
    let first_index = tree_size - 1;
    let mut tree = vec![0usize; 2 * tree_size - 1];
    let mut cross_count = 0;

    for pos in south_positions {
        let mut index = pos + first_index;
        tree[index] += 1;

        while index > 0 {
            // When going up from left child, add right sibling value
            if index % 2 == 1 {
                cross_count += tree[index + 1];
            }
            index = (index - 1) / 2;
            tree[index] += 1;
        }
    }

    cross_count
}

fn total_crossings(layers: &[Vec<String>], positions: &HashMap<String, usize>, diagram: &Diagram) -> usize {
    let mut total = 0;
    for i in 0..layers.len() - 1 {
        total += bilayer_cross_count(&layers[i], &layers[i + 1], positions, diagram);
    }
    total
}
```

#### Transpose Optimization
```rust
fn transpose_layer(
    layer: &mut Vec<String>,
    diagram: &Diagram,
    positions: &mut HashMap<String, usize>,
) -> bool {
    let mut improved = false;

    // Try swapping adjacent pairs
    for i in 0..layer.len() - 1 {
        let v = &layer[i];
        let w = &layer[i + 1];

        // Count crossings with v before w
        let crossings_vw = count_crossings_for_pair(v, w, diagram, positions);

        // Count crossings with w before v (simulate swap)
        positions.insert(v.clone(), i + 1);
        positions.insert(w.clone(), i);
        let crossings_wv = count_crossings_for_pair(w, v, diagram, positions);

        if crossings_wv < crossings_vw {
            // Keep the swap
            layer.swap(i, i + 1);
            improved = true;
        } else {
            // Revert positions
            positions.insert(v.clone(), i);
            positions.insert(w.clone(), i + 1);
        }
    }

    improved
}
```

#### Full Algorithm
```rust
fn reduce_crossings_full(
    layers: &mut Vec<Vec<String>>,
    diagram: &Diagram,
    use_transpose: bool,
) {
    let mut positions: HashMap<String, usize> = HashMap::new();

    // Initialize positions
    for layer in layers.iter() {
        for (pos, node) in layer.iter().enumerate() {
            positions.insert(node.clone(), pos);
        }
    }

    let mut best_layers = layers.clone();
    let mut best_crossings = total_crossings(layers, &positions, diagram);
    let mut no_improvement_count = 0;

    for iteration in 0.. {
        let down = iteration % 2 == 0;

        // One sweep
        if down {
            for i in 1..layers.len() {
                reorder_layer_by_barycenter(
                    &mut layers[i], &layers[i - 1],
                    diagram, &mut positions, true
                );
            }
        } else {
            for i in (0..layers.len() - 1).rev() {
                reorder_layer_by_barycenter(
                    &mut layers[i], &layers[i + 1],
                    diagram, &mut positions, false
                );
            }
        }

        // Transpose optimization
        if use_transpose {
            let range: Box<dyn Iterator<Item = usize>> = if down {
                Box::new(0..layers.len())
            } else {
                Box::new((0..layers.len()).rev())
            };

            for i in range {
                loop {
                    if !transpose_layer(&mut layers[i], diagram, &mut positions) {
                        break;
                    }
                }
            }
        }

        // Track best
        let crossings = total_crossings(layers, &positions, diagram);
        if crossings < best_crossings {
            best_crossings = crossings;
            best_layers = layers.clone();
            no_improvement_count = 0;
        } else {
            no_improvement_count += 1;
        }

        // Terminate after 4 sweeps without improvement
        if no_improvement_count >= 4 {
            break;
        }
    }

    *layers = best_layers;
}
```

**Characteristics:**
- Lines of code: ~300-400
- Time complexity: O(K * (V + E + E log V)) for K iterations
- Better crossing minimization
- Includes local optimization

**Pros:**
- Better results than simple barycenter
- Transpose catches local improvements
- Cross counting is efficient

**Cons:**
- More complex implementation
- More iterations needed
- Still heuristic (not optimal)

---

## Phase 4: Coordinate Assignment

### Simplified: Grid-Based Centering

**Algorithm:** Assign nodes to discrete grid positions. Center each layer horizontally. This is ideal for ASCII output where continuous coordinates are unnecessary.

**Pseudocode:**
```rust
fn grid_coordinate_assignment(
    layers: &[Vec<String>],
    node_dims: &HashMap<String, (usize, usize)>,
    h_spacing: usize,
    v_spacing: usize,
) -> (HashMap<String, (usize, usize)>, usize, usize) {
    let mut positions: HashMap<String, (usize, usize)> = HashMap::new();

    // Calculate max width of each layer
    let layer_widths: Vec<usize> = layers.iter().map(|layer| {
        let content: usize = layer.iter()
            .map(|n| node_dims[n].0)
            .sum();
        let spacing = if layer.len() > 1 { (layer.len() - 1) * h_spacing } else { 0 };
        content + spacing
    }).collect();

    let max_width = *layer_widths.iter().max().unwrap_or(&0);

    // Calculate layer heights
    let layer_heights: Vec<usize> = layers.iter().map(|layer| {
        layer.iter()
            .map(|n| node_dims[n].1)
            .max()
            .unwrap_or(0)
    }).collect();

    // Assign coordinates
    let mut y = 0;
    for (layer_idx, layer) in layers.iter().enumerate() {
        // Center this layer
        let layer_width = layer_widths[layer_idx];
        let start_x = (max_width - layer_width) / 2;

        let mut x = start_x;
        for node in layer {
            positions.insert(node.clone(), (x, y));
            x += node_dims[node].0 + h_spacing;
        }

        y += layer_heights[layer_idx] + v_spacing;
    }

    let total_height = y - v_spacing;
    (positions, max_width, total_height)
}
```

**Characteristics:**
- Lines of code: ~50-100
- Time complexity: O(V)
- Discrete positions (perfect for ASCII)
- Simple centering logic

**Pros:**
- Trivial to implement
- Native grid coordinates
- No adaptation needed for ASCII output
- Fast

**Cons:**
- May not minimize edge bends
- No edge-length optimization
- Less compact layouts

---

### Full Dagre: Brandes-Kopf Algorithm

**Algorithm:** Construct vertical alignments of nodes into "blocks", then perform horizontal compaction. Run in 4 directions (up-left, up-right, down-left, down-right) and take the median.

**Key Data Structures:**
```rust
struct BlockVertex {
    root: NodeIndex,   // Root of block (topmost node)
    align: NodeIndex,  // Next node in block (or self if last)
    sink: NodeIndex,   // Class representative
    shift: f64,        // Class shift value
    x: f64,            // X coordinate
    pos: usize,        // Position in layer
    block_width: f64,  // Max width of nodes in block
}
```

**Key Functions:**

#### findType1Conflicts
```rust
fn find_type1_conflicts(
    layers: &[Vec<NodeIndex>],
    graph: &Graph,
) -> HashSet<(NodeIndex, NodeIndex)> {
    let mut conflicts = HashSet::new();

    // Type-1: non-inner segment crosses inner segment
    // Inner segment = edge between two dummy nodes
    for i in 1..layers.len() {
        let prev_layer = &layers[i - 1];
        let curr_layer = &layers[i];

        let mut k0 = 0;  // Left boundary of last inner segment
        let mut scan_pos = 0;

        for (l1, v) in curr_layer.iter().enumerate() {
            // Check if v is incident to inner segment
            let k1 = if let Some(u) = inner_segment_upper_neighbor(graph, *v) {
                graph[u].pos
            } else if l1 == curr_layer.len() - 1 {
                prev_layer.len()
            } else {
                continue;
            };

            // Scan nodes between scan_pos and l1
            for l in scan_pos..=l1 {
                let scan_node = curr_layer[l];
                for pred in graph.predecessors(scan_node) {
                    let pred_pos = graph[pred].pos;
                    // Conflict if predecessor outside [k0, k1] range
                    // and not both are dummies
                    if (pred_pos < k0 || pred_pos > k1)
                        && !(graph[pred].is_dummy && graph[scan_node].is_dummy)
                    {
                        conflicts.insert((pred, scan_node));
                    }
                }
            }

            scan_pos = l1 + 1;
            k0 = k1;
        }
    }

    conflicts
}

fn inner_segment_upper_neighbor(graph: &Graph, v: NodeIndex) -> Option<NodeIndex> {
    if graph[v].is_dummy {
        graph.predecessors(v).find(|u| graph[*u].is_dummy)
    } else {
        None
    }
}
```

#### verticalAlignment
```rust
fn vertical_alignment(
    layers: &[Vec<NodeIndex>],
    graph: &mut Graph,
    conflicts: &HashSet<(NodeIndex, NodeIndex)>,
    down: bool,  // Direction
) {
    // Reset alignment
    for v in graph.node_indices() {
        graph[v].root = v;
        graph[v].align = v;
    }

    let layer_iter: Box<dyn Iterator<Item = &Vec<NodeIndex>>> = if down {
        Box::new(layers.iter())
    } else {
        Box::new(layers.iter().rev())
    };

    for layer in layer_iter {
        let mut r = -1i32;  // Rightmost aligned position

        for v in layer {
            // Get neighbors in direction
            let mut neighbors: Vec<NodeIndex> = if down {
                graph.predecessors(*v).collect()
            } else {
                graph.successors(*v).collect()
            };

            if neighbors.is_empty() {
                continue;
            }

            // Sort by position
            neighbors.sort_by_key(|n| graph[*n].pos);

            // Find median neighbors
            let d = (neighbors.len() as f64 - 1.0) / 2.0;
            let medians = [d.floor() as usize, d.ceil() as usize];

            for m in medians {
                if graph[*v].align == *v {
                    let neighbor = neighbors[m];
                    let neighbor_pos = graph[neighbor].pos as i32;

                    // Check for conflict and ordering
                    if !conflicts.contains(&(neighbor, *v))
                        && !conflicts.contains(&(*v, neighbor))
                        && r < neighbor_pos
                    {
                        graph[neighbor].align = *v;
                        graph[*v].root = graph[neighbor].root;
                        graph[*v].align = graph[*v].root;
                        r = neighbor_pos;
                    }
                }
            }
        }
    }
}
```

#### horizontalCompaction
```rust
fn horizontal_compaction(
    layers: &[Vec<NodeIndex>],
    graph: &mut Graph,
    left: bool,  // Direction
) -> HashMap<NodeIndex, f64> {
    let mut xs: HashMap<NodeIndex, f64> = HashMap::new();

    // Compute block widths
    compute_block_widths(graph);

    // Place blocks
    let roots: Vec<_> = graph.node_indices()
        .filter(|v| graph[*v].root == *v)
        .collect();

    for root in roots {
        place_block(layers, graph, root, &mut xs);
    }

    // Calculate class shifts
    for layer in layers {
        if layer.is_empty() { continue; }

        let v = layer[0];
        if graph[v].sink == v && graph[graph[v].sink].shift == f64::INFINITY {
            graph[graph[v].sink].shift = 0.0;
        }

        // Traverse blocks in class
        let mut current = v;
        loop {
            let align = graph[current].align;
            if align == graph[current].root {
                break;
            }

            current = align;
            let pos = graph[current].pos;

            if pos > 0 {
                let pred = layers[graph[current].rank as usize][pos - 1];
                let gap = (graph[current].block_width + graph[pred].block_width) / 2.0;
                let dist = xs[&current] - (xs[&pred] + gap);

                let pred_sink = graph[pred].sink;
                let current_sink = graph[current].sink;
                graph[pred_sink].shift = graph[pred_sink].shift.min(
                    graph[current_sink].shift + dist
                );
            }
        }
    }

    // Apply shifts
    for v in graph.node_indices() {
        let shift = graph[graph[v].sink].shift;
        if shift < f64::INFINITY {
            xs.insert(v, xs[&v] + shift);
        }
    }

    // Flip if left direction
    if left {
        for x in xs.values_mut() {
            *x = -*x;
        }
    }

    xs
}

fn place_block(
    layers: &[Vec<NodeIndex>],
    graph: &mut Graph,
    root: NodeIndex,
    xs: &mut HashMap<NodeIndex, f64>,
) {
    if xs.contains_key(&root) {
        return;
    }

    xs.insert(root, 0.0);
    let mut w = root;

    loop {
        let pos = graph[w].pos;
        if pos > 0 {
            let layer = &layers[graph[w].rank as usize];
            let u = layer[pos - 1];
            let u_root = graph[u].root;

            place_block(layers, graph, u_root, xs);

            if graph[root].sink == root {
                graph[root].sink = graph[u_root].sink;
            }

            if graph[root].sink == graph[u_root].sink {
                let gap = (graph[root].block_width + graph[u_root].block_width) / 2.0;
                xs.insert(root, xs[&root].max(xs[&u_root] + gap));
            }
        }

        w = graph[w].align;
        if w == root {
            break;
        }
    }

    // Align all nodes in block to root
    w = graph[root].align;
    while w != root {
        xs.insert(w, xs[&root]);
        graph[w].sink = graph[root].sink;
        w = graph[w].align;
    }
}
```

#### Four-Direction Balance
```rust
fn position_x(graph: &mut Graph, layers: &[Vec<NodeIndex>]) -> HashMap<NodeIndex, f64> {
    let conflicts = find_type1_conflicts(layers, graph);

    let mut layouts: Vec<HashMap<NodeIndex, f64>> = Vec::new();

    // 4 combinations: up/down x left/right
    for down in [true, false] {
        for left in [false, true] {
            // Reverse layers/positions for direction
            let mut adjusted_layers = if down {
                layers.to_vec()
            } else {
                layers.iter().rev().cloned().collect()
            };

            if left {
                for layer in &mut adjusted_layers {
                    layer.reverse();
                }
            }

            vertical_alignment(&adjusted_layers, graph, &conflicts, down);
            let mut xs = horizontal_compaction(&adjusted_layers, graph, left);

            layouts.push(xs);
        }
    }

    // Align all layouts to smallest width
    let smallest = find_smallest_width_layout(&layouts);
    align_layouts_to_smallest(&mut layouts, smallest);

    // Balance: take median of 4 values per node
    let mut final_xs: HashMap<NodeIndex, f64> = HashMap::new();
    for v in graph.node_indices() {
        let mut values: Vec<f64> = layouts.iter()
            .map(|l| l[&v])
            .collect();
        values.sort_by(|a, b| a.partial_cmp(b).unwrap());
        // Average of two middle values
        final_xs.insert(v, (values[1] + values[2]) / 2.0);
    }

    final_xs
}
```

**Characteristics:**
- Lines of code: ~400-500
- Time complexity: O(V + E) per direction, O(V + E) total
- Minimizes bends and edge length
- Produces compact layouts

**Pros:**
- At most 2 bends per edge
- Linear time complexity
- Compact, visually pleasing results

**Cons:**
- Very complex implementation
- Designed for continuous coordinates
- Requires adaptation for ASCII (grid quantization)
- Many edge cases to handle

---

## Summary Table

| Aspect | Simplified | Full Dagre |
|--------|------------|------------|
| **Phase 1 (Cycle)** | DFS back-edge | DFS back-edge (default) |
| Phase 1 LOC | 50-80 | 50-80 (same) |
| **Phase 2 (Layer)** | Longest Path | Network Simplex |
| Phase 2 LOC | 30-50 | 300-400 |
| **Phase 3 (Order)** | Basic Barycenter | Multi-sweep + Transpose |
| Phase 3 LOC | 100-150 | 300-400 |
| **Phase 4 (Position)** | Grid Centering | Brandes-Kopf |
| Phase 4 LOC | 50-100 | 400-500 |
| **Total LOC** | **~250-400** | **~1100-1500** |
| **Implementation Time** | 1-2 days | 1-2 weeks |
| **Layout Quality** | Good (85-90%) | Excellent (100%) |
| **Complexity** | Moderate | High |
| **WASM Size Impact** | Small (~5-10KB) | Medium (~20-30KB) |
| **Maintenance Burden** | Low | High |

---

## Recommendation for mmdflux

### Context

1. **ASCII Output Focus:** mmdflux renders to terminal ASCII art, which inherently uses discrete grid positions. Continuous coordinate optimization (Brandes-Kopf) must be quantized anyway.

2. **WASM Deployment:** Future plans include WebAssembly compilation. Simpler code means smaller binary size and faster load times.

3. **Typical Use Cases:** Mermaid flowcharts are typically small-to-medium size (5-50 nodes). The marginal quality improvement of full Dagre diminishes for smaller graphs.

4. **Maintenance Reality:** A Rust implementation needs to be maintained. Simpler algorithms are easier to debug and extend.

### Recommended Approach: **Simplified Sugiyama with Barycenter Enhancement**

**Phase 1:** Use DFS-based back-edge detection (matches Dagre's default)
- Simple, fast, and matches Mermaid/Dagre behavior
- Both iterate nodes in insertion order, producing identical results

**Phase 2:** Keep longest-path layering
- Already produces minimum layers
- Could add optional "balance" pass later if needed

**Phase 3:** Implement basic barycenter with 4 iterations
- This is the highest-impact improvement for crossing reduction
- Add transpose optimization only if initial results need improvement

**Phase 4:** Keep grid-based centering
- Perfect for ASCII output
- Add edge-aware centering (prefer positions that reduce edge length)

### Implementation Priorities

1. **First:** Implement barycenter crossing reduction (highest ROI)
2. **Second:** Move back-edge detection earlier (better cycle handling)
3. **Later (if needed):** Add transpose optimization
4. **Maybe never:** Network simplex or Brandes-Kopf (diminishing returns)

### When to Consider Full Dagre

Consider upgrading to full Dagre algorithms if:
- Users report poor layouts for complex diagrams (>30 nodes)
- mmdflux expands to graphical (SVG/PNG) output where continuous coordinates matter
- Performance profiling shows the simplified approach is a bottleneck (unlikely)

---

## Alternative: Use rust-sugiyama Crate

Another option is to integrate the `rust-sugiyama` crate, which implements full Sugiyama including Network Simplex and Brandes-Kopf.

**Pros:**
- Battle-tested implementation
- Full algorithm suite
- Maintained by others

**Cons:**
- Returns continuous coordinates (need grid adaptation)
- Adds dependency
- Less control over algorithm details
- May be overkill for ASCII output

**Verdict:** For mmdflux's specific use case (ASCII flowcharts), the custom simplified implementation is likely a better fit than adapting rust-sugiyama's continuous coordinates to a discrete grid.
