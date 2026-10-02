#import "/shared/lib/template.typ": *
#reg(1, "M13", "Distributed Rate Limiting")
#chapterhead("Part 2 · Modules", "M13 · Distributed Rate Limiting")
#ix("Token bucket")
#ix("Leaky bucket")
#ix("Sliding window")

#h1("M13 · Distributed Rate Limiting", c: red)

#text[
  A rate limiter decides which requests to #underline(stroke: 1pt + red)[refuse]. That framing
  matters: the limiter exists to protect the system from collapse, so when it is wrong it must
  fail toward availability of the #emph[service], not of any individual caller.
]
#v(2mm)

#h2("1 · The four algorithms", c: blue)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  // token bucket
  content((3.0, 2.6), dlbl("TOKEN BUCKET — allows bursts", sz: 7.5pt, c: green))
  rect((1.6, 0.2), (4.4, 2.0), stroke: 1.3pt + green, radius: 0.1)
  for (i, y) in ((0, 0.5), (1, 0.95), (2, 1.4)).enumerate() {
    for k in range(4) { circle((2.0 + k * 0.6, y.at(1)), radius: 0.16, stroke: 0.8pt + green) }
  }
  content((3.0, -0.4), dlbl("refill r/s, cap B", sz: 6.4pt, c: green))
  content((3.0, -1.0), dlbl("burst up to B, then r/s", sz: 6.4pt, c: purple))

  // leaky bucket
  content((8.4, 2.6), dlbl("LEAKY BUCKET — smooths", sz: 7.5pt, c: blue))
  line((7.0, 2.0), (7.6, 0.4), (9.2, 0.4), (9.8, 2.0), stroke: 1.3pt + blue)
  for k in range(3) { circle((8.4, 0.8 + k * 0.45), radius: 0.16, stroke: 0.8pt + blue) }
  line((8.4, 0.3), (8.4, -0.3), mark: (end: ">"), stroke: 1.1pt + blue)
  content((8.4, -0.75), dlbl("constant drain rate", sz: 6.4pt, c: blue))
  content((8.4, -1.35), dlbl("no bursts — queues or drops", sz: 6.4pt, c: purple))

  // sliding window
  content((14.4, 2.6), dlbl("SLIDING WINDOW — accurate", sz: 7.5pt, c: orange))
  line((11.6, 1.2), (17.2, 1.2), stroke: 1.2pt + ink)
  rect((12.2, 0.9), (15.4, 1.5), stroke: (paint: orange, dash: "dashed", thickness: 1pt))
  for x in (12.5, 12.9, 13.6, 14.2, 14.9, 15.2, 16.0, 16.6) {
    line((x, 1.2), (x, 1.75), stroke: 1.1pt + orange)
  }
  content((13.8, 0.45), dlbl("window slides with now()", sz: 6.4pt, c: orange))
  content((14.4, -0.4), dlbl("exact, but stores every timestamp", sz: 6.4pt, c: red))
  content((14.4, -1.0), dlbl("counter variant: 2 buckets + weighting", sz: 6.4pt, c: green))
}))
#v(2mm)

#table(
  columns: (auto, auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#eef4fb") } else { none },
  text(font: headfont, size: 8.5pt, fill: blue)[Algorithm],
  text(font: headfont, size: 8.5pt, fill: blue)[Memory/key],
  text(font: headfont, size: 8.5pt, fill: blue)[Bursts],
  text(font: headfont, size: 8.5pt, fill: blue)[Use when],

  text(size: 8.3pt)[Fixed window],
  text(size: 8.3pt, fill: green)[1 counter],
  text(size: 8.3pt, fill: red)[2× at edges],
  text(size: 8pt)[Never for strict limits — a client gets 2N across a boundary],

  text(size: 8.3pt)[Sliding log],
  text(size: 8.3pt, fill: red)[N timestamps],
  text(size: 8.3pt, fill: green)[exact],
  text(size: 8pt)[Low-volume, high-value limits (login attempts)],

  text(size: 8.3pt, fill: green)[Sliding counter],
  text(size: 8.3pt, fill: green)[2 counters],
  text(size: 8.3pt, fill: green)[~exact],
  text(size: 8pt, fill: green)[The default. Weighted blend of two windows],

  text(size: 8.3pt)[Token bucket],
  text(size: 8.3pt, fill: green)[2 fields],
  text(size: 8.3pt, fill: orange)[allowed],
  text(size: 8pt)[APIs where a burst is legitimate — page loads, batch sync],

  text(size: 8.3pt)[Leaky bucket],
  text(size: 8.3pt, fill: green)[1 queue],
  text(size: 8.3pt, fill: red)[none],
  text(size: 8pt)[Protecting a fixed-capacity downstream],
)
#v(2mm)

#h2("2 · Making it distributed and atomic", c: purple)

