# Q1: What does dagre.js's makeSpaceForEdgeLabels actually achieve?

## Summary

dagre.js's `makeSpaceForEdgeLabels` implements a **global transformation technique from the Gansner paper** that solves the label-placement problem by treating ranks as "split in half": it doubles ALL edge minlen values and halves ranksep globally. This creates an invariant where every edge, whether labeled or not, spans an even number of rank gaps, ensuring intermediate ranks exist as "dummy positions" where labels can be placed. The approach is **essential to the pipeline's correctness** because it creates rank-level alignment assumptions that downstream phases (normalization, ordering, positioning) depend on—removing the global constraint breaks these invariants.

## Where

**Sources consulted:**
- `/Users/kevin/src/dagre/lib/layout.js` — `makeSpaceForEdgeLabels` (lines 150-172), `injectEdgeLabelProxies` (lines 180-190), full pipeline orchestration
- `/Users/kevin/src/dagre/lib/rank/util.js` — `longestPath` algorithm using minlen (lines 31-59), `slack` calculation (lines 65-67)
- `/Users/kevin/src/dagre/lib/rank/feasible-tree.js` — tight tree construction respecting minlen (lines 33-95)
- `/Users/kevin/src/dagre/lib/rank/network-simplex.js` — network simplex algorithm using minlen constraints (lines 52-65)
- `/Users/kevin/src/dagre/lib/normalize.js` — long-edge normalization creating dummy nodes (lines 26-67)
- `/Users/kevin/src/dagre/lib/position/index.js` — positionY using halved ranksep (lines 17-40)
- `/Users/kevin/src/dagre/lib/util.js` — slack function and helper utilities

## What

### Effect 1: Global Rank Spacing Transformation

The function performs two critical transformations on lines 158-172:
```javascript
function makeSpaceForEdgeLabels(g) {
  let graph = g.graph();
  graph.ranksep /= 2;        // Halve vertical spacing between all ranks
  g.edges().forEach(e => {
    let edge = g.edge(e);
    edge.minlen *= 2;        // Double minimum rank distance for ALL edges
    if (edge.labelpos.toLowerCase() !== "c") {
      if (graph.rankdir === "TB" || graph.rankdir === "BT") {
        edge.width += edge.labeloffset;
      } else {
        edge.height += edge.labeloffset;
      }
    }
  });
}
```

What this does:
1. `ranksep` is halved globally (default 50 → 25). This affects ALL rank gap spacing in position phase.
2. `minlen` is doubled for EVERY edge, whether labeled or unlabeled (minlen 1 → 2).
3. Label width/height is augmented by labeloffset for horizontal spacing (only if label not centered).

### Effect 2: Creates Intermediate Rank Positions for Labels

When `minlen` is doubled to 2, the ranking algorithms (both longestPath and network-simplex) respect this constraint:
- An edge from rank N can now go to rank N+2 as a minimum
- The ranking phase ensures edges respect their new doubled minlen
- With all edges having minlen≥2, every edge spans an even number of ranks

The normalize phase (lines 40-64) then creates dummy nodes for long edges:
```javascript
if (wRank === vRank + 1) return;  // Don't normalize edges of length 1

g.removeEdge(e);
let dummy, attrs, i;
for (i = 0, ++vRank; vRank < wRank; ++i, ++vRank) {
  attrs = { width: 0, height: 0, edgeLabel: edgeLabel, edgeObj: e, rank: vRank };
  dummy = util.addDummyNode(g, "edge", attrs, "_d");
  if (vRank === labelRank) {
    attrs.width = edgeLabel.width;
    attrs.height = edgeLabel.height;
    attrs.dummy = "edge-label";
    attrs.labelpos = edgeLabel.labelpos;
  }
  // ... create edges through dummy chain
}
```

With minlen=2 globally, normalization creates a predictable structure: edges with minlen=2 don't need normalization, longer edges get dummy chains. **The intermediate ranks created by the minlen=2 constraint provide "slots" where label proxies can be positioned.**

### Effect 3: Label Proxy Injection at Midpoint Ranks

The `injectEdgeLabelProxies` function (lines 180-190) creates temporary dummy nodes at calculated midpoint ranks:
```javascript
function injectEdgeLabelProxies(g) {
  g.edges().forEach(e => {
    let edge = g.edge(e);
    if (edge.width && edge.height) {  // Only if label has dimensions
      let v = g.node(e.v);
      let w = g.node(e.w);
      let label = { rank: (w.rank - v.rank) / 2 + v.rank, e: e };
      util.addDummyNode(g, "edge-proxy", label, "_ep");
    }
  });
}
```

The critical calculation: `labelRank = (w.rank - v.rank) / 2 + v.rank`

This formula assumes:
- w.rank and v.rank differ by an EVEN number
- The result is an INTEGER rank

