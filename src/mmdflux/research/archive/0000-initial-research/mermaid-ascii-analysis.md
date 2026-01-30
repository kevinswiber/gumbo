# mermaid-ascii Project Analysis

Analysis of the mermaid-ascii project at `$HOME/src/mermaid-ascii`.

## 1. Language & Framework

- **Language**: Go 1.21+
- **Key Dependencies**:
  - `github.com/elliotchance/orderedmap/v2`: Maintains insertion order for graph edges
  - `github.com/gin-gonic/gin`: Web framework for interactive UI
  - `github.com/gookit/color`: Terminal color support
  - `github.com/mattn/go-runewidth`: Unicode width calculation
  - `github.com/sirupsen/logrus`: Logging
  - `github.com/spf13/cobra`: CLI framework

## 2. Mermaid Syntax Parsing

### Graph/Flowchart Parser (`cmd/parse.go`)

- Uses regex-based pattern matching for parsing
- Patterns matched in order: empty lines → arrows (`-->`) → labeled arrows (`-->|label|`) → `classDef` → `&` syntax
- Supports comment removal (lines starting with `%%`)
- Preserves node order using `OrderedMap`
- Builds a parent-child edge map structure

### Sequence Diagram Parser (`internal/sequence/parser.go`)

- Regex-based parsing for `participant` declarations and messages
- Message syntax: `[From]->>|dotted|[To]: Label`
- Supports participant aliases (`participant A as Alice`)
- Auto-creates participants if referenced but not declared

### Key Parsing Features

- Comments: `%%` prefix or inline `%%` stripped
- Graph directions: `graph LR`, `graph TD`, `flowchart LR`, `flowchart TD`
- Node styling: `node:::className` syntax
- Style definitions: `classDef className color:#rrggbb`
- Subgraph support (partial): `subgraph name ... end` blocks
- Padding directives: `paddingX=n` and `paddingY=n`

## 3. ASCII Rendering Approach

### Grid-Based Rendering Algorithm

**Phase 1: Grid Mapping (`cmd/graph.go` - `createMapping()`)**
- Creates logical grid (not pixels) with coordinate system
- Nodes occupy 3-column width (border-content-border)
- Spacing between nodes configurable (default: 5 units)
- Multi-level hierarchical placement
- Bidirectional level assignment for LR and TD layouts

**Phase 2: Path Finding (`cmd/mapping_edge.go`)**
- Calculates edge paths between nodes
- Considers two path strategies (preferred and alternative) to minimize steps
- Uses A*-like pathfinding to avoid overlapping nodes
- Label placement on longest horizontal segment of edge

**Phase 3: Drawing (`cmd/draw.go` - `drawLine()`)**
- Converts grid coordinates to drawing coordinates using column/row width maps
- Draws lines using Unicode box-drawing characters or ASCII
- Supports 8 directions: up, down, left, right, and 4 diagonals
- Merges drawing layers: subgraphs → nodes → lines → corners → arrows → labels

### Sequence Diagram Rendering (`internal/sequence/renderer.go`)

- Calculates participant column positions based on label width
- Fixed vertical spacing between messages
- Handles self-messages with special curved path
- Supports both solid (`->>`) and dotted (`-->>`) arrows

## 4. Character Sets

### ASCII Mode (`internal/sequence/charset.go`)

```go
var ASCII = BoxChars{
    TopLeft:      '+',
    TopRight:     '+',
    BottomLeft:   '+',
    BottomRight:  '+',
    Horizontal:   '-',
    Vertical:     '|',
    TeeDown:      '+',
    TeeRight:     '+',
    TeeLeft:      '+',
    Cross:        '+',
    ArrowRight:   '>',
    ArrowLeft:    '<',
    SolidLine:    '-',
    DottedLine:   '.',
}
```

### Unicode Mode

