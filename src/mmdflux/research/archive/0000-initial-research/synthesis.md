# Research Synthesis: Mermaid-to-ASCII Approaches

This document synthesizes research from analyzing existing tools and codebases to inform the design of mmdflux.

## Executive Summary

The primary existing solution is **mermaid-ascii** (Go), which uses a grid-based rendering approach. **ASCIIFlow** (TypeScript) provides excellent character connection algorithms that could improve edge rendering. The official **Mermaid.js** source reveals the complete grammar (JISON-based) and data structures we need to match for compatibility.

**Key finding:** A grid-based layout with intelligent junction merging is the proven approach. The main opportunity for mmdflux is to improve upon mermaid-ascii with better layout algorithms, broader diagram type support, and full syntax compatibility with official Mermaid.

## Sources Analyzed

1. **mermaid-ascii** - Go implementation, regex parsing, grid layout
2. **ASCIIFlow** - TypeScript, character connection metadata
3. **Mermaid.js** - Official source, JISON grammar, complete syntax
4. **Other tools** - Graph-Easy, PlantUML, svgbob, ditaa

---

## Approach Comparison

| Aspect | mermaid-ascii | ASCIIFlow | Mermaid.js | Recommendation |
|--------|--------------|-----------|------------|----------------|
| **Parsing** | Regex-based | N/A | JISON grammar | Port grammar to `pest` |
| **Layout** | Simple grid | Manual | Dagre engine | Start grid, add Sugiyama |
| **Edge routing** | A*-like | Context-aware snapping | Dagre | Combine grid + snapping |
| **Data model** | Ad-hoc structs | Layer/Vector | FlowVertex/FlowEdge | Match Mermaid structures |
| **Character handling** | BoxChars struct | Connection metadata | N/A (SVG) | Use connection metadata |

---

## Recommended Architecture

### 1. Parsing Layer

**Use a proper parser generator** (not regex):

```rust
// pest grammar example
graph = { "graph" ~ direction ~ NEWLINE ~ statement* }
direction = { "TD" | "TB" | "LR" | "RL" }
statement = { node_def | edge_def | subgraph | style_def }
```

**Why:** Regex-based parsing (mermaid-ascii approach) becomes fragile with complex nested structures. A grammar-based parser provides better error messages and extensibility.

**Recommended crates:**
- `pest` - PEG parser, good error messages, well-documented
- `nom` - Parser combinators, more flexible, steeper learning curve

### 2. Graph Representation

```rust
struct Diagram {
    nodes: HashMap<NodeId, Node>,
    edges: Vec<Edge>,
    subgraphs: Vec<Subgraph>,
    direction: Direction,
}

struct Node {
    id: NodeId,
    label: String,
    shape: Shape,
    style: Option<Style>,
    position: Option<GridPosition>,  // Set during layout
}

struct Edge {
    from: NodeId,
    to: NodeId,
    label: Option<String>,
    arrow_type: ArrowType,
    path: Option<Vec<GridPosition>>,  // Set during layout
}
```

### 3. Layout Algorithm

**Phase 1: Layer Assignment (Sugiyama-style)**
- Assign nodes to layers based on dependencies
- Handle cycles by temporarily removing back-edges

**Phase 2: Ordering**
- Minimize edge crossings within layers
- Use barycenter or median heuristics

**Phase 3: Coordinate Assignment**
- Assign x/y positions
- Use mermaid-ascii's column/row width maps for variable sizing

**Phase 4: Edge Routing**
- Calculate paths avoiding nodes
- Borrow A*-like approach from mermaid-ascii
- Apply ASCIIFlow's snapping for junction alignment

### 4. Rendering Layer

Adopt ASCIIFlow's connection metadata pattern:

```rust
enum Direction {
    Up, Down, Left, Right
}

struct CharacterInfo {
    char: char,
    connects: HashSet<Direction>,
    connectables: HashSet<Direction>,
}

fn connect(current: char, direction: Direction) -> char {
    // Transform character based on new connection
    // '─' + Up → '┬'
    // '│' + Left → '├'
    // etc.
}
```

### 5. Output Generation

**Layer-based rendering (from ASCIIFlow):**

```rust
struct Canvas {
    committed: Layer,    // Final output
    scratch: Layer,      // Work in progress
}

struct Layer {
    cells: HashMap<(i32, i32), char>,
}

impl Layer {
    fn set(&mut self, x: i32, y: i32, c: char);
    fn get(&self, x: i32, y: i32) -> Option<char>;
    fn merge(&mut self, other: &Layer);
}
```

---

## Complete Mermaid Flowchart Syntax

From the official Mermaid.js JISON grammar:

### Node Shapes (14 types)

