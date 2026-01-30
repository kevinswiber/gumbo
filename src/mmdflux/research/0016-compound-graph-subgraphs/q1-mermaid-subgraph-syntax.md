# Q1: Mermaid Subgraph Syntax and Parsing

## Summary

Mermaid flowcharts support subgraphs via `subgraph ... end` blocks that group nodes into visually distinct clusters with labeled borders. The syntax supports three ID/title notations: implicit ID (title becomes ID), explicit ID with quoted title `id[title]`, and direction overrides within subgraphs. Edges can cross subgraph boundaries freely, and subgraphs can contain nested subgraphs. The mermaid-js parser represents subgraphs as a flat array of `FlowSubGraph` objects, each with an ID, title, node membership list, optional direction override, and CSS classes.

## Where

- `/Users/kevin/src/mermaid/packages/mermaid/src/diagrams/flowchart/parser/flow.jison` -- JISON grammar (lines 119-120, 379-386)
- `/Users/kevin/src/mermaid/packages/mermaid/src/diagrams/flowchart/parser/subgraph.spec.js` -- Test cases covering all syntax variations
- `/Users/kevin/src/mermaid/packages/mermaid/src/diagrams/flowchart/flowDb.ts` -- FlowDB class and `addSubGraph()` method (lines 636-708)
- `/Users/kevin/src/mermaid/packages/mermaid/src/diagrams/flowchart/types.ts` -- FlowSubGraph interface definition
- `/Users/kevin/src/mermaid/packages/mermaid/src/docs/syntax/flowchart.md` -- Official documentation (lines 884-981)

## What

### Full Subgraph Syntax

**Basic Forms:**

1. **Implicit ID (title becomes ID):**
   ```
   subgraph title
     nodes and edges
   end
   ```
   The parser uses the title text as the ID. If it contains spaces, an auto-generated ID like `subGraph0` is assigned instead.

2. **Explicit ID with title (standard form):**
   ```
   subgraph id[title]
     nodes and edges
   end
   ```
   The `id` is a single token (alphanumeric, underscores, hyphens). The title in brackets can be multi-word, quoted, or unquoted.

3. **Quoted title form:**
   ```
   subgraph "multi-word title"
     nodes and edges
   end
   ```
   When title contains spaces and no ID is provided, an auto-generated ID is created.

**ID Generation Rules (from flowDb.ts lines 687-688):**
- If ID is explicit (from `subgraph id[title]`), use it as-is
- If ID would be the title and title contains spaces, use auto-generated `subGraph{n}` where n is a counter
- If ID is implicit and title is a single token, use the title as ID
- All generated/used IDs are unique within the flowchart

**Nesting:**
Subgraphs can be nested to arbitrary depth:
```
subgraph parent
  subgraph child1
    a1-->a2
  end
  subgraph child2
    b1-->b2
  end
end
```

**Direction Overrides:**
Each subgraph can override the parent direction:
```
graph LR
  subgraph A
    direction TD
    a1 --> a2
  end
  A --> B
```

**Edge Crossing Boundaries:**
- Edges can originate inside a subgraph and target outside
- Edges can originate outside and target a node inside
- Edges can target the subgraph ID itself
- No special syntax required; nodes are added to subgraphs independently of edges

**AST Structure (FlowSubGraph type, types.ts):**
```typescript
export interface FlowSubGraph {
  classes: string[];
  dir?: string;
  id: string;
  labelType: string;
  nodes: string[];
  title: string;
}
```

## How

**Grammar Rules (flow.jison lines 379-386):**

```jison
| subgraph SPACE textNoTags SQS text SQE separator document end
  {$$=yy.addSubGraph($textNoTags,$document,$text);}
| subgraph SPACE textNoTags separator document end
  {$$=yy.addSubGraph($textNoTags,$document,$textNoTags);}
| subgraph separator document end
  {$$=yy.addSubGraph(undefined,$document,undefined);}
```

Three rules handle:
1. `subgraph id[title]` -- textNoTags is ID, text is title
2. `subgraph title` -- textNoTags is both title and (potential) ID
3. `subgraph` alone (unnamed)

**Key Design Choices:**

1. **Flat Array of Subgraphs:** mermaid-js stores `subGraphs: FlowSubGraph[]` rather than a tree. Parent-child relationships are implicit -- a subgraph is nested if its nodes contain other subgraph IDs.

2. **Node Membership List:** Each subgraph maintains an explicit `nodes: string[]` array listing which node/subgraph IDs belong to it.

3. **Post-Parse Uniqueness:** `makeUniq()` method (flowDb.ts lines 923-931) removes nodes from earlier subgraphs if they later appear in later-defined subgraphs.

4. **Direction Handling:** `addSubGraph` extracts direction statements from the document by filtering for `{ stmt: 'dir', value: ... }` objects. Directions are inherited from parent if `flowchart.inheritDir` is enabled and the subgraph has no outgoing edges.

5. **Auto-ID Generation:** If no explicit ID is provided, `subGraph{counter}` is generated.

**Edge Cross-Boundary Handling:**
- Edges remain abstract: stored as FlowEdge with start/end node IDs
- No special edge type for "subgraph boundary crossing"
- The graph layer resolves whether an edge target is a node or a subgraph ID
- Renderer handles boundary-crossing edges by positioning endpoints at subgraph border coordinates

## Why

1. **Flat Array Over Tree:** mermaid-js uses a flat subgraph array because compound graph operations (nestingGraph.run(), border segment generation) operate on a flat parent-child map. Nest relationships are recovered during layout. This simplifies the parser.

2. **Explicit Node Membership:** Allows nodes to be declared before subgraph definitions, added via separate statements, and reassigned between subgraphs.

3. **Post-Parse Uniqueness:** `makeUniq()` ensures each node belongs to exactly one subgraph (the latest definition), simplifying layout.

4. **No Edge Type Distinctions for Boundaries:** The graph layer (dagre) infers boundary-crossing during layout by checking parent-child relationships. This keeps the parser and edge representation simple.

## Key Takeaways

- Mermaid accepts `subgraph title`, `subgraph id[title]`, and quoted titles -- parser must handle all three with auto-ID generation fallback
- Nested subgraphs use recursive grammar (`document` rule); parser builds a flat list with nesting implied by node membership
- `direction TD/LR/etc.` inside a subgraph is a statement, not part of the subgraph header
- FlowSubGraph has no parent field; nesting is inferred later (if subgraph A's nodes include subgraph B's ID, B is nested in A)
- Edges in the AST don't know about subgraph membership; the graph layer resolves whether an edge target is a node or subgraph
- Single-word titles become IDs; multi-word titles trigger auto-generation

## Open Questions

- Do edges targeting subgraph IDs exist in Mermaid (e.g. `outside --> subgraphID`)? Tests don't show clear examples
- How does Mermaid handle nodes added to multiple subgraphs? `makeUniq()` removes earlier assignments -- is this documented behavior?
- Can subgraph IDs be reused across different parent subgraphs? The ID uniqueness is global
- What is the interaction between direction inheritance and nested subgraphs with mixed directions?
- Are there style/class statements specific to subgraphs?
