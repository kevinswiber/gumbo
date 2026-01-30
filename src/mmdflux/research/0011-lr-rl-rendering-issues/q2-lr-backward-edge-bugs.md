# Q2: LR Backward Edge Routing Bugs

## Summary

In LR layouts, backward edge rendering had two severe bugs: (1) the arrow appeared on the wrong side of the target node because geometric intersection-based attachment could hit any face depending on waypoint approach angle, and (2) the routing path was disconnected because the final path segment was vertical (H-V L-shape) instead of horizontal (H-V-H Z-shape), causing wrong arrow glyphs and wrong offset directions. Both were fixed in commit 83d4877 by forcing direction-aware side-face attachments and switching to H-V-H Z-shaped paths for LR/RL layouts.

## Where

- `src/render/router.rs` lines 83-98 — `is_backward_edge()` detection
- `src/render/router.rs` lines 101-163 — `route_edge()` with waypoint reversal at 133-137
- `src/render/router.rs` lines 169-224 — `route_edge_with_waypoints()` full path construction
- `src/render/router.rs` lines 293-347 — `resolve_attachment_points()` with direction parameter at 308
- `src/render/router.rs` lines 375-417 — `offset_from_boundary()` face-dependent offset
- `src/render/router.rs` lines 449-475 — `entry_direction_from_segments()` arrow glyph selection
- `src/render/router.rs` lines 488-563 — `build_orthogonal_path_for_direction()` H-V-H fix at 540-560
- `src/render/router.rs` lines 569-603 — `build_orthogonal_path_with_waypoints()` multi-segment routing
- `src/render/router.rs` lines 809-912 — `compute_attachment_plan()` direction-aware face classification at 841-863
- `src/render/edge.rs` lines 451-468 — `draw_arrow_with_entry()` arrow rendering
- `src/render/intersect.rs` lines 28-59 — `classify_face()` geometric classification
- `issues/0001-lr-layout-and-backward-edge-issues/issues.md` — Issues 4 and 7
- `tests/fixtures/git_workflow.mmd` — test case
- Commit 83d4877 — the fix commit

## What

### Issue 4: Arrow Through Node

The backward "git pull" edge placed `◄` to the LEFT of Working Dir's left border:
```
◄│ Working Dir │
```

**Root cause:** Geometric intersection-based attachment (`calculate_attachment_points()`) could hit any face depending on the waypoint approach angle. For backward edges with waypoints arcing around the diagram, the last waypoint might approach from below, hitting the bottom face instead of the left face. This placed the target attachment at `(center_x, bottom_y)` instead of `(left_x, center_y)`.

### Issue 7: Disconnected Path

The backward edge path had a visible gap — the bottom horizontal routing segment (`└────────────────────────────────────┘`) had no vertical connection back up to the target node.

**Root cause:** Two interlocking problems:
1. Wrong attachment face (bottom instead of left) caused `offset_from_boundary()` to offset downward instead of leftward
2. The final path segment was vertical (old H-V L-shape), which didn't connect properly to a left-face attachment

### Four Interlocking Problems (All Fixed in 83d4877)

**Problem 1: Geometric Attachment Fallback** (lines 293-347, pre-fix)

`resolve_attachment_points()` used geometric center-to-center intersection regardless of layout direction. For backward edges approaching from off-axis waypoints, this could hit any face. Fix: direction-aware forced side-face attachment:
```rust
match direction {
    Direction::LeftRight => {
        source: (right_edge, center_y),  // exits right face
        target: (left_edge, center_y),   // enters left face
    }
}
```

**Problem 2: Wrong Path Segment Orientation** (lines 488-563, pre-fix)

Old code produced H-V (L-shaped) paths with a vertical final segment for LR. `entry_direction_from_segments()` mapped vertical final segments to up/down arrows (▼/▲), but LR needs left/right arrows (◄/►). Fix: H-V-H Z-shaped paths with horizontal final segment:
```rust
let mid_x = (start.x + end.x) / 2;
vec![
    Segment::Horizontal { y: start.y, x_start: start.x, x_end: mid_x },
    Segment::Vertical { x: mid_x, y_start: start.y, y_end: end.y },
    Segment::Horizontal { y: end.y, x_start: mid_x, x_end: end.x },
]
```

