# Q5: Dagre Layout Pipeline Changes for Compound Graphs

## Summary

The dagre.js compound graph pipeline requires adding 5 new phases strategically interspersed with existing Sugiyama phases. For mmdflux, this means adding 3 new modules (nesting, border, parent_dummies), modifying 4 existing phases to be compound-aware, and extending LayoutGraph/DiGraph with parent-child relationships and hierarchy metadata. The pipeline order is critical: nesting happens before ranking; border segments after ranking; dummy chain parenting after normalization; border removal after positioning. Simple graphs skip all compound phases with no overhead.

## Where

### dagre.js Reference
- `/Users/kevin/src/dagre/lib/layout.js` -- Pipeline orchestration (lines 30-58)
- `/Users/kevin/src/dagre/lib/nesting-graph.js` -- Compound nesting setup
- `/Users/kevin/src/dagre/lib/add-border-segments.js` -- Border node generation
- `/Users/kevin/src/dagre/lib/parent-dummy-chains.js` -- Parent assignment for dummy chains
- `/Users/kevin/src/dagre/lib/rank/util.js` -- Rank constraint propagation
- `/Users/kevin/src/dagre/lib/util.js` -- `asNonCompoundGraph()`

### mmdflux Current Implementation
- `/Users/kevin/src/mmdflux/src/dagre/mod.rs` -- Pipeline orchestration (lines 74-102)
- `/Users/kevin/src/mmdflux/src/dagre/graph.rs` -- DiGraph, LayoutGraph structures
- `/Users/kevin/src/mmdflux/src/dagre/rank.rs` -- Ranking phase
- `/Users/kevin/src/mmdflux/src/dagre/order.rs` -- Ordering phase
- `/Users/kevin/src/mmdflux/src/dagre/position.rs` -- Position phase
- `/Users/kevin/src/mmdflux/src/dagre/bk.rs` -- Brandes-Kopf algorithm
- `/Users/kevin/src/mmdflux/src/dagre/normalize.rs` -- Edge normalization

### Prior Research
- `/Users/kevin/src/mmdflux/research/0015-bk-block-graph-divergence/q2-border-type-guard.md`

## What

### Current mmdflux Pipeline (Simple Graphs Only)

```
1. acyclic::run()        -- Cycle removal via DFS
2. rank::run()           -- Layer assignment via longest-path
3. rank::normalize()     -- Shift ranks to min=0
4. normalize::run()      -- Long edge normalization (dummy insertion)
5. order::run()          -- Crossing reduction (barycenter, 4-direction sweeps)
6. position::run()       -- Coordinate assignment (BK algorithm)
7. Output extraction     -- Filter real nodes, rebuild edges with waypoints
```

### New Compound-Aware Pipeline

```
 1. acyclic::run()
 2. nesting::run()              [NEW]
 3. rank::run()                 [biased by nesting edges]
 4. rank::normalize()
 5. nesting::cleanup()          [NEW]
 6. assign_rank_minmax()        [NEW]
 7. normalize::run()
 8. parent_dummies::run()       [NEW]
 9. border::add_segments()      [NEW]
10. order::run()                [MODIFIED: hierarchy constraints]
11. position::run()             [MODIFIED: BK borderType guard]
12. border::remove_nodes()      [NEW]
```

### New Phases

#### 1. Nesting Graph Setup (`nesting::run`) -- Before ranking

- Creates border nodes for subgraph top/bottom
- Creates weighted nesting edges: borderTop->child, child->borderBottom
- Adjusts edge minlen by `nodeSep = 2*height + 1`
- Creates root dummy node connecting to all top-level nodes
- **Purpose:** Establishes hierarchy constraints that bias ranking

#### 2. Assign Rank MinMax (`assign_rank_minmax`) -- After ranking

- For each compound node, reads border node ranks
- Stores `minRank` and `maxRank` on compound nodes
- **Purpose:** Defines vertical span for border segment creation

#### 3. Parent Dummy Chains (`parent_dummies::run`) -- After normalization

- For each normalized long edge (chain of dummies)
- Finds lowest common ancestor (LCA) of source/target
- Assigns each dummy to correct compound parent based on rank
- **Purpose:** Ensures edge paths respect compound hierarchy

#### 4. Add Border Segments (`border::add_segments`) -- After parent dummies

- For each compound node with minRank/maxRank
- Creates left and right border nodes for each rank in range
- Links consecutive border nodes vertically (weight-1 edges)
- Sets `borderType: Left` or `Right` on each border node
- **Purpose:** Constrains ordering and positioning

#### 5. Remove Border Nodes (`border::remove_nodes`) -- After positioning

- Reads border node positions to compute subgraph bounding boxes
- Sets compound node width/height/center from border positions
- Removes all border dummy nodes from graph
- **Purpose:** Clean output with subgraph dimensions

### Modifications to Existing Phases

#### Ranking (rank.rs) -- No code changes needed

Nesting edges created by `nesting::run()` naturally bias the ranking to group children together. The existing algorithm runs unchanged on the graph including nesting edges.

#### Ordering (order.rs) -- Add hierarchy constraints

After computing barycenter positions, add constraint checks:
- Nodes cannot move past their compound boundaries
- `addSubgraphConstraints()` records ordering constraints between compound siblings
- Border nodes are filtered from movable set, restored at fixed positions

#### BK Algorithm (bk.rs) -- Pass 2 borderType guard

