# Research Directory

This directory contains research conducted to inform the design of mmdflux.

## Quick Reference

| File | What it covers | Read if you need... |
|------|---------------|---------------------|
| [synthesis.md](synthesis.md) | Consolidated recommendations | **Start here** - overall architecture decisions |
| [mermaid-js-analysis.md](mermaid-js-analysis.md) | Official Mermaid grammar & data structures | Complete syntax reference, node shapes, edge types |
| [mermaid-ascii-analysis.md](mermaid-ascii-analysis.md) | Existing Go implementation | Grid-based rendering approach, what works/doesn't |
| [asciiflow-analysis.md](asciiflow-analysis.md) | Character connection algorithms | Smart junction merging, line routing |
| [other-tools-analysis.md](other-tools-analysis.md) | Survey of related tools | Broader landscape, alternative approaches |

## File Summaries

### synthesis.md
**The TL;DR of all research.** Combines findings into actionable recommendations:
- Parser choice (`pest` or `nom`)
- Data structures to use
- Layout algorithm options
- Implementation phases
- ASCII shape mappings for Mermaid node types

### mermaid-js-analysis.md
Deep dive into the official Mermaid source code:
- JISON grammar structure
- All 14 node shapes with syntax
- Edge types and modifiers
- FlowVertex/FlowEdge/FlowSubGraph interfaces
- How parsing is separated from rendering

### mermaid-ascii-analysis.md
Analysis of github.com/AlexanderGrooff/mermaid-ascii (Go):
- Three-phase grid system (grid coords → sizing → drawing)
- Regex-based parsing approach (and its limitations)
- BoxChars abstraction for Unicode/ASCII modes
- Path-finding for edge routing
- Supported vs unsupported features

### asciiflow-analysis.md
Analysis of asciiflow.com source (TypeScript):
- Layer/LayerView architecture for composition
- Character connection metadata system
- Smart junction merging (`─` + `│` → `┼`)
- Snapping algorithm for alignment
- Context-aware character selection

### other-tools-analysis.md
Survey of the broader ecosystem:
- Graph-Easy (Perl) - advanced layout
- PlantUML - ASCII output mode
- ditaa - ASCII to PNG (reverse direction)
- svgbob - ASCII to SVG (Rust)
- Monodraw - commercial macOS app

## Key Findings

1. **Grid-based layout works** - Both mermaid-ascii and ASCIIFlow prove this approach is viable

2. **Use a real parser** - Regex-based parsing (mermaid-ascii) is fragile; use `pest` or `nom`

3. **Character metadata is key** - Storing connection directions per character enables smart junctions

4. **Match official syntax** - Mermaid.js grammar is the source of truth for compatibility

5. **Layout is separate** - Parsing produces abstract graph; layout/rendering is independent
