# 05: Dagre Version Mismatch

## Discovery

The prior research (docs 00-04) analyzed dagre from `$HOME/src/dagre`, which is at **v2.0.4-pre** (HEAD of the main branch). However, Mermaid uses **dagre-d3-es@7.0.13**, which is an ESM wrapper around **dagre v0.8.5**. The ordering algorithm differs between these versions.

## Version Comparison

### What Mermaid uses: dagre v0.8.5

Tag `v0.8.5` in the dagre repo. Confirmed by comparing `lib/order/index.js` at that tag against the copy shipped in `mermaid/node_modules/.pnpm/dagre-d3-es@7.0.13/`.

### What we analyzed: dagre v2.0.4-pre (HEAD)

The latest development version includes features added after v0.8.5.

## Differences Found in `lib/order/index.js`

### 1. `cc === bestCC` overwrite (NOT in v0.8.5)

v2.0.4-pre adds an `else if` branch that overwrites `best` when crossing count equals the current best:

```javascript
// v2.0.4-pre (HEAD)
if (cc < bestCC) {
  lastBest = 0;
  best = Object.assign({}, layering);
  bestCC = cc;
} else if (cc === bestCC) {       // <-- NOT in v0.8.5
  best = structuredClone(layering);
}
```

v0.8.5 only saves on strict improvement:

```javascript
// v0.8.5 (what Mermaid uses)
if (cc < bestCC) {
  lastBest = 0;
  best = _.cloneDeep(layering);
  bestCC = cc;
}
// No else-if branch
```

**Impact:** When all orderings produce equal crossing counts (common for fan-in/fan-out with no crossings), v2.0.4-pre keeps overwriting `best` with each sweep's result. The last sweep before termination uses `biasRight=true`, which reverses sibling order. v0.8.5 preserves the first good ordering (from `initOrder`), which respects declaration order.

This caused 10 of 26 test fixtures to produce reversed node orderings compared to Mermaid.

### 2. `customOrder` callback (NOT in v0.8.5)

v2.0.4-pre supports an `opts.customOrder` callback:

```javascript
function order(g, opts = {}) {
  if (typeof opts.customOrder === 'function') {
    opts.customOrder(g, order);
    return;
  }
  // ...
```

Not present in v0.8.5. Mermaid calls `dagreLayout(graph)` with no options.

### 3. `constraints` parameter (NOT in v0.8.5)

v2.0.4-pre passes `constraints` to `sweepLayerGraphs`:

```javascript
const constraints = opts.constraints || [];
sweepLayerGraphs(..., constraints);
```

v0.8.5 has no constraints support.

### 4. `disableOptimalOrderHeuristic` (NOT in v0.8.5)

v2.0.4-pre supports skipping the optimization loop entirely:

```javascript
if (opts.disableOptimalOrderHeuristic) {
  return;
}
```

Not present in v0.8.5.

## Files Potentially Affected

The version differences are concentrated in `lib/order/`. Files to audit against v0.8.5:

| File | Status |
|------|--------|
| `lib/order/index.js` | **Confirmed different** - see above |
| `lib/order/init-order.js` | Needs audit |
| `lib/order/sort-subgraph.js` | Needs audit |
| `lib/order/sort.js` | Needs audit |
| `lib/order/barycenter.js` | Needs audit |
| `lib/order/resolve-conflicts.js` | Needs audit |
| `lib/order/cross-count.js` | Needs audit |
| `lib/order/build-layer-graph.js` | Needs audit |
| `lib/order/add-subgraph-constraints.js` | Needs audit |

Other dagre modules (rank, position, etc.) may also differ but are outside the scope of this investigation.

## Immediate Fix

Remove the `else if (cc == best_cc)` branch from `src/dagre/order.rs` to match v0.8.5 behavior. This is the only confirmed difference that affects our current implementation, since we don't use `customOrder`, `constraints`, or `disableOptimalOrderHeuristic`.

## Next Steps

After validating the fix, audit remaining `lib/order/` files by diffing v0.8.5 against HEAD to identify any other behavioral differences that may have been carried into our Rust port.