#text(size: 9pt)[
  Across N API pods, a per-pod counter means the real limit is
  #text(fill: red, weight: "bold")[N × limit]. Centralising in Redis is the usual answer, and
  the trap is that `GET` then `INCR` is #underline(stroke: 1pt + red)[not atomic] — two
  concurrent requests both read 99, both write 100, both are allowed.
  #note[Use a Lua script: Redis executes it atomically on one shard, so read-modify-write cannot
  interleave. `INCR` + `EXPIRE` in one script is the minimum viable limiter. For token bucket,
  the script computes refill from the elapsed time rather than running a timer.]
]
#v(2mm)

#formula("Sliding-window counter, the arithmetic")[
  #text(size: 8.6pt)[
    Limit 100/min. At 10:00:30, the previous minute saw 80 and the current minute has 30.
    #linebreak()
    weight = #text(weight: "bold")[(60 − 30)/60 = 0.5] #sym.arrow.r
    estimate = 80 × 0.5 + 30 = #text(fill: orange, weight: "bold")[70] #sym.arrow.r allow.
    #linebreak() #v(1mm)
    Two counters per key instead of N timestamps: 1M keys × ~50 B =
    #text(fill: green, weight: "bold")[50 MB] rather than gigabytes of per-request timestamps.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Redis capacity:] 50,000 limiter checks/s, each a Lua script round trip
    at ~0.2 ms #sym.arrow.r one Redis node handles it, but it is now
    #underline(stroke: 1pt + red)[on the critical path of every request] — budget it in your p99
    and give it a timeout.
  ]
]
#v(2mm)

#h2("3 · Responding correctly", c: green)

#text(size: 9pt)[
  Return #text(fill: orange, weight: "bold")[429 Too Many Requests] with a
  #text(weight: "bold")[`Retry-After`] header (RFC 6585), plus `RateLimit-Limit`,
  `RateLimit-Remaining` and `RateLimit-Reset` so a well-behaved client can self-pace rather than
  discovering the limit by hitting it. #note[A limiter with no `Retry-After` guarantees a retry
  storm: every blocked client retries immediately and in unison. The header is not politeness,
  it is #underline(stroke: 1pt + green)[load shaping].]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Redis down takes the API down.] Every request blocks on the
  limiter. #text(fill: green)[Fix:] decide the failure policy explicitly ---
  #text(fill: green)[fail-open] for ordinary traffic (accept a brief unprotected window),
  #text(fill: red)[fail-closed] for auth and payment endpoints. Short timeout, circuit breaker,
  and a local in-process fallback limiter.

  #text(fill: red, weight: "bold")[Limiting the wrong key.] Per-IP limiting throttles an entire
  corporate NAT or university as if it were one user, while a distributed attacker from 10,000
  IPs passes freely. #text(fill: green)[Fix:] limit per authenticated identity where you have
  one; per-IP is a blunt fallback for unauthenticated endpoints only.

  #text(fill: red, weight: "bold")[Fixed-window edge burst.] A client sends 100 at 10:00:59 and
  100 at 10:01:00 --- #text(fill: red, weight: "bold")[200 requests in one second] under a
  "100/min" limit. #text(fill: green)[Fix:] sliding counter.

  #text(fill: red, weight: "bold")[Retry amplification.] Clients retry on 429 without honouring
  `Retry-After`, so the limiter sheds the same request repeatedly and the system does more work
  rejecting than it would have done serving. #text(fill: green)[Fix:] `Retry-After` plus full
  jitter (M6/Part 1 §6.2) on the client.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Design a rate limiter for a distributed API.]
  #linebreak()
  Sliding-window counter in Redis via an atomic Lua script, keyed by authenticated identity,
  returning 429 with `Retry-After`, failing open on Redis loss for ordinary endpoints.
  #note[Testing: do you reach atomicity unprompted? "Increment a Redis counter" without the
  script is the common wrong answer, and it is a race.]

  #text(fill: green, weight: "bold")[Q: Token bucket or sliding window?]
  #linebreak()
  Token bucket when bursts are legitimate; sliding window when the limit must be strict.
  #note[Testing: whether you ask what the limit protects. Protecting a downstream with fixed
  capacity argues for leaky bucket; protecting fairness argues for sliding window.]

  #text(fill: green, weight: "bold")[Q: Redis is down. Now what?]
  #linebreak()
  A decision made in advance, per endpoint: fail-open for browsing, fail-closed for login and
  payments. #note[Testing: that you treat it as a product decision rather than discovering it
  during an incident.]
]
#v(2mm)

#anti("per-pod rate limiting")[
  Each pod keeps its own counter, so a "1,000 req/min" limit across
  #text(fill: red, weight: "bold")[20 pods] is really 20,000 — and it silently changes every
  time the deployment autoscales. The limit becomes a function of your replica count rather than
  your capacity, and nobody notices until a scale-up event lets through 10× the intended traffic.
  #text(fill: green)[Fix:] shared state in Redis, or a gateway-level limiter that sees all
  traffic. If you must limit locally, divide the global budget by the
  #underline(stroke: 1pt + green)[current] replica count and re-derive it on scale events.
]
