#import "/shared/lib/template.typ": *
#reg(1, "M7", "API Contract Evolution")
#chapterhead("Part 2 · Modules", "M7 · API Contract Evolution")
#ix("Tolerant reader")
#ix("Expand-contract")

#h1("M7 · API Contract Evolution", c: purple)

#text[
  A web API can be changed on Tuesday and every client has the new version by Wednesday. A
  mobile API cannot. Some fraction of your users will be on a build from
  #text(fill: red, weight: "bold")[two years ago], forever, because they never update and you
  cannot make them. Every contract decision has to assume that.
]
#v(2mm)

#h2("1 · What is safe, and what is not", c: blue)

#table(
  columns: (auto, 1fr, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#eef4fb") } else { none },
  text(font: headfont, size: 8.5pt, fill: blue)[Change],
  text(font: headfont, size: 8.5pt, fill: blue)[Why],
  text(font: headfont, size: 8.5pt, fill: blue)[Safe?],

  text(size: 8.3pt)[Add an optional field],
  text(size: 8pt)[Old clients ignore unknown fields — if they were written as tolerant readers],
  text(size: 8.3pt, fill: green)[yes],

  text(size: 8.3pt)[Add a new endpoint],
  text(size: 8pt)[Nothing existing is touched],
  text(size: 8.3pt, fill: green)[yes],

  text(size: 8.3pt)[Add an enum value],
  text(size: 8pt, fill: red)[Old clients may `switch` exhaustively and crash on the default branch],
  text(size: 8.3pt, fill: orange)[careful],

  text(size: 8.3pt)[Make a required field optional],
  text(size: 8pt, fill: red)[Old clients assume presence and dereference null],
  text(size: 8.3pt, fill: red)[no],

  text(size: 8.3pt)[Rename a field],
  text(size: 8pt, fill: red)[A delete plus an add. Old clients see the field vanish],
  text(size: 8.3pt, fill: red)[no],

  text(size: 8.3pt)[Change a type],
  text(size: 8pt, fill: red)[`"123"` → `123` breaks strict parsers immediately],
  text(size: 8.3pt, fill: red)[no],

  text(size: 8.3pt)[Tighten validation],
  text(size: 8pt, fill: red)[Requests that worked yesterday start failing today],
  text(size: 8.3pt, fill: red)[no],

  text(size: 8.3pt)[Remove anything],
  text(size: 8pt, fill: red)[Guaranteed break for whoever still reads it],
  text(size: 8.3pt, fill: red)[no],
)
#v(2mm)

#key[
  The only reliably safe evolution is #underline(stroke: 1pt + green)[additive]. Everything else
  is a migration with a timeline, a measurement plan and a rollback — not a code change.
]
#v(2mm)

#h2("2 · The expand–migrate–contract cycle", c: green)

#align(center, cetz.canvas(length: 0.84cm, {
  import cetz.draw: *
  rnode(2.8, 1.4, "e", "1 · EXPAND", "add new field, keep old", green, w: 4.4, h: 1.15)
  rnode(9.0, 1.4, "m", "2 · MIGRATE", "write both, read new", orange, w: 4.4, h: 1.15)
  rnode(15.2, 1.4, "c", "3 · CONTRACT", "remove old field", red, w: 4.4, h: 1.15)
  line("e.east", "m.west", mark: (end: ">"), stroke: hot)
  line("m.east", "c.west", mark: (end: ">"), stroke: miss)
  content((5.9, 2.15), dlbl("deploy", sz: 6.3pt, c: green))
  content((12.1, 2.15), dlbl("WAIT", sz: 6.5pt, c: red))

  content((2.8, 0.3), dlbl("server writes old + new", sz: 6.3pt, c: green))
  content((2.8, -0.3), dlbl("old clients unaffected", sz: 6.3pt, c: green))
  content((9.0, 0.3), dlbl("new clients adopt new field", sz: 6.3pt, c: orange))
  content((9.0, -0.3), dlbl("measure old-field read rate", sz: 6.3pt, c: purple))
  content((15.2, 0.3), dlbl("only when usage hits ~0", sz: 6.3pt, c: red))
  content((15.2, -0.3), dlbl("can take 18+ months", sz: 6.3pt, c: red))

  bracket(0.6, 17.4, -1.2, "the WAIT is the whole technique — it is measured, not guessed", purple)
}))
#v(2mm)

