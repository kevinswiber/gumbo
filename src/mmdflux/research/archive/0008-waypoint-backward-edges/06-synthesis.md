# 06: Synthesis — Waypoint-Based Backward Edge Routing

## The Core Question

> Can we route backward edges through their dummy node waypoints using orthogonal ASCII paths (going upward through the node layout area) instead of routing around the outside via corridors?

**Answer: Yes.** The data, infrastructure, and spacing all exist. Here's why and how.

## Why It Works

### 1. Dagre Already Creates Backward Edge Waypoints

When dagre processes a backward edge (e.g., E→A in `complex.mmd`):

1. **Acyclic phase** reverses it to A→E (marked `reversed: true`)
2. **Normalization** inserts dummy nodes at intermediate ranks (just like forward long edges)
3. **Ordering** positions those dummies to minimize crossings — they get x-positions that avoid colliding with real nodes
4. **Position assignment** gives dummies concrete x,y coordinates
5. **Denormalization** extracts those positions as waypoints

mmdflux already stores these waypoints in `LayoutResult.edge_waypoints`. We just don't use them for backward edges — instead, we throw them away and route through corridors.

### 2. The Waypoint X-Positions Are Already Optimized

This is the critical insight. Dagre's crossing-minimization treats backward edge dummy nodes identically to forward edge dummy nodes. Their x-positions are chosen to minimize edge crossings. This means:

- A backward edge dummy at rank 1 will be placed in a column that **doesn't overlap** with real nodes at rank 1
- Multiple backward edge dummies at the same rank are ordered to minimize crossing with each other
- The resulting x-positions define a natural "corridor" through the layout — but it's an **internal** corridor, not a perimeter one

### 3. ASCII Spacing Is Sufficient

Current defaults: `h_spacing=4`, `v_spacing=3`. The inter-rank gap of 3 characters provides room for orthogonal routing segments (entry turn + vertical travel + exit turn). The inter-column gap of 4+ characters provides room for vertical backward edge segments.

## What Changes

### Remove
- `backward_corridors`, `corridor_width`, `backward_edge_lanes` from `Layout` struct
- Canvas width/height expansion for corridors (`layout.rs:115-168`)
- Lane assignment algorithm (`layout.rs:512-555`)
- `route_backward_edge()` in `router.rs` (corridor-based routing)
- Special-case backward edge label placement in `edge.rs`

### Add/Modify
- Route backward edges through waypoints using the **same** `route_edge_with_waypoints()` infrastructure as forward edges
- Handle the reversed direction: waypoints are in effective (forward) order; for the actual backward edge, traverse them in reverse
- Arrow direction logic: ensure upward-pointing arrows (`▲`) render correctly (already works — `entry_direction` logic handles this)

### Keep
- `is_backward_edge()` detection — still needed for arrow direction
- Forward edge routing — unchanged
- `edge_waypoints` data from denormalization — already correct

## The Implementation Path

### Step 1: Unify routing dispatch

In `route_edge()` (`router.rs:124-177`), backward edges currently take a separate code path. Change this to:

```rust
if has_waypoints {
    route_edge_with_waypoints(edge, waypoints, layout, direction)
} else {
    route_edge_direct(edge, from_bounds, to_bounds, direction)
}
```

Both forward and backward long edges would use waypoints. Only short edges (1 rank span) use direct routing. The `is_backward_edge` flag still determines arrow direction and entry point.

### Step 2: Handle reverse waypoint traversal

For backward edges, waypoints are stored in effective order (low rank → high rank). The actual edge goes high rank → low rank. Options:

**Option A**: Reverse the waypoint list before routing. This means the router sees waypoints in source→target order regardless of edge direction.

**Option B**: Generate segments directly from reversed waypoints. The existing `build_orthogonal_path_for_direction()` should handle upward movement naturally — it just produces vertical segments with `y_end < y_start`.

Option A is simpler and keeps the router direction-agnostic.

### Step 3: Coordinate transformation

Waypoints are in dagre coordinate space (floating-point). The render layer uses ASCII grid coordinates (integer). The transformation already exists for forward edge waypoints — it needs to work identically for backward edge waypoints.

The transform in `layout.rs` maps dagre coordinates to draw coordinates using:
- Rank → y position (including v_spacing gaps)
- Dagre x → draw x (including h_spacing gaps and node widths)

### Step 4: Remove corridor infrastructure

Once backward edges route through waypoints:
- Canvas no longer needs corridor expansion
- Layout struct simplifies
- All edges use the same rendering path

## Edge Cases

### Multiple backward edges at the same rank
Dagre's ordering handles this — each dummy gets a distinct x-position. Multiple backward edges passing through the same rank will use different columns.

### Backward edge crosses a node
Dagre's ordering minimizes this, but it can happen. In SVG, the edge is drawn on top. In ASCII:
- If the crossing is at an inter-rank gap: no problem (no node there)
- If the crossing is at a node position: the edge character would overwrite node characters
- **Mitigation**: Check for collision; if detected, offset the waypoint x by 1-2 characters, or fall back to corridor routing for that edge

### Short backward edges (1 rank span)
These have no dummy nodes and no waypoints. Route directly: exit from appropriate side, one segment. Same as current behavior but without corridor.

### Labels on backward edges
Currently special-cased. With waypoint routing, labels can be placed at the midpoint of the edge path (between waypoints), same as forward edges. The `label_positions` from denormalization already provides the correct position.

## Expected Visual Result

**Current (corridor):**
```
  ┌─────┐
  │ Top │◄──────┐
  └─────┘       │
     │          │
     ▼          │
 ┌────────┐     │
 │ Middle │     │
 └────────┘     │
     │          │
     ▼          │
 ┌────────┐     │
 │ Bottom │─────┘
 └────────┘
```

**Proposed (waypoint):**
```
     ┌─────┐
  ┌──│ Top │
  │  └─────┘
  │     │
  │     ▼
  │ ┌────────┐
  │ │ Middle │
  │ └────────┘
  │     │
  │     ▼
  │ ┌────────┐
  └►│ Bottom │
    └────────┘
```

Or, depending on where dagre places the dummy nodes:
```
  ┌─────┐
  │ Top │◄─┐
  └─────┘  │
     │     │
     ▼     │
 ┌────────┐│
 │ Middle ││
 └────────┘│
     │     │
     ▼     │
 ┌────────┐│
 │ Bottom │┘
 └────────┘
```

The exact appearance depends on where dagre's ordering algorithm places the dummy nodes — but crucially, it will match the **structure** of Mermaid's rendering (edges routed through the layout, not around it).

## Risk Assessment

- **Technical risk**: LOW — all building blocks exist
- **Visual quality risk**: LOW-MEDIUM — dagre waypoints are optimized for crossing minimization, which generally produces good layouts. Edge cases (node collision) have clear fallback
- **Regression risk**: LOW — forward edge routing is unchanged. Backward edge routing changes are isolated to `route_backward_edge()` and layout corridor code
- **Complexity**: MEDIUM — removing corridors simplifies layout; adding waypoint routing for backward edges adds some routing logic but reuses existing infrastructure
