# Issue 02: Skip-edge stagger missing — nodes not offset, edges pass behind nodes

**Severity:** High
**Category:** Dagre coordinate assignment / BK algorithm
**Status:** Fixed (Plan 0020, Phase 2 + Phase 5)
**Affected fixtures:** `double_skip`, `skip_edge_collision`, `stacked_fan_in`

## Description

When a graph has edges that skip ranks (e.g., A→C bypassing B), Mermaid offsets
nodes progressively along the cross-axis so skip edges have clear visual space.
mmdflux places all nodes at approximately the same x-position, forcing skip
edges to route along node borders — often passing visually behind or through
intermediate node boxes.

## Reproduction

### double_skip.mmd

```
graph TD
    A[Start] --> B[Step 1]
    B --> C[Step 2]
    C --> D[End]
    A --> C
    A --> D
```

```
cargo run -q -- tests/fixtures/double_skip.mmd
```

**mmdflux output:**
```
      ┌───────┐
      │ Start │
      └───────┘
       ┌┘ │└───┐
       ▼  │    │
┌────────┐│    │
│ Step 1 ││    │
└────────┘┘    │
     │         │
   ┌─┤         │
   ▼ ▼         │
┌────────┐     │
│ Step 2 │     │
└────────┘┌────┘
      │   │
      └──┐│
         ▼▼
       ┌─────┐
       │ End │
       └─────┘
```

Step 1 and Step 2 are flush-left at the same x-position. The Start→Step 2 skip
edge runs down the right border of the Step 1 box (`│` touching `┘`). The
Start→End edge also hugs the right side. No x-axis stagger.

### skip_edge_collision.mmd

```
graph TD
    A[Start] --> B[Step 1]
    B --> C[Step 2]
    C --> D[End]
    A --> D
```

**mmdflux output:**
```
  ┌───────┐
  │ Start │
  └───────┘
     │ └──┐
     ▼    │
┌────────┐│
│ Step 1 ││
└────────┘│
     │    │
     │    │
     ▼    │
┌────────┐│
│ Step 2 ││
└────────┘┘
     ││
     ││
     ▼▼
   ┌─────┐
   │ End │
   └─────┘
```

The Start→End skip edge passes directly along the right border of Step 1 and
Step 2 boxes. The `│` merges with `┘` at Step 2's right border.

### stacked_fan_in.mmd

```
graph TD
    A[Top] --> B[Mid]
    B --> C[Bot]
    A --> C
```

**mmdflux output:**
```
 ┌─────┐
 │ Top │
 └─────┘
   │└───┐
   ▼    │
┌─────┐ │
│ Mid │ │
└─────┘─┘
   ││
   ││
   ▼▼
 ┌─────┐
 │ Bot │
 └─────┘
```

The Top→Bot skip edge hugs Mid's right border. The `─┘` at Mid's bottom-right
shows the edge merging into the node border.

## Expected behavior

Mermaid offsets nodes along the x-axis to create visual space for skip edges:

**double_skip.svg Mermaid positions:**
| Node   | X     | Y   |
|--------|-------|-----|
| Start  | 147.9 | 35  |
| Step 1 | 60.4  | 139 |
| Step 2 | 104.2 | 243 |
| End    | 147.9 | 347 |

Diagonal stagger: Step 1 leftmost, Step 2 middle, Start/End rightmost. Skip
edges route through the open space created by this stagger.

## Root cause (confirmed by research/0015, Q5)

The BK algorithm always computed correct dummy-node separation that produces
stagger. The root cause was in the rendering pipeline: `compute_layout_direct()`
in `src/render/layout.rs` used `saturating_sub` to compute draw positions from
dagre centers. When a wide node's half-width exceeded its raw center coordinate
(common for left-positioned nodes), `saturating_sub` clipped to zero, collapsing
multiple nodes to the same column and destroying BK-computed separations.

The initial hypothesis (above) and research 0013 Q2's conclusion that BK needed
a block graph for stagger were both incorrect.

## Resolution

**Plan 0020, Phase 2** (commit `ed803b8`): Fixed via two-pass overhang offset —
a uniform coordinate-space translation that preserves all BK-computed
separations. This revealed the stagger that BK had produced all along.

**Plan 0020, Phase 5** (commit `1846cfb`): Extended the overhang offset to
waypoints and label positions, giving skip edges proper clearance from node
borders.

**Plan 0022** (block graph compaction): Replaced recursive `place_block` with
two-pass block graph algorithm. Node positions unchanged for all fixtures;
only edge routing details changed. Confirmed that BK was already correct.

The fix is robust and intentional: it is a mathematically correct coordinate
transformation that preserves all BK-computed separations.
