# Port-Based Edge Attachment Implementation Plan

## Status: ❌ CANCELLED

**Cancelled:** 2026-01-28
**Reason:** Superseded by 0015-attachment-point-spreading, which is based on deeper research (research 0009) into how dagre/mermaid handle attachment spreading.
**Superseded by:** 0015-attachment-point-spreading

## Overview

Implement a port-based edge attachment system to resolve forward-forward edge collisions. The current system handles backward-backward collisions (via separate lanes) and forward-backward collisions (via different sides). The remaining issue is multiple forward edges entering/exiting the same side of a node at the same attachment point.

## Current State

### Already Implemented (Solution 1)
- `route_backward_edge_vertical()` exits from RIGHT side (TD/BT layouts)
- `route_backward_edge_horizontal()` exits from BOTTOM side (LR/RL layouts)
- Multi-lane corridors via `backward_edge_lanes` HashMap
- Intersection calculation infrastructure in `intersect.rs`

### Collision Cases

| Collision Type | Status |
|---------------|--------|
| Forward - Backward | Fixed (different sides) |
| Backward - Backward | Fixed (separate lanes) |
| Forward - Forward (same target) | **Collides** |

### When Forward-Forward Collisions Occur

Collisions happen when:
1. Multiple edges enter the same node from the same direction
2. The intersection calculation yields the same attachment point (after integer rounding)
3. Example: Three nodes A, B, C above target D, all edges enter D from top

## Implementation Approach

### Phase 1: Port Counting Infrastructure (layout.rs)

Add data structures to track how many edges connect to each side of each node.

```rust
pub struct NodePorts {
    pub top: Vec<EdgeRef>,     // Edges using top side
    pub bottom: Vec<EdgeRef>,  // Edges using bottom side
    pub left: Vec<EdgeRef>,    // Edges using left side
    pub right: Vec<EdgeRef>,   // Edges using right side
}

pub struct EdgeRef {
    pub from: String,
    pub to: String,
    pub is_outgoing: bool,  // true if this node is the source
}
```

Key logic:
- Count edges during layout computation
- Sort edges within each side for deterministic port ordering
- Store in `Layout.edge_ports: HashMap<String, NodePorts>`

### Phase 2: Port Position Methods (shape.rs)

Extend `NodeBounds` to calculate distributed attachment points.

```rust
impl NodeBounds {
    pub fn port(&self, side: AttachDirection, index: usize, total: usize) -> (usize, usize) {
        if total <= 1 {
            // Use center attachment for single edge
            return match side { ... };
        }

        // Distribute ports evenly along the side
        let usable = self.width.saturating_sub(2); // Exclude corners
        let spacing = usable / (total + 1);
        let x = self.x + 1 + spacing * (index + 1);
        ...
    }
}
```

### Phase 3: Router Integration (router.rs)

Modify `route_edge()` to use port allocation:

```rust
fn route_edge_direct(...) -> Option<RoutedEdge> {
    // Get port allocation
    let (src_idx, src_total) = layout.get_edge_port_info(edge, true).unwrap_or((0, 1));
    let (tgt_idx, tgt_total) = layout.get_edge_port_info(edge, false).unwrap_or((0, 1));

    // Calculate attachment points using ports
    let src_attach = from_bounds.port(exit_dir, src_idx, src_total);
    let tgt_attach = to_bounds.port(entry_dir, tgt_idx, tgt_total);
    ...
}
```

### Phase 4: Testing

Create test fixtures and integration tests for:
- Single edge (center attachment)
- Two edges to same target (distributed)
- Three edges to same target (three positions)
- Diamond shapes (reduced port space)
- All 4 directions (TD, BT, LR, RL)

## Files to Modify/Create

| File | Changes |
|------|---------|
| `src/render/layout.rs` | Add `NodePorts`, `EdgeRef`, `edge_ports` field, port counting |
| `src/render/shape.rs` | Add `port()` method to `NodeBounds` |
| `src/render/router.rs` | Integrate port allocation into routing |
| `tests/fixtures/fan_in.mmd` | New test: multiple edges to same target |
| `tests/integration.rs` | Add port-based attachment tests |

## Edge Cases

### Minimum Node Width
For N edges on one side, minimum usable width = N + 2:
- Small nodes may need width expansion

### Direction-Specific Port Ordering
| Direction | Entry Side | Port Order |
|-----------|------------|------------|
| TD | Top | Left-to-Right (by source x) |
| BT | Bottom | Left-to-Right (by source x) |
| LR | Left | Top-to-Bottom (by source y) |
| RL | Right | Top-to-Bottom (by source y) |

### Diamond Shapes
Diamonds have smaller effective boundaries - use reduced port range.

## Testing Strategy

1. Unit tests for `NodeBounds::port()` with various configurations
2. Integration tests with fan-in diagrams
3. Visual inspection of rendered output
4. Regression tests for existing fixtures

## Research References

- `research/archive/0004-backward-edge-overlap/SYNTHESIS.md` - Executive summary
- `research/archive/0004-backward-edge-overlap/solution-proposals.md` - Solution 2 details
- `research/archive/0004-backward-edge-overlap/mermaid-dagre-analysis.md` - Dagre approach
