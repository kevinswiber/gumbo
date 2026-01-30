# Q1: Canvas Top Margin and Vertical Trimming

## Summary

The canvas `Display` implementation only strips horizontal leading whitespace and trailing spaces per line — it does NOT trim empty leading rows. When stagger positioning in LR layouts places nodes with top padding, those top rows remain as blank lines in the output. The canvas allocation is correct; the issue is purely in the string conversion path. The fix is straightforward: add vertical trimming to skip leading (and trailing) empty rows.

## Where

- `src/render/canvas.rs` lines 187-228 — `Display` impl with horizontal-only trimming
- `src/render/canvas.rs` lines 193-200 — cell-to-string conversion, trailing space trimming
- `src/render/canvas.rs` lines 202-208 — minimum leading whitespace computation
- `src/render/canvas.rs` lines 210-227 — horizontal indentation stripping
- `src/render/layout.rs` lines 851-1007 — `grid_to_draw_horizontal()` canvas height computation
- `src/render/layout.rs` lines 876-894 — `max_column_content_height + 2 * padding` allocation
- `src/render/layout.rs` lines 927-949 — stagger positioning using `stagger_centers`
- `src/render/layout.rs` lines 989-998 — `final_height` recalculation from actual node bounds
- `src/render/layout.rs` lines 1017-1132 — `compute_stagger_positions()` mapping dagre cross-axis to draw Y
- `issues/0001-lr-layout-and-backward-edge-issues/issues.md` — Issue 1

## What

### Canvas Height Computation

For LR layouts, `max_column_content_height` is the maximum across all columns of (total node heights + spacing between nodes). Canvas is allocated at `max_column_content_height + 2 * padding`.

### Stagger Positioning

Targets get Y positions from `stagger_centers`, computed in `compute_stagger_positions()`. These map dagre's internal cross-axis coordinates to draw coordinates. The source node is centered: `y = padding + (max_column_content_height - height) / 2`.

After positioning, `final_height` is recomputed from actual node bounds — this correctly captures the vertical extent but doesn't push content upward.

### Display Implementation

The `fmt` method:
1. Converts each cell row to a string
2. Trims trailing spaces per line (line 198)
3. Computes `min_indent` as minimum leading whitespace across all non-empty lines (lines 203-208)
4. Strips horizontal indentation (lines 215-225)

**Critically: Empty rows (all spaces) are preserved in the output.** There is no logic to skip leading or trailing empty rows.

### Why Blank Rows Appear

Different layers in LR layouts can have different minimum Y values:
- Layer 1 (source A): Centers at Y ≈ 7 (middle of canvas)
- Layer 2 (targets B,C,D): May be positioned starting at Y ≈ 1 (via stagger)

This creates empty rows at the top of the canvas. The canvas is correctly allocated — content just doesn't naturally start at Y=0.

## How

**What's trimmed:**
- Trailing spaces on each line (`line.trim_end()`)
- Common leading horizontal whitespace

**What's NOT trimmed:**
- Leading empty rows (all spaces after horizontal trim)
- Trailing empty rows

The horizontal trimming approach was designed for centering diagrams left-to-right. The assumption that content fills from the top of the canvas breaks with stagger positioning in LR layouts, where nodes in different columns have different minimum Y values.

## Why

The stagger positioning is a feature of the dagre integration, where dagre computes optimal Y positions for nodes to minimize edge crossings and improve aesthetic layout. These positions are preserved in draw coordinates, which means content may not start at the top of the canvas.

The fix is straightforward — add vertical trimming to `Display::fmt()`:
```rust
let first_content_idx = lines.iter().position(|line| !line.is_empty()).unwrap_or(0);
let trimmed_lines = &lines[first_content_idx..];
```

## Key Takeaways

- Canvas allocation is correct — `final_height` recalculation properly accounts for stagger
- Node positioning is correct — stagger centers place nodes at intended dagre-derived positions
- Trimming is incomplete — `Display` only handles horizontal trimming, not vertical
- This is a Canvas-level issue in the string conversion path, not in layout/positioning logic
- The fix is simple and low-risk: skip leading (and optionally trailing) empty rows in `Display::fmt()`

## Open Questions

- Should trailing empty rows also be trimmed (defensive)?
- Is vertical trimming safe to apply unconditionally, or could there be cases where leading empty rows are intentional?
- Do TD/BT layouts with stagger positioning exhibit similar issues?
