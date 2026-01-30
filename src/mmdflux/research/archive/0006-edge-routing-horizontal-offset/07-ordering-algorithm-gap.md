# Ordering Algorithm Gap: Why Mermaid Renders Differently

## Executive Summary

After implementing the Brandes-Kopf coordinate assignment algorithm (Plan 0011), `complex.mmd` still renders differently from Mermaid. Investigation reveals the root cause is **node ordering within layers**, not coordinate assignment.

**Key Finding:** The Brandes-Kopf algorithm positions nodes optimally *within their assigned order*. But if the order itself places nodes on the wrong side of the diagram, BK can't fix that. The ordering algorithm (`order.rs`) is the actual gap.

---

## Visual Comparison

### Mermaid's Layout

```
        ┌───────┐
        │ Input │◄──────────┐
        └───────┘           │
            │               │
            ▼               │
        ┌──────────┐        │
        │ Validate │        │
        └──────────┘        │
           │    │           │
     valid │    │ invalid   │ yes
           ▼    ▼           │
      ┌─────────┐  ┌───────────────┐
      │ Process │  │ Error Handler │
      └─────────┘  └───────────────┘
           │              │    │
           ▼              ▼    ▼
    ┌────────────┐  ┌─────────┐ ┌──────────────┐
    │ More Data? │  │Log Error│ │ Notify Admin │
    └────────────┘  └─────────┘ └──────────────┘
         │ no              └────┬────┘
         │                      ▼
         │               ┌─────────┐
         │               │ Cleanup │
         │               └─────────┘
         │                    │
         └──────────┬─────────┘
                    ▼
               ┌────────┐
               │ Output │
               └────────┘
```

**Key characteristics:**
- Main flow (Input → Validate → Process → More Data?) on **LEFT**
- Error handling branch on **RIGHT**
- Backward edge ("yes" loop) goes up the **LEFT** side
- Output receives edges from nearby nodes

### mmdflux's Layout

```
                                  ┌───────┐
                                  │ Input │◄────────────────────────┐
                                  └───────┘                         │
                                      │                             │
                                      ▼                             │
                                ┌──────────┐                        │
                                < Validate >                        │
                                └──────────┘                        │
                                    │   │                           │
                             ┌──────┘   └────────┐              yes │
                     invalid │                   │ valid            │
                             ▼                   ▼                  │
                   ╭───────────────╮           ┌─────────┐          │
                   │ Error Handler │           │ Process │          │
                   ╰───────────────╯           └─────────┘          │
                        │    │                        │             │
               ┌────────┘    └──────┐                 │             │
               ▼                    ▼                 ▼             │
      ┌───────────┐           ┌──────────────┐  ┌────────────┐      │
      │ Log Error │           │ Notify Admin │  < More Data? >──────┘
      └───────────┘           └──────────────┘  └────────────┘
                                                      │ no
                                 ┌─────────┐          │
                                 │ Cleanup │◄─────────┤
                                 └─────────┘          │
                                      │               │
                                      ▼               ▼
                                 ┌────────┐
                                 │ Output │
                                 └────────┘
```

**Key characteristics:**
- Error Handler on **LEFT**, Process on **RIGHT** (swapped!)
- More Data? on **RIGHT** side
- Backward edge goes up the **RIGHT** side
- Output centered, edges cross from both sides

---

## Root Cause Analysis

### What We Thought Was the Problem

The research in `05-full-dagre-parity-analysis.md` identified coordinate assignment as the gap:
> "The gap is primarily in **coordinate assignment** - Dagre uses Brandes-Kopf optimization while mmdflux uses simple layer centering."

### What the Actual Problem Is

After implementing Brandes-Kopf (Plan 0011), the layout still differs. The actual gap is in **Phase 3: Ordering**, not Phase 4: Positioning.

The BK algorithm works correctly - it positions nodes optimally within their assigned order. But the **order itself** is wrong. Nodes end up on the wrong side of the diagram before BK even runs.

---

## Technical Details

### Dagre's Ordering Algorithm

From `02-dagre-edge-routing.md`:

```javascript
function order(g, opts = {}) {
  for (let i = 0, lastBest = 0; lastBest < 4; ++i, ++lastBest) {
    sweepLayerGraphs(
      i % 2 ? downLayerGraphs : upLayerGraphs,
      i % 4 >= 2,  // biasRight: true for iterations 2,3
    );
    // ...
  }
}
```

**Key features:**
1. **Bias parameter**: Alternates between left-bias (i=0,1) and right-bias (i=2,3)
2. **Reset on improvement**: Continues until 4 iterations without improvement
3. **Edge weights**: Long edges carry their label weight through crossings

### mmdflux's Ordering Algorithm

From `src/dagre/order.rs`:

