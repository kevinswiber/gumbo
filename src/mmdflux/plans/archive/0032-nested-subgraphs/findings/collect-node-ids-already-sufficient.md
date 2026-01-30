# Finding: Recursive collect_node_ids Made Some Tasks Pass Early

**Type:** discovery
**Task:** 2.1, 3.2
**Date:** 2026-01-29

## Details
Task 1.3 (making `collect_node_ids` recurse into nested subgraphs) had a bigger impact than expected. Because outer subgraphs now include inner subgraph nodes in their `nodes` list, the existing bounds computation already produced valid bounds for both inner and outer subgraphs — the Task 2.1 test passed immediately.

The inside-out redesign (Task 3.2) was still needed to ensure proper containment (parent bounds enclosing child bounds with padding), since the flat approach computed both from the same node positions and produced identical bounds.

## Impact
Some planned "red" tests were already green before the green phase. The overall design still needed all changes for correctness.

## Action Items
- None