#text(size: 9pt)[
  #text(fill: purple, weight: "bold")[The tolerant reader.] Postel's principle applied to
  clients: ignore fields you do not recognise, never fail on extra data, treat absent optional
  fields as absent rather than as an error. A client written this way lets the server evolve
  without coordination. #note[This is a #underline(stroke: 1pt + green)[client-side] discipline
  that pays off server-side years later. If your mobile apps parse strictly today, your API is
  frozen tomorrow — and you will not discover it until you try to change something.]
]
#v(2mm)

#h2("3 · Capacity & deprecation arithmetic", c: orange)

#formula("When can you actually remove the old field?")[
  #text(size: 8.6pt)[
    Mobile adoption is roughly: #text(weight: "bold")[60%] on the latest version after 30 days,
    #text(weight: "bold")[85%] after 90 days, #text(weight: "bold")[95%] after a year. The last
    #text(fill: red, weight: "bold")[1–3%] may never upgrade.
    #linebreak() #v(1mm)
    10M MAU, removing a field at #text(weight: "bold")[97%] adoption #sym.arrow.r
    0.03 × 10,000,000 = #text(fill: red, weight: "bold")[300,000 users broken].
    At 99.5% #sym.arrow.r still #text(fill: red, weight: "bold")[50,000].
    #linebreak() #v(1mm)
    #text(fill: green, weight: "bold")[The decision rule:] do not remove on a percentage, remove
    on an #underline(stroke: 1pt + green)[absolute count you are willing to break], and know what
    those users see when you do. For a payment flow that number is near zero; for a cosmetic
    field it may be thousands.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Force-upgrade is the escape hatch:] a server-driven minimum-version
    check that blocks the app with "please update". Reserve it for security fixes — it costs you
    the users who cannot update, including ones on devices that no longer receive OS updates.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[The enum that crashed the app.] The server adds
  `status: "PARTIALLY_SHIPPED"`. An old iOS client does an exhaustive `switch` over a non-frozen
  enum and hits a path that calls `fatalError()`. The app crashes on launch for anyone with such
  an order. #text(fill: green)[Fix:] clients always handle an unknown case; servers treat new
  enum values as a breaking change until proven otherwise.

  #text(fill: red, weight: "bold")[Version sprawl.] `/v1`, `/v2`, `/v3` all live, each with its
  own bugs, and every feature now ships three times.
  #text(fill: green)[Fix:] version at the #underline(stroke: 1pt + green)[field] level through
  additive evolution, not the URL. Reserve a whole new version for genuine redesigns, and run at
  most two.

  #text(fill: red, weight: "bold")[Silent contract drift.] No schema is enforced, so a careless
  serialiser change alters a type and nothing catches it until crash reports arrive.
  #text(fill: green)[Fix:] a schema (OpenAPI, protobuf) in CI with a
  #text(fill: purple)[backwards-compatibility check] that fails the build --- `buf breaking`
  for protobuf, or contract tests against recorded old-client requests.

  #text(fill: red, weight: "bold")[Deprecation with no telemetry.] You cannot retire what you
  cannot measure. #text(fill: green)[Fix:] log reads of deprecated fields with the client
  version, so "who is still using this" is a query, not a guess.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: How do you deprecate an API used by millions of mobile
  apps?]
  #linebreak()
  Expand–migrate–contract, instrumented: ship the new field alongside the old, move new clients
  over, measure old-field usage by client version, and remove only when the broken count is one
  you accept. #note[Testing: do you know you can #underline(stroke: 1pt + red)[never] reach
  100%? The weak answer says "deprecate v1 and give six months' notice", which assumes clients
  that read your notices.]

  #text(fill: green, weight: "bold")[Q: URL versioning or header versioning?]
  #linebreak()
  URL (`/v2/orders`) is explicit, cacheable and obvious in logs; headers keep URLs stable and
  allow finer negotiation. Prefer neither for routine change — evolve additively instead.
  #note[Testing: whether you see versioning as a last resort rather than a default.]

  #text(fill: green, weight: "bold")[Q: GraphQL solves this, doesn't it?]
  #linebreak()
  It helps with over-fetching and lets clients request only what they use, but the schema still
  has breaking changes — removing a field or changing nullability breaks persisted queries.
  #note[Testing: resistance to the idea that a technology eliminates a structural problem.]
]
#v(2mm)

#anti("the \"quick\" field rename")[
  `userName` reads badly in a review, so it becomes `username` in the same PR. It ships. Crash
  reports arrive from app versions #text(fill: red)[18 months old] that dereference the missing
  field on a screen nobody tested, because nobody on the team still runs that build. The fix is a
  server-side rollback, and the lesson costs a day of incident.
  #text(fill: green)[Fix:] a rename is an add plus a deprecation plus a wait. Treat the wire
  format as a #underline(stroke: 1pt + green)[published contract], not as code you own.
]
