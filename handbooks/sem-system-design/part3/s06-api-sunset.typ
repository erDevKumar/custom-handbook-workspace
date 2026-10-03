#import "/shared/lib/template.typ": *
#reg(1, "S6", "Sunsetting an API used by millions of old apps")
#chapterhead("Part 3 · Interview Scenarios", "S6 · Legacy API Sunset")

#h1("S6 · Sunsetting a Legacy Mobile API", c: purple)

#text[
  #text(fill: purple, weight: "bold")[The prompt.] A v1 API costs a fortune to maintain and
  blocks a redesign. Millions of installed apps still call it, including builds from four years
  ago on devices that no longer receive OS updates. Retire it without churning customers.
]
#v(2mm)

#h2("1 · The dilemma and its root cause", c: red)

#text(size: 9pt)[
  You cannot force an upgrade. A meaningful fraction of users have auto-update disabled, are on
  devices your current minimum SDK excludes, or simply never open the app store. Shutting off v1
  does not migrate them — it #underline(stroke: 1pt + red)[deletes them as customers], and they
  experience it as the app breaking, not as a deprecation they ignored.

  #text(fill: purple, weight: "bold")[Root cause.] v1 was built without an evolution strategy
  (M7): no tolerant readers, no versioned fields, no telemetry on which endpoints each client
  version actually uses. The sunset is expensive because the groundwork was never laid, and the
  first six weeks of this project are spent acquiring information that should already exist.
]
#v(2mm)

#formula("Who actually breaks, and what it costs")[
  #text(size: 8.6pt)[
    10M MAU. Realistic adoption of a new release:
    #text(weight: "bold")[60%] at 30 days, #text(weight: "bold")[85%] at 90 days,
    #text(weight: "bold")[95%] at one year, and a persistent tail that never moves.
    #linebreak() #v(1mm)
    Shutting off v1 at #text(weight: "bold")[97%] adoption #sym.arrow.r
    #text(fill: red, weight: "bold")[300,000 users] whose app stops working.
    #linebreak()
    At #text(weight: "bold")[99.5%] #sym.arrow.r still
    #text(fill: red, weight: "bold")[50,000].
    #linebreak() #v(1mm)
    If ARPU is £40/year, 50,000 churned users is
    #text(fill: red, weight: "bold")[£2M/year] — set against the cost of maintaining v1, which
    might be two engineers, or £300k. #underline(stroke: 1pt + green)[The arithmetic frequently
    says: keep v1 running in reduced form.] Running it is cheaper than the churn.
    #linebreak() #v(1mm)
    #text(fill: green, weight: "bold")[The decision rule:] never retire on a percentage. Retire
    on an #text(weight: "bold")[absolute user count] whose loss the business has explicitly
    accepted, with a named person who accepted it.
  ]
]
#v(2mm)

#h2("2 · The solution — a staged campaign, not a switch", c: green)

