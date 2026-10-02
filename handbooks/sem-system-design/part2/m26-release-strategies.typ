#import "/shared/lib/template.typ": *
#reg(1, "M26", "Traffic Engineering & Release Strategies")
#chapterhead("Part 2 · Modules", "M26 · Release Strategies")
#ix("Canary deployment")
#ix("Blue-green")
#ix("Shadow traffic")

#h1("M26 · Traffic Engineering & Releases", c: orange)

#text[
  Every release strategy answers the same question: how much of your traffic is exposed to a
  change before you know whether it works? The progression below trades
  #underline(stroke: 1pt + green)[blast radius] against time-to-full-rollout, and the right
  answer differs per service.
]
#v(2mm)

#h2("1 · The strategies", c: blue)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  swimlane(-0.4, -1.4, 9.0, 2.3, "BLUE / GREEN — instant switch, 2× cost", blue, rgb("#f4f8fd"))
  rnode(2.2, 1.2, "lb1", "router", "100% → green", blue, w: 3.0, h: 0.85)
  rnode(6.4, 1.7, "blue", "BLUE v1", "idle, warm", luma(130), w: 3.0, h: 0.75)
  rnode(6.4, 0.5, "green", "GREEN v2", "live", green, w: 3.0, h: 0.75)
  line("lb1.east", "green.west", mark: (end: ">"), stroke: hot)
  content((4.4, -0.4), dlbl("rollback = flip the router back", sz: 6.3pt, c: green))
  content((4.4, -1.0), dlbl("but DB migrations must work for BOTH", sz: 6.3pt, c: red))

  swimlane(9.8, -1.4, 18.4, 2.3, "CANARY — gradual, one fleet", orange, rgb("#fdf7f2"))
  rnode(11.8, 1.2, "lb2", "router", "weighted", blue, w: 2.8, h: 0.85)
  rnode(15.6, 1.7, "v1", "v1 — 95%", "stable", green, w: 3.2, h: 0.75)
  rnode(15.6, 0.5, "v2", "v2 — 5%", "canary", orange, w: 3.2, h: 0.75)
  line("lb2.east", "v1.west", mark: (end: ">"), stroke: hot)
  line("lb2.east", "v2.west", mark: (end: ">"), stroke: (paint: orange, thickness: 1.2pt))
  content((14.2, -0.4), dlbl("compare canary metrics vs baseline", sz: 6.3pt, c: orange))
  content((14.2, -1.0), dlbl("5% → 25% → 50% → 100%, auto-rollback on regression", sz: 6.3pt, c: green))
}))
#v(1.5mm)

#h2("2 · Trade-off matrix", c: purple)

#table(
  columns: (auto, auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#fff3e8") } else { none },
  text(font: headfont, size: 8.5pt, fill: orange)[Strategy],
  text(font: headfont, size: 8.5pt, fill: orange)[Exposure],
  text(font: headfont, size: 8.5pt, fill: orange)[Rollback],
  text(font: headfont, size: 8.5pt, fill: orange)[Cost / caveat],

  text(size: 8.3pt)[Rolling],
  text(size: 8.3pt, fill: orange)[grows per batch],
  text(size: 8.3pt, fill: orange)[roll forward],
  text(size: 8pt)[Default in K8s. Both versions live simultaneously — API must be compatible],

  text(size: 8.3pt)[Blue/green],
  text(size: 8.3pt, fill: red)[0% then 100%],
  text(size: 8.3pt, fill: green)[instant],
  text(size: 8pt, fill: red)[2× infrastructure; the switch is still all-or-nothing],

  text(size: 8.3pt, fill: green)[Canary],
  text(size: 8.3pt, fill: green)[1% → 100%],
  text(size: 8.3pt, fill: green)[shift weight],
  text(size: 8pt, fill: green)[Best blast-radius control; needs good metrics to judge],

  text(size: 8.3pt)[Shadow],
  text(size: 8.3pt, fill: green)[0% — real traffic, discarded response],
  text(size: 8.3pt, fill: green)[n/a],
  text(size: 8pt)[Tests load and correctness safely. #text(fill: red)[Side effects must be stubbed]],

  text(size: 8.3pt)[Feature flag],
  text(size: 8.3pt, fill: green)[per user],
  text(size: 8.3pt, fill: green)[seconds],
  text(size: 8pt)[Decouples release from deploy entirely (M24)],
)
#v(2mm)

#key[
  Canary and feature flags solve different halves of the problem.
  #text(fill: orange, weight: "bold")[Canary] limits exposure to a #emph[binary] — it catches
  crashes, memory leaks, and latency regressions. #text(fill: green, weight: "bold")[Flags] limit
  exposure to a #emph[behaviour] inside an already-deployed binary. Mature teams use both: deploy
  by canary, release by flag.
]
#v(2mm)

