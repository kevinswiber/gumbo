#!/usr/bin/env node
// Trace dagre's ordering algorithm for complex.mmd
// Usage: node trace-dagre.js
//
// Patches dagre's initOrder and order sweeps to log the same info
// as mmdflux's MMDFLUX_DEBUG_ORDER=1 output for comparison.

const dagre = require("/Users/kevin/src/dagre");
const Graph = dagre.graphlib.Graph;

// Build complex.mmd graph
const g = new Graph({ multigraph: true, compound: true })
  .setGraph({ rankdir: "TB" })
  .setDefaultEdgeLabel(() => ({}));

// Nodes
g.setNode("A", { label: "Input", width: 50, height: 30 });
g.setNode("B", { label: "Validate", width: 50, height: 30 });
g.setNode("C", { label: "Process", width: 50, height: 30 });
g.setNode("D", { label: "Error Handler", width: 50, height: 30 });
g.setNode("E", { label: "More Data?", width: 50, height: 30 });
g.setNode("F", { label: "Output", width: 50, height: 30 });
g.setNode("G", { label: "Log Error", width: 50, height: 30 });
g.setNode("H", { label: "Notify Admin", width: 50, height: 30 });
g.setNode("I", { label: "Cleanup", width: 50, height: 30 });

// Edges
g.setEdge("A", "B");
g.setEdge("B", "C", { label: "valid" });
g.setEdge("B", "D", { label: "invalid" });
g.setEdge("C", "E");
g.setEdge("E", "A", { label: "yes" });
g.setEdge("E", "F", { label: "no" });
g.setEdge("D", "G");
g.setEdge("D", "H");
g.setEdge("G", "I");
g.setEdge("H", "I");
g.setEdge("I", "F");

// Run layout
dagre.layout(g);

// Print results
console.log("\n=== Final node positions ===");
for (const v of g.nodes()) {
  const node = g.node(v);
  console.log(`  ${v} (${node.label}): x=${node.x}, y=${node.y}, rank=${node.rank}, order=${node.order}`);
}

// Group by rank and sort by order
console.log("\n=== Nodes by rank (sorted by order) ===");
const byRank = {};
for (const v of g.nodes()) {
  const node = g.node(v);
  const rank = node.rank;
  if (rank === undefined) continue; // skip dummy cleanup
  if (!byRank[rank]) byRank[rank] = [];
  byRank[rank].push({ id: v, label: node.label, order: node.order, x: node.x });
}
for (const rank of Object.keys(byRank).sort((a, b) => a - b)) {
  const nodes = byRank[rank].sort((a, b) => a.order - b.order);
  const names = nodes.map(n => `${n.id}(${n.label})=${n.order}`).join(", ");
  console.log(`  rank ${rank}: [${names}]`);
}
