# Q4: Does compute_stagger_positions() consider edge_sep, and should it?

## Summary

The proportional mapping formula in `compute_stagger_positions()` does NOT consider `edge_sep` at all — it only divides by `nodesep`. This is lossy because dagre's BK algorithm produces a `dagre_range` where dummy nodes are packed much tighter (using `edge_sep ≈ 2.4–10`) while real nodes are spaced at `nodesep ≈ 50`, but the proportional formula `target_stagger = (dagre_range / nodesep * (spacing + 2.0))` treats all nodes identically. A dummy-aware formula would need to compute the "equivalent spacing" based on the actual mix of dummy and real nodes in each layer, not assume all nodes are separated by `nodesep`.

## Where

- `/Users/kevin/src/mmdflux/src/render/layout.rs` — lines 1034–1157 (`compute_stagger_positions()` function and call sites at 363–401)
- `/Users/kevin/src/dagre/lib/position/bk.js` — lines 389–425 (`sep()` function in dagre.js reference implementation)
- `/Users/kevin/src/mmdflux/src/dagre/bk.rs` — lines 740–754 (Rust BK compaction with edge_sep distinction)
- `/Users/kevin/src/mmdflux/src/dagre/bk.rs` — lines 1849–1930 (unit tests for dummy/real node separation)
- `/Users/kevin/src/mmdflux/src/render/layout.rs` — lines 240–259 (dagre config creation with edge_sep values)

## What

### The Current Formula

Located at line 1103 of `/Users/kevin/src/mmdflux/src/render/layout.rs`:

```rust
let target_stagger = (dagre_range / nodesep * (spacing as f64 + 2.0))
    .round()
    .max(2.0)
    .min(max_layer_content as f64 / 2.0) as usize;
```

**Components:**
- `dagre_range`: Global cross-axis span from minimum to maximum dagre coordinate across all layers
- `nodesep`: The BK separation constant for real nodes (50.0 for TD/BT, or derived from avg node height for LR/RL)
- `spacing`: ASCII grid spacing (h_spacing=4 for TD/BT, v_spacing=3 for LR/RL)

**What the formula assumes:** All nodes in the layout were separated using `nodesep` distance.

**What's missing:** The formula completely ignores that dummy nodes were separated using `edge_sep`, which is significantly smaller.

### How dagre's BK Algorithm Distinguishes Nodes

In dagre.js reference implementation (`/Users/kevin/src/dagre/lib/position/bk.js`, lines 408–409):

```javascript
sum += (vLabel.dummy ? edgeSep : nodeSep) / 2;
sum += (wLabel.dummy ? edgeSep : nodeSep) / 2;
```

In mmdflux's Rust BK implementation (`/Users/kevin/src/dagre/bk.rs`, lines 743–753):

```rust
let left_sep = if is_dummy(graph, left) {
    config.edge_sep
} else {
    config.node_sep
};
let node_s = if is_dummy(graph, node) {
    config.edge_sep
} else {
    config.node_sep
};
let sep = (left_sep + node_s) / 2.0;
let min_separation = (left_width + node_width) / 2.0 + sep;
```

### Mmdflux's Actual edge_sep Values

From `/Users/kevin/src/mmdflux/src/render/layout.rs`, lines 240–259:

**For TD/BT (vertical layouts):**
- `node_sep = 50.0`, `edge_sep = 20.0`
- Ratio: edge_sep / nodesep = 0.4

**For LR/RL (horizontal layouts):**
```rust
let avg_height = total_height / num_nodes;
let node_sep = (avg_height * 2.0).max(6.0);
let edge_sep = (avg_height * 0.8).max(2.0);
```
- Example: avg_height = 8 → node_sep = 16.0, edge_sep = 6.4
- Ratio: edge_sep / nodesep ≈ 0.4

**Consistent pattern:** Dummy nodes are separated at 30–40% of the spacing used for real nodes.

## How

### Mathematical Analysis of the Formula

**Setup for worked example:**
- Layer with 2 real nodes + 3 dummy nodes
- Real node dimensions: 7 wide × 15 tall
- Dummy node dimensions: 1 wide × 1 tall
- Direction: TD/BT, spacing: h_spacing = 4
- dagre config: nodesep = 50.0, edge_sep = 20.0

**BK Compaction of this layer (left-to-right):**

| Gap | Pair | Separation | Position |
|-----|------|-----------|----------|
| — | Real1 | — | x = 0 |
| 1 | Real1→Dummy1 | (7+1)/2 + (50+20)/2 = 39 | x = 39 |
| 2 | Dummy1→Dummy2 | (1+1)/2 + 20 = 21 | x = 60 |
| 3 | Dummy2→Dummy3 | (1+1)/2 + 20 = 21 | x = 81 |
| 4 | Dummy3→Real2 | (1+7)/2 + (20+50)/2 = 39 | x = 120 |