```go
var Unicode = BoxChars{
    TopLeft:      '┌',
    TopRight:     '┐',
    BottomLeft:   '└',
    BottomRight:  '┘',
    Horizontal:   '─',
    Vertical:     '│',
    TeeDown:      '┬',
    TeeRight:     '├',
    TeeLeft:      '┤',
    Cross:        '┼',
    ArrowRight:   '►',
    ArrowLeft:    '◄',
    SolidLine:    '─',
    DottedLine:   '┈',
}
```

## 5. Supported Diagram Types

### Graph/Flowchart Diagrams ✅

- Directions: LR (left-to-right) and TD (top-down)
- Node connections: `A --> B`, `A --> B --> C`
- Multiple targets: `A --> B & C` and `A & B --> C`
- Labeled edges: `A -->|label| B`
- CSS-like styling: `classDef` and `class` application
- Subgraph support (with some limitations)

### Sequence Diagrams ✅

- Participant declarations (explicit and auto-discovered)
- Participant aliases
- Solid and dotted arrows
- Self-messages
- Autonumbering (`autonumber` directive)
- Unicode emoji/CJK support via `go-runewidth`

### Not Yet Supported ❌

- Shapes other than rectangles
- Diagonal arrows
- Subgraph nesting details
- Notes, activation boxes
- Loop, alt, opt, par blocks
- Class diagrams, state diagrams, etc.

## 6. Limitations & Trade-offs

### Limitations

1. **Fixed rectangular nodes**: No support for diamonds, circles, or other shapes
2. **Grid discretization**: Output is constrained to character grid (not continuous positioning)
3. **No diagonal edges**: Edges only follow cardinal directions + diagonals on grid level
4. **Subgraph incompleteness**: Subgraphs render as boxes but lack visual nesting clarity
5. **Terminal width**: No automatic terminal width detection/wrapping
6. **Single layout pass**: No iterative optimization for compactness

### Trade-offs

1. **Simplicity vs. Compactness**: Grid-based approach is simple but produces verbose layouts
2. **ASCII limitations**: Unicode output looks better but requires terminal support
3. **Rendering speed**: Fast (no expensive layout algorithms) but less optimal placement
4. **Mermaid compatibility**: Partial support—focuses on core features, not all syntax variations

## 7. Interesting Architectural Decisions

1. **OrderedMap for Edge Data**: Uses `elliotchance/orderedmap` to maintain edge insertion order, preserving user intent

2. **Three-Phase Grid System**:
   - Grid coords (logical placement)
   - Column/row width maps (variable sizing)
   - Drawing coords (final pixel positions)
   - This indirection allows flexible layout

3. **Dual-Strategy Path Finding**: Evaluates preferred + alternative paths to avoid node overlap

4. **Character Set Abstraction**: Separate `BoxChars` struct for Unicode vs ASCII, enabling format switching

5. **Subgraph Offset Correction**: Calculates subgraph bounding boxes post-layout, applies offset if negative coordinates exist

6. **Diagram Factory Pattern**: Detects diagram type (graph vs sequence) at runtime via keyword matching

7. **Web UI Architecture**: Gin-based web server allows interactive rendering with live updates

8. **Stateless Rendering**: Each diagram render is independent; no state mutation across diagrams

9. **Merged Drawing Layers**: Builds drawing as layered compositions rather than immediate placement

## Key Files

- `$HOME/src/mermaid-ascii/cmd/graph.go` - Grid mapping and graph layout
- `$HOME/src/mermaid-ascii/cmd/parse.go` - Syntax parsing
- `$HOME/src/mermaid-ascii/cmd/draw.go` - Rendering to ASCII/Unicode
- `$HOME/src/mermaid-ascii/internal/sequence/parser.go` - Sequence parsing
- `$HOME/src/mermaid-ascii/internal/sequence/renderer.go` - Sequence rendering
- `$HOME/src/mermaid-ascii/internal/sequence/charset.go` - Character set definitions
