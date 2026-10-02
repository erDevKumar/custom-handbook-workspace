# SEM System Design Handbook

The handbook is **one typst document**. `book.typ` is the only file compiled; everything
else is a fragment it includes.

```
handbooks/sem-system-design/
├── book.typ                  ← the master. Compile THIS.
├── lib/
│   ├── template.typ          styles, 6-pen palette, diagram helpers, book state
│   ├── reference-standard.typ the quality bar a module page must meet
│   └── MODULE-TEMPLATE.md    the 7-part structure every module follows
├── frontmatter/front.txt     half-title → about the author  (roman i–xiii)
├── part1/
│   ├── 00-part-title.typ     part-title page
│   └── ch01..ch06            the six foundation chapters
├── part2/
│   ├── 00-part-title.typ
│   └── m01..m36              the module reference sheets
└── backmatter/back.typ       appendices A–E, glossary, bibliography, index, colophon
```

## Why one document and not one-PDF-per-chapter

The first edition compiled each chapter separately and merged the PDFs. Every chapter
therefore began its own page count at 1, so the assembled book contained **eight pages
numbered "1"** and a table of contents whose page references pointed at nothing.

Page numbers, running heads and the contents page all depend on a chapter knowing where it
falls in the whole volume. That is only true inside a single document.

## Adding a chapter

1. Create `part2/m05-caching.typ`.
2. Begin it with exactly two lines:

```typst
#import "/shared/lib/template.typ": *
#reg(1, "M5", "Multi-Tier Caching")
#chapterhead("Part 2 · Modules", "M5 · Multi-Tier Caching")
```

3. Add `#include "part2/m05-caching.typ"` to `book.typ` in reading order.

`#reg(..)` puts it in the Contents at its real page number. `#chapterhead(..)` sets the
running head: verso carries the part, recto the chapter. Neither needs maintaining by hand.

**A fragment must not set page geometry, numbering or fonts.** The master owns those. A
fragment that calls `set page(..)` will fight the master and corrupt the numbering.

## Build

```
../../build.sh sem-system-design   → dist/sem-system-design.pdf
../../build.sh sem-system-design --watch
```

The build asserts A4 geometry and continuous page numbering on every run. Both have broken
silently before.

## Conventions

- **Colour is semantic**, never decorative: green = healthy path, red = failure,
  orange = arithmetic, purple = definition/caveat, blue = structure.
- **Diagrams are CeTZ with named anchors.** Never hand-place boxes with absolute
  coordinates — arrows must attach to component edges by construction.
- **Every module** carries an anti-pattern and shows its capacity arithmetic in full.
  Both are mandatory under the verification procedure printed on page xi.