**dagre_range = 120**

### Current Formula Result

```
target_stagger = (120 / 50.0) × (4 + 2.0)
               = 2.4 × 6
               = 14.4 → 14 (rounded)
```

### What Should It Be?

Average separation per gap:
```
(39 + 21 + 21 + 39) / 4 = 30 units per gap
```

Correct formula:
```
target_stagger = (120 / 30) × 6 = 4 × 6 = 24
```

**Error: Off by 71%**

### With Low edge_sep (LR/RL Config)

Using edge_sep = 2.4, nodesep = 8.0:

| Gap | Pair | Separation | Position |
|-----|------|-----------|----------|
| — | Real1 | — | x = 0 |
| 1 | Real1→Dummy1 | 4 + 5.2 = 9.2 | x = 9.2 |
| 2 | Dummy1→Dummy2 | 1 + 2.4 = 3.4 | x = 12.6 |
| 3 | Dummy2→Dummy3 | 1 + 2.4 = 3.4 | x = 16.0 |
| 4 | Dummy3→Real2 | 4 + 5.2 = 9.2 | x = 25.2 |

**dagre_range = 25.2**

Current formula: `(25.2 / 8.0) × 6 = 18.9 → 19`
Average separation: `(9.2 + 3.4 + 3.4 + 9.2) / 4 = 6.3`
Correct formula: `(25.2 / 6.3) × 6 = 24`

**Error: Off by ~26%** (less extreme but still significant)

### Why the Error Gets Worse

The error increases as:
1. edge_sep gets smaller relative to nodesep
2. The layer has more dummy nodes (more gaps use edge_sep)

The formula's assumption that separation = nodesep becomes increasingly false in dummy-heavy layers.

## Why

### Why the Formula is Lossy

1. **BK encodes the dummy/real mix in dagre_range.** Every separation step uses the appropriate constant (edge_sep or nodesep), so the resulting range faithfully records the layout.

2. **The proportional mapping erases that information.** By dividing only by `nodesep`, it assumes all separations were equal, destroying data about which nodes are dummy.

3. **This defeats the purpose of edge_sep.** The whole point of edge_sep < nodesep is to pack dummy nodes tightly. When stagger mapping ignores the distinction, the advantage is lost.

### What a Dummy-Aware Fix Would Look Like

```
For each layer:
  1. Sort nodes by their dagre cross-axis position
  2. For each consecutive pair, determine their types (dummy/real)
  3. Compute the separation each pair actually had in BK
  4. Average these separations
  5. Scale: target_stagger = (layer_dagre_range / avg_sep) × (spacing + 2.0)
```

This requires knowing which nodes are dummy at stagger-mapping time, which would need the information to be passed forward from the dagre stage.

## Key Takeaways

- **The formula is provably wrong for dummy-aware layouts.** It divides by `nodesep` when it should divide by the actual average separation, which is a weighted mix of `nodesep` and `edge_sep`.

- **The error magnitude is significant.** For typical configurations, the formula can be off by 25–70% depending on the dummy/real node mix in each layer.

- **The data exists to fix it.** Since mmdflux has `is_dummy()` checks in BK, and the layer composition is known at call time, the actual average separation per gap could be computed.

- **This is necessary but not sufficient.** Even with per-layer dummy-awareness, other pipeline stages (like `map_cross_axis()` waypoint interpolation) might further neutralize the effect. But it's a prerequisite fix.

- **Direct coordinate translation (Q5) would eliminate the problem entirely** by not using the lossy proportional formula at all.

## Open Questions

- How to pass BK separation data forward? Would need to store which separations were used between which node pairs, or recompute them from graph structure at stagger time.

- Is per-layer dummy-awareness enough? Or do subsequent transformations (especially `map_cross_axis()` waypoint interpolation) further homogenize the spacing?

- Would direct dagre-to-ASCII translation (Q5) eliminate the need for this fix? If Q3/Q5 recommend replacing stagger mapping entirely, this becomes a moot optimization.

- How does the aspect ratio factor (2.0) interact with sep ratio? The formula adds 2.0 to spacing (4 → 6, 3 → 5). If we adjust the sep part, should we also recalibrate the aspect ratio tuning?

- Are there test cases that would verify the fix works? Layers with predominantly dummy nodes (e.g., from fan-out patterns) should show visible improvement in compactness if the formula is fixed.
