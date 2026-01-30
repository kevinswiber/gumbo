# Research: Mermaid Grammar Reference for Pest Translation

## Status: SYNTHESIZED

---

## Goal

Catalog all grammar definition files in the upstream Mermaid codebase (`~/src/mermaid`)
and document the parser migration status, so we can systematically translate them to
Pest PEG grammars in mmdflux.

## Context

mmdflux re-implements Mermaid rendering in Rust. The parser uses Pest but is not yet
fully compliant with upstream Mermaid syntax. The upstream project has formal grammar
files in two parser technologies (Jison and Langium), and is in the middle of a
multi-year migration from Jison to Langium. Understanding which grammar file is
authoritative for each diagram type is essential before translating.

## Questions

### Q1: What grammar files exist and what technology do they use?

**Where:** `~/src/mermaid/packages/parser/` (Langium), `~/src/mermaid/packages/mermaid/src/diagrams/*/parser/` (Jison)
**What:** Complete inventory of `.langium` and `.jison` files, organized by diagram type
**How:** File search across the mermaid repo
**Why:** Need to know which file to use as the translation source for each diagram

**Output file:** `q1-grammar-inventory.md`

### Q2: What is the Jison-to-Langium migration status?

**Where:** GitHub issues/PRs on mermaid-js/mermaid, git log
**What:** Which diagrams have been migrated, which are in progress, what the plan is
**How:** GitHub search, git log analysis
**Why:** Determines which grammar file is canonical for each diagram type

**Output file:** `q2-migration-status.md`

### Q3: Are there syntax differences between Jison and Langium grammars?

**Where:** GitHub PRs for migrated diagrams, Langium grammar files
**What:** Known breaking changes, stricter validation, behavioral differences
**How:** PR review, grammar comparison
**Why:** Affects which syntax variant mmdflux should target

**Output file:** `q3-syntax-differences.md`

## Sources

| Source | Location | Used by |
|--------|----------|---------|
| Langium grammars | `~/src/mermaid/packages/parser/src/language/` | Q1, Q3 |
| Langium config | `~/src/mermaid/packages/parser/langium-config.json` | Q1 |
| Jison grammars | `~/src/mermaid/packages/mermaid/src/diagrams/*/parser/*.jison` | Q1, Q3 |
| Migration tracking issue | https://github.com/mermaid-js/mermaid/issues/4401 | Q2 |
| Common grammar conflicts | https://github.com/mermaid-js/mermaid/issues/6694 | Q3 |
| Flowchart migration PR | https://github.com/mermaid-js/mermaid/pull/5892 | Q2 |
| XY chart migration PR | https://github.com/mermaid-js/mermaid/pull/6572 | Q2, Q3 |

## Expected Outputs

| File | Question | Status |
|------|----------|--------|
| `q1-grammar-inventory.md` | Q1: Grammar inventory | Done |
| `q2-migration-status.md` | Q2: Migration status | Done |
| `q3-syntax-differences.md` | Q3: Syntax differences | Done |
| `synthesis.md` | Combined findings | Done |
