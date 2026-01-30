# Mermaid.js Source Code Analysis

Analysis of the official Mermaid library at `$HOME/src/mermaid`.

## 1. Parser/Grammar System

**Mermaid uses JISON** - a JavaScript-based LALR parser generator (similar to Yacc/Bison).

Key files:
- `packages/mermaid/src/diagrams/flowchart/parser/flow.jison` - Main grammar file
- Each diagram type has its own `.jison` file

**Parsing Architecture:**
```
Text Input
   ↓
Lexer (tokenization with 20+ states)
   ↓
JISON Parser (generates parser.js from .jison)
   ↓
DiagramDB (accumulates parsed data)
   ↓
Renderer
```

## 2. Internal Data Structures for Flowcharts

### FlowVertex (nodes)

```typescript
interface FlowVertex {
  id: string;                    // Unique identifier
  text?: string;                 // Display label
  type?: FlowVertexTypeParam;    // Shape type
  labelType: 'text';             // Type of label (text/markdown)
  domId: string;                 // SVG element ID
  styles: string[];              // CSS styles
  classes: string[];             // Style classes
  dir?: string;                  // Layout direction
  link?: string;                 // Hyperlink
  linkTarget?: string;           // Link target
  icon?: string;                 // Icon reference
  img?: string;                  // Image reference
  props?: Record<string, any>;   // Custom properties
}
```

### FlowEdge (connections)

```typescript
interface FlowEdge {
  start: string;                 // Source node ID
  end: string;                   // Target node ID
  text: string;                  // Edge label
  type?: string;                 // Arrow type (arrow_point, arrow_circle, etc)
  stroke?: 'normal' | 'thick' | 'invisible' | 'dotted';
  length?: number;               // Length (1-10)
  style?: string[];              // CSS styles
  labelType: 'text';
  classes: string[];
  id?: string;                   // Optional edge ID
}
```

### FlowSubGraph

```typescript
interface FlowSubGraph {
  id: string;
  title: string;
  nodes: string[];               // Array of node IDs
  classes: string[];
  dir?: string;                  // Layout direction
}
```

## 3. Complete Flowchart Syntax

### Node Shapes

| Shape | Syntax | Description |
|-------|--------|-------------|
| Rectangle | `[text]` | Default square |
| Round | `(text)` | Rounded rectangle |
| Circle | `((text))` | Circle |
| Double Circle | `(((text)))` | Double circle |
| Ellipse | `(-text-)` | Ellipse |
| Stadium | `([text])` | Stadium/pill |
| Subroutine | `[[text]]` | Subroutine box |
| Diamond | `{text}` | Decision diamond |
| Hexagon | `{{text}}` | Hexagon |
| Odd | `>text]` | Flag/odd shape |
| Trapezoid | `[/text\]` | Trapezoid |
| Inv Trapezoid | `[\text/]` | Inverted trapezoid |
| Cylinder | `[(text)]` | Database cylinder |
| Parallelogram | `[/text/]` | Parallelogram |

### Edge Types

```
Line styles:
--    Normal
==    Thick
-.    Dotted

Arrow ends:
>     Point arrow
x     Cross
o     Circle
(none) Open end

Examples:
A --> B          Normal arrow
A ==> B          Thick arrow
A -.-> B         Dotted arrow
A --x B          Cross end
A --o B          Circle end
A --- B          Open end
A <--> B         Bidirectional

Length control:
A ---- B         Length 2
A ------ B       Length 3
(up to 10 dashes)
```

### Edge Labels

```
A -->|text| B
A --> |multi word text| B
A -- text --> B
```

### Directions

- `TB` or `TD` - Top to bottom (default)
- `BT` - Bottom to top
- `LR` - Left to right
- `RL` - Right to left

### Subgraphs

```mermaid
subgraph id[Title]
  node1 --> node2
end

subgraph "Multiple Word Title"
  a --> b
end
```

### Styling

```mermaid
classDef className fill:#fff,stroke:#333,color:#000;
class node1,node2 className;

style node1 fill:#f00,stroke:#333;
linkStyle 0,1 stroke:#f00,stroke-width:2px;
```