In horizontal compaction Pass 2 (pull-right):
```rust
// Only apply right-pull if node is not a border of the wrong type
if min.is_finite() {
    if let Some(btype) = node.border_type {
        if btype != expected_border_type {
            xs[elem] = xs[elem].max(min);
        }
    } else {
        xs[elem] = xs[elem].max(min);
    }
}
```

For simple graphs (no borderType), the guard is vacuous.

#### Position (position.rs) -- Minimal changes

Must call border removal phase after positioning. No algorithm changes to coordinate assignment itself.

## How

### LayoutGraph Extension

```rust
pub struct LayoutGraph {
    // ... existing fields ...

    // NEW: Compound graph support
    pub parents: Vec<Option<usize>>,           // parent index per node
    pub min_rank: HashMap<usize, i32>,         // compound node rank ranges
    pub max_rank: HashMap<usize, i32>,
    pub border_top: HashMap<usize, usize>,     // compound -> borderTop node
    pub border_bottom: HashMap<usize, usize>,  // compound -> borderBottom node
    pub border_left: HashMap<usize, Vec<usize>>,  // compound -> left borders per rank
    pub border_right: HashMap<usize, Vec<usize>>, // compound -> right borders per rank
    pub border_type: HashMap<usize, BorderType>,   // border node type
    pub nesting_root: Option<usize>,
    pub nesting_edges: HashSet<usize>,
}

pub enum BorderType {
    Left,
    Right,
}
```

### DiGraph Extension

```rust
pub struct DiGraph<N> {
    // ... existing fields ...
    parents: HashMap<NodeId, NodeId>,  // NEW: parent relationships
}

impl<N> DiGraph<N> {
    pub fn set_parent(&mut self, node: NodeId, parent: NodeId);
    pub fn parent(&self, node: &NodeId) -> Option<&NodeId>;
    pub fn children(&self, node: &NodeId) -> Vec<&NodeId>;
}
```

### New Module Structure

```
src/dagre/
  nesting.rs        -- nesting::run(), nesting::cleanup()
  border.rs         -- border::add_segments(), border::remove_nodes()
  parent_dummies.rs -- parent_dummies::run()
```

### Integration into mod.rs

```rust
pub fn layout_with_labels<N, F>(...) -> LayoutResult {
    let mut lg = LayoutGraph::from_digraph(graph, get_dimensions);

    acyclic::run(&mut lg);

    if lg.has_compound_nodes() {
        nesting::run(&mut lg);
    }

    rank::run(&mut lg);
    rank::normalize(&mut lg);

    if lg.has_compound_nodes() {
        nesting::cleanup(&mut lg);
        assign_rank_minmax(&mut lg);
    }

    normalize::run(&mut lg, edge_labels);

    if lg.has_compound_nodes() {
        parent_dummies::run(&mut lg);
        border::add_segments(&mut lg);
    }

    order::run(&mut lg);
    position::run(&mut lg, config);

    if lg.has_compound_nodes() {
        border::remove_nodes(&mut lg);
    }

    // ... output extraction ...
}
```

## Why

### Design Rationale

1. **Nesting before ranking:** Weighted nesting edges dominate rank assignment, pulling children into contiguous blocks. Leverages existing rank algorithm without modification.

2. **Ranking unchanged:** The existing algorithm works on any graph; nesting edges are just regular weighted edges to it.

3. **MinMax after ranking:** Can only compute compound rank spans after all leaf nodes have ranks.

4. **Dummy parenting before borders:** Ensures edge dummies are in correct compound parents before border segments reference them.

5. **Compound-aware ordering:** Border nodes act as invisible barriers constraining the ordering phase.

6. **BK borderType guard:** Small targeted change; prevents border nodes from being pulled past their intended side.

7. **Conditional phases:** All compound logic is gated on `has_compound_nodes()`. Simple graphs get zero overhead.

### What Remains Unchanged

- Core Sugiyama algorithm (same principles throughout)
- Edge routing (waypoint extraction unchanged)
- Cycle removal (nesting edges are regular edges to it)
- Edge normalization (dummy creation unchanged; parenting added after)

### Risk Assessment

**Low risk:** New phases are additive; don't modify existing code
**Medium risk:** LayoutGraph/DiGraph extension needs careful index management; ordering constraints need validation
**Higher risk:** Nesting graph tree traversal is complex; LCA finding in parent dummy chains is non-trivial

## Key Takeaways

- Compound support is interspersed throughout Sugiyama, not a separate algorithm
- Three new modules needed: `nesting.rs`, `border.rs`, `parent_dummies.rs`
- Four existing phases need compound awareness: ranking (via nesting edges), ordering (constraints), BK (borderType guard), position (border removal)
- LayoutGraph needs ~8 new fields for compound metadata
- dagre.js's pipeline is the blueprint; insertion points and phase order are proven
- Simple graphs skip all compound phases with conditional checks
- Pipeline order is critical: nesting -> rank -> cleanup -> minmax -> normalize -> parent dummies -> borders -> order -> position -> remove borders

## Open Questions

- Should ordering constraints be hard (cannot cross boundaries) or soft (prefer not to)?
- How are self-edges handled in compound graphs?
- Can BK's block graph be computed more efficiently given parent relationships?
- Performance of LCA computation for deeply nested hierarchies?
- How should the output LayoutResult expose subgraph bounding boxes to the rendering layer?
