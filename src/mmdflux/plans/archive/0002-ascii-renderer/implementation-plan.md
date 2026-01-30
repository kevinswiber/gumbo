# ASCII Renderer Implementation Plan

## Status: 🚧 IN PROGRESS

## Overview

Implement an ASCII/Unicode renderer for Mermaid flowcharts. The parser is complete and produces a `Diagram` struct with nodes, edges, and direction. The renderer will transform this graph representation into ASCII art using a grid-based layout approach with intelligent character merging.

## Current State

**Parser (Complete)**
- `src/parser/` - Pest-based parser for Mermaid flowchart syntax
- Produces `Flowchart` AST with statements

**Graph Model (Complete)**
- `src/graph/diagram.rs` - `Diagram` with `Direction`, `nodes: HashMap<String, Node>`, `edges: Vec<Edge>`
- `src/graph/node.rs` - `Node` with `id`, `label`, `shape` (Rectangle, Round, Diamond)
- `src/graph/edge.rs` - `Edge` with `from`, `to`, `label`, `stroke` (Solid, Dotted, Thick), `arrow` (Normal, None)

**CLI (Partial)**
- `src/main.rs` - Basic CLI with `--debug` flag, placeholder for rendering at lines 84-91

## Architecture

### Module Structure

```
src/
  render/
    mod.rs           # Public API: render(diagram) -> String
    canvas.rs        # Canvas: 2D grid with character metadata
    chars.rs         # CharSet: Unicode/ASCII character definitions
    layout.rs        # Layout: grid position assignment
    router.rs        # EdgeRouter: orthogonal path calculation
    shape.rs         # ShapeRenderer: draw nodes as boxes
    edge.rs          # EdgeRenderer: draw edges with arrows
```

### Data Flow

```
Diagram (from parser)
    ↓
Layout Phase (assign grid coords to nodes)
    ↓
Coordinate Mapping (grid → drawing coords with variable sizing)
    ↓
Node Rendering (draw boxes on canvas)
    ↓
Edge Routing (calculate paths)
    ↓
Edge Rendering (draw lines, arrows, labels)
    ↓
Canvas Serialization (to String)
```

## Core Data Structures

### Canvas

```rust
/// Connection directions for a cell
pub struct Connections {
    pub up: bool,
    pub down: bool,
    pub left: bool,
    pub right: bool,
}

/// A cell in the canvas with character and metadata
pub struct Cell {
    pub char: Option<char>,
    pub connections: Connections,
    pub is_node: bool,  // Protected from edge overwriting
}

/// 2D canvas for rendering
pub struct Canvas {
    width: usize,
    height: usize,
    cells: Vec<Cell>,  // row-major: cells[y * width + x]
}
```

### Character Set

Unicode box-drawing characters with ASCII fallback:
- Corners: `┌ ┐ └ ┘` (ASCII: `+ + + +`)
- Lines: `─ │` (ASCII: `- |`)
- T-junctions: `┬ ┴ ├ ┤` (ASCII: `+ + + +`)
- Cross: `┼` (ASCII: `+`)
- Arrows: `▲ ▼ ◄ ►` (ASCII: `^ v < >`)
- Rounded: `╭ ╮ ╰ ╯` (ASCII: `/ \ \ /`)

### Layout

```rust
/// Position in the logical grid
pub struct GridPos {
    pub col: usize,
    pub row: usize,
}

/// Layout result with positions for all nodes
pub struct Layout {
    pub node_positions: HashMap<String, GridPos>,
    pub col_widths: Vec<usize>,
    pub row_heights: Vec<usize>,
    pub direction: Direction,
}
```

## Implementation Phases

### Phase 1: Foundation (Canvas + Characters)
Create basic rendering infrastructure - canvas operations and character sets.

### Phase 2: Node Rendering
Render individual nodes as boxes with all shapes (Rectangle, Round, Diamond).

### Phase 3: Simple Layout (TD)
Position nodes in top-down layout using topological sort for layer assignment.

### Phase 4: Edge Routing
Calculate orthogonal paths between nodes, avoiding node boundaries.

### Phase 5: Edge Rendering
Draw edges with correct line characters, corners, and arrows.

### Phase 6: Edge Labels
Render labels on edges at midpoints of longest segments.

### Phase 7: LR Layout
Support left-to-right layout direction.

### Phase 8: Junction Merging
Smart character selection when edges cross or meet (`─` + `│` = `┼`).

### Phase 9: Polish
Handle BT/RL directions, edge cases, crossing minimization.

## Files to Create

| File | Purpose |
|------|---------|
| `src/render/mod.rs` | Public `render()` API and module exports |
| `src/render/canvas.rs` | 2D canvas with cell metadata |
| `src/render/chars.rs` | Unicode/ASCII character sets |
| `src/render/layout.rs` | Layer assignment and positioning |
| `src/render/router.rs` | Orthogonal edge path calculation |
| `src/render/shape.rs` | Node shape rendering |
| `src/render/edge.rs` | Edge line and arrow rendering |

## Files to Modify

| File | Changes |
|------|---------|
| `src/main.rs` | Replace placeholder with `render()` call, add `--ascii` flag |
| `src/lib.rs` | Export render module |

## Testing Strategy

1. **Unit tests** for each module (canvas ops, character selection, layout algorithms)
2. **Integration tests** in `tests/render_tests.rs` with expected output fixtures
3. **Fixture files** in `tests/fixtures/` with `.mmd` input and `.txt` expected output

## Expected Output Examples

Simple TD flowchart:
```
┌───┐
│ A │
└─┬─┘
  │
  ▼
┌───┐
│ B │
└───┘
```

LR flowchart:
```
┌───┐     ┌───┐     ┌───┐
│ A │────►│ B │────►│ C │
└───┘     └───┘     └───┘
```

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Complex layouts with many crossings | Start simple, add crossing minimization later |
| Unicode terminal support | Provide `--ascii` fallback |
| Cycles in graph | Detect and break back-edges during layer assignment |
| Diamond shape complexity | Use simple `/\` `\/` approximation |
