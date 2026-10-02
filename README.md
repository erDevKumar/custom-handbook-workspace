# Custom Handbook Workspace

A workspace for producing print-ready A4 technical handbooks. One shared style
library, one folder per handbook.

```
custom-handbook-workspace/
├── build.sh                      ./build.sh [name] [--watch]
├── shared/
│   ├── lib/template.typ          the style module — fonts, 6-pen palette,
│   │                             callouts, flowchart shapes, TOC/index engine
│   ├── lib/reference-standard.typ a page that defines the quality bar
│   └── CHAPTER-TEMPLATE.md       the structure every chapter follows
├── handbooks/
│   └── sem-system-design/        ← one handbook
│       ├── handbook.typ          the master. Compile THIS.
│       ├── SPEC.md               the original brief it was written against
│       ├── frontmatter/ part1/ part2/ part3/ part4/ backmatter/
└── dist/                         built PDFs, one per handbook
```

## Build

```
./build.sh                      every handbook
./build.sh sem-system-design    one
./build.sh sem-system-design --watch
```

Each build asserts A4 geometry, continuous page numbering, and that every
internal link resolves. All three have broken silently before.

## Handbooks

| Name | Subject | Status |
|---|---|---|
| `sem-system-design` | Senior Engineering Manager system design interviews | complete — 161 pp |

## Adding a handbook

1. `mkdir -p handbooks/<name>/{frontmatter,part1,backmatter}`
2. Create `handbooks/<name>/handbook.typ`, starting from the SEM one. It must:
   - `#import "/shared/lib/template.typ": *`
   - set page geometry and the running-head state **once**
   - `#include` each fragment by its absolute workspace path
3. `./build.sh <name>`

### What belongs in `shared/` and what does not

`shared/lib/template.typ` is subject-agnostic: typography, colour semantics,
callout blocks, diagram shapes, and the machinery that generates the contents
and index from real page positions. **Nothing in it mentions system design.**
Anything subject-specific belongs in the handbook folder.

If a second handbook needs a style change, change it in `shared/` and rebuild
both — that is the point of the split.

## Conventions every handbook inherits

- **Colour is semantic**, never decorative: green = healthy path, red = failure,
  orange = arithmetic, purple = definition/caveat, blue = structure. Icons
  (▸ ✗ § ※) reinforce the same meanings so a greyscale print still reads.
- **Diagrams are CeTZ with named anchors.** Never hand-place boxes at absolute
  coordinates — arrows must attach to component edges by construction.
- **Margins are mirrored**, 32 mm on the outer edge, as deliberate note-taking
  space for a printed copy. It never falls in the gutter.
- **Chapters start on a fresh page** (`h1()` forces the break), so a reader can
  flip to any chapter.
- **Contents and index are generated** from real page positions, so they cannot
  drift when content moves.
- Every chapter carries at least one diagram, shows its arithmetic in full, and
  names at least one anti-pattern.
