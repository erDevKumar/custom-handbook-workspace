# Diagram authoring guide — process-flow shape language

Every diagram in every handbook uses the helpers in `shared/lib/template.typ`.
The shape vocabulary is a port of the Cocoon AI process-flow-diagram generator
into CeTZ; the dark theme is deliberately not ported (this book prints on cream
A4), but the *information model* is.

## Non-negotiable rules

1. **Anchors, never coordinates.** Arrows attach to `"name.east"`, never to a
   hand-computed `(x, y)`. Hand-placed boxes were the original cause of the
   distorted diagrams in the first proofs.
2. **One pen, one meaning.** Use the `st-*` constants, not raw colours.
3. **Every diagram is a page-width figure.** Target canvas width ≈ 20 units at
   `length: 0.76cm`. Wider than ~21 overflows the 164mm text block.
4. **A diagram that needs more than ~6 steps in a row wraps** to a second row
   with the `wrap` stroke — it does not shrink to fit.

## The helpers

| Helper | What it is | Used for |
|---|---|---|
| `pstep(x,y,name,title,sub,c, n:, actor:, w:, h:)` | numbered step box | every processing step |
| `pdec(x,y,name,q, w:,h:)` | decision diamond | a branch point |
| `ppill(x,y,name,label, c:)` | rounded pill | where a flow starts / lands |
| `pprereq(x1,x2,y,items)` | dashed band | preconditions, above the flow |
| `plabel(x,y,text, c:, dy:)` | arrow label | what flows along an arrow |
| `ploop(from,to,y,label, c:)` | dashed return rail | retry / always-on cycle |
| `pcards(prereq, io, tools)` | three cards | operational context, under the figure |
| `plegend((label, stroke), ..)` | stroke key | first diagram of a chapter only |
| `pfig(title)` | caption line | above every diagram |

Pre-existing helpers stay valid and should still be used where they fit:
`swimlane`, `rnode`, `node`, `cylinder`, `bracket`, `badge`.

## Step-type pens

```
st-start  blue    boundary / structure      ppill, entry and exit
st-man    green   human-driven step         operator, reviewer, on-call
st-auto   purple  system-driven step        scheduler, worker, compactor
st-integ  orange  external hop              third-party API, CDN, payment PSP
st-dec    red     branch point              pdec, and failure sinks
```

## Stroke semantics

```
hot      solid green    the happy path
lookup   dashed green   a probe / cache read
miss     solid red      fallthrough / failure
async    dashed purple  replication, eventual consistency
cold     dotted orange  archival / cold tier
except   dashed red     exception path (pfdg's rose path)
wrap     dashed grey    row continuation
loopbk   dashed blue    return rail
```

## Layout conventions that prevent collisions

- Step boxes on a row share one `y`. Default row `y = 0`.
- Horizontal stride **4.4 units** for `w: 3.4` boxes — tighter and the arrow
  label between them has nowhere to sit.
- `plabel` takes the **arrow's** y; it lifts itself clear. Pass `dy: -0.3` to
  drop a label under a return path.
- `ploop` rail at `y ≈ 1.75` for a row at 0. Target `.east`/`.west`, **not**
  `.north` — a loop dropping onto a box top runs through that box's actor label.
- Exception sinks go **below** the row at `y ≈ -3.2`, reached with `except`.
- `pprereq` spans the full canvas at `y ≈ 2.6`, above the loop rail.

## Canonical skeleton

```typst
#pfig("Fig M5.1 · read path and what each tier costs")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.5, 20.5, 2.6, "what must already be true")

  ppill(1.2, 0, "in", "request")
  pstep(5.0, 0, "a", "validate", "Envoy · 2ms", st-integ, n: 1, actor: "gateway")
  pdec(9.4, 0, "d", "cached?")
  pstep(13.8, 0, "b", "origin read", "Postgres · 40ms", st-auto, n: 2, actor: "svc")
  ppill(18.2, 0, "out", "response")

  line("in.east", "a.west", mark: (end: ">"), stroke: hot)
  line("a.east", "d.west", mark: (end: ">"), stroke: hot)
  line("d.east", "b.west", mark: (end: ">"), stroke: miss)
  plabel(11.6, 0, "miss", c: red)
  line("b.east", "out.west", mark: (end: ">"), stroke: hot)
}))
#pcards([preconditions], [In: … · Out: …], [systems involved])
```

## Where each part puts its diagrams

- **Part 1 (foundations):** the mechanism being defined. 2–3 per chapter.
- **Part 2 (modules):** one request/data path per module, showing the concrete
  tech and its cost in the `sub` line.
- **Part 3 (scenarios):** the failure and the response as a flow, with the
  exception path drawn, not described.
- **Part 4 (case studies):** full-context multi-stage — edge → service →
  storage swimlanes, plus the step flow across them.
