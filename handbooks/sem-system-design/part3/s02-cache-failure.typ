#import "/shared/lib/template.typ": *
#reg(1, "S2", "Total cache failure threatening the database")
#chapterhead("Part 3 · Interview Scenarios", "S2 · Cache Layer Collapse")

#h1("S2 · Total Cache Failure", c: red)

#text[
  #text(fill: purple, weight: "bold")[The prompt.] The Redis cluster serving a 95% hit rate fails
  entirely. Every read now goes to the primary database, which was sized for 5% of that traffic.
  You have perhaps sixty seconds before the database becomes unresponsive and takes down writes
  as well as reads.
]
#v(2mm)

#h2("1 · The dilemma and its root cause", c: red)

#formula("The amplification, exactly")[
  #text(size: 8.6pt)[
    Steady state: 20,000 reads/s at a 95% hit rate #sym.arrow.r DB sees
    #text(weight: "bold")[1,000/s] and is provisioned for ~2,000/s.
    #linebreak()
    Cache gone #sym.arrow.r DB sees #text(fill: red, weight: "bold")[20,000/s] — a
    #text(weight: "bold")[20×] overload against a 2× margin.
    #linebreak() #v(1mm)
    The database does not degrade gracefully at 10× its capacity; it queues, connection pools
    exhaust, and #underline(stroke: 1pt + red)[writes fail alongside reads]. A read-availability
    incident becomes a total outage in under a minute.
  ]
]
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: purple, weight: "bold")[Root cause.] The cache was treated as an
  #text(fill: red, weight: "bold")[optimisation] when it was in fact
  #underline(stroke: 1pt + red)[load-bearing capacity]. If the system cannot survive its loss,
  the cache is a tier-0 dependency and must be engineered like one — which almost nobody does,
  because caches are introduced as a performance improvement and never re-classified.
]
#v(2mm)

#h2("2 · The solution", c: green)

#pfig("Fig S2.1 · Redis gone — the three defences, and which one is the hard guarantee")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.7, 3.0, "per-endpoint staleness budget recorded in advance; L1 LRU in every pod; DB concurrency measured, not guessed")

  ppill(1.4, 0, "fail", "Redis down", c: red, w: 2.6)
  pstep(5.56, 0, "l1", "L1 in-proc LRU", "hot 1-5% still warm", st-auto, n: 1, actor: "read svc", w: 4.8)
  pstep(10.81, 0, "sf", "single-flight", "10k reqs/key → 1 query", st-auto, n: 2, actor: "read svc", w: 4.8)
  pdec(15.67, 0, "cap", "in-flight\n< 2,000?")
  ppill(19.42, 0, "fast", "fast 503", c: red, w: 2.6)

  pstep(10.4, -3.6, "db", "primary read", "Postgres · 2,000/s cap", st-integ, n: 3, actor: "database", w: 4.8)
  pstep(4.6, -3.6, "warm", "throttled warm", "shadow 5% into new Redis", st-auto, n: 4, actor: "backfill job", w: 4.8)
  ppill(18.4, -3.6, "stale", "stale + header", w: 3.2)

  line("fail.east", "l1.west", mark: (end: ">"), stroke: miss)
  line("l1.east", "sf.west", mark: (end: ">"), stroke: miss)
  line("sf.east", "cap.west", mark: (end: ">"), stroke: hot)
  line("cap.east", "fast.west", mark: (end: ">"), stroke: except)
  plabel(17.3, 0, "no", c: red)
  line("cap.south", (15.67, -3.6), "db.east", mark: (end: ">"), stroke: lookup)
  plabel(13.6, -2.4, "yes — admit", c: green, dy: 0.0)
  line("db.west", "warm.east", mark: (end: ">"), stroke: cold)
  line("fast.south", (19.42, -3.6), "stale.east", mark: (end: ">"), stroke: hot)
  plabel(18.7, -1.8, "stale beats absent", c: green, dy: 0.34)

  ploop("warm.west", "l1.south", -5.4, "re-route only once the new Redis is above an 80% hit rate", c: blue)
}))
#pcards(
  [Cache reclassified as a tier-0 dependency, not an optimisation; staleness budget per endpoint; L1 sized to the hot set],
  [In: 20,000 reads/s with 0% Redis hit rate · Out: ~2,000/s served from the primary, the hot set from L1, the excess a fast 503 or a marked-stale body],
  [In-process LRU (M5) · stampede lock / single-flight · concurrency limiter (M20) · Postgres primary · throttled Redis warm-up],
)
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: green, weight: "bold")[1 · L1 is the reason you survive.] A per-pod in-process LRU
  (M5) is unaffected by the Redis outage and typically holds the hottest 1–5% of keys — which on
  a Zipfian distribution is #underline(stroke: 1pt + green)[30–60% of traffic]. This single tier
  converts a 20× amplification into roughly 8×.

  #text(fill: green, weight: "bold")[2 · Concurrency-limit the database, do not rate-limit it.]
  Cap in-flight queries at the measured safe concurrency and reject the excess immediately
  (M20). A fast 503 costs one user a retry; an unbounded queue costs everyone the database.

  #text(fill: green, weight: "bold")[3 · Single-flight every key.] Ten thousand concurrent
  requests for the same missing key must produce #text(weight: "bold")[one] database query, not
  ten thousand. This is the stampede lock from M5 applied fleet-wide, and it is the highest-value
  line of code in the scenario.

  #text(fill: green, weight: "bold")[4 · Serve stale deliberately.] If L1 holds an expired entry,
  return it with a header marking it stale. For a product description this is obviously correct;
  for a balance it is obviously not. #underline(stroke: 1pt + green)[The staleness budget from M5
  tells you which] — which is why that budget must be recorded per endpoint before the incident.

  #text(fill: green, weight: "bold")[5 · Warm the replacement cache slowly.] A cold Redis
  rejoining is a second stampede: every request misses again. Fill it from a background job at a
  throttled rate, or shadow a fraction of reads into it, before routing traffic back.
]
#v(2mm)

