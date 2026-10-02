#!/bin/bash
# Custom Handbook Workspace — build one handbook, or all of them.
#
#   ./build.sh                     build every handbook
#   ./build.sh sem-system-design   build one
#   ./build.sh <name> --watch      rebuild on save
#
# Each handbook is ONE typst document (handbooks/<name>/handbook.typ) that
# includes chapter fragments and imports the shared style module. Do not compile
# fragments individually and merge the PDFs: that gives every chapter its own
# page-1 and a table of contents that points nowhere.
#
# --root is the WORKSPACE, so `/shared/lib/template.typ` resolves from any
# handbook and the shared library is genuinely shared rather than copied.
set -e
cd "$(dirname "$0")"
mkdir -p dist

build_one() {
  local name="$1"
  local src="handbooks/$name/handbook.typ"
  [ -f "$src" ] || { echo "  no such handbook: $name"; return 1; }

  if [ "$2" = "--watch" ]; then
    exec typst watch --root . "$src" "dist/$name.pdf"
  fi

  typst compile --root . "$src" "dist/$name.pdf"
  echo "  built dist/$name.pdf"

  python3 - "$name" <<'PY'
import sys
from pypdf import PdfReader
name = sys.argv[1]
r = PdfReader(f"dist/{name}.pdf")
sizes = {(round(float(p.mediabox.width)), round(float(p.mediabox.height))) for p in r.pages}
links = sum(len(p.get('/Annots') or []) for p in r.pages)

# every link must resolve to a real page
pages = {p.indirect_reference.idnum: i for i, p in enumerate(r.pages)}
broken = 0
for p in r.pages:
    for an in (p.get('/Annots') or []):
        o = an.get_object()
        d = o.get('/A', {}).get('/D') or o.get('/Dest')
        if not d or pages.get(d[0].idnum) is None:
            broken += 1

# body page numbering must never restart
prev, restarts = None, 0
for p in r.pages:
    ls = [x.strip() for x in (p.extract_text() or "").split("\n") if x.strip()]
    if ls and ls[-1].isdigit():
        n = int(ls[-1])
        if prev is not None and n < prev:
            restarts += 1
        prev = n

print(f"    {len(r.pages)} pages")
print(f"    geometry   {'A4 ✓' if sizes == {(595, 842)} else f'MIXED {sizes} ✗'}")
print(f"    links      {links} ({'all resolve ✓' if broken == 0 else f'{broken} BROKEN ✗'})")
print(f"    numbering  {'continuous ✓' if restarts == 0 else f'{restarts} RESTARTS ✗'}")
PY
}

if [ -n "$1" ]; then
  build_one "$1" "$2"
else
  for d in handbooks/*/; do
    name="$(basename "$d")"
    [ -f "$d/handbook.typ" ] || continue
    echo "== $name =="
    build_one "$name"
  done
fi
