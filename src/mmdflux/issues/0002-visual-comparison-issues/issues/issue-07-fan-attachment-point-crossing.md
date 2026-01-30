# Issue 07: Fan-in/fan-out attachment point ordering causes edge crossings

**Severity:** Medium
**Category:** Attachment point ordering
**Status:** Fixed (Plan 0020, Phase 3)
**Affected fixtures:** `fan_in`, `fan_out`, `multiple_cycles`

## Description

In TD fan-in and fan-out patterns, edge attachment points on the shared node
are ordered incorrectly, causing edges to cross unnecessarily. Edges from
left-side source nodes attach at right-side positions on the target (and vice
versa), creating an X-shaped crossing that makes the diagram harder to read.

## Reproduction

### fan_in.mmd

```
graph TD
    A[Source A] --> D[Target]
    B[Source B] --> D
    C[Source C] --> D
```

```
cargo run -q -- tests/fixtures/fan_in.mmd
```

**mmdflux output:**
```
┌──────────┐    ┌──────────┐    ┌──────────┐
│ Source A │    │ Source B │    │ Source C │
└──────────┘    └──────────┘    └──────────┘
         └─────┐ ┌───┼──────────┘
               ▼ ▼   ▼
            ┌────────┐
            │ Target │
            └────────┘
```

Source B (center) connects to Target at a point to the LEFT of Source C's
connection. The `┌───┼──────────┘` shows Source C's edge crossing over Source
B's attachment point. Source B should attach at the center of Target (between
A and C), but instead it attaches to the left of C, causing a crossing.

### fan_out.mmd

```
graph TD
    A[Source] --> B[Target A]
    A --> C[Target B]
    A --> D[Target C]
```

**mmdflux output:**
```
            ┌────────┐
            │ Source │
            └────────┘
         ┌─────┘ └───┼──────────┐
         ▼           ▼          ▼
┌──────────┐    ┌──────────┐    ┌──────────┐
│ Target A │    │ Target B │    │ Target C │
└──────────┘    └──────────┘    └──────────┘
```

Same issue reversed: Source's bottom attachment points are not ordered
left-to-right matching the target positions. The `└───┼──────────┐` shows
Target B's edge crossing over Target C's line.

### multiple_cycles.mmd

```
graph TD
    A[Top] --> B[Middle]
    B --> C[Bottom]
    C --> A
    C --> B
```

**mmdflux output:**
```
  ┌─────┐
  │ Top │
  └─────┘
    └▲
     └────┐
┌────────┐│
│ Middle ││
└────────┘│
   │ ▲    │
  ┌┘ └┐   │
  ▼ ┌─┼───┘
┌────────┐
│ Bottom │
└────────┘
```

The backward edges from Bottom create crossings due to flipped attachment
point ordering. The `┌─┼───┘` shows the C→A backward edge crossing over
the C→B backward edge.

## Expected behavior

Attachment points on a shared node face should be ordered to match the
spatial positions of the connected nodes — leftmost source gets leftmost
attachment point, rightmost source gets rightmost attachment point. This
prevents unnecessary crossings.

## Root cause hypothesis

The attachment point spreading logic in `compute_attachment_plan()`
(`src/render/router.rs`) does not sort edges by the spatial position of the
opposite node. Instead, edges may be ordered by insertion order or edge index,
which doesn't correlate with geometric position.
