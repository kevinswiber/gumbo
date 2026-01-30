# Analysis of Mermaid-to-ASCII and Related Tools

This document analyzes existing tools and approaches for converting Mermaid diagrams to ASCII/text art, as well as related ASCII diagramming tools.

## Table of Contents

1. [Direct Mermaid-to-ASCII Tools](#direct-mermaid-to-ascii-tools)
2. [General ASCII Diagram Tools](#general-ascii-diagram-tools)
3. [Text-Based Diagram Languages](#text-based-diagram-languages)
4. [Approach Comparison](#approach-comparison)
5. [Key Design Decisions](#key-design-decisions)

---

## Direct Mermaid-to-ASCII Tools

### 1. mermaid-ascii (AlexanderGrooff)

**Repository:** https://github.com/AlexanderGrooff/mermaid-ascii

**Language/Platform:** Go

**Description:**
A CLI tool and web interface for rendering Mermaid diagrams as ASCII/Unicode art in the terminal.

**Approach:**
- **Parsing:** Custom regex-based parser for Mermaid syntax
- **Layout:** Grid-based coordinate system with configurable padding
  - Uses a logical grid where each node occupies 3x3 cells
  - Converts grid coordinates to drawing coordinates
  - Supports both LR (left-right) and TD (top-down) layouts
- **Rendering:** Two-pass rendering
  1. First pass: Parse and create node/edge graph
  2. Second pass: Map to grid, then render to 2D character array
- **Output:** Supports both Unicode box-drawing characters and ASCII-only mode

**Supported Diagram Types:**
- Flowcharts/Graphs (graph LR, graph TD, flowchart LR, flowchart TD)
- Sequence diagrams
- Subgraphs (partial support)

**Features:**
- Labeled edges
- Configurable horizontal/vertical padding
- ASCII-only mode (`--ascii` flag)
- Colored output via `classDef` syntax
- Web interface for interactive rendering
- Docker support

**Trade-offs and Limitations:**
- Only supports rectangular node shapes
- No diagonal arrows (only orthogonal)
- Limited subgraph support
- No class diagrams, state diagrams, or ER diagrams
- Layout algorithm is relatively simple (may not produce optimal layouts for complex graphs)
- Path-finding for edges uses simple grid traversal

**Code Architecture Highlights:**
```
cmd/
  parse.go       - Mermaid syntax parsing
  graph.go       - Graph data structure and mapping
  draw.go        - ASCII rendering primitives
  mapping_edge.go - Edge path calculation
  mapping_node.go - Node positioning
internal/
  sequence/      - Sequence diagram support
  diagram/       - Common diagram interfaces
```

---

## General ASCII Diagram Tools

### 2. ASCIIFlow

**Repository:** https://github.com/lewish/asciiflow

**Website:** https://asciiflow.com

**Language/Platform:** TypeScript (web-based)

**Description:**
A web-based ASCII art editor for drawing diagrams interactively. Not a Mermaid converter, but a freeform ASCII drawing tool.

**Approach:**
- **Interactive Canvas:** Mouse/touch-driven drawing on a 2D grid
- **Drawing Tools:** Box, Line, Arrow, Freeform, Text, Select, Move, Erase
- **Character System:** Intelligent box-drawing character connection
  - Maintains a character metadata system tracking which directions each character connects
  - Auto-connects adjacent lines and boxes
  - Smart junction handling (e.g., joining a vertical and horizontal line creates a cross or T-junction)
- **Layers:** Scratch layer for in-progress drawing, committed layer for final

**Features:**
- Undo/redo support
- Copy/paste
- Multiple drawing modes
- Touch support
- Local storage persistence
- Export to text

**Trade-offs and Limitations:**
- No structured diagram input (purely interactive)
- No parsing of diagram languages
- Manual layout required
- Browser-only (no CLI)

**Relevance to mmdflux:**
The character connection logic and box-drawing character handling is highly relevant. ASCIIFlow's approach to:
- Junction merging (when lines cross)
- Direction-aware character selection
- Character metadata (connections Set per character)

Could inform how mmdflux handles complex edge routing.

---

### 3. Graph-Easy

**Repository:** https://github.com/ironcamel/Graph-Easy (Perl)

**Language/Platform:** Perl

**Description:**
A versatile ASCII graph generator that can read various input formats and produce ASCII art output.

**Approach:**
- Multiple input formats (DOT, VCG, GDL, its own format)
- Sophisticated layout algorithm
- Multiple output formats (ASCII, HTML, SVG, etc.)

**Features:**
- Advanced edge routing
- Multiple node shapes (box, diamond, ellipse, etc. rendered as ASCII approximations)
- Clustering/grouping
- Auto-layout

**Trade-offs:**
- Perl dependency
- No direct Mermaid support
- Slower than compiled alternatives
- Complex codebase

---

### 4. Monodraw (macOS)

**Website:** https://monodraw.helftone.com/

**Language/Platform:** macOS native (Swift/Objective-C)

**Description:**
Commercial macOS application for ASCII art and diagrams.

**Features:**
- Vector-like drawing that renders to ASCII
- Smart text flow
- Extensive shape library

**Trade-offs:**
- macOS only
- Commercial (not open source)
- No CLI/automation
- No Mermaid input

---

### 5. ditaa

**Repository:** https://github.com/stathissideris/ditaa

**Language/Platform:** Java

**Description:**
Converts ASCII art diagrams to bitmap images (opposite direction from our goal).

**Relevance:**
- Documents patterns for ASCII diagram recognition
- Character set and conventions could inform output format

---

## Text-Based Diagram Languages

### 6. PlantUML

**Website:** https://plantuml.com/

**Description:**
Popular text-to-diagram tool with its own DSL.

**ASCII Output:**
- Has an ASCII art output mode (`-tutxt` flag)
- Limited quality compared to graphical output

**Trade-offs:**
- Java dependency
- Different syntax than Mermaid
- ASCII mode is not primary focus

---

### 7. Pikchr

**Repository:** https://pikchr.org/

**Language/Platform:** C (single file)

**Description:**
A PIC-like diagram language that can render to SVG.

**Relevance:**
- Single-file C implementation is interesting for embedding
- No ASCII output, but layout algorithms could be studied

---

### 8. svgbob

**Repository:** https://github.com/nickel-2002/svgbob

**Language/Platform:** Rust

**Description:**
Converts ASCII art to SVG (opposite direction, but relevant).

**Relevance:**
- Documents ASCII art conventions
- Character recognition patterns
- Rust implementation (same as mmdflux target)

---

## Approach Comparison

| Tool | Input Format | Output Format | Layout Algorithm | Language |
|------|-------------|---------------|------------------|----------|
| mermaid-ascii | Mermaid | ASCII/Unicode | Grid-based | Go |
| ASCIIFlow | Interactive | ASCII/Unicode | Manual | TypeScript |
| Graph-Easy | DOT/custom | ASCII/HTML/SVG | Advanced auto | Perl |
| ditaa | ASCII | PNG | Recognition | Java |
| PlantUML | PlantUML DSL | PNG/SVG/ASCII | Auto | Java |
| svgbob | ASCII | SVG | Recognition | Rust |

---

## Key Design Decisions for mmdflux

Based on analyzing these tools, key architectural decisions for mmdflux:

### 1. Parsing Strategy

**Options:**
- **Regex-based (mermaid-ascii):** Simple but fragile, hard to extend
- **Parser combinator (recommended for Rust):** Use `nom` or `pest` for robust parsing
- **Full grammar (plantUML approach):** Most robust but complex

**Recommendation:** Use `pest` or `nom` for Rust - provides good error messages and is extensible.

### 2. Layout Algorithm

**Options:**
- **Simple grid (mermaid-ascii):** Fast, predictable, limited
- **Force-directed:** Good for organic layouts, non-deterministic
- **Layered/Sugiyama:** Best for hierarchical diagrams (flowcharts)
- **Constraint-based:** Flexible but complex

**Recommendation:** Start with layered layout (good for flowcharts), with simple grid as fallback.

### 3. Character Set

**Options:**
- **Unicode box-drawing only:** Most readable
- **ASCII-only mode:** Maximum compatibility
- **Both (mermaid-ascii approach):** Best flexibility

**Recommendation:** Support both, default to Unicode with `--ascii` flag.

### 4. Rendering Architecture

**From mermaid-ascii:**
- 2D array-based canvas works well
- Junction merging is essential (their `mergeJunctions` function)
- Separate drawing layers for background (subgraphs), lines, nodes, labels

**From ASCIIFlow:**
- Character metadata (connection directions) is valuable
- Scratch/committed layer separation aids debugging

### 5. Box Drawing Character Reference

Standard Unicode box drawing characters:

```
Corners:   ┌ ┐ └ ┘
Lines:     ─ │
T-junctions: ┬ ┴ ├ ┤
Cross:     ┼
Arrows:    ▲ ▼ ◄ ►
```

Junction merging rules (from mermaid-ascii):
- `─` + `│` = `┼`
- `┌` + `│` = `├`
- `┐` + `│` = `┤`
- etc.

### 6. Supported Diagram Types (Priority Order)

1. **Flowcharts** (graph/flowchart) - Most common use case
2. **Sequence diagrams** - Well-suited to ASCII
3. **Class diagrams** - Moderately complex
4. **State diagrams** - Similar to flowcharts
5. **ER diagrams** - Most complex (relationships)

---

## Implementation Recommendations

### Phase 1: Core Infrastructure
- Mermaid parser (pest-based)
- 2D canvas with Unicode box-drawing
- Basic node rendering
- Simple edge routing

### Phase 2: Flowcharts
- LR and TD layouts
- Labeled edges
- Basic shapes (rectangle, diamond)
- Subgraphs

### Phase 3: Additional Diagram Types
- Sequence diagrams
- Class diagrams
- State diagrams

### Phase 4: Polish
- Advanced edge routing (avoid overlaps)
- Compact layout optimization
- Color support (ANSI codes)
- Width constraints (terminal width)

---

## References

- [mermaid-ascii source](https://github.com/AlexanderGrooff/mermaid-ascii)
- [ASCIIFlow source](https://github.com/lewish/asciiflow)
- [Graph-Easy](https://github.com/ironcamel/Graph-Easy)
- [Mermaid.js Documentation](https://mermaid.js.org/)
- [Unicode Box Drawing Characters](https://en.wikipedia.org/wiki/Box-drawing_character)
- [Sugiyama Layout Algorithm](https://en.wikipedia.org/wiki/Layered_graph_drawing)
