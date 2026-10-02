#import "/shared/lib/template.typ": *
#reg(1, "M24", "Dynamic Config & Feature Flags")
#chapterhead("Part 2 · Modules", "M24 · Config & Feature Flags")
#ix("Feature flag")
#ix("Kill switch")

#h1("M24 · Dynamic Config & Feature Flags", c: green)

#text[
  A feature flag separates #underline(stroke: 1pt + green)[deploy] from
  #underline(stroke: 1pt + green)[release]. Code ships dark, is enabled for 1% of users, and is
  disabled in seconds if it misbehaves — without a rebuild, a redeploy, or an app-store review
  that takes a week. That last point is why flags matter far more on mobile than on the web.
]
#v(2mm)

#h2("1 · Push vs pull, and why both exist", c: blue)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  swimlane(-0.4, -1.9, 9.0, 2.2, "PULL — simple, bounded staleness", blue, rgb("#f4f8fd"))
  rnode(2.4, 1.1, "c1", "client", "poll every 60 s", blue, w: 3.0, h: 0.85)
  rnode(6.6, 1.1, "s1", "config svc", "ETag → 304", blue, w: 3.2, h: 0.85)
  line("c1.east", "s1.west", mark: (end: ">"), stroke: lookup)
  content((4.4, -0.1), dlbl("stale up to the poll interval", sz: 6.3pt, c: orange))
  content((4.4, -0.75), dlbl("works everywhere, no connection held", sz: 6.3pt, c: green))
  content((4.4, -1.4), dlbl("N clients x 1/60s = constant load floor", sz: 6.3pt, c: purple))

  swimlane(9.8, -1.9, 18.4, 2.2, "PUSH — instant, needs a connection", green, rgb("#f6fbf7"))
  rnode(12.4, 1.1, "c2", "client", "SSE / WebSocket", green, w: 3.2, h: 0.85)
  rnode(16.4, 1.1, "s2", "config svc", "broadcasts delta", green, w: 3.2, h: 0.85)
  line("s2.west", "c2.east", mark: (end: ">"), stroke: hot)
  content((14.4, -0.1), dlbl("propagates in < 1 s", sz: 6.3pt, c: green))
  content((14.4, -0.75), dlbl("but you now hold N connections (M10)", sz: 6.3pt, c: red))
  content((14.4, -1.4), dlbl("must fall back to polling when disconnected", sz: 6.3pt, c: purple))
}))
#v(1.5mm)

#text(size: 9pt)[
  Mobile reality forces a hybrid: #text(fill: green, weight: "bold")[fetch on app foreground],
  poll on a modest interval while active, and accept that a backgrounded app learns nothing until
  it returns. #note[The kill-switch case is different and deserves its own path: a flag that
  disables a broken feature must be checked #underline(stroke: 1pt + green)[before] the feature
  runs, on every cold start, with a short timeout and a cached last-known value — never blocking
  app launch on a network call.]
]
#v(2mm)

#h2("2 · Flag types — they are not interchangeable", c: purple)

#table(
  columns: (auto, auto, 1fr, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.5pt, fill: purple)[Type],
  text(font: headfont, size: 8.5pt, fill: purple)[Lifespan],
  text(font: headfont, size: 8.5pt, fill: purple)[Purpose],
  text(font: headfont, size: 8.5pt, fill: purple)[Removal],

  text(size: 8.3pt)[Release toggle],
  text(size: 8.3pt)[days–weeks],
  text(size: 8pt)[Ship dark, ramp 1% → 100%],
  text(size: 8.3pt, fill: red)[mandatory],

  text(size: 8.3pt)[Kill switch],
  text(size: 8.3pt)[permanent],
  text(size: 8pt)[Disable a dependency or an expensive path under load],
  text(size: 8.3pt, fill: green)[keep],

  text(size: 8.3pt)[Experiment],
  text(size: 8.3pt)[weeks],
  text(size: 8pt)[A/B test with a stable per-user bucket],
  text(size: 8.3pt, fill: red)[mandatory],

  text(size: 8.3pt)[Entitlement],
  text(size: 8.3pt)[permanent],
  text(size: 8pt)[Plan or tenant gating — business logic, not a flag],
  text(size: 8.3pt, fill: green)[keep],

  text(size: 8.3pt)[Ops tuning],
  text(size: 8.3pt)[permanent],
  text(size: 8pt)[Timeouts, batch sizes, concurrency limits],
  text(size: 8.3pt, fill: green)[keep],
)
#v(1.5mm)

