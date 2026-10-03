#import "/shared/lib/template.typ": *
#reg(1, "S12", "Automated canary with anomaly detection")
#chapterhead("Part 3 · Interview Scenarios", "S12 · Automated Canary")

#h1("S12 · Automated Canary & Rollback", c: green)

#text[
  #text(fill: purple, weight: "bold")[The prompt.] Deploys happen forty times a day across thirty
  services. Humans cannot watch every canary. Build a system that decides, without a person, when
  a release is bad — and rolls it back before customers notice.
]
#v(2mm)

#h2("1 · The dilemma and its root cause", c: red)

#text(size: 9pt)[
  The hard part is not shifting traffic; it is #underline(stroke: 1pt + red)[deciding]. Too
  sensitive and every deploy rolls back on noise, so engineers disable the gate. Too lax and
  regressions reach 100%, so the gate provides false assurance. Both failure modes end with the
  canary being ignored, which is worse than not having one.

  #text(fill: purple, weight: "bold")[Root cause.] Comparing the canary against
  #underline(stroke: 1pt + red)[historical data]. Traffic mix, time of day, upstream behaviour and
  user population all drift, so yesterday's baseline differs from today's for reasons unrelated to
  the release.
]
#v(2mm)

#formula("Why a concurrent baseline, and how long to bake")[
  #text(size: 8.6pt)[
    #text(fill: green, weight: "bold")[Run a baseline deployment of the OLD version alongside the
    canary], both receiving a slice of live traffic simultaneously. Any difference is then
    attributable to the #underline(stroke: 1pt + green)[code], because everything else is shared.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Bake time is a statistics problem, not a habit.] Baseline error rate
    0.1%, canary at 5% of 10,000 RPS = 500 RPS #sym.arrow.r 0.5 errors/s expected.
    #linebreak()
    Detecting a doubling to 0.2% with confidence needs on the order of
    #text(fill: orange, weight: "bold")[1,000 canary errors] #sym.arrow.r ~2,000 s ≈
    #text(fill: orange, weight: "bold")[33 minutes].
    #linebreak()
    #text(fill: red, weight: "bold")[A 5-minute canary on a low-traffic service proves nothing.]
    Either raise the canary share, extend the window, or state openly that you are relying on
    rollback speed rather than detection.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Impact budget:] 33 min detection + 2 min rollback, at 5% exposure =
    #text(fill: green, weight: "bold")[~1.75 minutes] of full-traffic-equivalent damage. That is
    the number to quote when someone asks why canaries are worth the pipeline complexity.
  ]
]
#v(2mm)

#h2("2 · The system", c: green)

#pfig("Fig S12.1 · canary vs a concurrent baseline — bake time is a statistics problem, and rollback must be boring")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.7, 3.0, "every schema change backwards-compatible; a business metric beside error rate and latency; rollback under 2min")

  ppill(1.41, 0, "rel", "v2 release", w: 2.6)
  pstep(5.57, 0, "split", "90 / 5 / 5 split", "baseline = SAME old code", st-start, n: 1, actor: "router", w: 4.8)
  pstep(10.84, 0, "bake", "bake 33 min", "~1,000 canary errors", st-auto, n: 2, actor: "pipeline", w: 4.8)
  pstep(16.09, 0, "an", "compare the shape", "Mann-Whitney + z-test", st-auto, n: 3, actor: "analysis", w: 4.8)
  pdec(16.0, -3.8, "sig", "canary worse,\nsignificantly?")
  pstep(10.4, -3.8, "ramp", "graduated promote", "25% → 50% → 100%", st-auto, n: 4, actor: "pipeline", w: 4.8)
  ppill(4.0, -3.8, "live", "v2 at 100%", w: 2.6)
  pstep(16.2, -7.2, "rb", "auto rollback", "< 2min, code only", st-integ, n: 5, actor: "pipeline", w: 4.8)
  ppill(8.2, -7.2, "stuck", "schema not reversible", c: red, w: 4.5)

  line("rel.east", "split.west", mark: (end: ">"), stroke: hot)
  line("split.east", "bake.west", mark: (end: ">"), stroke: hot)
  line("bake.east", "an.west", mark: (end: ">"), stroke: hot)
  line("an.south", (16.09, -2.0), (16.0, -2.0), "sig.north", mark: (end: ">"), stroke: lookup)
  line("sig.west", "ramp.east", mark: (end: ">"), stroke: hot)
  plabel(13.6, -2.6, "no", c: green, dy: 0.0)
  line("ramp.west", "live.east", mark: (end: ">"), stroke: hot)
  line("sig.south", "rb.north", mark: (end: ">"), stroke: except)
  plabel(16.1, -5.5, "yes — ~1.75min of full-traffic damage", c: red, dy: 0.0)
  line("rb.west", "stuck.east", mark: (end: ">"), stroke: except)
  plabel(11.3, -7.2, "a dropped column does not revert", c: red, dy: 0.46)

  ploop("rb.west", "split.south", -8.9, "re-canary the fix from 5% — never straight back to 100%", c: blue)
}))
#pcards(
  [A concurrent baseline deployment of the old version; statistical bake time computed from the real error rate, not a habit; nothing irreversible in the release],
  [In: 10,000 RPS, 5% to canary and 5% to baseline, baseline error rate 0.1% · Out: a defensible promote-or-rollback verdict in ~33 minutes, for ~1.75 minutes of full-traffic-equivalent damage],
  [Traffic-splitting router · concurrent baseline of v1 · Mann-Whitney U on latency, two-proportion z-test on errors · business metric (checkout completion, search CTR) · automated rollback],
)
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: green, weight: "bold")[Metrics, in priority order.] Error rate and latency are
  mandatory; saturation catches leaks; and #underline(stroke: 1pt + green)[at least one business
  metric] — checkout completion, search click-through — catches the regressions that are
  technically healthy and commercially disastrous. A release can return 200s for an empty page.

  #text(fill: purple, weight: "bold")[Compare distributions, not averages.] A Mann–Whitney U test
  on latency samples detects a shifted distribution that a mean would hide. For error rates, a
  two-proportion z-test gives a defensible confidence level rather than a threshold someone
  invented.

  #text(fill: orange, weight: "bold")[Graduated promotion with escalating confidence:]
  5% for 30 min → 25% for 20 min → 50% for 10 min → 100%. Each stage has more traffic, so each
  needs less time for the same statistical power.

  #text(fill: red, weight: "bold")[Rollback must be the cheap, boring path.] Automatic, under two
  minutes, requiring no human. If rollback is slow or risky, the system will choose to
  #underline(stroke: 1pt + red)[wait and investigate] instead, which is exactly the delay the
  canary exists to prevent.
]
#v(2mm)

