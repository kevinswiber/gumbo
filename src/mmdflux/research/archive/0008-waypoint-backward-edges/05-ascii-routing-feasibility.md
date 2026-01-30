# 05: ASCII Orthogonal Routing Feasibility

## Current Forward Edge Routing

**`router.rs`**: Forward edges use orthogonal (axis-aligned) paths:
- TD/BT: Z-shaped (vertical → horizontal → vertical)
- LR/RL: L-shaped (horizontal → vertical → horizontal)

For edges with waypoints (`route_edge_with_waypoints`, lines 183-228):
- Generates segments through each waypoint
- Uses `build_orthogonal_path_for_direction()` for each waypoint-to-waypoint leg

The system is fully orthogonal — no diagonal edges.

## Spacing Analysis

**Default spacing** (`LayoutConfig::default()`):
- `h_spacing: 4` — horizontal gap between nodes in same rank
- `v_spacing: 3` — vertical gap between ranks
- `padding: 1` — canvas edge padding
- `corridor_width: 3` — current backward edge corridor width

**Grid layout for TD** with 3 ranks:
```
y=0:  padding row
y=1:  ┌───────┐   Node A (height 3)
y=2:  │  Top  │
y=3:  └───────┘
y=4:  (gap row 1)  ← inter-rank gap
y=5:  (gap row 2)  ← inter-rank gap  (edge routing space)
y=6:  (gap row 3)  ← inter-rank gap
y=7:  ┌────────┐   Node B (height 3)
y=8:  │ Middle │
y=9:  └────────┘
y=10: (gap row 1)
y=11: (gap row 2)
y=12: (gap row 3)
y=13: ┌────────┐   Node C (height 3)
y=14: │ Bottom │
y=15: └────────┘
```

The 3-row inter-rank gap provides space for:
- 1 row for horizontal edge segments
- 1 row for vertical travel
- 1 row for arrows/entry

## Current Output Examples

**Simple cycle (TD, C→A backward edge via corridor):**
```
  ┌─────┐
  │ Top │◄──────┐
  └─────┘       │
     │          │
     └┐         │
      ▼         │
 ┌────────┐     │
 │ Middle │◄─┐  │
 └────────┘  │  │
      │      │  │
      ▼      │  │
 ┌────────┐  │  │
 │ Bottom │──┴──┘
 └────────┘
```

**Same cycle (LR, backward edge via bottom corridor):**
```
 ┌───────┐    ┌─────────┐    ┌─────┐
 │ Start │───►│ Process │───►│ End │
 └───────┘    └─────────┘    └─────┘
     ▲                          │
     │                          │
     └──────────────────────────┘
```

## Box-Drawing Characters Available

**Unicode** (`chars.rs`):
```
│ ─ ┌ ┐ └ ┘ ┬ ┴ ├ ┤ ┼
▲ ▼ ◄ ►
```

**ASCII**:
```
| - + + + + + + + + +
^ v < >
```

Full junction support exists — `CharSet::junction()` handles all connection patterns including `up=true`.

**Upward arrows are supported**: `▲` (unicode) / `^` (ascii).

## Feasibility of Waypoint-Based Upward Routing

### Approach: Route Through Inter-Rank Gaps

For a backward edge C→A in TD layout (C at rank 2, A at rank 0):

**Proposed path using waypoints:**
```
  ┌─────┐
  │ Top │◄─┐          A receives arrow from left/top
  └─────┘  │
           │          Vertical upward segment
     │     │
     ▼     │
 ┌────────┐│
 │ Middle ││          Passes alongside B
 └────────┘│
     │     │
     ▼     │
 ┌────────┐│
 │ Bottom │┘          C exits from right side
 └────────┘
```

Or with more horizontal spread:
```
  ┌─────┐◄────────┐
  │ Top │         │
  └─────┘         │
     │            │
     ▼            │
 ┌────────┐       │
 │ Middle │       │
 └────────┘       │
     │            │
     ▼            │
 ┌────────┐       │
 │ Bottom │───────┘
 └────────┘
```

### Where Waypoints Would Route

Dagre's crossing-minimization already positions backward edge dummy nodes. For C→A:
- Dummy at rank 1 gets an x-position chosen to minimize crossings
- This x-position is typically to the **side** of other nodes at that rank

