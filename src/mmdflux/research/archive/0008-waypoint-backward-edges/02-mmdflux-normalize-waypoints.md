# 02: mmdflux Normalize/Denormalize Waypoint Data

## Normalization: Handling Backward Edges

**File:** `src/dagre/normalize.rs` (lines 196-321)

mmdflux's normalize step handles backward edges with special direction logic:

```rust
// For reversed edges, build chain in effective direction (eff_from -> eff_to)
// so chain edges flow from lower rank to higher rank.
let (chain_start, chain_end) = if is_reversed {
    (to_idx, from_idx) // effective direction: to_idx has lower rank
} else {
    (from_idx, to_idx)
};
```

Key behaviors:
- Identifies edges where `to_rank > from_rank + 1` (spans multiple ranks)
- For reversed edges, builds dummy chains in **effective direction** (lower rank → higher rank)
- Inserts dummy nodes at each intermediate rank
- Uses collect-and-rebuild strategy (fixed in commit b3d31bc) to avoid index corruption

## Denormalization: Extracting Waypoints

**File:** `src/dagre/normalize.rs` (lines 331-364)

After coordinate assignment, `denormalize()` extracts waypoints from positioned dummy nodes:

```rust
pub(crate) fn denormalize(graph: &LayoutGraph) -> HashMap<usize, Vec<WaypointWithRank>> {
    let mut waypoints: HashMap<usize, Vec<WaypointWithRank>> = HashMap::new();
    for chain in &graph.dummy_chains {
        let mut points = Vec::new();
        for dummy_id in &chain.dummy_ids {
            if let Some(&dummy_idx) = graph.node_index.get(dummy_id) {
                let pos = graph.positions[dummy_idx];
                let dims = graph.dimensions[dummy_idx];
                let rank = graph.dummy_nodes.get(dummy_id)
                    .map(|d| d.rank)
                    .unwrap_or(graph.ranks[dummy_idx]);
                points.push(WaypointWithRank {
                    point: Point {
                        x: pos.x + dims.0 / 2.0,
                        y: pos.y + dims.1 / 2.0,
                    },
                    rank,
                });
            }
        }
        waypoints.insert(chain.edge_index, points);
    }
    waypoints
}
```

Returns `HashMap<usize, Vec<WaypointWithRank>>` — original edge index → ordered waypoints with rank info.

## Data Structures

**WaypointWithRank** (`normalize.rs:18-26`):
```rust
pub struct WaypointWithRank {
    pub point: Point,  // (x, y) in dagre coordinate space
    pub rank: i32,     // Layer this waypoint belongs to
}
```

**LayoutResult** (`types.rs:112-140`):
```rust
pub struct LayoutResult {
    pub nodes: HashMap<NodeId, Rect>,
    pub edges: Vec<EdgeLayout>,
    pub reversed_edges: Vec<usize>,
    pub width: f64,
    pub height: f64,
    pub edge_waypoints: HashMap<usize, Vec<WaypointWithRank>>,
    pub label_positions: HashMap<usize, Point>,
}
```

## Comparison with JS dagre

| Aspect | JS dagre | mmdflux |
|--------|----------|---------|
| Point collection | `origLabel.points.push({x, y})` during `undo()` | `denormalize()` after layout |
| Rank tracking | Implicit (chain order) | Explicit `WaypointWithRank.rank` |
| Storage | On edge label object directly | `HashMap<usize, Vec<WaypointWithRank>>` |
| Point reversal | `edge.points.reverse()` for reversed edges | `reversed_edges` tracks which edges are reversed |
| Label position | `origLabel.x/y` from "edge-label" dummy | `label_positions` HashMap |

## What's Available for Waypoint-Based Routing

After denormalization, the following data is available:
1. **Waypoint positions** with rank info — enables dagre→ASCII coordinate transformation
2. **Edge index mapping** — links waypoints to original edges
3. **Label dummy identification** — via `chain.label_dummy_index`
4. **Reversed edge set** — `reversed_edges` tells us which edges are backward

This provides everything needed to route backward edges through their dummy node waypoints instead of through corridors. The waypoints are already positioned by dagre's crossing-minimization algorithm, so they naturally avoid other nodes in the layout.