#pfig("Fig S6.1 · v1 sunset — the shim deletes the backend early; retirement waits on an absolute user count")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.7, 3.0, "per-version, per-endpoint call telemetry exists; a named executive accepted the absolute user loss in writing")

  ppill(2.35, 0, "v1", "v1 maintenance burden", c: red, w: 4.5)
  pstep(7.46, 0, "ins", "instrument v1", "40% unused · 6wk", st-start, n: 1, actor: "platform", w: 4.8)
  pstep(12.71, 0, "shim", "v1 → v2 shim", "contract kept, backend cut", st-auto, n: 2, actor: "gateway", w: 4.8)
  pstep(17.96, 0, "mig", "drive migration", "prompt + email · 90d", st-man, n: 3, actor: "growth", w: 4.8)
  pdec(13.94, -3.6, "cnt", "tail below\naccepted count?")
  pstep(8.55, -3.6, "bo", "brownouts", "503 for 1h → 4h → 1 day", st-integ, n: 4, actor: "gateway", w: 4.8)
  ppill(2.9, -3.6, "ret", "retire v1 — blast radius known", c: red, w: 5.6)
  ppill(18.65, -3.6, "keep", "keep the shim running", w: 4.5)

  line("v1.east", "ins.west", mark: (end: ">"), stroke: miss)
  line("ins.east", "shim.west", mark: (end: ">"), stroke: hot)
  line("shim.east", "mig.west", mark: (end: ">"), stroke: hot)
  line("mig.south", (17.96, -1.8), (13.94, -1.8), "cnt.north", mark: (end: ">"), stroke: lookup)
  plabel(15.5, -1.8, "95% at 1yr, then flat", c: orange, dy: 0.34)
  line("cnt.east", "keep.west", mark: (end: ">"), stroke: except)
  plabel(17.6, -2.4, "no — 50k = £2M/yr", c: red, dy: 0.0)
  line("cnt.west", "bo.east", mark: (end: ">"), stroke: hot)
  plabel(12.0, -2.4, "yes", c: green, dy: 0.0)
  line("bo.west", "ret.east", mark: (end: ">"), stroke: hot)

  ploop("bo.south", "mig.south", -5.6, "each brownout converts silent ignorers into informed upgraders", c: blue)
}))
#pcards(
  [Usage logged per client version and endpoint; a v2 contract worth migrating to; a named owner of the accepted-loss decision],
  [In: 10M MAU, ~95% on v2 at one year and a flat tail · Out: the v1 backend deleted in quarter two, the v1 contract served by a thin shim, retirement only on an absolute count],
  [Per-version request logging · v1→v2 translation shim at the gateway · in-app upgrade prompts · scheduled 503 brownouts · tolerant readers in v2 (M7)],
)
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: blue, weight: "bold")[1 · Instrument before deciding anything.] Log every v1 call
  with client version, endpoint and user id. You need to know which endpoints are genuinely used
  — typically #underline(stroke: 1pt + green)[a handful carry 95% of traffic] and the rest can be
  retired immediately with almost no impact. Without this data, the project is guesswork.

  #text(fill: green, weight: "bold")[2 · Build a translation shim.] This is the key move: a thin
  adapter exposing the v1 contract and calling v2 internally. The expensive
  #underline(stroke: 1pt + green)[v1 implementation and its database coupling are deleted
  immediately]; only a small translation layer remains. Maintenance cost collapses while
  compatibility is preserved, which removes most of the urgency.

  #text(fill: green, weight: "bold")[3 · Drive migration actively.] In-app upgrade prompts for
  users who can upgrade, email for those who cannot be reached in-app, and a hard "please update"
  interstitial for versions with known security defects. Measure weekly; the curve flattens and
  that flattening tells you where the floor is.

  #text(fill: orange, weight: "bold")[4 · Brownouts.] Return 503 for v1 for one hour, announced in
  advance, then four hours, then a day. Users who ignored every notification
  #underline(stroke: 1pt + green)[discover the deadline while it is still reversible], and your
  support team learns the true blast radius before the permanent cutoff.

  #text(fill: red, weight: "bold")[5 · Retire, with the loss accepted in writing.]
]
#v(2mm)

#key[
  The shim is what makes this tractable. Separating
  #text(fill: green, weight: "bold")[the contract] (which must live for years) from
  #text(fill: orange, weight: "bold")[the implementation] (which can be deleted next quarter)
  turns an impossible deadline into a manageable one. Teams that conflate the two conclude they
  must support v1 forever, and are right.
]
#v(2mm)

#h2("3 · SEM execution strategy", c: purple)

#text(size: 8.9pt)[
  #text(fill: purple, weight: "bold")[Reframe the goal for leadership.] The objective is not
  "turn off v1" — it is #underline(stroke: 1pt + green)[stop paying for v1]. The shim achieves
  90% of the cost saving at 10% of the risk, and it lands in a quarter rather than two years. In
  an interview, this reframing is the senior answer; "we'll deprecate with six months' notice"
  is not.

  #text(fill: purple, weight: "bold")[Who decides the cutoff.] Churning 50,000 paying customers
  is a #text(fill: red, weight: "bold")[business decision], not an engineering one. Bring the
  numbers — affected users, revenue at risk, maintenance cost avoided — and get an explicit,
  recorded decision from product and finance. Engineering owning this call alone is how a team
  becomes responsible for a revenue drop.

  #text(fill: purple, weight: "bold")[Blast radius.] Brownouts are the containment mechanism:
  short, announced, reversible exposures that surface problems while recovery is one config flip.
  Never discover the real impact at permanent shutoff.

  #text(fill: purple, weight: "bold")[Support readiness.] The week of each brownout, support
  volume spikes. Brief them with scripted responses and an upgrade path
  #underline(stroke: 1pt + green)[before] the brownout, not after the queue fills.

  #text(fill: purple, weight: "bold")[The lesson to institutionalise.] Every new API ships with
  per-version usage telemetry and a documented deprecation policy from day one. This project is
  expensive because that was absent; the remediation is a platform standard, not a one-off fix.
]
#v(2mm)

#anti("the sunset announcement as the whole plan")[
  A deprecation notice is published, a six-month deadline is set, and the team considers the
  migration handled. Mobile users #text(fill: red, weight: "bold")[do not read changelogs,
  developer blogs or emails about APIs] — many do not know their app calls an API at all. On
  cutoff day, hundreds of thousands of apps break simultaneously, support is overwhelmed, the
  app-store rating collapses, and the change is
  #underline(stroke: 1pt + red)[rolled back within hours] — after the reputational damage, and
  with the project no further forward. #text(fill: green)[Fix:] measure actual usage, build a
  shim so the deadline is no longer urgent, drive upgrades in-app where users actually are, and
  use announced brownouts so the deadline is discovered while it is still reversible.
]
