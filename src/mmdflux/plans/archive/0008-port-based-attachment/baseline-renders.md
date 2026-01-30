# Baseline Renders (Before Port-Based Attachment)

These renders show the current behavior with forward-forward edge collisions.
After implementing port-based attachment, these should improve.

## skip_edge_collision.mmd

**Issue**: The long edge A→D overlaps with the short edges A→B→C→D

```
 ┌───────┐
 │ Start │
 └───────┘
     │
     ├┐
     │▼
 ┌────────┐
 │ Step 1 │
 └────────┘
     ││
     ││
     │▼
 ┌────────┐
 │ Step 2 │
 └────────┘
     ││
     ├┘
     ▼
  ┌─────┐
  │ End │
  └─────┘
```

**Problems:**
- `├┐` and `├┘` show edges merging at same column
- Not clear which edge is which
- Arrow into End is shared

## double_skip.mmd

**Issue**: A→C and A→D both skip nodes, creating confusing overlaps

```
 ┌───────┐
 │ Start │
 └───────┘
     ├┐
     ├┤
     ││
 ┌────────┐
 │ Step 1 │
 └────────┘
     ││
     ││
     │▼
 ┌────────┐
 │ Step 2 │
 └────────┘
     ││
     ├┘
     ▼
  ┌─────┐
  │ End │
  └─────┘
```

**Problems:**
- `├┐` and `├┤` show multiple edges stacked
- Hard to trace individual paths
- Ambiguous which edge goes where

## stacked_fan_in.mmd

**Issue**: Long edge Top→Bot overlaps with Top→Mid→Bot path

```
 ┌─────┐
 │ Top │
 └─────┘
    │
    │
    │
 ┌─────┐
 │ Mid │
 └─────┘
    │
    │
    ▼
 ┌─────┐
 │ Bot │
 └─────┘
```

**Problems:**
- Only shows what looks like 2 edges (Top→Mid, Mid→Bot)
- The Top→Bot long edge is completely hidden
- 3 edges defined but only 2 visible paths

## five_fan_in.mmd

**Note**: This actually renders reasonably well, but edge density is high

```
 ┌───┐    ┌───┐    ┌───┐    ┌───┐    ┌───┐
 │ A │    │ B │    │ C │    │ D │    │ E │
 └───┘    └───┘    └───┘    └───┘    └───┘
     │        │      │      │        │
     └────────┴──┬─┐ │ ┌─┬──┴────────┘
                 ▼ ▼ ▼ ▼ ▼
                ┌────────┐
                │ Target │
                └────────┘
```

**Notes:**
- 5 arrows `▼ ▼ ▼ ▼ ▼` are visible
- Junction characters `┬─┐` and `┌─┬` show edge merging
- Would benefit from port-based distribution into the target

---

## Expected Improvements After Implementation

With port-based attachment:

1. **skip_edge_collision.mmd**: Long edge A→D should exit from a different port on Start and enter a different port on End

2. **double_skip.mmd**: A→C and A→D should use separate exit ports from Start and separate entry ports on Step 2 and End

3. **stacked_fan_in.mmd**: Top→Bot should clearly route separately from Top→Mid path

4. **five_fan_in.mmd**: Edges should distribute evenly across the top of Target node
