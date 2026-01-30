# Pest Grammar Expansion Task List

## Status: COMPLETE

**Implementation Plan:** [implementation-plan.md](./implementation-plan.md)

---

## Phase 1: Flowchart Grammar Quick Wins

- [x] **1.1** Add semicolon statement separator
  → [tasks/1.1-semicolon-separator.md](./tasks/1.1-semicolon-separator.md)

- [x] **1.2** Add style/class statement passthrough (parse and discard)
  → [tasks/1.2-style-passthrough.md](./tasks/1.2-style-passthrough.md)

## Phase 2: Additional Node Shapes

- [x] **2.1** Add additional node shapes to Pest grammar
  → [tasks/2.1-node-shapes-grammar.md](./tasks/2.1-node-shapes-grammar.md)

- [x] **2.2** Add Shape enum variants and render fallbacks
  → [tasks/2.2-shape-enum-render.md](./tasks/2.2-shape-enum-render.md)

## Phase 3: Multi-Diagram Infrastructure

- [x] **3.1** DiagramType enum and detection function
  → [tasks/3.1-diagram-type-detection.md](./tasks/3.1-diagram-type-detection.md)

- [x] **3.2** Update CLI to dispatch by diagram type
  → [tasks/3.2-cli-dispatch.md](./tasks/3.2-cli-dispatch.md)

## Phase 4: New Diagram Parsers

- [x] **4.1** Info Pest grammar and parser
  → [tasks/4.1-info-grammar.md](./tasks/4.1-info-grammar.md)

- [x] **4.2** Pie Pest grammar and parser
  → [tasks/4.2-pie-grammar.md](./tasks/4.2-pie-grammar.md)

- [x] **4.3** Packet Pest grammar and parser
  → [tasks/4.3-packet-grammar.md](./tasks/4.3-packet-grammar.md)

## Phase 5: Extended Edge Syntax

- [x] **5.1** Extended edge syntax (length variants, bidirectional, cross/circle heads)
  → [tasks/5.1-extended-edges.md](./tasks/5.1-extended-edges.md)

## Phase 6: Compliance Testing

- [x] **6.1** Flowchart compliance tests from upstream spec files
  → [tasks/6.1-flowchart-compliance.md](./tasks/6.1-flowchart-compliance.md)

- [x] **6.2** Pie/info/packet compliance tests from upstream spec files
  → [tasks/6.2-new-diagram-compliance.md](./tasks/6.2-new-diagram-compliance.md)

## Progress Tracking

| Phase | Status | Notes |
|-------|--------|-------|
| 1 - Flowchart Quick Wins | Complete | Semicolons + style passthrough |
| 2 - Node Shapes | Complete | Grammar + AST + builder + render fallbacks |
| 3 - Multi-Diagram Infra | Complete | DiagramType enum + CLI dispatch |
| 4 - New Diagram Parsers | Complete | Info + Pie + Packet grammars |
| 5 - Extended Edges | Complete | ConnectorSpec struct + variable length + arrow heads |
| 6 - Compliance Testing | Complete | 104 passing, 5 ignored |

## Quick Links

| Resource | Path |
|----------|------|
| Implementation Plan | [implementation-plan.md](./implementation-plan.md) |
| Research: Grammar Reference | [research/0026-mermaid-grammar-reference/synthesis.md](../../research/0026-mermaid-grammar-reference/synthesis.md) |
