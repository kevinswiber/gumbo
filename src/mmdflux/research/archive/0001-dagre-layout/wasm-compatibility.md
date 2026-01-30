# WASM Compatibility Analysis for Dagre Layout Dependencies

This document analyzes WebAssembly compatibility for the Rust libraries being considered for the dagre-style graph layout implementation in mmdflux.

## 1. petgraph WASM Compatibility

### Summary: EXCELLENT

petgraph has **native no_std support** and is well-suited for WASM compilation.

### no_std Support

From the [petgraph documentation](https://docs.rs/petgraph/latest/petgraph/):
- The `std` feature is enabled by default but can be disabled
- Disabling `std` makes it possible to use petgraph in `no_std` contexts
- Uses `indexmap` and `hashbrown` with `default-features = false`

**Cargo.toml configuration for WASM:**
```toml
[dependencies]
petgraph = { version = "0.8", default-features = false }
```

### Features Available Without std

From examining the [petgraph Cargo.toml](https://github.com/petgraph/petgraph/blob/master/Cargo.toml):
- `graphmap` - works without std
- `stable_graph` - works without std (uses `serde?/alloc`)
- `matrix_graph` - works without std

Features that **require std**:
- `rayon` - parallel iterators (not needed for WASM single-threaded)
- `dot_parser` - DOT file parsing
- `quickcheck` - testing only

### Dependencies Analysis

| Dependency | no_std Compatible | Notes |
|------------|------------------|-------|
| fixedbitset | Yes | No std requirement |
| hashbrown | Yes | Pure Rust hash map |
| indexmap | Yes | See section 3 |

### WASM-Specific Projects

The [petgraph-wasm](https://github.com/urbdyn/petgraph-wasm) project exists as a proof-of-concept wrapper. While still a work-in-progress, it demonstrates that petgraph can successfully compile to WASM and be exposed to JavaScript.

**Performance characteristics from petgraph-wasm:**
- Toposort on 100,000 nodes with 900,000 edges: ~600ms
- Memory becomes a constraint at extreme scales (1M+ nodes)

### Verdict

petgraph is **WASM-safe**. Use with `default-features = false` for optimal WASM binary size.

---

## 2. rust-sugiyama WASM Compatibility

### Summary: MODERATE (Requires Modifications)

rust-sugiyama currently **uses std** and would need modifications for strict WASM compatibility, though it should compile to `wasm32-unknown-unknown` as-is.

### Current std Usage

From examining the source code:

```rust
// Found in src/lib.rs, src/algorithm/mod.rs, etc.
use std::collections::{BTreeMap, HashMap, HashSet, VecDeque};
use std::time::Instant;  // PROBLEMATIC for WASM
use std::env;             // PROBLEMATIC for WASM
```

### Compatibility Issues

| Usage | File | WASM Issue |
|-------|------|------------|
| `std::time::Instant` | src/lib.rs | No system time in WASM |
| `std::env` | src/configure.rs | No environment variables in WASM |
| `std::collections::*` | Multiple | Can be replaced with `alloc` equivalents |

### Dependencies

```toml
[dependencies]
log = "0.4.20"      # WASM compatible
petgraph = "0.8.1"  # WASM compatible (see above)
```

### Required Modifications for WASM

1. **Replace std::time::Instant with feature-gated timing:**
   ```rust
   #[cfg(feature = "std")]
   use std::time::Instant;

   #[cfg(not(feature = "std"))]
   fn now() -> () { () }  // No-op timing
   ```

2. **Replace std::env with configuration structs:**
   ```rust
   // Instead of reading from environment
   pub struct SugiyamaConfig {
       pub debug: bool,
       pub log_level: LogLevel,
   }
   ```

3. **Add no_std support:**
   ```rust
   #![cfg_attr(not(feature = "std"), no_std)]
   extern crate alloc;
   use alloc::collections::{BTreeMap, VecDeque};
   use hashbrown::{HashMap, HashSet};  // no_std hash maps
   ```

### Verdict

rust-sugiyama is **WASM-compilable with modifications**. The timing code is only for debugging and can be feature-gated. The core algorithm has no fundamental WASM incompatibilities.

---

## 3. indexmap WASM Compatibility

### Summary: EXCELLENT

indexmap has **first-class no_std support** and is widely used in WASM projects.

### no_std Support

From the [indexmap documentation](https://docs.rs/indexmap/latest/indexmap/):
- Since Rust 1.36, indexmap supports building without std
- Automatically detects when std is unavailable
- Requires `alloc` crate instead

### Limitations in no_std Mode

1. `new()` and `with_capacity()` are unavailable
2. Must use `default()`, `with_hasher()`, or `with_capacity_and_hasher()`
3. `indexmap!` macro unavailable (use `indexmap_with_default!` instead)

### WASM Usage in Production

indexmap is used by major WASM projects:
- wasmparser (WebAssembly parser)
- wasmtime (WebAssembly runtime)
- Many browser-targeted Rust projects

### Cargo.toml Configuration

```toml
[dependencies]
indexmap = { version = "2.5", default-features = false }
```

### Verdict

indexmap is **WASM-safe**. No modifications needed.

---

## 4. General WASM Considerations for Graph Layout

### Memory Management

WebAssembly has a **linear memory model** with some important characteristics:

1. **Memory pages are 64KiB** - allocations smaller than this waste space
2. **No garbage collection** - Rust's ownership model handles this
3. **Memory cannot be returned** - once allocated, pages stay allocated

**Recommendations:**
- Pre-allocate node/edge vectors when graph size is known
- Use `Vec::with_capacity()` to avoid reallocations
- Consider arena allocators for graph traversal temporary data

**Allocator options:**
- Default `dlmalloc` - works well, larger code size
- `talc` - smaller and faster for WASM, recommended for production
- `wee_alloc` - smallest but unmaintained, has memory leaks

### Performance Expectations

Based on [WASM performance benchmarks](https://dev.to/dataformathub/rust-webassembly-2025-why-wasmgc-and-simd-change-everything-3ldh):

| Metric | Expected Performance |
|--------|---------------------|
| vs JavaScript | 3-10x faster for compute-heavy tasks |
| vs Native Rust | 1.5-2x slower typically |
| SIMD operations | 10-15x faster than JS (when enabled) |

Graph layout is **ideal for WASM** because:
- CPU-intensive computation (good for WASM)
- Minimal DOM interaction needed
- No file I/O or network required
- Deterministic algorithms

### Serialization for JS Interop

**Recommended: serde-wasm-bindgen**

From the [serde-wasm-bindgen documentation](https://github.com/RReverser/serde-wasm-bindgen):
- Now the officially preferred approach over JSON-based serialization
- Smaller code size than JSON serialization
- Performance ranges from 1.6x slower to 3.3x faster than JSON depending on data

**Configuration:**
```toml
[dependencies]
serde = { version = "1.0", features = ["derive"] }
serde-wasm-bindgen = "0.6"
wasm-bindgen = "0.2"
```

**Example usage:**
```rust
use serde::{Serialize, Deserialize};
use wasm_bindgen::prelude::*;

#[derive(Serialize, Deserialize)]
pub struct LayoutResult {
    pub nodes: Vec<NodePosition>,
    pub edges: Vec<EdgePath>,
}

#[wasm_bindgen]
pub fn compute_layout(input: JsValue) -> Result<JsValue, JsError> {
    let diagram: Diagram = serde_wasm_bindgen::from_value(input)?;
    let result = layout_algorithm(&diagram);
    Ok(serde_wasm_bindgen::to_value(&result)?)
}
```

### JS-WASM Boundary Optimization

The boundary between JavaScript and WebAssembly has overhead. Minimize crossings by:

1. **Batch operations** - Pass entire graph, not individual nodes
2. **Return complete results** - All positions in one call
3. **Use TypedArrays** - For numeric data (coordinates)
4. **Avoid frequent small calls** - Layout should be one call

---

## 5. Recommendations

### Dependencies That Are Safe for WASM

| Crate | Status | Configuration |
|-------|--------|---------------|
| petgraph | Safe | `default-features = false` |
| indexmap | Safe | `default-features = false` |
| hashbrown | Safe | Already no_std |
| fixedbitset | Safe | Already no_std |
| serde | Safe | `default-features = false, features = ["derive", "alloc"]` |
| log | Safe | Works in WASM |

### Dependencies to Avoid or Gate

| Crate/Feature | Issue | Solution |
|---------------|-------|----------|
| rayon | Threading not available | Feature-gate, not needed for WASM |
| std::time | No system time | Use `web_time` crate or feature-gate |
| std::env | No environment | Use config structs instead |
| std::fs | No filesystem | Not needed for layout |
| std::net | No networking | Not needed for layout |

### Recommended Crate Structure

```toml
# Cargo.toml for WASM-compatible layout crate
[package]
name = "mmdflux-layout"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "rlib"]

[features]
default = ["std"]
std = ["indexmap/std", "petgraph/std"]
wasm = ["wasm-bindgen", "serde-wasm-bindgen"]

[dependencies]
petgraph = { version = "0.8", default-features = false, features = ["stable_graph"] }
indexmap = { version = "2.5", default-features = false }
serde = { version = "1.0", default-features = false, features = ["derive", "alloc"] }

# WASM-specific
wasm-bindgen = { version = "0.2", optional = true }
serde-wasm-bindgen = { version = "0.6", optional = true }

[profile.release]
opt-level = "z"      # Optimize for size
lto = true           # Link-time optimization
codegen-units = 1    # Better optimization
```

### Build Commands

```bash
# Native build
cargo build --release

# WASM build
cargo build --release --target wasm32-unknown-unknown --features wasm --no-default-features

# With wasm-pack (recommended)
wasm-pack build --target web --features wasm --no-default-features
```

### Testing WASM Compatibility

To verify a crate compiles for WASM:
```bash
cargo check --target wasm32-unknown-unknown --no-default-features
```

---

## Summary

| Component | WASM Ready | Effort Required |
|-----------|------------|-----------------|
| petgraph | Yes | None - use `default-features = false` |
| indexmap | Yes | None - use `default-features = false` |
| rust-sugiyama | Partial | Moderate - replace std::time, std::env |
| Custom layout | Yes | Design with WASM in mind from start |

**Overall Assessment:** The Rust ecosystem is well-prepared for WASM graph layout. petgraph and indexmap work out of the box. rust-sugiyama needs minor modifications but the core algorithm is portable. For best results, design the layout crate with WASM as a first-class target from the beginning.

---

## References

- [Rust and WebAssembly Book](https://rustwasm.github.io/book/reference/which-crates-work-with-wasm.html)
- [petgraph-wasm Project](https://github.com/urbdyn/petgraph-wasm)
- [serde-wasm-bindgen](https://github.com/RReverser/serde-wasm-bindgen)
- [WASM Memory Management Guide](https://radu-matei.com/blog/practical-guide-to-wasm-memory/)
- [Rust WebAssembly Performance 2025](https://dev.to/dataformathub/rust-webassembly-2025-why-wasmgc-and-simd-change-everything-3ldh)
- [Speeding Up WebCola with Rust/WASM](https://cprimozic.net/blog/speeding-up-webcola-with-webassembly/)
- [@antv/layout-wasm Benchmarks](https://www.npmjs.com/package/@antv/layout-wasm)