#key[
  #text(fill: red, weight: "bold")[Release toggles must have an expiry date recorded when they
  are created.] A flag that outlives its rollout becomes permanent untested branching: 20 flags
  is 2²⁰ theoretical configurations, of which you test one. Flag debt compounds exactly like
  code debt and is harder to see.
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("Evaluation cost and config service load")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Never evaluate remotely per request.] 10,000 RPS × 5 flag checks =
    50,000 evaluations/s. As network calls at 1 ms each, that is
    #text(fill: red, weight: "bold")[50 seconds of added latency per second of traffic] — plus a
    hard dependency on the flag service for every request.
    #linebreak()
    #text(fill: green, weight: "bold")[Correct model:] the SDK holds the full ruleset in memory
    and evaluates locally in #text(weight: "bold")[microseconds]; only the ruleset is fetched, on
    a poll or a push.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Config service load:] 1M clients polling every 60 s =
    #text(fill: orange, weight: "bold")[16,667 req/s] as a constant floor. With `ETag` and 304
    responses the payload is ~200 B, so ~3 MB/s — trivial bandwidth, but
    #underline(stroke: 1pt + red)[the request rate never goes away] and must be sized for peak
    plus the reconnect spike after any outage.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Bucketing must be deterministic:]
    `bucket = murmur3(flag_key + user_id) % 100`. Hashing the flag key alongside the user id
    means a user in the 1% of flag A is not systematically also in the 1% of flag B — otherwise
    the same unlucky cohort receives every experiment.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[The flag service becomes tier-0.] Config fetch fails and the
  app refuses to start, or every request errors.
  #text(fill: green)[Fix:] ship defaults compiled into the binary, cache the last known good
  ruleset on disk, and treat a fetch failure as "keep current behaviour". A flag system must
  #underline(stroke: 1pt + green)[fail static], never fail closed.

  #text(fill: red, weight: "bold")[Non-sticky bucketing.] Evaluation uses a random number instead
  of a hash of the user id, so a user flips between variants on every request — the UI changes
  under them and the experiment data is meaningless.
  #text(fill: green)[Fix:] deterministic hash of a stable identifier, computed the same way on
  every platform.

  #text(fill: red, weight: "bold")[Inconsistent evaluation across services.] Service A sees the
  flag on, service B sees it off, and a request straddles both.
  #text(fill: green)[Fix:] evaluate once at the edge and propagate the decision in the request
  context, rather than re-evaluating at each hop.

  #text(fill: red, weight: "bold")[Flags that cannot reach the client.] A broken mobile release
  is gated by a flag the broken build cannot fetch.
  #text(fill: green)[Fix:] the kill-switch check must be in the most stable code path — early in
  startup, independent of the feature it guards, with a cached fallback.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: How do you roll out a risky mobile feature?]
  #linebreak()
  Ship it dark behind a flag, enable for internal users, then 1% → 5% → 25% → 100% while watching
  crash rate and the relevant business metric, with a kill switch that works without an app
  update. #note[Testing: do you know a mobile rollback is #underline(stroke: 1pt + red)[not a
  deploy]? Review latency means the flag is the only fast remedy you have.]

  #text(fill: green, weight: "bold")[Q: Where are flags evaluated?]
  #linebreak()
  Locally in-process against a cached ruleset; only the ruleset is fetched remotely.
  #note[Testing: whether you would put a network call in the hot path. Many candidates do.]

  #text(fill: green, weight: "bold")[Q: The flag service is down. What happens?]
  #linebreak()
  Nothing visible — last known good config from local cache, compiled defaults if there is none.
  #note[Testing: that the safety mechanism must not itself be a single point of failure.]
]
#v(2mm)

#anti("flags that never get removed")[
  A team adds flags freely and removes none. Two years later the codebase has
  #text(fill: red, weight: "bold")[200 permanent flags], every function is wrapped in
  conditionals nobody can reason about, and the test suite exercises exactly one combination out
  of 2²⁰⁰. A bug reproduces only for users in a particular flag combination, which makes it
  effectively #underline(stroke: 1pt + red)[undebuggable]. Deleting a flag becomes risky because
  nobody knows who depends on it. #text(fill: green)[Fix:] every release toggle gets an owner and
  an expiry at creation; a weekly report lists flags past expiry; removing the flag is part of
  the rollout ticket, not a follow-up nobody schedules.
]
