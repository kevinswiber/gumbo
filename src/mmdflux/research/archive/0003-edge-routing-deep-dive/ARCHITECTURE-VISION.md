# mmdflux Edge Routing Architecture Vision

## Status: Research Complete → Ready for Implementation

This document synthesizes findings from the edge-routing-deep-dive research and outlines a comprehensive architecture overhaul rather than incremental patches.

**Research completed 2026-01-25.** All open questions answered. See `IMPLEMENTATION-PLAN.md` for next steps.

---

## The Problem with Shortcuts

We've been playing whack-a-mole:

1. **Backward edges exited right** → Problems with sibling nodes on same row
2. **Changed to exit from top** → Issues 1-4 emerged (missing arrows, label collision, overlapping edges, edge through node)
3. **Proposed fixes for Issues 1-4** → Each fix is a patch that doesn't address root causes

The root cause: **mmdflux's dagre module is missing core mechanisms** that make the real dagre work:

| Mechanism | Real Dagre | mmdflux Dagre | Impact |
|-----------|------------|---------------|--------|
| Dummy nodes for long edges | ✓ | ✗ | Issues 3, 4 |
| Edge labels as dummy nodes | ✓ | ✗ | Issue 2 |
| Dynamic intersection calculation | ✓ | ✗ | Issue 3 |
| Edge waypoints from dummy positions | ✓ | ✗ | Issue 4 |

---

## Three Missing Mechanisms

### 1. Dummy Nodes for Long Edges

**What it is:** Edges spanning more than 1 rank are split into chains of short edges connected by zero-size "dummy" nodes.

**How it works in dagre (`lib/normalize.js`):**
```javascript
function normalizeEdge(g, e) {
  // Edge from rank 0 to rank 3 becomes:
  // real_node → dummy_1 → dummy_2 → real_node
  // Each segment spans exactly 1 rank
}
```

**Why it matters:**
- Dummy nodes participate in crossing reduction
- Their positions become edge waypoints
- Edges naturally route around intermediate nodes

**See:** `issue-3-overlapping-edges.md`, `issue-4-edge-through-node.md`

### 2. Edge Labels as Layout Entities

**What it is:** Edge labels are converted to dummy nodes at the midpoint rank, with the label's bounding box as dimensions.

**How it works in dagre (`lib/normalize.js`):**
```javascript
if (vRank === labelRank) {
  attrs.width = edgeLabel.width;
  attrs.height = edgeLabel.height;
  attrs.dummy = "edge-label";
  attrs.labelpos = edgeLabel.labelpos;
}
```

**Why it matters:**
- Labels are positioned during coordinate assignment (not after rendering)
- Crossing reduction considers label positions
- Labels never collide with nodes or other labels
- Label position options: left (`"l"`), right (`"r"`), center (`"c"`)

**See:** `issue-2-label-collision.md`

### 3. Dynamic Intersection Calculation

**What it is:** Edge endpoints are computed by ray-casting from the edge's first/last waypoint to the node boundary, producing unique attachment points per edge.

**How it works in dagre (`lib/util.js`):**
```javascript
function intersectRect(rect, point) {
  // Returns the point where a line from rect.center to `point`
  // crosses the rect boundary
  // Different approach angles → different attachment points
}
```

**Why it matters:**
- Multiple edges to the same node side get different attachment points
- No need for port-based systems or fixed center points
- Works naturally with waypoints from dummy nodes

**See:** `issue-3-overlapping-edges.md`

---

## How These Mechanisms Interact

```
┌─────────────────────────────────────────────────────────────────┐
│                        LAYOUT PHASE                              │
├─────────────────────────────────────────────────────────────────┤
│  1. Acyclic (reverse cycle edges)                               │
│  2. Rank Assignment (nodes to layers)                           │
│  3. NORMALIZE EDGES ← Insert dummy nodes for long edges         │
│                     ← Insert label dummies at midpoint ranks    │
│  4. Crossing Reduction (order nodes+dummies within layers)      │
│  5. Coordinate Assignment (x,y for all nodes including dummies) │
│  6. DENORMALIZE ← Convert dummy positions to edge waypoints     │
│                 ← Extract label positions from label dummies    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                       ROUTING PHASE                              │
├─────────────────────────────────────────────────────────────────┤
│  For each edge:                                                  │
│  1. Get waypoints from layout (dummy positions)                  │
│  2. Compute intersection points at source/target boundaries      │
│  3. Convert waypoints to orthogonal segments (for ASCII)        │
│  4. Record entry direction for arrow rendering                   │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                      RENDERING PHASE                             │
├─────────────────────────────────────────────────────────────────┤
│  1. Render nodes                                                 │
│  2. Render edge segments (from computed paths)                   │
│  3. Render arrows (at intersection points)                       │
│  4. Render labels (at precomputed positions from layout)         │
└─────────────────────────────────────────────────────────────────┘
```

---

## ASCII-Specific Considerations

### Integer Grid Constraint

Dagre uses floating-point coordinates. mmdflux must:
- Round coordinates to integer grid
- Handle cases where rounding causes collisions
- Ensure minimum spacing between elements

### Orthogonal Routing

Dagre produces smooth curves via splines. mmdflux must:
- Convert waypoint sequences to orthogonal (horizontal/vertical) segments
- Handle waypoints that aren't axis-aligned

### Label Placement

Dagre places labels at exact positions. mmdflux must:
- Place horizontal text labels (no vertical text)
- Handle labels on vertical edge segments (offset to left/right)
- Ensure labels don't overlap edge characters

### Intersection Calculation