| Shape | Syntax | ASCII Approximation |
|-------|--------|---------------------|
| Rectangle | `[text]` | `┌───┐ │ x │ └───┘` |
| Round | `(text)` | `╭───╮ │ x │ ╰───╯` |
| Circle | `((text))` | Round (approximation) |
| Stadium | `([text])` | Round |
| Subroutine | `[[text]]` | `╟───╢ ║ x ║ ╟───╢` |
| Diamond | `{text}` | ` ◇ ╱x╲ ◇ ` |
| Hexagon | `{{text}}` | ` ╱─╲ │x│ ╲─╱` |
| Odd/Flag | `>text]` | `┌──▶ │ x │ └───┘` |
| Trapezoid | `[/text\]` | ` ╱──╲ │ x │ └────┘` |
| Inv Trapezoid | `[\text/]` | Flip trapezoid |
| Cylinder | `[(text)]` | ` ╭─╮ │x│ ╰─╯` |
| Parallelogram | `[/text/]` | ` ╱──╱ │ x │ ╱──╱` |

### Edge Types

```
Line:  --  (normal)  ==  (thick)  -.  (dotted)
Arrow: >   (point)   x   (cross)  o   (circle)  (none = open)

A --> B      A ==> B      A -.-> B
A --x B      A ==o B      A --- B
A <--> B     (bidirectional)
```

### Directions

`TB`/`TD` (top-down), `BT`, `LR`, `RL`

---

## Character Set

### Unicode Box Drawing (default)

```
Corners:     ┌ ┐ └ ┘
Lines:       ─ │
T-junctions: ┬ ┴ ├ ┤
Cross:       ┼
Arrows:      ▲ ▼ ◄ ►
Dotted:      ┈ ┊
```

### ASCII Fallback

```
Corners:     + + + +
Lines:       - |
T-junctions: + + + +
Cross:       +
Arrows:      ^ v < >
Dotted:      . :
```

---

## Diagram Type Priority

Based on complexity and use cases:

1. **Flowcharts** (`graph`/`flowchart`) - Most common, best ASCII fit
2. **Sequence diagrams** - Well-suited to ASCII columns
3. **State diagrams** - Similar to flowcharts
4. **Class diagrams** - More complex (relationships, multiplicities)
5. **ER diagrams** - Most complex (cardinality notation)

---

## Trade-offs to Consider

### Layout Compactness vs. Simplicity

- **mermaid-ascii:** Simple grid, predictable but verbose
- **Alternative:** Sugiyama algorithm, more compact but complex
- **Recommendation:** Start simple (like mermaid-ascii), add optimization later

### Edge Routing Complexity

- **Simple:** Orthogonal routing only (up/down/left/right)
- **Advanced:** Allow diagonal segments, curve approximations
- **Recommendation:** Start orthogonal only, match mermaid-ascii

### Unicode vs. ASCII

- **Unicode:** Better visuals, requires terminal support
- **ASCII:** Maximum compatibility
- **Recommendation:** Default to Unicode, `--ascii` flag for fallback

### Error Handling

- **mermaid-ascii:** Often silently fails or produces malformed output
- **Recommendation:** Fail fast with clear error messages; use `Result` types

---

## Implementation Phases

### Phase 1: Core Infrastructure
- [ ] CLI with clap (✅ done)
- [ ] Mermaid parser for flowcharts
- [ ] Basic graph data structures
- [ ] 2D canvas with character cells

### Phase 2: Basic Flowcharts
- [ ] Node rendering (rectangles only)
- [ ] Edge rendering (orthogonal)
- [ ] TD and LR layouts
- [ ] Junction merging

### Phase 3: Enhanced Flowcharts
- [ ] Labeled edges
- [ ] Subgraphs
- [ ] Node shapes (diamond, rounded)
- [ ] Styling (colors via ANSI)

### Phase 4: Additional Diagrams
- [ ] Sequence diagrams
- [ ] State diagrams
- [ ] Class diagrams

### Phase 5: Polish
- [ ] Terminal width constraints
- [ ] Compact layout optimization
- [ ] Better error messages
- [ ] Performance optimization

---

## Key Learnings

1. **Grid-based layout works**: Both mermaid-ascii and ASCIIFlow prove that a cell grid approach is viable for ASCII diagrams.

2. **Junction merging is essential**: Smart character selection based on adjacent connections produces cleaner output than naive character placement.

3. **Layered rendering aids debugging**: Separating scratch/committed layers and merging at the end makes the system more maintainable.

4. **Parser quality matters**: Regex-based parsing quickly becomes unmaintainable; invest in a proper parser early.

5. **Character metadata > hardcoded logic**: Storing connection directions per character is more extensible than case-by-case character handling.

---

## References

- [mermaid-ascii source](https://github.com/AlexanderGrooff/mermaid-ascii)
- [ASCIIFlow source](https://github.com/lewish/asciiflow)
- [Mermaid.js syntax](https://mermaid.js.org/syntax/flowchart.html)
- [Sugiyama layout algorithm](https://en.wikipedia.org/wiki/Layered_graph_drawing)
- [Unicode box drawing](https://en.wikipedia.org/wiki/Box-drawing_character)
