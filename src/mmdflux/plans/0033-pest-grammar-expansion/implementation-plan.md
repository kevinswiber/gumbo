# Pest Grammar Expansion Implementation Plan

## Status: IN PROGRESS

**Task List:** [task-list.md](./task-list.md)

---

## Overview

Expand mmdflux's Pest grammar coverage in two directions: (1) add support for new Mermaid diagram types (info, pie, packet) starting with the simplest Langium-defined grammars, and (2) improve flowchart grammar coverage with additional node shapes, edge syntax, semicolon separators, and style statement passthrough.

## Current State

mmdflux currently supports **flowchart diagrams only** via a single Pest grammar (`src/parser/grammar.pest`). The parser handles:
- `graph`/`flowchart` + direction (TD/TB/BT/LR/RL)
- Node shapes: Rectangle `[text]`, Round `(text)`, Diamond `{text}`
- Edge types: `-->`, `-.->`, `==>`, `---` with `|label|`
- Chains: `A --> B --> C`
- Ampersand groups: `A & B --> C`
- Subgraphs with optional bracket titles
- Comments: `%%`

## Implementation Approach

**Architecture decision:** Separate `.pest` grammar files per diagram type, each with their own parser module and AST. Pest derives one `Parser` struct per grammar file, giving clean type safety. Shared terminal rules (comments, newlines, strings, numbers) are duplicated by convention across grammar files until a build-script approach becomes warranted.

**File structure for new diagrams:**
```
src/parser/
  mod.rs              -- adds DiagramType enum, detect_diagram_type()
  error.rs            -- unchanged
  grammar.pest        -- flowchart (extended)
  flowchart.rs        -- unchanged name
  ast.rs              -- flowchart AST (extended)
  pie_grammar.pest    -- new
  pie.rs              -- new
  info_grammar.pest   -- new
  info.rs             -- new
  packet_grammar.pest -- new
  packet.rs           -- new
```

**Phase ordering:** Flowchart improvements first (semicolons, style passthrough, node shapes) since they benefit existing users immediately, then diagram type detection infrastructure, then new diagram types, then extended edge syntax.

## Files to Modify/Create

| File | Action | Purpose |
|------|--------|---------|
| `src/parser/grammar.pest` | Modify | Add node shapes, semicolons, style rules |
| `src/parser/ast.rs` | Modify | Add ShapeSpec variants, ConnectorSpec redesign |
| `src/parser/flowchart.rs` | Modify | Handle new grammar rules in parse tree walker |
| `src/parser/mod.rs` | Modify | DiagramType detection, new submodule declarations |
| `src/graph/node.rs` | Modify | Add Shape enum variants |
| `src/render/shape.rs` | Modify | Fallback rendering for new shapes |
| `src/main.rs` or `src/lib.rs` | Modify | Dispatch by diagram type |
| `src/parser/info_grammar.pest` | Create | Info diagram grammar |
| `src/parser/info.rs` | Create | Info parser + AST |
| `src/parser/pie_grammar.pest` | Create | Pie diagram grammar |
| `src/parser/pie.rs` | Create | Pie parser + AST |
| `src/parser/packet_grammar.pest` | Create | Packet diagram grammar |
| `src/parser/packet.rs` | Create | Packet parser + AST |
| `tests/compliance_flowchart.rs` | Create | Upstream compliance tests |

## Task Details

| Task | Description | Details |
|------|-------------|---------|
| 1.1 | Add semicolon statement separator | [tasks/1.1-semicolon-separator.md](./tasks/1.1-semicolon-separator.md) |
| 1.2 | Add style/class statement passthrough | [tasks/1.2-style-passthrough.md](./tasks/1.2-style-passthrough.md) |
| 2.1 | Add additional node shapes to grammar | [tasks/2.1-node-shapes-grammar.md](./tasks/2.1-node-shapes-grammar.md) |
| 2.2 | Add Shape enum variants and render fallbacks | [tasks/2.2-shape-enum-render.md](./tasks/2.2-shape-enum-render.md) |
| 3.1 | DiagramType enum and detection function | [tasks/3.1-diagram-type-detection.md](./tasks/3.1-diagram-type-detection.md) |
| 3.2 | Update CLI to dispatch by diagram type | [tasks/3.2-cli-dispatch.md](./tasks/3.2-cli-dispatch.md) |
| 4.1 | Info Pest grammar and parser | [tasks/4.1-info-grammar.md](./tasks/4.1-info-grammar.md) |
| 4.2 | Pie Pest grammar and parser | [tasks/4.2-pie-grammar.md](./tasks/4.2-pie-grammar.md) |
| 4.3 | Packet Pest grammar and parser | [tasks/4.3-packet-grammar.md](./tasks/4.3-packet-grammar.md) |
| 5.1 | Extended edge syntax (length, bidirectional, cross/circle heads) | [tasks/5.1-extended-edges.md](./tasks/5.1-extended-edges.md) |
| 6.1 | Flowchart compliance tests from upstream | [tasks/6.1-flowchart-compliance.md](./tasks/6.1-flowchart-compliance.md) |
| 6.2 | Pie/info/packet compliance tests | [tasks/6.2-new-diagram-compliance.md](./tasks/6.2-new-diagram-compliance.md) |

## Research References

- [Synthesis: Mermaid Grammar Reference](../../research/0026-mermaid-grammar-reference/synthesis.md)
- [Q1: Grammar Inventory](../../research/0026-mermaid-grammar-reference/q1-grammar-inventory.md)
- [Q2: Migration Status](../../research/0026-mermaid-grammar-reference/q2-migration-status.md)
- [Q3: Syntax Differences](../../research/0026-mermaid-grammar-reference/q3-syntax-differences.md)

## Testing Strategy

All tasks follow strict TDD (Red/Green/Refactor):
- **Red:** Write failing test first (parse test for new syntax, or assert new AST variant)
- **Green:** Implement minimum grammar rules / parser code to pass
- **Refactor:** Clean up, ensure existing tests still pass

Compliance tests (Phase 6) translate upstream Mermaid test cases from `~/src/mermaid/packages/mermaid/src/diagrams/*/parser/*.spec.js` into Rust `#[test]` functions. Tests for not-yet-implemented syntax use `#[ignore]` to document the gap.

## Key Risks

1. **PEG ordered-choice for shapes:** Multi-character delimiters (`([`, `[[`, `((`) must be tried before single-character ones. Addressed by explicit ordering in the `shape` rule.
2. **ConnectorSpec refactor (Task 5.1):** Changing from enum to struct is a breaking internal change. Two-step approach: first add new enum variants, then refactor.
3. **New shapes without render support:** New Shape variants fall back to Rectangle rendering to prevent crashes. Render support is a separate plan.
4. **Upstream flowchart Langium migration:** WIP PR #5892 could change canonical grammar. Compliance tests catch regressions.
