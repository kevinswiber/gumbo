# Q6: Mermaid's Diagram Plugin Architecture

## Summary

Mermaid uses a registry-based plugin architecture where each diagram type is a self-contained bundle of four components — a **detector** (text matching), a **parser** (grammar), a **db** (semantic model), and a **renderer** (SVG output) — registered via `registerDiagram()` and loaded lazily on demand. Shared infrastructure is minimal: a common DB mixin for titles/accessibility, text sanitization utilities, a unified `Node`/`Edge` type system in `rendering-util/types.ts`, and a pluggable layout algorithm registry. The architecture is designed primarily for SVG rendering in a browser, with significant coupling to D3 and the DOM.

## Where

All paths relative to `/Users/kevin/src/mermaid/packages/mermaid/src/`:

- **Plugin system core:** `diagram-api/types.ts`, `diagram-api/diagramAPI.ts`, `diagram-api/detectType.ts`, `diagram-api/loadDiagram.ts`, `diagram-api/diagram-orchestration.ts`
- **Diagram entry point:** `Diagram.ts` — the `Diagram.fromText()` factory
- **Shared common code:** `diagrams/common/commonDb.ts`, `diagrams/common/common.ts`, `diagrams/common/commonTypes.ts`, `diagrams/common/populateCommonDb.ts`, `diagrams/common/svgDrawCommon.ts`
- **Rendering utilities:** `rendering-util/render.ts`, `rendering-util/types.ts`, `rendering-util/createGraph.ts`
- **Style system:** `styles.ts`
- **Diagram implementations examined:** `diagrams/flowchart/`, `diagrams/er/`, `diagrams/class/`, `diagrams/pie/`

## What

### The DiagramDefinition Interface

Every diagram type must satisfy `DiagramDefinition` (`diagram-api/types.ts`):

```typescript
interface DiagramDefinition {
  db: DiagramDB;              // Semantic model (data store)
  renderer: DiagramRenderer;  // draw() function
  parser: ParserDefinition;   // parse(text) function
  styles?: any;               // CSS style generator function
  init?: (config: MermaidConfig) => void;  // One-time config setup
  injectUtils?: (...) => void;  // Legacy: inject shared utilities
}
```

**DiagramDB** is the generic interface all diagram databases share:
```typescript
interface DiagramDB {
  getConfig?: () => BaseDiagramConfig | undefined;
  clear?: () => void;
  setDiagramTitle?: (title: string) => void;
  getDiagramTitle?: () => string;
  setAccTitle?: (title: string) => void;
  getAccTitle?: () => string;
  setAccDescription?: (description: string) => void;
  getAccDescription?: () => string;
  getDirection?: () => string | undefined;
  setDirection?: (dir: DiagramOrientation) => void;
  setDisplayMode?: (title: string) => void;
  bindFunctions?: (element: Element) => void;
}
```

All methods are optional on the base interface. A stricter `DiagramDBBase<T>` type makes `clear`, title, and accessibility methods required for new diagrams.

**DiagramRenderer** requires a `draw()` function:
```typescript
interface DiagramRenderer {
  draw: (text: string, id: string, version: string, diagramObject: Diagram) => void | Promise<void>;
  getClasses?: (text: string, diagram: Pick<DiagramDefinition, 'db'>) => Map<string, DiagramStyleClassDef>;
}
```

**ParserDefinition** is minimal:
```typescript
interface ParserDefinition {
  parse: (text: string) => void | Promise<void>;
  parser?: { yy: DiagramDB };  // Legacy JISON support
}
```

### The Registration System

There are two registration mechanisms:

1. **Eager registration** via `registerDiagram(id, definition, detector?)` — stores the definition immediately in a `Record<string, DiagramDefinition>` map, adds the detector, registers CSS styles, and injects shared utilities.

2. **Lazy registration** via `registerLazyLoadedDiagrams(...definitions)` — stores only the detector function and a `loader: () => Promise<{id, diagram}>` factory. The actual diagram module is imported only when that diagram type is detected.

Each lazy-loaded diagram is an `ExternalDiagramDefinition`:
```typescript
interface ExternalDiagramDefinition {
  id: string;
  detector: DiagramDetector;  // (text: string, config?: MermaidConfig) => boolean
  loader: DiagramLoader;      // () => Promise<{ id: string; diagram: DiagramDefinition }>
}
```