**With global minlen=2, this invariant is guaranteed:**
- Example 1: Edge from rank 0 to rank 2: midpoint = (2-0)/2 + 0 = 1 ✓ (integer)
- Example 2: Edge from rank 0 to rank 4: midpoint = (4-0)/2 + 0 = 2 ✓ (integer)
- Example 3 (WITHOUT global minlen=2): Edge from rank 0 to rank 3: midpoint = (3-0)/2 + 0 = 1.5 ✗ (fractional!)

This is the **critical invariant** that makes the global approach necessary.

### Effect 4: Rank Assignment Respects Doubled Minlen

The ranking algorithms (longestPath and network-simplex) enforce minlen constraints. Looking at longestPath in rank/util.js (lines 31-59):

```javascript
function longestPath(g) {
  var visited = {};
  function dfs(v) {
    let outEdgesMinLens = g.outEdges(v).map(e => {
      return dfs(e.w) - g.edge(e).minlen;  // <-- minlen constraint
    });
    var rank = applyWithChunking(Math.min, outEdgesMinLens);
    return (label.rank = rank);
  }
  g.sources().forEach(dfs);
}
```

With minlen=2:
- Starting from rank 0, an outgoing edge with minlen=2 means the target must be at rank 0-(-2) = 2 at minimum
- The ranking phase creates rank gaps of at least 2
- This distributes nodes further apart than default minlen=1

**Concrete example:**
- Graph: A → B → C (no labels, linear chain)
- With minlen=1: A(rank 0), B(rank 1), C(rank 2) — spans 2 rank levels
- With minlen=2: A(rank 0), B(rank 2), C(rank 4) — spans 4 rank levels

### Effect 5: Halved Ranksep Compensates Vertically

The positionY function (position/index.js, lines 15-40) assigns Y-coordinates using ranksep:

```javascript
function positionY(g) {
  let layering = util.buildLayerMatrix(g);
  let rankSep = g.graph().ranksep;  // Now 25 instead of 50
  let prevY = 0;
  layering.forEach(layer => {
    const maxHeight = layer.reduce((acc, v) => Math.max(acc, g.node(v).height), 0);
    layer.forEach(v => {
      let node = g.node(v);
      node.y = prevY + maxHeight / 2;
    });
    prevY += maxHeight + rankSep;  // Add spacing
  });
}
```

The halved ranksep (25 instead of 50) compensates for the increased rank count:
- With minlen=2, we have 2x as many ranks
- With ranksep/2, each rank gap is half as tall
- **Net effect:** Original nodes end up at similar vertical positions compared to minlen=1, ranksep=50

**Math example:**
- Scenario 1 (original): 3 nodes at ranks 0,1,2 with ranksep=50 → Y positions at 0, 50, 100
- Scenario 2 (minlen=2): 3 nodes at ranks 0,2,4 with ranksep=25 → Y positions at 0, 50, 100
- **Result:** Same final visual spacing, but with intermediate ranks available for labels

### Effect 6: Unlabeled Edges ARE Affected

**Critical fact:** Unlabeled edges (with width=0, height=0) ALSO get minlen doubled, but NO label proxy is created.

In injectEdgeLabelProxies (line 183):
```javascript
if (edge.width && edge.height) {  // Only create proxy if label has dimensions
```

**Consequence:**
- Unlabeled edges: minlen=2 (doubled), no proxy
- Labeled edges: minlen=2 (doubled), proxy created at midpoint
- Result: All edges are rank-spaced uniformly, but only labeled edges get explicit label positioning

This creates **consistent rank distribution** across the entire graph.

## How

### Pipeline Integration

The transformation happens early in the pipeline (layout.js runLayout, lines 30-57):

1. **makeSpaceForEdgeLabels()** ← Transforms graph: minlen×2, ranksep÷2
2. **acyclic.run()** ← Detects and reverses backward edges
3. **rank()** ← Assigns ranks respecting the new minlen=2 constraint
4. **injectEdgeLabelProxies()** ← Creates dummy nodes at midpoint ranks (calculated using the modified ranks)
5. **removeEdgeLabelProxies()** ← Extracts label rank info from proxies
6. **normalize.run()** ← Creates dummy node chains for long edges using the transformed minlen
7. **order()** ← Minimizes crossings (works with transformed rank structure)
8. **position()** ← Assigns coordinates using the halved ranksep

**Key insight:** Every subsequent phase assumes the doubled minlen and halved ranksep. The transformation must be global and applied before ranking because ranking depends on it.

### Why Global, Not Selective?

A targeted approach (minlen=2 only for labeled edges) fails because:

**1. Ranking Invariant Breaks:**
The ranking algorithms try to minimize edge length while respecting minlen. With mixed minlen values:
- Labeled edges (minlen=2) would push nodes apart
- Unlabeled edges (minlen=1) would pack them closer
- Result: Unpredictable, asymmetric rank spacing

