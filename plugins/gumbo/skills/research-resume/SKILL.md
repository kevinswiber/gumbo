---
name: research-resume
description: Resume a research plan through investigation, progress checks, and synthesis within the requested scope.
---

# Research Resume Skill

Resume work on a research plan through investigation, collection, and synthesis. Honor status-only requests; when execution is authorized, continue to the requested outcome within the agreed budget.

## Process

1. **Resolve the target:**
   - Use an explicit research plan or unambiguous current-session cursor first.
   - Scan for active research only when the target is unresolved:
   - Look for `.gumbo/research/NNNN-*/research-plan.md` files (exclude `.gumbo/research/archive/`)
   - A research plan is active if its `.research-state.json` has `status` other than `"complete"` or `"archived"`
   - If no state file exists, treat as active if the research-plan.md exists

2. **Handle different scenarios:**

   **No active research found:**
   ```
   No active research plans found in `.gumbo/research/`.

   To create a new research plan, use `/research-create <topic description>`.
   ```

   **Multiple active research plans and no target resolved:**
   List all and ask user to choose:
   ```
   Found multiple active research plans:

   1. `.gumbo/research/0001-edge-routing/` - Status: in_progress (3/5 questions complete)
   2. `.gumbo/research/0002-layout-algo/` - Status: planned (not started)

   Which research plan would you like to resume?
   ```

   **Single plan found:** Proceed to state-based handling below.

3. **Read `.research-state.json`** and handle based on status. If it is missing, inspect existing findings and session context before choosing the initial state; do not assume completed work must be repeated.

### State: `planned` (investigation not started)

1. Display the research plan summary
2. Reuse existing execution authorization. A request to create or inspect a plan does not authorize investigation; ask only when starting remains outside the requested scope.
3. **Investigate the questions using an appropriate execution shape.** Parallelize independent questions when delegation is authorized and useful; otherwise investigate serially. Use the active environment's capabilities, without assuming agent types or background flags. Each question produces its own findings file.
   - Each investigation's prompt should include:
     - The specific question to investigate
     - The where/what/how/why framework from the research plan
     - The sources to consult
     - **A shared interface-contract block** (when the questions share decided constraints, a vocabulary, or an interface): paste the *same* block verbatim into every agent's prompt. Independent investigators need the same decided constraints to avoid drift in names, verdict values, or seams. After they return, sweep the outputs for agreement on those shared terms and reconcile any drift before synthesizing.
     - Instructions to write findings to the output file using the findings template
     - The full path to the output file: `.gumbo/research/NNNN-topic/qN-filename.md`
     - **Hard rules:** write the findings file end-to-end; do **not** edit source under the code repo (read-only — propose, don't change); do not commit; return only a terse summary (the file is the deliverable, which keeps the orchestrator's context lean)
   - **Sequence dependent questions:** a question that must read the others' outputs (e.g. a final "allocation / synthesis-input" question) is spawned *after* the independent ones land, not in the same batch — it reads their files. Independent questions may run concurrently; dependent questions follow their prerequisites.
   - Keep agent tasks bounded and reuse existing agents where continuity matters. If working serially, apply the same findings contract locally.
4. **Collect any agent/task IDs** the mechanism returns (for resuming or tracking); use an empty `agent_ids` array for local investigation.
5. **Update `.research-state.json`:**
   ```json
   {
     "status": "in_progress",
     "updated_at": "...",
     "agent_ids": ["agent-1-id", "agent-2-id", "agent-3-id"],
     ...
   }
   ```
6. **Update `research-plan.md`** status to `IN PROGRESS` and update the Expected Outputs table statuses
7. Display:
   ```
   **Research started:** `.gumbo/research/NNNN-topic-name/`
   **Investigations:** N questions; local or delegated as authorized
   **Agent IDs:** `id1`, `id2`, `id3`

   Continue collecting results and synthesize when complete. If the user requested a background handoff, report the live task IDs and current state instead.
   ```

### State: `in_progress` (investigation underway)