**Detection** works by iterating registered detectors in order; the first one returning `true` wins. Detectors are simple regex checks on the first line of input (e.g., `/^\s*flowchart/.test(txt)` for flowchart-v2, `/^\s*erDiagram/.test(txt)` for ER).

**Orchestration** (`diagram-orchestration.ts`) registers all built-in diagram types at startup, with order mattering for detection precedence. Two special diagrams are eagerly registered: `error` and `---` (YAML front-matter error case).

### The Diagram.fromText() Factory

`Diagram.fromText(text, metadata)` is the main entry point:

1. Calls `detectType(text, config)` to identify the diagram type
2. Encodes entities and appends newline
3. Loads the diagram definition (lazy-loading if needed)
4. Retrieves `{db, parser, renderer, init}` from the definition
5. Wires JISON parser's `yy` to the DB (legacy support)
6. Calls `db.clear()` to reset state
7. Calls `init(config)` for diagram-specific setup
8. Sets title from metadata if present
9. Calls `parser.parse(text)` — this populates the DB
10. Returns a `Diagram` instance wrapping `(type, text, db, parser, renderer)`

The returned `Diagram` object has a `render(id, version)` method that delegates to `renderer.draw()`.

### Shared Common Infrastructure

**commonDb.ts** — Module-level state for accessibility title, diagram title, and accessibility description. Provides `setAccTitle`, `getAccTitle`, `setAccDescription`, `getAccDescription`, `setDiagramTitle`, `getDiagramTitle`, and `clear`. Every diagram DB imports and re-exports these functions. This is the most reused piece.

**common.ts** — Text utilities: `sanitizeText` (DOM purification), `getRows` (line splitting), `hasBreaks`, `splitBreaks`, `removeScript`, `getUrl`, `parseGenericTypes`, `hasKatex`, `renderKatexSanitized`. Heavily browser/DOM-oriented.

**commonTypes.ts** — SVG drawing type definitions: `RectData`, `Bound`, `TextData`, `TextObject`, plus D3 selection type aliases. Entirely SVG-specific.

**populateCommonDb.ts** — A small helper that takes a parsed AST and calls `db.setAccDescription`, `db.setAccTitle`, `db.setDiagramTitle` from it. Used by newer Langium-based parsers.

**svgDrawCommon.ts** — Shared SVG drawing functions: `drawRect`, `drawBackgroundRect`, `drawText`, `drawImage`, `drawEmbeddedImage`, `getNoteRect`, `getTextObj`, `createTooltip`. All D3/SVG-specific.

### Rendering Utilities (rendering-util/)

**render.ts** — A second plugin registry, this time for **layout algorithms**. Layout algorithms implement `LayoutAlgorithm`:
```typescript
interface LayoutAlgorithm {
  render(layoutData: LayoutData, svg: SVG, helpers: InternalHelpers, options?: RenderOptions): Promise<void>;
}
```
Built-in layout algorithms: `dagre` and `cose-bilkent` (for architecture diagrams). The ELK layout is an external package.

**types.ts** — The unified `Node` and `Edge` interfaces used by newer "v3-unified" renderers. `Node` has a large superset of properties from all diagram types (flowchart, state, class, kanban). `Edge` similarly combines flowchart, class, and state diagram edge properties. `LayoutData` packages `{nodes, edges, config}` for layout algorithms.

**createGraph.ts** — Creates a graphlib graph from `LayoutData`, inserts SVG node elements, measures bounding boxes, and handles edge labels as dummy nodes. This is the bridge between the abstract layout data and graphlib+D3.

### Style System

Each diagram provides a `styles` function `(options: FlowChartStyleOptions) => string` that generates CSS for that diagram type. `styles.ts` at the root wraps all diagram styles with common CSS (font, animations, edge patterns, markers, error styles) and registers them via `addStylesForDiagram(type, styleFunction)`.

### Per-Diagram Components (What's Unique)

Examining flowchart, ER, class, and pie reveals the pattern:

