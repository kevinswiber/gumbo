# ASCIIFlow Project Analysis

Analysis of the asciiflow project at `$HOME/src/asciiflow`.

## 1. Language and Framework

- **Language:** TypeScript
- **Framework:** React 16.14 with React DOM
- **Build System:** Bazel (with Bazelisk for version management)
- **Build Tools:** Webpack 5
- **Runtime:** Node.js / Electron 29 for desktop
- **Platform:** Client-side only web application (asciiflow.com)

## 2. ASCII Art Rendering and Layout

The project uses a **grid-based cell system** with the following key components:

### Core Data Structures

- **Vector System** (`vector.ts`): 2D coordinate system representing positions in the canvas
- **Layer System** (`layer.ts`): Core data structure that maps Vector positions to character values
  - `Layer`: Individual drawable layer with position-to-character mappings
  - `LayerView`: Composite view combining multiple layers with proper layering/blending
- **Box Model** (`common.ts`): Rectangular region definitions with computed boundaries

### Rendering Approach

- Grid dimensions: Up to 2000 x 600 cells
- Character pixels: 9px horizontal × 16px vertical
- Content serialized as plain text with offset coordinates for efficiency
- Text-based format: Stores minimal bounding box, not entire canvas

## 3. Box Drawing Character Algorithms

### Direction System (`direction.ts`)

- Four cardinal directions: UP, DOWN, LEFT, RIGHT
- Each direction is a vector offset (-1,-1) to (1,1)
- Opposite direction mapping for reversal operations

### Character Set (`characters.ts`)

15 supported Unicode box-drawing characters:

```
├─────┐
│ ┌─┐ │
│ ├─┤ │
│ │┼│ │
│ └─┘ │
│  ◄► │
│  ▲▼ │
└─────┘
```

### Connection Metadata System

Each character has:
1. **Connections**: Which directions it connects in (e.g., `├` connects UP, DOWN, RIGHT)
2. **Connectables**: Which directions it can accept new connections from

### Dynamic Connection Algorithm (`characters.ts: connect()` and `disconnect()`)

- Transforms characters based on adjacent connections
- Example: `─` + UP direction → `┬` (T-junction)
- Smooth 4-way junction building: `─` → `┬` → `┼` as connections accumulate
- Handles disconnection by removing direction appropriately

## 4. Line Routing and Rendering

### Line Drawing Algorithm (`draw/utils.ts`)

**Straight Lines:** Directional (horizontal or vertical only)
- Horizontal: fills cells with `─` (U+2500)
- Vertical: fills cells with `│` (U+2502)

**Corner Lines:** L-shaped path with automatic direction selection
- Determines corner position based on `horizontalFirst` flag
- Selects appropriate corner character (┌┐┘└)
- Example: horizontal-first path = right-then-down

### Smart Line Orientation Inference (`draw/line.ts`)

- Analyzes adjacent cells to determine initial direction
- Checks if start has vertical connections (up/down) → suggests horizontal first
- Checks if end has horizontal connections (left/right) → suggests vertical first
- User can override with Ctrl/Shift modifiers

### Snapping Algorithm (`snap.ts`)

- Auto-connects lines to adjacent box-drawing characters
- Bidirectional: connects new lines to existing AND upgrades existing characters
- Only snaps to box-drawing characters (not text)
- Respects "connectability" metadata (not all characters accept all directions)
- Auto-unsnaps when underlying characters are deleted

## 5. Text and Box Handling

### Text Placement (`draw/utils.ts`)

- Direct character-by-character placement at grid positions
- Preserves newlines, spaces ignored
- No justification or wrapping logic

### Box Drawing (`draw/box.ts`)

- Two-point box (start, end) with normalized dimensions
- Fills edges with `─` and `│`
- Places appropriate corners (┌┐┘└) at angles
- Handles degenerate cases (zero-width or zero-height)

### Serialization (`text_utils.ts`)

- Converts grid to text with minimal bounding box
- Filters control characters (ASCII < 32)
- Supports offset positioning for efficient storage
- Round-trip: text ↔ Layer via Vector coordinates

## 6. Advanced Rendering Features

### Context-Aware Character Selection (`render_layer.ts`)

- Analyzes 8 neighboring cells (up, down, left, right, + diagonals)
- Context sum = number of adjacent special values (0-4)
- Different character selection rules per sum level:
  - Sum=1: Terminal endpoint
  - Sum=2: Straight line or corner
  - Sum=3: Three-way junction with special arrow handling
  - Sum=4: Four-way junction with arrow conflict resolution

### Arrow Handling

- Directional arrows: `◄ ► ▲ ▼` (U+25C0, U+25B6, U+25B2, U+25BC)
- Auto-orient based on context
- Special rules for preventing double-arrows on lines
- When 3+ connections and one is an arrow: prefer line over junction

### Modifier Key Interactions

- Ctrl/Shift toggles horizontal-first vs vertical-first routing
- Affects corner position in L-shaped lines

## 7. Techniques Applicable to mmdflux

### Borrowable Concepts

1. **Layering System**: The Layer/LayerView architecture is excellent for composition:
   - Scratch layer for preview during drawing
   - Committed layer for final state
   - Easy undo/redo support
   - Apply/compose pattern is flexible

2. **Connection Metadata Approach**: Instead of character-by-character logic, use directional metadata:
   - Each shape stores which directions it connects
   - Auto-upgrade characters as more connections appear
   - Enables smart junction detection

3. **Smart Line Routing**: Context analysis for path direction selection could apply to:
   - Automatic diagram layout decisions
   - Reducing unnecessary routing around obstacles
   - Adaptive corner placement

4. **Snapping Algorithm**: Two-pass approach perfect for constraint satisfaction:
   - Forward pass: connect new elements to existing
   - Backward pass: clean up deleted connections
   - Could adapt for Mermaid node/link alignment

5. **Serialization Strategy**: Minimal bounding box + text format is:
   - Highly compressible (good for share URLs)
   - Human-readable for debugging
   - Efficient for sparse diagrams
   - Easy version migration

6. **Character Sets**: Dual Unicode/ASCII fallback pattern allows:
   - Rich output for capable terminals
   - Degradation for limited environments
   - Easy to extend with new character sets

7. **Rendering Pipeline**:
   - Raw grid → context analysis → character selection
   - Could abstract character maps to support different styles
   - Enables ASCII vs Unicode vs other modes

### Potential Adaptation for Mermaid

- Use Layer system for diagram geometry (nodes + edges)
- Apply connection metadata to node shapes (rounded boxes, diamonds, etc.)
- Use snapping for alignment/distribution
- Leverage text serialization for compact export
- Adapt context analysis for edge routing around nodes

## Key Files

- `$HOME/src/asciiflow/client/characters.ts` - Character connection logic
- `$HOME/src/asciiflow/client/layer.ts` - Layer data structures
- `$HOME/src/asciiflow/client/vector.ts` - 2D coordinate system
- `$HOME/src/asciiflow/client/common.ts` - Box and CellContext classes
- `$HOME/src/asciiflow/client/text_utils.ts` - Text serialization
- `$HOME/src/asciiflow/client/draw/` - Drawing tools
- `$HOME/src/asciiflow/client/store/canvas.ts` - Canvas state management
