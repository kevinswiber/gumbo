# Issue 01: LR forward edge missing horizontal line, arrow points wrong direction

**Severity:** High
**Category:** LR/RL edge routing
**Status:** Fixed (Plan 0020, Phase 1)
**Affected fixtures:** `left_right`, `fan_in_lr`

## Description

In LR layouts, forward edges between nodes lack a horizontal connecting segment.
The arrowhead points upward (or leftward) instead of rightward toward the target.
The edge appears as a single arrow character jammed between two node borders
with no visible horizontal line.

## Reproduction

### left_right.mmd

```
graph LR
    A[User Input] --> B[Process Data]
    B --> C[Display Result]
```

```
cargo run -q -- tests/fixtures/left_right.mmd
```

**mmdflux output:**
```
┌────────────┐ ┌──────────────┐     ┌────────────────┐
│ User Input │▲│ Process Data │────►│ Display Result │
└────────────┘ └──────────────┘     └────────────────┘
```

The `▲` between "User Input" and "Process Data" points UP/LEFT. There is no
horizontal line segment connecting them. The second edge (Process→Display) is
correct with `────►`.

### fan_in_lr.mmd

```
graph LR
    A[Src A] --> D[Target]
    B[Src B] --> D
    C[Src C] --> D
```

```
cargo run -q -- tests/fixtures/fan_in_lr.mmd
```

**mmdflux output:**
```
┌───────┐
│ Src A │┐
└───────┘│
         │
         │
         │
┌───────┐│┌────────┐
│ Src B │▲│ Target │
└───────┘│└────────┘
         │
         │
         │
┌───────┐│
│ Src C │┘
└───────┘
```

The `▲` between "Src B" and "Target" points UP instead of RIGHT. All three
source nodes connect through a single vertical merge line on the right side,
but there is no horizontal segment connecting to Target's left face. Only Src B
gets an arrow, and it faces the wrong direction.

## Expected behavior

- Each forward LR edge should have a horizontal segment: `──►`
- Arrow should point RIGHT toward the target node
- For fan-in, each source should have its own horizontal connection to the
  target's left face

## Mermaid reference

**left_right.svg:** All nodes at y=35, arrows all point right with horizontal lines.
**fan_in_lr.svg:** Sources at x=56.1, Target at x=206.8. All arrows point right.

## Root cause hypothesis

The edge routing or attachment point logic for LR layouts places the arrowhead
at the source attachment point facing backward, and fails to generate a
horizontal line segment between source right-face and target left-face for
certain edge configurations (particularly same-rank or adjacent-rank edges).