| Component | Flowchart | ER | Class | Pie |
|-----------|-----------|-----|-------|-----|
| **Detector** | Regex on `graph`/`flowchart` + config check for renderer variant | Regex on `erDiagram` | Regex on `classDiagram` + config check | Regex on `pie` |
| **Parser** | JISON → Langium migration in progress | JISON | JISON | Langium-based |
| **DB** | `FlowDB` class: vertices, edges, subgraphs, tooltips, classes, direction. Imports commonDb. | `ErDB` class: entities, relationships, classes, direction. Imports commonDb. | `ClassDB` class: classes, relations, notes. Imports commonDb. | Module-level state: sections map, showData. Imports commonDb. |
| **Renderer** | v3-unified: calls `db.getData()` → `LayoutData`, delegates to `render()` | unified: similar pattern | v3-unified: similar pattern | Custom D3 pie chart drawing |
| **Styles** | Flowchart-specific CSS (nodes, clusters, edges, tooltips) | ER-specific CSS (entity boxes, relationship lines, markers) | Class-specific CSS | Pie-specific CSS |
| **Init** | Sets `arrowMarkerAbsolute`, layout config | None | Sets `arrowMarkerAbsolute` | None |
| **Types** | `FlowVertex`, `FlowEdge`, `FlowSubGraph`, `FlowLink` | `EntityNode`, `Attribute`, `Relationship`, `RelSpec` | Class members, relations, notes types | `Sections`, `D3Section` |

Key observation: The newer "v3-unified" renderers (flowchart, class, ER) share a common rendering path:
1. `db.getData()` returns `LayoutData` (unified `Node[]` + `Edge[]`)
2. `render(layoutData, svg)` dispatches to the registered layout algorithm
3. Layout algorithm handles node placement, edge routing, and SVG rendering

Older renderers handle everything themselves with direct D3 manipulation.

## How

### Lifecycle of a Diagram Render

```
Input Text
    ↓
extractFrontMatter(text) → {text, metadata}
    ↓
detectType(text, config) → diagram type ID (e.g., "flowchart-v2")
    ↓
getDiagram(type) or lazy-load via loader()
    ↓
registerDiagram(id, definition) if lazy-loaded
    ↓
Diagram.fromText(text, metadata):
  1. db.clear()          — reset diagram state
  2. init(config)        — diagram-specific config setup
  3. parser.parse(text)  — populate db with parsed data
    ↓
Diagram.render(id, version):
  renderer.draw(text, id, version, this)
    ↓
  [For unified renderers]:
    db.getData() → LayoutData {nodes, edges, config}
    render(layoutData, svg)  — layout algorithm plugin
    setupViewPortForSVG()
```

### Plugin Registration Flow

```
diagram-orchestration.ts :: addDiagrams()
  ├── registerDiagram("error", errorDiagram, detector)    [eager]
  ├── registerDiagram("---", yamlErrorDiagram, detector)  [eager]
  ├── registerLazyLoadedDiagrams(flowchartElk, mindmap, architecture)  [lazy, large]
  └── registerLazyLoadedDiagrams(c4, kanban, classDiagramV2, ..., treemap)  [lazy]
```

Each `registerDiagram` call:
1. Stores definition in `diagrams` record
2. Adds detector to `detectors` record (if provided)
3. Registers CSS styles via `addStylesForDiagram`
4. Calls `injectUtils()` on the definition (legacy DI pattern)

### Data Flow Through the System

For unified renderers (the modern path):

```
Parser → DB (populates semantic model)
  ↓
DB.getData() → LayoutData { nodes: Node[], edges: Edge[], config }
  ↓
render(layoutData, svg) → dispatches to layout algorithm
  ↓
Layout algorithm (e.g., dagre):
  createGraphWithElements() → graphlib.Graph + DOM elements
  run dagre layout
  position nodes and route edges in SVG
```

The `Node` and `Edge` types in `rendering-util/types.ts` serve as the **universal intermediate representation** between diagram-specific DBs and the shared layout/rendering pipeline.

## Why

### What These Abstractions Exist For

1. **DiagramDefinition as a plugin contract**: Allows third-party diagrams via `registerDiagram()`. Each diagram is self-contained with its own parser, data model, and renderer. The contract is intentionally loose (most DiagramDB methods are optional) to accommodate very different diagram types.

2. **Lazy loading**: Most diagrams are loaded only when detected, keeping initial bundle size small. The detector is a lightweight regex test; the full implementation loads on demand.

3. **commonDb as shared state**: Title and accessibility are universal concerns, so every diagram delegates to `commonDb`. This avoids reimplementing the same boilerplate.

4. **Unified Node/Edge types**: The v3-unified renderers converge on a shared `LayoutData` format. This allows different diagram types (flowchart, class, ER, state) to share the same layout algorithms (dagre, ELK, cose-bilkent) and rendering infrastructure.