1. **Check task status and question outputs.** File existence alone does not establish completion; a worker may still be writing.
2. **Read completed findings files** and verify they answer the question substantively. For delegated work, also verify that the worker finished or explicitly handed off that output.
3. **Update `research-plan.md`** Expected Outputs table with current status
4. Display progress:
   ```
   **Research progress:** `.gumbo/research/NNNN-topic-name/`
   **Questions:** X/N complete

   **Complete:**
   - Q1: [Title] -> `q1-file.md`
   - Q3: [Title] -> `q3-file.md`

   **Pending:**
   - Q2: [Title] -> `q2-file.md` (agent: `id2`)
   ```

5. **If all questions complete**, proceed to synthesis (see below)
6. **If some are pending**, continue collection within the authorized budget using the available wait mechanism. Repair or retry bounded failures when authorized. At a budget limit or external blocker, retain partial results and report the next action. Label a requested partial synthesis explicitly; do not present it as complete.

### State: `in_progress` with all questions complete -> Synthesis

> **Propagate every change across the research (the anti-drift rule).** Research is iterated — a review,
> a late finding, or an owner direction changes a decided value, a vocabulary term, or a recommendation.
> When that happens, it almost never lives in one file: a rule stated in Q5 is echoed in Q2's
> takeaways, Q7's allocation, and the synthesis. Before moving on, search **every** question file *and*
> `synthesis.md` for the OLD form and reconcile **all** of them — a synthesis that contradicts its own
> question files (or two question files that disagree) is the most common research defect, and it is
> cheap to fix now and expensive later. `/research-review` is the reactive net for what the sweep misses.

1. **Read all findings files**
2. **Synthesize findings** into `synthesis.md`:

   ```markdown
   # Research Synthesis: Topic Name

   ## Summary

   [3-5 sentence executive summary of all findings]

   ## Key Findings

   ### [Finding 1 title]
   [Cross-cutting finding that draws from multiple questions]

   ### [Finding 2 title]
   [Another cross-cutting finding]

   ## Recommendations

   1. **[Recommendation]** — [Rationale based on findings]
   2. **[Recommendation]** — [Rationale]

   ## Where/What/How/Why Summary

   | Aspect | Key Points |
   |--------|------------|
   | **Where** | [Key locations/sources identified] |
   | **What** | [Core facts discovered] |
   | **How** | [Key mechanisms understood] |
   | **Why** | [Design rationale and tradeoffs] |

   ## Open Questions

   - [Questions that emerged and may warrant deeper research]

   ## Next Steps

   - [ ] [Suggested follow-up action]
   - [ ] [Suggested follow-up action]

   ## Source Files

   | File | Question |
   |------|----------|
   | `q1-file.md` | Q1: Title |
   | `q2-file.md` | Q2: Title |
   ```

3. **Update `.research-state.json`:**
   ```json
   {
     "status": "synthesized",
     "updated_at": "...",
     "synthesis_agent_id": null,
     "last_session_notes": "Synthesis complete. N findings, M recommendations.",
     ...
   }
   ```
   Note: `synthesis_agent_id` is null when synthesis is done inline. Set it to an agent ID if a separate agent performed synthesis.

4. **Update `research-plan.md`** status to `SYNTHESIZED` and mark synthesis as complete in Expected Outputs
5. Display:
   ```
   **Research synthesized:** `.gumbo/research/NNNN-topic-name/`
   **Findings:** N questions answered
   **Synthesis:** `synthesis.md`

   **Key findings:**
   - [Finding 1]
   - [Finding 2]

   **Recommendations:**
   - [Recommendation 1]
   - [Recommendation 2]

   To create an implementation plan based on this research, run `/plan-create` and reference `.gumbo/research/NNNN-topic-name/`.

   To archive this research, run `/research-archive NNNN`.
   ```

### State: `synthesized` (synthesis complete)

1. Display the synthesis summary
2. Offer options:
   - Create a deeper investigation on a subtopic (hierarchical research)
   - Create an implementation plan based on findings
   - Archive the research

### Deeper Investigation (Hierarchical Research)

If the user wants to investigate a subtopic further:

1. Create `.gumbo/research/NNNN-topic/subtopic-name/` subdirectory
2. Create a new `research-plan.md` and `.research-state.json` inside it
3. The parent research's synthesis should note the child investigation
4. Follow the same create/resume lifecycle for the child

## Session Notes

Before ending any session, update `.research-state.json` with:
- `updated_at`: current UTC timestamp
- `last_session_notes`: summary of what happened and what to do next