**Problem 3: Path Disconnection from Face Mismatch**

When attachment was on the bottom face, `offset_from_boundary()` offset downward. The waypoint path arrived at the bottom but the target was offset even further down, creating a gap. With correct left-face attachment, offset goes leftward and the H-V-H path connects properly.

**Problem 4: Face Classification in Attachment Spreading** (lines 809-912)

`compute_attachment_plan()` used geometric face classification for all directions. Multiple edges on the same node could be classified to different faces, breaking visual grouping. Fix: forced left/right face classification for LR/RL:
```rust
let (src_face, tgt_face) = match direction {
    Direction::LeftRight => (NodeFace::Right, NodeFace::Left),
    Direction::RightLeft => (NodeFace::Left, NodeFace::Right),
    _ => { /* geometric for TD/BT */ }
};
```

## How

### Trace: Backward "git pull" Edge (After Fix)

1. **Backward detection** (line 128): Working.x < Remote.x → backward=true
2. **Waypoint reversal** (133-137): reversed to go from source (Remote) toward target (Working)
3. **Direction-aware attachment** (315-344): source=(right_edge, center_y), target=(left_edge, center_y) — guaranteed correct faces
4. **Boundary offset** (375-417): source offset right (+1,0), target offset left (saturating_sub)
5. **Path construction** (569-603): waypoint-to-waypoint segments via `orthogonalize_segment()`, final segment via `build_orthogonal_path_for_direction()` producing H-V-H
6. **Entry direction** (449-475): horizontal final segment → `AttachDirection::Right` → arrow `◄`
7. **Arrow rendering** (edge.rs 451-468): `◄` placed at target position, correctly approaching from right

### Key Difference: TD vs LR Backward Edges

TD backward edges work correctly because:
- Waypoints naturally align on the vertical axis (same x, different y)
- Geometric intersection reliably hits top/bottom faces
- V-H-V Z-paths produce vertical final segments → correct up/down arrows

LR backward edges needed the fix because:
- Waypoints arc around the diagram with varied approach angles
- Geometric intersection could hit any face
- H-V L-paths produced wrong arrow glyphs; H-V-H Z-paths are required

## Why

**Fundamental issue:** LR/RL layouts impose a strict structural constraint — edges must flow along the left-right axis and attach to left/right node faces. Geometric intersection is layout-agnostic and can violate this constraint.

**Why backward edges are specifically vulnerable:**
- Forward edges span one rank with short, aligned waypoints
- Backward edges span multiple ranks with waypoints arcing around the diagram
- Varied approach angles defeat geometric intersection more often

**Why the fix works:** Direction-aware forced attachment is deterministic — same layout direction always produces same face assignment. Combined with H-V-H paths (horizontal final segment), arrows and offsets are always consistent with the layout direction.

## Key Takeaways

- Geometric intersection is layout-sensitive: works for TD/BT (natural vertical alignment) but fails for LR/RL cross-axis approaches
- Path structure must match layout direction: final segment axis controls arrow glyph
- Backward edges are complexity multipliers: waypoint reversal + multi-rank spanning + attachment calculation + path construction — any error cascades
- Face forcing is deterministic and necessary for LR/RL consistency
- `offset_from_boundary()` behavior depends entirely on attachment face — wrong face → wrong offset → disconnected path

## Open Questions

- Canvas boundary handling at x=0: `saturating_sub(1)` returns 0 — does rendering handle leftmost column correctly?
- Are there remaining code paths that still use H-V L-shaped paths for LR/RL?
- RL direction: the fix treats RL symmetrically (swapping left↔right). What test coverage exists for RL backward edges?
- When backward waypoints are reversed, do they still map correctly through `rank_cross_anchors` in all cases?
- Issues 5-6 (label detachment) were NOT fixed by 83d4877 — they require separate label placement changes (see Q3)