5. **Layout algorithm registry**: Decouples diagram types from layout engines. A flowchart can use dagre or ELK without changing its renderer code.

### What mmdflux Would Need for Multi-Diagram Support

**Minimal plugin architecture** (Rust equivalent):

1. **Diagram trait** — The core abstraction:
   ```rust
   trait DiagramType {
       fn detect(text: &str) -> bool;
       fn parse(text: &str) -> Result<Box<dyn DiagramData>>;
   }

   trait DiagramData {
       fn title(&self) -> Option<&str>;
       fn direction(&self) -> Direction;
       fn to_layout_graph(&self) -> LayoutInput;  // Equivalent of getData()
   }
   ```

2. **Shared layout pipeline** — mmdflux already has this (dagre module). The key insight from Mermaid is that the `LayoutData` (nodes + edges + config) is the universal interchange format. mmdflux's `Diagram` struct already plays this role.

3. **Diagram registry** — In Rust, either a static registry or an enum-based dispatch:
   ```rust
   enum DiagramKind {
       Flowchart(FlowchartData),
       Sequence(SequenceData),
       // ...
   }
   ```

4. **Text detection** — Simple regex-based, exactly as Mermaid does it. First match wins.

5. **Shared rendering infrastructure** — mmdflux's Canvas/CharSet already serves this role. The equivalent of Mermaid's `svgDrawCommon` would be shared text-rendering primitives for the Canvas.

**What to NOT replicate from Mermaid:**
- The `injectUtils` DI pattern is a legacy workaround for JISON parsers and module isolation; Rust's module system handles this natively.
- The `DiagramDB` mutable state pattern (module-level variables mutated by parsers) is an artifact of JISON; Rust would use owned data structures returned from parsing.
- The `styles` system is SVG/CSS-specific and irrelevant for terminal rendering.
- The loose optional-everything interface exists to accommodate 20+ diagram types with vastly different needs; mmdflux can start with a stricter trait.

## Key Takeaways

- **The plugin contract is four functions**: detect (regex), parse (text → db), getData (db → universal layout format), draw (layout → output). In mmdflux terms: detect, parse, build_diagram, render.
- **Mermaid's real shared infrastructure is surprisingly thin**: commonDb (title/accessibility), text sanitization, and the LayoutData type system. Everything else is per-diagram.
- **The unified renderer pattern is the architectural win**: Newer diagrams (flowchart-v3, class-v3, ER-unified) all converge on `db.getData() → LayoutData → render()`, sharing layout algorithms. Older renderers are completely standalone. This suggests mmdflux should design its multi-diagram support around a shared layout data format from the start.
- **The Node/Edge union type is a design smell**: `rendering-util/types.ts` has a single `Node` interface with properties from flowchart, state, class, kanban, and mindmap all mixed together. A Rust implementation should use traits or enums rather than a bag-of-optional-fields.
- **Detection order matters**: Mermaid relies on detector registration order for ambiguous inputs (e.g., `graph` could match flowchart-v1 or v2 depending on config). mmdflux should define clear precedence rules.
- **Lazy loading is a web concern**: In a Rust CLI, all diagram types would be compiled in. The equivalent concern is compile-time feature flags for optional diagram support.
- **Layout algorithm pluggability is valuable**: Mermaid's layout algorithm registry allows swapping dagre for ELK. mmdflux could benefit from a similar abstraction if supporting different layout strategies (e.g., force-directed for certain diagram types).
- **Each diagram type has ~5 unique files**: detector, parser/grammar, DB/data model, renderer, styles/types. This is a reasonable module structure to replicate per diagram type.

## Open Questions

- **How much shared layout infrastructure is reusable across diagram types in text rendering?** Mermaid's flowchart, class, and ER diagrams share dagre layout, but sequence, gantt, and pie have completely custom renderers. Which mmdflux diagram types (if any beyond flowchart) could share the Sugiyama layout pipeline?
- **Should mmdflux's Diagram struct become a trait?** Currently it's concrete for flowcharts. Making it generic would require defining what data each diagram type provides.
- **What's the minimal viable second diagram type?** Adding a simple diagram type (e.g., pie chart as ASCII, or a basic class diagram) would validate the plugin architecture without requiring a full Sugiyama layout.
- **Should detection and parsing be split or combined?** Mermaid separates detection (regex) from parsing (full grammar) for lazy loading. In a compiled Rust binary, combining them (try parsing, fail means wrong type) might be simpler.
