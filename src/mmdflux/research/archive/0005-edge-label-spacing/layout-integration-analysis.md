# Layout Integration Analysis

## Executive Summary

The infrastructure for layout-time label positioning **already exists** in mmdflux but has significant gaps that cause the current label overlap issues. The fix requires completing the existing system rather than building something new.

## Current Architecture

### Data Flow

```
Diagram
   │
   ▼
compute_layout_dagre()          ← Collects edge labels with dimensions
   │
   ▼
dagre::layout_with_labels()     ← Passes labels to normalization
   │
   ├─► normalize::run()         ← Creates EdgeLabel dummy nodes (ONLY for long edges)
   │      │
   │      ▼
   │   order::run()             ← Dummy nodes participate in crossing reduction
   │      │
   │      ▼
   │   position::run()          ← Positions dummies with node spacing
   │
   ▼
normalize::get_label_position() ← Extracts label positions from dummies
   │
   ▼
Layout {
    edge_label_positions: HashMap<(String, String), (usize, usize)>
}
   │
   ▼
render_all_edges_with_labels()
   │
   ├─► Pre-computed position exists? → draw_label_at_position()
   │
   └─► Fallback → draw_edge_label_with_tracking() → OVERLAP ISSUES
```

### Key Files and Functions

| File | Function | Purpose |
|------|----------|---------|
| `layout.rs:231-249` | `compute_layout_dagre()` | Collects edge labels |
| `layout.rs:268-273` | `compute_layout_dagre()` | Calls dagre with labels |
| `layout.rs:469-476` | `compute_layout_dagre()` | Extracts label positions |
| `dagre/mod.rs:63-68` | `layout_with_labels()` | Entry point for dagre |
| `dagre/mod.rs:86` | `layout_with_labels()` | Calls normalize with labels |
| `dagre/mod.rs:98-103` | `layout_with_labels()` | Extracts label positions |
| `dagre/normalize.rs:192-228` | `run()` | Creates label dummies |
| `dagre/normalize.rs:232-309` | `normalize_edge()` | Inserts dummy nodes |
| `dagre/normalize.rs:358-375` | `get_label_position()` | Returns label center |
| `edge.rs:454-515` | `render_all_edges_with_labels()` | Renders with label positions |
| `edge.rs:481-498` | (within above) | Uses pre-computed positions |

## Identified Gaps

### Gap 1: Only Long Edges Get Label Dummies

**Location:** `dagre/normalize.rs:210-215`

```rust
// Only normalize edges that span more than 1 rank
if to_rank > from_rank + 1 {
    long_edges.push((from_idx, to_idx, orig_edge_idx, from_rank, to_rank));
}
```

**Impact:** Short edges (spanning exactly 1 rank) don't get normalized, so they never have label dummies created, so they never have pre-computed label positions.

**Example:**
```
graph TD
    A -->|label| B   ← A at rank 0, B at rank 1 (span = 1, NOT normalized)
```

This is the **most common case** - and it falls back to heuristic placement.

### Gap 2: Coordinate Transformation Incomplete

**Location:** `layout.rs:469-476`

```rust
// Convert label_positions from edge index to (from, to) key
for (edge_idx, pos) in &result.label_positions {
    if let Some(edge) = diagram.edges.get(*edge_idx) {
        let key = (edge.from.clone(), edge.to.clone());
        edge_label_positions_converted
            .insert(key, (pos.x.round() as usize, pos.y.round() as usize));
    }
}
```

Compare with waypoint transformation (lines 414-467):
- Waypoints get proper rank-based transformation using `layer_starts`
- Label positions just get rounded - no transformation applied

**Impact:** Even for long edges, the label positions may be incorrect because they're in dagre coordinate space, not draw coordinate space.

### Gap 3: Non-Dagre Layout Path Has No Labels

**Location:** `layout.rs:91-186` (`compute_layout()` - the non-dagre path)

