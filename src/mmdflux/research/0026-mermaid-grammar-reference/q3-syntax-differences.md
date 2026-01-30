# Q3: Syntax Differences Between Jison and Langium Grammars

## Summary

Langium grammars are intentionally **stricter** than their Jison predecessors. Known
breaking changes include rejection of unquoted spaces in categories, leading zeros,
and `+`-prefixed numbers. There are also behavioral differences in how the AST is
populated. The `common.langium` shared grammar has known conflicts with complex
diagram grammars around string handling.

## Where

- XY chart migration PR (documents breaking changes): https://github.com/mermaid-js/mermaid/pull/6572
- Common grammar conflicts: https://github.com/mermaid-js/mermaid/issues/6694
- Architecture string label fixes: recent commits on `develop`
- Error reporting improvements: https://github.com/mermaid-js/mermaid/pull/7333

## What

### Documented Breaking Changes (from XY Chart PR #6572)

1. **Unquoted spaces in categories rejected.**
   - Jison: `[category name with spaces]` silently strips spaces
   - Langium: requires quotes — `["category name with spaces"]`

2. **Leading zeros on numbers rejected.**
   - Jison: `007` accepted (parsed as 7)
   - Langium: `007` is a parse error

3. **Positive `+` prefix on numbers rejected.**
   - Jison: `+5` accepted (parsed as 5)
   - Langium: `+5` is a parse error; use `5` instead

### Behavioral Differences

4. **AST population timing.**
   - Jison: populates the diagram database on-the-fly during parsing (via inline JS actions)
   - Langium: parses the full input into an AST first, then populates the database in a
     separate pass
   - Impact: ordering of elements (e.g., plot order, colors) can differ

5. **Error reporting.**
   - Jison: limited error context, no line/column info
   - Langium: accurate line and column numbers in parse errors (PR #7333)

### Known Issues in Langium Grammars

6. **`common.langium` string handling conflicts** (issue #6694)
   - The shared `common.langium` grammar defines string rules that conflict with more
     complex diagram grammars
   - Particularly affects diagrams with rich string syntax (quoted labels, special chars)
   - Architecture diagram had specific fixes for quoted string labels with apostrophes

### Strictness Pattern

The general pattern is that Langium grammars enforce what Jison grammars were
**permissive** about:

| Area | Jison | Langium |
|------|-------|---------|
| Whitespace in tokens | Often silently ignored | Must be explicit |
| Number formats | Permissive (leading zeros, `+` prefix) | Strict |
| String quoting | Sometimes optional | Required where grammar says so |
| Error recovery | Ad-hoc (JS in actions) | Structured (Langium framework) |

## How

The differences arise from fundamental parser architecture differences:

- **Jison** uses LALR(1) parsing with inline JavaScript actions. The actions can do
  arbitrary transformations during parsing, making the effective grammar more permissive
  than what the BNF rules express.

- **Langium** generates a clean parser from the grammar alone. No inline code means the
  grammar must explicitly handle every valid input. This naturally produces a stricter
  parser.

## Why

The stricter behavior is **intentional**. The Mermaid team views the migration as an
opportunity to clean up ambiguous or surprising parsing behavior. However, they are
cautious about breaking existing diagrams — the approach is to port Jison test cases
and verify backward compatibility where possible.

## Key Takeaways

- **For mmdflux:** target the Langium strictness level where Langium grammars exist.
  For Jison-only diagrams, match Jison's permissive behavior since that's what users
  actually rely on.
- The on-the-fly vs. post-parse AST population difference is irrelevant for Pest
  translation — Pest naturally produces a parse tree first, like Langium.
- Watch for `common.langium` string handling patterns; these may need special attention
  in Pest since PEG grammars handle string matching differently.

## Open Questions

- Will flowchart migration introduce similar breaking changes for the most-used diagram type?
- Should mmdflux implement a "strict" and "permissive" mode to handle both styles?