#h2("3 · Automated canary analysis", c: green)

#text(size: 9pt)[
  Judging a canary by eye does not scale and does not work at 3am. Automated analysis compares
  canary against baseline on a fixed metric set — error rate, p99 latency, saturation, and one
  or two business metrics — and promotes or rolls back on the result.
  #note[Compare the canary to a #underline(stroke: 1pt + green)[baseline running the old version
  at the same time], not to yesterday's numbers. Traffic mix, time of day and upstream behaviour
  all drift; only a concurrent control isolates the change.]
]
#v(2mm)

#formula("How long must a canary run?")[
  #text(size: 8.6pt)[
    To detect a regression you need enough events for the difference to be significant. For a
    baseline error rate #text(weight: "bold")[p = 0.1%] and a 5% canary at 10,000 RPS:
    #linebreak()
    canary traffic = 500 RPS #sym.arrow.r expected errors = 0.5/s.
    #linebreak()
    Detecting a #text(weight: "bold")[doubling] (0.1% → 0.2%) with reasonable confidence needs on
    the order of #text(fill: orange, weight: "bold")[1,000+ canary errors] #sym.arrow.r
    ~2,000 s ≈ #text(fill: orange, weight: "bold")[33 minutes] at 5%.
    #linebreak() #v(1mm)
    #text(fill: red, weight: "bold")[Consequence:] a 5-minute canary on a low-traffic service
    proves #underline(stroke: 1pt + red)[nothing]. Either raise the canary percentage, extend the
    window, or accept that you are relying on rollback speed rather than detection. Say which one
    you chose.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Rollback budget:] detection time + rollback time = user-visible damage.
    33 min detection + 2 min rollback at 5% exposure = 35 min × 5% =
    #text(fill: orange, weight: "bold")[1.75 minutes of full-traffic-equivalent impact].
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[The database migration that is not reversible.] Code rolls
  back in seconds; a dropped column does not. #text(fill: green)[Fix:] expand–contract (M35) —
  never deploy a schema change and the code that requires it in the same release.

  #text(fill: red, weight: "bold")[Shadow traffic with real side effects.] Mirrored requests hit
  the payment provider and #underline(stroke: 1pt + red)[charge customers twice].
  #text(fill: green)[Fix:] shadow only read paths, or stub every external effect and assert in CI
  that the shadow environment cannot reach production dependencies.

  #text(fill: red, weight: "bold")[Canary on unrepresentative traffic.] The canary receives only
  health checks or only one region, so it looks perfect and fails at 100%.
  #text(fill: green)[Fix:] weighted random routing across the real traffic mix; verify the canary
  is receiving the same request distribution as baseline.

  #text(fill: red, weight: "bold")[Sticky sessions defeat the canary.] Session affinity pins each
  user to one version, so a user who lands on the canary experiences
  #text(fill: red)[100%] of the bad version rather than 5%.
  #text(fill: green)[Fix:] understand that canary percentage is a percentage of
  #underline(stroke: 1pt + green)[users], not of requests, whenever affinity is in play.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Design a zero-downtime deploy for a tier-0 service.]
  #linebreak()
  Expand–contract migrations first, then a canary at 1% with automated analysis against a
  concurrent baseline, graduated promotion, automatic rollback on regression, and a feature flag
  for the behaviour itself. #note[Testing: do you address the database? Most candidates design a
  perfect traffic shift over a migration that cannot roll back.]

  #text(fill: green, weight: "bold")[Q: Blue/green or canary?]
  #linebreak()
  Canary for blast-radius control; blue/green when you need an instant, atomic switch and can
  afford double capacity. #note[Testing: that blue/green's switch is still all-or-nothing — it
  gives fast rollback, not reduced exposure.]

  #text(fill: green, weight: "bold")[Q: How long should a canary bake?]
  #linebreak()
  Long enough to accumulate statistically meaningful events at the canary's traffic share — a
  calculation, not a habit. #note[Testing: whether "canary for 5 minutes" is a ritual or a
  decision.]
]
#v(2mm)

#anti("the canary nobody is watching")[
  A pipeline deploys to 5%, waits #text(fill: red, weight: "bold")[two minutes], and promotes to
  100% if no pod crashed. It catches startup failures and nothing else: a 30% latency regression,
  a 0.5% error increase, a slow memory leak, and a corrupted-data bug all sail through, because
  "did it crash" is the only question asked. The canary provides
  #underline(stroke: 1pt + red)[the appearance of safety], which is worse than no canary — the
  team believes the change was validated. #text(fill: green)[Fix:] automated analysis on error
  rate, p99 and a business metric against a concurrent baseline, with promotion blocked until the
  comparison is statistically meaningful.
]