**2. Label Rank Calculation Fails:**
The formula `(w.rank - v.rank) / 2 + v.rank` assumes even rank spacing.
- With global minlen=2: All rank differences are even → formula always produces integers
- With selective minlen: Some differences are odd → formula produces non-integers
- Result: Label proxies at fractional ranks cause coordinate truncation and crossing artifacts

**3. Ordering Phase Becomes Unstable:**
The layer-sweep crossing-reduction algorithm assumes consistent layer structure:
- With uneven ranks, layer matrices have holes and asymmetries
- Barycenter heuristic becomes less effective
- Result: Suboptimal or incorrect node ordering

**4. Position Phase Consistency:**
The positionY algorithm distributes vertical space based on rank count:
- Predictable rank count (with global minlen=2) → smooth vertical distribution
- Unpredictable rank count (with selective minlen) → fragile positioning
- Result: Vertical positions become unstable

## Why

### The Gansner Paper Insight

The Gansner et al. "Technique for Drawing Directed Graphs" paper observed that standard Sugiyama algorithm layouts place nodes on ranks but have nowhere to put edge labels. Their insight: **Conceptually "split" each rank in half.**

They proved that:
1. Doubling all edge minlen forces the ranking phase to create more rank gaps (approximately 2x as many)
2. Halving ranksep compensates so final visual scaling remains similar
3. These intermediate "virtual ranks" provide natural positions for edge labels
4. No changes needed to downstream algorithms—they work unchanged with the transformed graph

### Design Philosophy: Simplicity Through Uniform Treatment

Rather than adding special logic for labeled vs unlabeled edges throughout the pipeline, the approach applies a **single, uniform transformation** at the start:
- **Pro:** All edges treated identically by ranking, ordering, positioning phases
- **Pro:** No special cases or conditional logic in downstream phases
- **Pro:** Label proxy ranks are guaranteed to be integers
- **Pro:** Ranking algorithm produces consistent, predictable rank distributions
- **Con:** All edges get minlen doubled (slight layout overhead)
- **Con:** Graph has 2x as many ranks, though visually compressed

### The Tradeoff Matrix

| Aspect | Global Approach | Selective Approach |
|--------|-----------------|-------------------|
| **Rank consistency** | Uniform, predictable | Mixed, asymmetric |
| **Label rank formula** | Always integers | Potentially fractional |
| **Downstream phases** | Work unchanged | Need modifications |
| **Code complexity** | Minimal (single transform) | High (many special cases) |
| **Label placement reliability** | Guaranteed correct | Fragile, error-prone |
| **Unlabeled edge rendering** | Slightly more spread out | More compact |

## Key Takeaways

1. **`makeSpaceForEdgeLabels` is fundamentally a global transformation:** It modifies ALL edges and the graph configuration together. It's not optional or a convenience—it's essential for correctness.

2. **The approach creates a critical invariant:** All rank differences are even, ensuring label proxy midpoint calculations produce integers. Downstream phases depend on this.

3. **Unlabeled edges ARE affected:** They get minlen=2 but no label proxy. This uniform treatment is what makes the pipeline stable.

4. **Halved ranksep is not arbitrary:** It's carefully coordinated with doubled minlen to keep final visual spacing similar while creating intermediate ranks. Both transformations are needed together.

5. **The approach is pipeline-wide:** Every phase after the transformation (rank, normalize, order, position) works with doubled minlen and halved ranksep. You cannot selectively apply it—you must transform globally before ranking.

6. **Label proxy ranks must be integers:** The midpoint formula only works when rank differences are even. The global minlen=2 constraint guarantees this, preventing coordinate rounding errors and edge crossing artifacts.

7. **A targeted approach breaks the pipeline:** Applying minlen=2 only to labeled edges causes:
   - Unpredictable rank spacing (not uniform)
   - Fractional label proxy ranks (integer truncation)
   - Inconsistent layer structures (ordering phase fails)
   - Fragile position assignments (vertical spacing breaks)

## Open Questions

1. **What is the exact mathematical proof in the Gansner paper?** The code references the paper but doesn't provide formal justification. Reading the original would clarify the theoretical foundation.

2. **How sensitive is the BK horizontal coordinate assignment to the changed ranksep?** The positionX algorithm might have assumptions about ranksep or rank count that affect horizontal layout.

3. **Can ranksep halving be skipped?** Testing with minlen doubled but ranksep unchanged would reveal if they're tightly coupled or if one could be applied independently.

4. **Why is labeloffset added to edge width/height?** Is this for horizontal spacing during ordering, or for final rendering margin? Understanding this would clarify the label positioning mechanism.

5. **How does compound graph handling interact with this?** The nestingGraph phase runs after makeSpaceForEdgeLabels—does it rely on the transformed minlen/ranksep values, or does it compensate?

6. **What would a selective minlen approach need to succeed?** Would we need to modify ranking to handle mixed minlen, adjust the label rank formula, or add crossing-reduction logic? Is there a principled way to fix it?
