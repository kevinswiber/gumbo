# Mermaid Flowchart Parser Task List

## Status: ✅ COMPLETE

## Phase 1: Project Setup and Basic Parser Infrastructure
- [x] **1.1** Add pest dependencies to Cargo.toml (pest, pest_derive, thiserror)
- [x] **1.2** Create module structure (parser/, graph/ directories with mod.rs files)
- [x] **1.3** Create minimal grammar for graph header parsing only
- [x] **1.4** Implement pest parser with derive macro in flowchart.rs
- [x] **1.5** Add ParseError type with line/column info in error.rs
- [x] **1.6** Unit test header parsing (graph TD, graph LR, flowchart TB)

## Phase 2: Node Parsing
- [x] **2.1** Add identifier rule to grammar
- [x] **2.2** Add rectangle shape rule `[text]` to grammar
- [x] **2.3** Add round shape rule `(text)` to grammar
- [x] **2.4** Add diamond shape rule `{text}` to grammar
- [x] **2.5** Create Node and Shape types in graph/node.rs
- [x] **2.6** Create AST types (Vertex, ShapeSpec) in parser/ast.rs
- [x] **2.7** Unit tests for node parsing (all shapes)

## Phase 3: Edge Parsing
- [x] **3.1** Add solid arrow rule `-->` to grammar
- [x] **3.2** Add edge label rule `-->|text|` to grammar
- [x] **3.3** Add dotted arrow rule `-.->` to grammar
- [x] **3.4** Add thick arrow rule `==>` to grammar
- [x] **3.5** Add open line rule `---` to grammar
- [x] **3.6** Create Edge, Stroke, Arrow types in graph/edge.rs
- [x] **3.7** Unit tests for edge parsing (all types)

## Phase 4: Statement Composition
- [x] **4.1** Add vertex_statement rule combining nodes and edges
- [x] **4.2** Add chain support for `A --> B --> C`
- [x] **4.3** Add ampersand support for `A & B --> C`
- [x] **4.4** Add multi-line statement parsing
- [x] **4.5** Add comment support `%%`
- [x] **4.6** Integration tests for complete flowcharts

## Phase 5: Graph Building
- [x] **5.1** Create Diagram struct in graph/diagram.rs
- [x] **5.2** Implement AST-to-graph builder in graph/builder.rs
- [x] **5.3** Handle node deduplication (same ID referenced multiple times)
- [x] **5.4** Populate nodes HashMap from AST
- [x] **5.5** Populate edges Vec from AST
- [x] **5.6** Set default labels (node label defaults to ID)
- [x] **5.7** Integration tests for full pipeline

## Phase 6: CLI Integration and Polish
- [x] **6.1** Create lib.rs with public parse_flowchart() API
- [x] **6.2** Update main.rs to call parser and output graph summary
- [x] **6.3** Improve error messages with context
- [x] **6.4** Add --debug flag for AST/graph dump
- [x] **6.5** Add doc comments on public types
- [x] **6.6** Update README with usage examples

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Setup & Infrastructure | ✅ Complete | |
| 2 - Node Parsing | ✅ Complete | |
| 3 - Edge Parsing | ✅ Complete | |
| 4 - Statement Composition | ✅ Complete | |
| 5 - Graph Building | ✅ Complete | |
| 6 - CLI Integration | ✅ Complete | |