The original `compute_layout()` function doesn't process edge labels at all:
```rust
Layout {
    // ...
    edge_waypoints: HashMap::new(),     // Empty
    edge_label_positions: HashMap::new(), // Empty
    // ...
}
```

**Impact:** If dagre layout isn't used, label positions are never computed.

### Gap 4: Fallback Rendering Has Overlap Issues

When pre-computed positions aren't available, `render_all_edges_with_labels()` falls back to `draw_edge_label_with_tracking()`, which has all the issues identified in the original research:
- No check for edge character collision
- Hard-coded 1-character offsets
- Overwrites edge path characters

## What Works vs What Doesn't

### Works ✓

- Long edges (spanning 2+ ranks) get label dummies
- Label dummies participate in crossing reduction
- Label dummies get positioned with proper spacing from nodes
- Pre-computed positions are used when available

### Doesn't Work ✗

- **Short edges** (most common) don't get label dummies
- Coordinate transformation for label positions is incomplete
- Non-dagre layout has no label support
- Fallback rendering overwrites edge characters

## Recommended Fix Strategy

### Phase 1: Fix Short Edge Labels (High Impact)

Create label positions for ALL edges, not just long ones.

**Option A: Add label dummies for short edges too**

Modify `normalize::run()` to create a label dummy even for span-1 edges:
- Insert a "virtual" rank between source and target
- Create label dummy at that rank
- This preserves Dagre's dummy node approach

**Option B: Compute label positions during coordinate assignment**

Add a post-processing step in `position::run()` that computes label positions for edges without dummies:
- For each edge without a label dummy, calculate midpoint
- Store in a separate map
- Merge with dummy-derived positions

**Recommendation:** Option B is simpler and less invasive.

### Phase 2: Fix Coordinate Transformation

Apply the same transformation to label positions as waypoints:

```rust
// In compute_layout_dagre(), transform label positions like waypoints
for (edge_idx, pos) in &result.label_positions {
    if let Some(edge) = diagram.edges.get(*edge_idx) {
        let key = (edge.from.clone(), edge.to.clone());

        // Transform using layer_starts (like waypoints do)
        let (x, y) = if is_vertical {
            let y = layer_starts.get(/* label rank */).copied().unwrap_or(0);
            let x = pos.x.round() as usize;
            (x, y)
        } else {
            // Similar for horizontal
        };

        edge_label_positions_converted.insert(key, (x, y));
    }
}
```

### Phase 3: Add Spacing Buffer

Labels need a minimum distance from edge paths:

1. **During layout:** When computing label position, add offset perpendicular to edge direction
2. **During rendering:** Before writing label, verify no edge characters at that position

### Phase 4: Improve Fallback Rendering

Even with good pre-computed positions, we need a safe fallback:

1. Add `is_edge` flag to `Cell` struct
2. Mark edge cells during segment rendering
3. Check `is_edge` in collision detection
4. Refuse to overwrite edge cells (shift instead)

## Implementation Order

1. **Phase 2 first** - Fix coordinate transformation (low risk, might fix some cases)
2. **Phase 1** - Add short edge label positions (main fix)
3. **Phase 4** - Improve fallback (safety net)
4. **Phase 3** - Add spacing buffer (polish)

## Code Changes Summary

| File | Change |
|------|--------|
| `dagre/normalize.rs` | Option: Handle span-1 edges |
| `dagre/position.rs` | Add label position computation for all edges |
| `dagre/mod.rs` | Extract label positions for all edges |
| `layout.rs` | Fix coordinate transformation for labels |
| `render/canvas.rs` | Add `is_edge` flag |
| `render/edge.rs` | Mark edge cells, check in collision detection |

## Estimated Complexity

- Phase 1: Medium (core fix)
- Phase 2: Low (transformation fix)
- Phase 3: Low (add offset)
- Phase 4: Medium (canvas changes + collision logic)

Total: ~300-400 lines of changes across 5-6 files.