## 4. Other Diagram Types

Mermaid supports 20+ diagram types, each with its own JISON parser:

| Type | Detector Keyword | Parser File |
|------|------------------|-------------|
| Flowchart | `graph`, `flowchart` | `flow.jison` |
| Sequence | `sequenceDiagram` | `sequenceDiagram.jison` |
| Class | `classDiagram` | `classDiagram.jison` |
| State | `stateDiagram` | `stateDiagram.jison` |
| ER | `erDiagram` | `erDiagram.jison` |
| Gantt | `gantt` | `gantt.jison` |
| Pie | `pie` | TypeScript parser |
| Git | `gitGraph` | TypeScript parser |
| Journey | `journey` | `journey.jison` |
| Mindmap | `mindmap` | `mindmap.jison` |
| Timeline | `timeline` | `timeline.jison` |
| Sankey | `sankey-beta` | `sankey.jison` |
| XY Chart | `xychart-beta` | `xychart.jison` |
| Quadrant | `quadrantChart` | `quadrant.jison` |
| C4 | `C4Context` | `c4Diagram.jison` |
| Requirement | `requirementDiagram` | `requirementDiagram.jison` |

## 5. Lexer States

The JISON lexer uses 20+ states for context-aware tokenization:

- `string` - Inside quoted strings
- `md_string` - Inside markdown strings
- `text` - Node text content
- `edgeText` - Edge label content
- `dir` - Direction parsing
- `click` - Click handler parsing
- Shape-specific states: `ellipseText`, `trapText`, etc.

## 6. Key Insights for mmdflux

### Parser is independent of renderer

The JISON parser builds abstract data structures (vertices, edges, subgraphs) completely separate from SVG rendering. This means:

1. **We can study the grammar** to ensure syntax compatibility
2. **Layout is separate** - Mermaid uses Dagre for layout, we'll do our own grid-based layout
3. **Style system is decoupled** - We can ignore CSS-based styling for ASCII output

### Recommended approach for mmdflux

**Option A: Port the grammar**
- Translate JISON grammar to `pest` or `nom` in Rust
- Match the exact syntax
- Highest compatibility

**Option B: Subset implementation**
- Implement the most common syntax
- Skip advanced features (icons, links, markdown labels)
- Faster to build, covers 90% of use cases

### Shape mapping for ASCII

| Mermaid Shape | ASCII Representation |
|---------------|---------------------|
| Rectangle `[x]` | `┌───┐ │ x │ └───┘` |
| Round `(x)` | `╭───╮ │ x │ ╰───╯` |
| Diamond `{x}` | ` ◇ ╱ x ╲ ◇ ` |
| Circle `((x))` | Approximate with round |
| Stadium `([x])` | Same as round |
| Hexagon `{{x}}` | ` ╱─╲ │ x │ ╲─╱` |

### Priority for implementation

1. **Flowchart** - Most complex but most used
2. **Sequence** - Already well-suited to ASCII (columns)
3. **State** - Similar to flowchart
4. **Class** - Boxes with relationships
5. **ER** - Boxes with cardinality notation

## 7. Grammar Excerpt (flow.jison)

Key production rules:

```jison
start: graphConfig document

document: line+

line: statement | NEWLINE | EOF

statement:
  | vertexStatement
  | linkStatement
  | styleStatement
  | clickStatement
  | subgraph node_id text_string statements end
  | direction

vertex:
  | node_id SQS text SQE                    // [text]
  | node_id PS text PE                      // (text)
  | node_id PS PS text PE PE                // ((text))
  | node_id DIAMOND_START text DIAMOND_STOP // {text}
  | node_id HEXAGON_START text HEXAGON_END  // {{text}}
  | ...

link:
  | vertex ARROW_POINT vertex
  | vertex ARROW_CIRCLE vertex
  | vertex ARROW_CROSS vertex
  | vertex ARROW_OPEN vertex
  | link PIPE text PIPE                     // label
```

## References

- JISON documentation: https://gerhobbelt.github.io/jison/
- Mermaid syntax docs: https://mermaid.js.org/syntax/flowchart.html
- Dagre layout: https://github.com/dagrejs/dagre