```rust
pub fn run(graph: &mut LayoutGraph) {
    // Initialize order based on current layer positions
    for layer in &layers {
        for (idx, &node) in layer.iter().enumerate() {
            graph.order[node] = idx;
        }
    }

    for _ in 0..MAX_ITERATIONS {
        sweep_down(graph, &layers, &edges);
        sweep_up(graph, &layers, &edges);
        // ...
    }
}
```

**Missing features:**
1. **No bias parameter**: Always uses stable sort with original position as tiebreaker
2. **No right-bias iterations**: Never explores right-biased orderings
3. **No edge weights**: All edges treated equally

---

## Why This Matters

### The Ordering Determines Layout Structure

Consider the graph structure:
```
A[Input] --> B{Validate}
B -->|valid| C[Process]      // Main flow
B -->|invalid| D[Error]      // Error branch
```

If ordering puts `C` left and `D` right:
- Main flow stays left
- Error handling stays right
- Clean visual separation

If ordering puts `D` left and `C` right:
- Flows cross each other
- More edge crossings
- Confusing layout

### Brandes-Kopf Can't Fix Bad Ordering

BK optimizes positions **within** the assigned order:
- If node A has order=0 and node B has order=1, BK places A left of B
- BK decides *how far* left/right, not *which side*

The ordering algorithm decides which nodes go left vs. right. BK just fine-tunes the distances.

---

## Specific Gaps in order.rs

### 1. Initial Ordering

**Dagre:** Uses `initOrder()` which may consider connectivity
**mmdflux:** Uses index in layer vector (arbitrary)

```rust
// Current: arbitrary order
for (idx, &node) in layer.iter().enumerate() {
    graph.order[node] = idx;
}
```

### 2. Bias Parameter

**Dagre:** Alternates `biasRight` between true/false
**mmdflux:** No bias, always uses original position for ties

```rust
// Current: always same tie-breaking
barycenters.sort_by(|a, b| {
    a.1.partial_cmp(&b.1)
        .unwrap_or(std::cmp::Ordering::Equal)
        .then_with(|| a.2.cmp(&b.2))  // Always original position
});
```

### 3. No Solution Space Exploration

**Dagre:** Runs 4 different bias configurations, keeps best
**mmdflux:** Runs same algorithm repeatedly, stops on plateau

---

## Potential Fixes

### Option A: Add Bias Parameter

Add a `bias_right` parameter to `reorder_layer()`:

```rust
fn reorder_layer(
    graph: &mut LayoutGraph,
    fixed: &[usize],
    free: &[usize],
    edges: &[(usize, usize)],
    downward: bool,
    bias_right: bool,  // NEW
) {
    // ...
    barycenters.sort_by(|a, b| {
        a.1.partial_cmp(&b.1)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| {
                if bias_right {
                    b.2.cmp(&a.2)  // Prefer later positions (right)
                } else {
                    a.2.cmp(&b.2)  // Prefer earlier positions (left)
                }
            })
    });
}
```

### Option B: Multiple Ordering Attempts

Try different orderings and keep best:

```rust
pub fn run(graph: &mut LayoutGraph) {
    let mut best_order = graph.order.clone();
    let mut best_crossings = usize::MAX;

    for bias_config in [false, false, true, true] {
        // Reset to initial
        reset_order(graph);

        // Run with this bias
        run_with_bias(graph, bias_config);

        let crossings = count_crossings(graph);
        if crossings < best_crossings {
            best_crossings = crossings;
            best_order = graph.order.clone();
        }
    }

    graph.order = best_order;
}
```

### Option C: Connectivity-Aware Initial Order

Initialize order based on graph structure:

```rust
fn init_order(graph: &mut LayoutGraph, layers: &[Vec<usize>]) {
    // For each layer, order nodes by:
    // 1. Connected component (keep related nodes together)
    // 2. Edge direction (sources left, sinks right)
    // 3. Input parse order (tiebreaker)
}
```

---

## Complexity Estimate

| Option | Lines | Risk | Impact |
|--------|-------|------|--------|
| A: Bias parameter | ~30 | Low | Medium |
| B: Multiple attempts | ~50 | Low | High |
| C: Smart initial order | ~80 | Medium | High |
| A + B combined | ~70 | Low | High |

---

## Recommendation

**Implement Option A + B together:**

1. Add `bias_right` parameter to `reorder_layer()`
2. Run ordering with 4 different bias configurations (like Dagre)
3. Keep the ordering with fewest crossings

This matches Dagre's approach and should produce similar results without major architectural changes.

**Note:** This is separate from and builds on the Brandes-Kopf work (Plan 0011). BK handles coordinate assignment correctly; this fixes the ordering that feeds into BK.

---

## References

- `02-dagre-edge-routing.md` - Dagre's ordering algorithm details
- `05-full-dagre-parity-analysis.md` - Original parity analysis (focused on BK)
- `src/dagre/order.rs` - Current ordering implementation
- Plan 0011 - Brandes-Kopf implementation (complete)