#key[
  Rank the three defences by what they save:
  #text(fill: green, weight: "bold")[single-flight] collapses duplicate work (largest win),
  #text(fill: orange, weight: "bold")[L1] absorbs the hot set, and
  #text(fill: red, weight: "bold")[concurrency limits] guarantee the database survives whatever
  the first two let through. Only the third is a hard guarantee; the others are mitigations.
]
#v(2mm)

#h2("3 · SEM execution strategy", c: purple)

#text(size: 8.9pt)[
  #text(fill: purple, weight: "bold")[Classify the cache honestly.] The moment a cache is load
  bearing, it inherits tier-0 obligations: multi-AZ replication, tested failover, capacity
  reviews, and inclusion in DR drills. The cheap alternative is to
  #underline(stroke: 1pt + green)[size the database for a cache-cold day] — expensive, but it
  converts a catastrophe into a slowdown. State which you chose and why.

  #text(fill: purple, weight: "bold")[Blast radius.] Reads and writes must not share a connection
  pool. If they do, a read storm takes down order placement, and a cache outage becomes a revenue
  outage. Separate pools, separate limits, and writes get the larger reservation.

  #text(fill: purple, weight: "bold")[Rehearsal.] This scenario is testable on a Tuesday
  afternoon: fail the cache deliberately in staging under production-shaped load, and measure
  whether the database survives. #note[A team that has run this drill answers the interview
  question from memory. A team that has not will discover during the real incident that
  single-flight was never implemented, or that L1 was disabled months ago for a bug nobody
  revisited.]

  #text(fill: purple, weight: "bold")[Communication.] #text(fill: green)["Reads are degraded and
  some data may be a few minutes stale. Orders are unaffected. We are protecting the database
  deliberately."] The phrase #emph[deliberately] matters — it tells stakeholders the degradation
  is a decision, not a symptom spreading out of control.
]
#v(2mm)

#anti("the \"cache is just an optimisation\" assumption")[
  Capacity planning sizes the database for steady-state load #emph[with] the cache, and nobody
  writes down what happens without it. The assumption survives because the cache is reliable for
  years. Then a failover, a bad config push, or a full-memory eviction storm removes it, and the
  system discovers it was running at #text(fill: red, weight: "bold")[10× its real database
  capacity] the entire time. #text(fill: green)[Fix:] decide explicitly — either the cache is
  tier-0 and engineered accordingly, or the database can absorb a cold-cache day. Both are
  defensible; #underline(stroke: 1pt + red)[not knowing which one you have] is not.
]
