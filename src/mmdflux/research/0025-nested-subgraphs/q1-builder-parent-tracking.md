# Q1: Builder Parent Tracking for Nested Subgraphs

## Summary

The graph builder currently skips nested subgraphs when collecting node IDs (line 89 in `builder.rs`), preventing parent-child relationships from being tracked. To support nested subgraphs, the `Subgraph` struct needs a new `parent` field, `process_statements` needs to pass parent context through the recursion, and `collect_node_ids` must recursively collect IDs from nested subgraphs—treating them as transitive descendants at render time while tracking the explicit parent for layout purposes.

## Where

**Files consulted with line numbers:**
- `src/graph/builder.rs` (lines 20–98, especially 36–46, 82–98)
- `src/graph/diagram.rs` (lines 22–31)
- `src/parser/ast.rs` (lines 103–123)
- `src/graph/node.rs` (lines 16–26, confirms `parent` field exists for nodes)

## What

**Current behavior:**

1. **Parser output (AST):** The recursive parser correctly parses nested subgraphs into `SubgraphSpec.statements`, which can itself contain `Statement::Subgraph` variants.

2. **Builder processing (lines 36–46):** When `process_statements` encounters a `Statement::Subgraph`, it:
   - Recursively calls `process_statements` on the subgraph's statements with `parent_subgraph: Some(&sg_spec.id)` (correct)
   - Collects node IDs from the subgraph via `collect_node_ids(&sg_spec.statements)`
   - Creates a `Subgraph` struct with those IDs (lines 41–46)
   - Inserts it into `diagram.subgraphs`

3. **Node parent tracking (lines 61–79):** Nodes get their `parent` field set correctly. Nodes in nested subgraph "d" get `parent: Some("d")`.

4. **collect_node_ids implementation (lines 82–98):**
   - Returns `Vec<String>` of node IDs from `Statement::Vertex` and `Statement::Edge`
   - **Returns empty vec `[]` for `Statement::Subgraph` (line 89)** — This is the critical gap
   - For example input, subgraph "a" gets `nodes: [b, c]` (from direct edges), subgraph "d" gets `nodes: [c, f]` (correct)
   - But if a subgraph contained *only* nested subgraphs and no direct nodes, it would get `nodes: []` and be skipped at lines 826–828 in `convert_subgraph_bounds`

5. **Missing parent relationship:** The `Subgraph` struct (lines 22–31 in `diagram.rs`) has no `parent` field, so downstream stages cannot know that "d" is a child of "a". The layout system cannot call `dagre::set_parent(child_sg, parent_sg)`.

## How

**Minimal changes required:**

### 1. Add `parent` field to `Subgraph` struct

In `src/graph/diagram.rs` (lines 22–31), add:

```rust
pub struct Subgraph {
    pub id: String,
    pub title: String,
    pub nodes: Vec<String>,
    pub parent: Option<String>,  // NEW: Track parent subgraph ID
}
```

### 2. Update `process_statements` to pass parent context

Modify lines 36–46 in `src/graph/builder.rs`:

```rust
Statement::Subgraph(sg_spec) => {
    process_statements(diagram, &sg_spec.statements, Some(&sg_spec.id));
    let node_ids = collect_node_ids(&sg_spec.statements);
    diagram.subgraphs.insert(
        sg_spec.id.clone(),
        Subgraph {
            id: sg_spec.id.clone(),
            title: sg_spec.title.clone(),
            nodes: node_ids,
            parent: parent_subgraph.map(|s| s.to_string()),  // NEW
        },
    );
}
```

### 3. Handle nested subgraphs in `collect_node_ids`

Modify lines 82–98 in `src/graph/builder.rs`:

```rust
fn collect_node_ids(statements: &[Statement]) -> Vec<String> {
    let mut seen = HashSet::new();
    let mut ids = Vec::new();
    for stmt in statements {
        let new_ids: Vec<String> = match stmt {
            Statement::Vertex(v) => vec![v.id.clone()],
            Statement::Edge(e) => vec![e.from.id.clone(), e.to.id.clone()],
            Statement::Subgraph(sg) => collect_node_ids(&sg.statements),  // CHANGED: Recurse
        };
        for id in new_ids {
            if seen.insert(id.clone()) {
                ids.push(id);
            }
        }
    }
    ids
}
```

### 4. Update struct construction in tests

Any place that constructs a `Subgraph` needs `parent: None,` added.

## Why

**Design rationale:**

1. **Parent tracking is essential for the layout stage (Q2).** The dagre infrastructure has a `set_parent(child, parent)` call but needs subgraph-to-subgraph relationships to invoke it.

2. **Recursive `collect_node_ids` is pragmatic.** Including transitive descendants in `nodes` allows existing bounds computation to work unchanged. Q2 will use the `parent` field for precise hierarchical layout.

3. **Tradeoffs:**
   - **Pro:** Minimal builder changes; existing logic continues to work.
   - **Con:** `nodes` loses the distinction between direct vs. nested descendants. Q3 will use the `parent` field to reconstruct this when rendering nested borders.

## Key Takeaways

- Nested subgraphs parse correctly but builder relationship info is lost due to empty return from `collect_node_ids` for `Statement::Subgraph`.
- The `Subgraph` struct needs a `parent` field (parallel to `Node.parent`) to enable downstream stages to build the subgraph hierarchy.
- Recursive `collect_node_ids` ensures outer subgraphs include transitive node descendants, preventing empty bounds computation and skip logic.
- Three minimal changes: add `parent` field to struct, pass parent through recursion in `process_statements`, and recurse in `collect_node_ids`.

## Open Questions

- **Q2 follow-up:** Does dagre's `set_parent` API handle multi-level compound nesting correctly?
- **Q3 follow-up:** How should nested borders be rendered when bounds are computed from transitive descendants rather than direct child subgraphs?
- **Edge case:** What happens with node re-use across subgraph levels?
