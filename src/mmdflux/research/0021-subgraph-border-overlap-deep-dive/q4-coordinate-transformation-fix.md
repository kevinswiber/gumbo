# Q4: What would it take to use dagre bounds correctly in mmdflux?

## Summary

The core issue is a **coordinate frame mismatch**: the node position formula treats `rect.x` as a center and includes a right-edge offset term (`rect.width/2.0`), while `to_ascii()` treats coordinates as raw points. When `to_ascii()` is applied to dagre subgraph Rects (which are center-based), it systematically misplaces the bounds by roughly `width/2.0 * scale_x`. The correct approach is to either apply the full node position formula to dagre Rects, or use member-node draw positions (the current, correct approach).

## Where

Files read:
- `/Users/kevin/src/mmdflux-subgraphs/src/render/layout.rs` **lines 284-344** (node position formula), **lines 700-812** (subgraph bounds conversion), **lines 845-868** (`TransformContext::to_ascii()` method), **lines 548-573** (scale factor computation)
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/types.rs` **lines 63-79** (Rect definition with center-based x,y)
- `/Users/kevin/src/mmdflux-subgraphs/src/dagre/mod.rs` **lines 145-164** (how dagre nodes are extracted to LayoutResult)
- `/Users/kevin/src/mmdflux/plans/0026-subgraph-padding-overlap/findings/dagre-to-draw-coordinate-mismatch.md`

## What

### Node Position Formula (lines 300-344)

Two passes:

**Pass 1 - Raw center scaling (lines 303-304):**
```
cx = ((rect.x + rect.width/2.0 - dagre_min_x) * scale_x).round() as usize
cy = ((rect.y + rect.height/2.0 - dagre_min_y) * scale_y).round() as usize
```

The critical term is `rect.x + rect.width/2.0` — because `rect.x` is the **center** in dagre space, adding `width/2.0` gives the **right edge**.

**Pass 2 - Overhang correction & offset (lines 325-330):**
```
center_x = rc.cx + max_overhang_x
center_y = rc.cy + max_overhang_y
x = center_x - rc.w/2 + config.padding + config.left_label_margin
y = center_y - rc.h/2 + config.padding
```

### to_ascii() Transformation (lines 858-867)

```rust
fn to_ascii(&self, dagre_x: f64, dagre_y: f64) -> (usize, usize) {
    let x = ((dagre_x - self.dagre_min_x) * self.scale_x).round() as usize
        + self.overhang_x + self.padding + self.left_label_margin;
    let y = ((dagre_y - self.dagre_min_y) * self.scale_y).round() as usize
        + self.overhang_y + self.padding;
    (x, y)
}
```

Treats `dagre_x` and `dagre_y` as **raw coordinates**, scaling linearly with no special center handling.

### The Divergence

When converting a dagre Rect (where `.x` and `.y` are center coordinates):

**Node formula:** `(rect.x + rect.width/2.0 - dagre_min_x) * scale_x` — includes right-edge offset

**to_ascii():** `(rect.x - dagre_min_x) * scale_x` — **missing** the `rect.width/2.0` term

**Concrete error example:** If `rect.x=89.5`, `rect.width=50`, `dagre_min_x=89.5`, `scale_x=0.22`:
- Node formula: `((89.5 + 25.0 - 89.5) * 0.22).round() = 5`
- to_ascii(): `((89.5 - 89.5) * 0.22).round() = 0`
- Difference: **5 characters**

## How

### Correct Subgraph Rect Transformation

Given a dagre Rect (center-based: `x, y, width, height`):

**Step 1: Scale the center**
```
scaled_cx = ((rect.x + rect.width/2.0 - dagre_min_x) * scale_x).round()
scaled_cy = ((rect.y + rect.height/2.0 - dagre_min_y) * scale_y).round()
```

**Step 2: Apply overhang offset**
```
center_x = scaled_cx + max_overhang_x
center_y = scaled_cy + max_overhang_y
```

**Step 3: Compute top-left corner**
```
draw_x = center_x - scaled_width/2 + padding + left_label_margin
draw_y = center_y - scaled_height/2 + padding
```

Where:
```
scaled_width = (rect.width * scale_x).round()
scaled_height = (rect.height * scale_y).round()
```

### Gap Sufficiency Analysis

The dagre layout uses `rank_sep = 50.0`. For vertical layouts (TD/BT):
```
scale_y = (max_h + v_spacing) / (max_h + rank_sep) ≈ 0.113
```

So `50.0 dagre units → 50.0 * 0.113 ≈ 6 text rows`

This leaves room for:
- Top border: 1 row (`┌─ Title ─┐`)
- Bottom border: 1 row (`└────────┘`)
- Visual gap: 4 rows between adjacent subgraphs

### Alternative: Member-Node Approach (Current)

The current code (lines 721-747) uses already-transformed draw positions:

```rust
for node_id in &sg.nodes {
    if let (Some(&(x, y)), Some(&(w, h))) =
        (draw_positions.get(node_id), node_dims.get(node_id))
    {
        min_x = min_x.min(x);
        min_y = min_y.min(y);
        max_x = max_x.max(x + w);
        max_y = max_y.max(y + h);
    }
}
let border_x = min_x.saturating_sub(border_padding);
let border_y = min_y.saturating_sub(border_padding);
let border_right = max_x + border_padding;
let border_bottom = max_y + border_padding;
```

This is **correct and stable** because all nodes in `draw_positions` have already been through the full pipeline.

## Why

### Why the Node Position Formula Includes the Width Offset

`rect.x` is the **center** position. Adding `width/2.0` gives the right edge. Scaling this extent ensures node width is preserved in draw space. The overhang correction then shifts everything to prevent clipping.

### Why to_ascii() Doesn't Work for Rects

It was designed for **transforming points** (edge waypoints, label positions), not bounding boxes. It assumes input is already a point, not a center with an extent.

### Why the Member-Node Approach Was Chosen

1. **All transformations already applied** — node positions went through scaling, overhang, collision repair, rank gap enforcement
2. **No re-derivation needed** — uses final results directly
3. **Robust to pipeline changes** — adapts automatically if algorithms change
4. **Correct for practical cases** — subgraph bounds should encompass member nodes

The attempted fix using dagre Rects and `to_ascii()` was a regression because dagre coordinates need the full transformation, not just linear scaling.

## Key Takeaways

- **Node position formula uses right-edge offset**: `rect.x + rect.width/2.0` because `rect.x` is center
- **to_ascii() has no such offset**: treats input as a raw coordinate, creating systematic error for Rects
- **Member-node approach is correct**: operating in draw space guarantees consistency
- **Dagre bounds need the full formula**: if Rect bounds are needed, apply the same formula as nodes
- **Gap is sufficient**: ~6 text rows from `rank_sep=50.0` allows borders + visual separation
- **Overhang correction is critical**: prevents wide left-positioned nodes from clipping to x=0

## Open Questions

- Could `dagre_bounds` be used as a fallback when member nodes don't span the full subgraph?
- Should `rankSep` be exposed as a configuration option to control inter-subgraph spacing?
- Could `TransformContext::to_ascii()` be extended to handle Rect coordinates explicitly?
- How do the border padding constants (`border_padding=2`) relate to typical scale factors?