#key[
  Database migrations must be #underline(stroke: 1pt + green)[expand–contract] (M35) or the
  automated rollback is a lie. Code reverts in ninety seconds; a dropped column does not. The
  canary system is only as trustworthy as the reversibility of the least reversible thing in the
  release.
]
#v(2mm)

#h2("3 · SEM execution strategy", c: purple)

#text(size: 8.9pt)[
  #text(fill: purple, weight: "bold")[Tune for trust first, sensitivity second.] A new canary
  system should start deliberately conservative — it will be judged on false positives. Engineers
  who experience three spurious rollbacks will route around the gate, and recovering that trust
  takes longer than building the system did. Publish the false-positive rate alongside the catch
  rate.

  #text(fill: purple, weight: "bold")[Make the verdict legible.] When a rollback fires, the
  engineer must immediately see #underline(stroke: 1pt + green)[which metric, how much it moved,
  and the comparison chart]. "Canary failed" with no explanation produces distrust and manual
  overrides. The explanation is as important as the decision.

  #text(fill: purple, weight: "bold")[Blast radius.] 5% exposure for 33 minutes is the contract.
  For tier-0 services, run the canary in a single region or a single availability zone first, so
  even the 5% is geographically contained.

  #text(fill: purple, weight: "bold")[Team and sequencing.] This is a platform investment: two
  engineers for a quarter, built once and adopted by thirty services. Sequence it as metrics
  standardisation first (every service emitting the same four signals in the same shape), then
  the analysis engine. #note[Teams that skip standardisation end up writing a bespoke analysis
  config per service, which does not scale and quietly rots.]

  #text(fill: purple, weight: "bold")[Measure the system itself.] Track releases caught, false
  positives, mean time to rollback, and the fraction of deploys that bypassed the gate. The last
  one is the health indicator — a rising bypass rate means the system has lost the engineers'
  confidence, and no amount of catch-rate makes up for it.
]
#v(2mm)

#anti("canary analysis against yesterday's metrics")[
  The canary's error rate is compared to the same service's metrics from 24 hours earlier. Monday
  morning traffic does not resemble Sunday morning traffic; a marketing email shifts the user mix;
  an upstream dependency deployed its own change. The comparison produces
  #text(fill: red, weight: "bold")[false positives on quiet days and false negatives on busy
  ones], seemingly at random. Engineers learn the gate is unreliable, start overriding it as
  routine, and the one time it correctly detects a real regression
  #underline(stroke: 1pt + red)[someone clicks "promote anyway"].
  #text(fill: green)[Fix:] a concurrent baseline running the old code against live traffic in the
  same window. It costs one extra small deployment and is the difference between a signal and a
  coin flip.
]
