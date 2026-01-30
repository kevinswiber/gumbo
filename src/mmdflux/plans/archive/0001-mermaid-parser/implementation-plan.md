# Mermaid Flowchart Parser Implementation Plan

## Status: 🚧 IN PROGRESS

## Overview

Implement a Mermaid flowchart parser for mmdflux using the `pest` PEG parser crate. This is the foundational component that converts Mermaid diagram text into graph data structures for layout and rendering.

## Current State

- CLI infrastructure exists in `src/main.rs` using clap
- `render()` function is a placeholder that echoes input
- No parser, AST, or graph structures exist yet
- Extensive research completed in `research/` directory

## Implementation Approach

### Syntax Scope (MVP)

| Feature | Syntax | Notes |
|---------|--------|-------|
| Graph Declaration | `graph TD`, `flowchart LR` | TB/TD synonyms |
| Directions | `TB`, `TD`, `LR`, `RL`, `BT` | Start with TB/LR |
| Node ID Only | `A`, `NodeName` | Bare identifier |
| Rectangle Shape | `A[text]` | Most common |
| Round Shape | `A(text)` | Rounded rectangle |
| Diamond Shape | `A{text}` | Decision nodes |
| Solid Arrow | `A --> B` | Primary edge |
| Edge Labels | `A -->\|label\| B` | Common usage |
| Chain Edges | `A --> B --> C` | Single line |
| Comments | `%% comment` | Line comments |

### File Structure

```
src/
├── main.rs                  # CLI entry point (existing)
├── lib.rs                   # Library root
├── parser/
│   ├── mod.rs               # Parser module root
│   ├── grammar.pest         # PEG grammar definition
│   ├── ast.rs               # Abstract Syntax Tree types
│   ├── flowchart.rs         # Pest parser integration
│   └── error.rs             # Parser error types
├── graph/
│   ├── mod.rs               # Graph module root
│   ├── diagram.rs           # Diagram struct
│   ├── node.rs              # Node types and shapes
│   ├── edge.rs              # Edge types and arrows
│   └── builder.rs           # AST to graph conversion
└── render.rs                # Placeholder for future
```

### Data Structures

**Node:**
```rust
pub struct Node {
    pub id: String,
    pub label: String,
    pub shape: Shape,
}

pub enum Shape {
    Rectangle,  // [text]
    Round,      // (text)
    Diamond,    // {text}
    Circle,     // ((text))
    // ... more shapes later
}
```

**Edge:**
```rust
pub struct Edge {
    pub from: String,
    pub to: String,
    pub label: Option<String>,
    pub stroke: Stroke,  // Solid, Dotted, Thick
    pub arrow: Arrow,    // start/end heads
}
```

**Diagram:**
```rust
pub struct Diagram {
    pub direction: Direction,
    pub nodes: HashMap<String, Node>,
    pub edges: Vec<Edge>,
    pub subgraphs: Vec<Subgraph>,
}
```

## Files to Modify/Create

| File | Action | Description |
|------|--------|-------------|
| `Cargo.toml` | Modify | Add pest, pest_derive, thiserror |
| `src/lib.rs` | Create | Library root with public API |
| `src/parser/mod.rs` | Create | Parser module exports |
| `src/parser/grammar.pest` | Create | PEG grammar rules |
| `src/parser/ast.rs` | Create | AST type definitions |
| `src/parser/flowchart.rs` | Create | Pest parser implementation |
| `src/parser/error.rs` | Create | Error types |
| `src/graph/mod.rs` | Create | Graph module exports |
| `src/graph/diagram.rs` | Create | Diagram container |
| `src/graph/node.rs` | Create | Node and Shape types |
| `src/graph/edge.rs` | Create | Edge and Arrow types |
| `src/graph/builder.rs` | Create | AST to graph conversion |
| `src/main.rs` | Modify | Integrate parser |
| `tests/integration.rs` | Create | End-to-end tests |

## Testing Strategy

1. **Unit Tests**: Test individual grammar rules in isolation
2. **Integration Tests**: Test complete flowchart parsing
3. **Golden Tests**: Compare output against known-good results
4. **Error Tests**: Verify helpful error messages with line/column info

### Test Sources
- Port test cases from mermaid-ascii `cmd/testdata/`
- Extract examples from Mermaid.js documentation
- Edge cases: empty labels, special characters, unicode

## Reference Files

- `/Users/kevin/src/mermaid/packages/mermaid/src/diagrams/flowchart/parser/flow.jison` - Official grammar
- `/Users/kevin/src/mmdflux/research/synthesis.md` - Architecture recommendations
- `/Users/kevin/src/mermaid-ascii/cmd/parse.go` - Patterns to avoid (regex fragility)
