# Research Prompt for Edge Routing Deep Dive

Copy and paste this prompt into a new Claude Code session to run the research:

---

## Prompt

I need you to research edge routing issues in mmdflux by comparing with Mermaid.js and Dagre implementations.

**Research Directory:** `research/edge-routing-deep-dive/`

**Tracker File:** Read `RESEARCH-TRACKER.md` for full context on the 4 issues to research.

**Instructions:**

1. **Launch 4 parallel research subagents** using the Task tool with `subagent_type=Explore`. Each agent should investigate one issue:
   - Issue 1: Missing arrow on Process → More Data? edge
   - Issue 2: "yes" label collision with other edges
   - Issue 3: Overlapping edges at node top
   - Issue 4: Edge routing through/alongside Cleanup node

2. **Each subagent should:**
   - Use WebFetch to examine Mermaid.js source code on GitHub (flowchart rendering, edge routing)
   - Use WebFetch to examine Dagre source code on GitHub (layout algorithm, edge routing)
   - Use Read to examine mmdflux source code (`src/render/router.rs`, `src/render/layout.rs`, `src/render/edge.rs`)
   - Use the Mermaid live editor (https://mermaid.live/) to see reference output for `tests/fixtures/complex.mmd`
   - Write findings to the designated output file (e.g., `issue-1-missing-arrow.md`)

3. **For each issue, document:**
   - What Mermaid/Dagre actually do
   - What mmdflux currently does
   - Why the difference exists
   - What properties we need to achieve
   - What ASCII constraints affect the solution
   - Proposed tradeoffs and recommendations

4. **After all 4 agents complete**, synthesize the findings:
   - Read all 4 output files
   - Create `SYNTHESIS.md` with combined analysis
   - Update the status table in `RESEARCH-TRACKER.md`
   - Report key findings and recommended next steps

**Key GitHub URLs to examine:**
- Mermaid flowchart: `https://github.com/mermaid-js/mermaid/tree/develop/packages/mermaid/src/diagrams/flowchart`
- Dagre layout: `https://github.com/dagrejs/dagre/tree/master/lib`
- Dagre-D3 rendering: `https://github.com/dagrejs/dagre-d3`

**Test command:** `cargo run -q -- ./tests/fixtures/complex.mmd`

Run the 4 research agents in parallel, wait for them to complete, then synthesize.