Dagre's `intersectRect` returns continuous coordinates. mmdflux must:
- Round to nearest character cell
- Handle cases where multiple edges round to same cell
- Possibly fall back to port-based distribution for ties

---

## Research Questions - ANSWERED

Research completed 2026-01-25. See detailed findings in:
- `normalize-deep-dive.md`
- `intersection-deep-dive.md`
- `ascii-adaptation.md`

### For Dummy Nodes ✓

**Q1: How does dagre's `normalize.js` handle edge labels with `labelpos` options?**

The `labelpos` attribute is stored on the edge label object, copied to the edge-label dummy's attributes during normalization, and preserved for the rendering phase. The normalize module doesn't interpret it—just passes it through.

**Q2: How are dummy nodes removed during `denormalize`?**

The `undo()` function walks each dummy chain via successor relationships, calling `g.removeNode(v)` on each dummy while recording their positions in `origLabel.points`.

**Q3: What data structure tracks the mapping from dummies back to original edges?**

Two mechanisms:
- `g.graph().dummyChains` array stores first dummy ID of each chain
- Each dummy has `edgeObj` attribute referencing the original edge `{v, w, name}`

### For Labels as Layout Entities ✓

**Q1: How is label width/height calculated before layout?**

Before calling normalize, the caller sets `edgeLabel.width` and `edgeLabel.height` based on text measurement. For ASCII, this is `label.len()` characters for width, 1 for height.

**Q2: How does the label dummy interact with crossing reduction?**

Label dummies are treated exactly like regular nodes in crossing reduction. Their non-zero dimensions ensure space is reserved, and barycenter ordering positions them to minimize crossings.

**Q3: What happens when a label is wider than the edge segment?**

The label dummy has its own width, so coordinate assignment allocates space for it. Other nodes and dummies shift to accommodate. In ASCII, we may need to enforce minimum spacing.

### For Intersection Calculation ✓

**Q1: How do we handle ties when rounding to integer grid?**

Three strategies (recommend starting with #1):
1. Accept ties for now—visual may be fine for ASCII
2. Add index-based spreading for tied edges
3. Implement port system for high-density cases

**Q2: Should we implement port-based fallback for high edge density?**

Not initially. The combination of dynamic intersection + dummy node separation + integer rounding should be sufficient. Add ports only if testing reveals problems.

**Q3: How does intersection interact with diamond/rounded node shapes?**

Each shape needs its own intersection formula:
- Rectangle: standard slope comparison (implemented)
- Diamond: line-rhombus intersection
- Rounded: approximate with rectangle (ASCII limitation)

### For ASCII Adaptation ✓

**Q1: What's the minimum node spacing to avoid segment collisions?**

Recommended minimums:
- Dummy nodes on same rank: 2 characters
- Labels: label width + 1 character buffer
- Corridor columns: 2 characters between

**Q2: How do we handle the case where a waypoint is inside a node's bounding box?**

Two options:
1. Push-outside logic: detect and offset to nearest boundary
2. Pre-scale: multiply coordinates by scale factor before rounding

Recommend starting with scale factor approach—simpler and prevents the problem.

**Q3: Should we pre-expand layout spacing to accommodate ASCII constraints?**

Yes. Use a configurable `SCALE_FACTOR` (default 1.0, increase if needed) applied to all dagre coordinates before integer rounding. This provides breathing room for:
- Edge separation
- Label placement
- Orthogonal path routing

---

## Relationship to Existing Research Files

| Research File | Relevant To | Key Insights |
|---------------|-------------|--------------|
| `issue-1-missing-arrow.md` | Rendering phase | Arrow render order matters; arrows should be drawn last |
| `issue-2-label-collision.md` | Labels as layout entities | Dagre treats labels as dummy nodes; mmdflux places opportunistically |
| `issue-3-overlapping-edges.md` | Intersection calculation, dummy nodes | Dagre uses `intersectRect`; mmdflux uses fixed center points |
| `issue-4-edge-through-node.md` | Dummy nodes | Dagre's dummy nodes enable implicit collision avoidance |
| `DUMMY-NODES-ARCHITECTURE.md` | Implementation plan | Detailed code changes for dummy node support |
| `normalize-deep-dive.md` | Dummy nodes, labels | Complete algorithm for normalization and denormalization |
| `intersection-deep-dive.md` | Intersection calculation | Full `intersectRect` algorithm with shape variants |
| `ascii-adaptation.md` | ASCII constraints | Integer rounding, spacing, orthogonal paths |
| `IMPLEMENTATION-PLAN.md` | **Implementation** | Ordered phases with test cases |

---

## Next Steps

~~1. **Deep dive into dagre's normalize.js**~~ ✓ Complete - see `normalize-deep-dive.md`
~~2. **Deep dive into dagre's util.js intersectRect**~~ ✓ Complete - see `intersection-deep-dive.md`
~~3. **Prototype ASCII intersection**~~ ✓ Design complete - see `ascii-adaptation.md`
~~4. **Design label layout integration**~~ ✓ Covered in normalize deep dive
~~5. **Create implementation plan**~~ → **NOW**: see `IMPLEMENTATION-PLAN.md`

---

## Decision: Full Architecture vs. Patches

**We are choosing the full architecture approach** because:

1. Patches have proven to be whack-a-mole
2. The missing mechanisms are well-documented in dagre
3. The effort is bounded (~1000 lines of code total)
4. The result will be robust for future complex diagrams
5. mmdflux already has the dagre module structure to build on

The individual issue fixes (render order for arrows, segment index for labels) can still be applied as low-risk improvements, but the real solution is implementing the missing dagre mechanisms.