The waypoint x-position determines **which column** the backward edge travels through:
- If dummy x is between B and the right edge → routes to the right of B
- If dummy x is to the left of B → routes to the left of B

### Challenges

#### Challenge 1: Node Collision
**Problem**: Vertical backward edge segments might overlap with nodes at intermediate ranks.

**Solution**: Dagre's ordering algorithm already places dummy nodes to minimize crossings. The dummy node x-position provides a safe column for routing. We can verify by checking `node_bounds` at each rank.

**Mitigation**: If collision detected, offset by 1-2 characters or fall back to corridor.

#### Challenge 2: Edge Crossing
**Problem**: Multiple backward edges might cross each other or cross forward edges.

**Solution**: Dagre's ordering minimizes crossings. For ASCII, we can use junction characters (`┼`, `+`) at crossing points. The existing `CharSet::junction()` already handles this.

#### Challenge 3: Arrow Direction
**Problem**: Upward entries need correct arrow placement.

**Current logic already handles this**: Entry direction is computed from the last segment's direction. If the final segment goes upward (y decreasing), `entry_direction = Bottom`, producing `▲`.

#### Challenge 4: Tight Spacing
**Problem**: Inter-rank gap is only 3 characters — backward edges need to fit within this.

**Analysis**: A vertical segment needs 1 column width. A horizontal turn needs 1 row. With v_spacing=3, we have room for: exit row + travel row + entry row. This is sufficient for orthogonal routing.

If labels are present on backward edges, v_spacing may need to increase (already handled for forward edges by `layout_config_for_diagram`).

## Creative Routing Ideas

### Idea 1: Waypoint-Aligned Column Routing
Route backward edges in the column where dagre placed their dummy nodes. The dummy x-position is already optimized for crossing minimization.

```
  ┌─────┐   ┌─────┐
  │  A  │◄──┤  B  │
  └─────┘   └─────┘
     │     ↗    │
     │    │     │
     ▼    │     ▼
  ┌─────┐ │ ┌─────┐
  │  C  │ │ │  D  │
  └─────┘ │ └─────┘
     │    │
     ▼    │
  ┌─────┐ │
  │  E  │─┘     E→B backward edge routes through gap
  └─────┘
```

### Idea 2: Side-Hugging
Route backward edges tight against the side of nodes they pass, using the 1-character gap between node boundary and the h_spacing zone.

### Idea 3: Staircase Pattern
For long backward edges, step sideways at each rank to avoid a long straight vertical line:
```
  ┌───┐
  │ A │◄──┐
  └───┘   │
     │  ┌─┘
     ▼  │
  ┌───┐ │
  │ B │ │
  └───┘ │
     │  │
     ▼  │
  ┌───┐ │
  │ C │─┘
  └───┘
```

### Idea 4: Hybrid Approach (Recommended)
- **Short backward edges** (1-2 rank distance): Route through inter-rank gaps using waypoints
- **Long backward edges** (3+ ranks): Use corridor approach or side-channel
- **Collision detected**: Fall back to corridor

## Comparison: Corridor vs Waypoint Routing

| Aspect | Corridor | Waypoint |
|--------|----------|----------|
| Canvas width | +3 per backward edge | No expansion needed |
| Visual integration | Separated from layout | Integrated in layout |
| Collision risk | None (dedicated space) | Low (dagre-optimized positions) |
| Resemblance to Mermaid | Low | High |
| Implementation effort | Done | Medium |
| Backward edge clarity | Good | Good-to-excellent |

## Recommendation

Waypoint-based routing is **highly feasible**. The key enabler is that dagre's normalization already creates dummy nodes for backward edges, and the ordering algorithm positions them to minimize crossings. We have:

1. **Waypoint positions** from `edge_waypoints` in `LayoutResult`
2. **Character set** with full junction and arrow support
3. **Orthogonal routing** infrastructure already working for forward edges
4. **Collision detection** possible via existing `node_bounds` data

The main implementation work is adapting `route_backward_edge()` in `router.rs` to use waypoints instead of corridor geometry, and handling the coordinate transform from dagre space to ASCII draw coordinates.
