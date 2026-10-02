#import "/shared/lib/template.typ": *
#pagebreak(weak: true)
#chapterhead("Appendices & Reference", "Back Matter")

// ============================================================================
// BACK MATTER — appendices A–E, glossary, bibliography, index, colophon.
// ============================================================================


// ========================================================== APPENDIX A
#chapterhead("Appendices & Reference", "Appendix A · Formulae")
#reg(1, "A", "Formula Reference")
#anchor("appA")
#fmhead("Appendix A · Formula Reference")

#text(size: 9pt)[Everything in the book that is worth being able to reproduce from memory.]
#v(3mm)

#formula("Scaling and parallelism")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Amdahl's Law] — fixed problem size, s = serial fraction: \
    #h(4mm) S(N) = 1 / ( s + (1 − s)/N ) #h(6mm) ceiling = #text(fill: orange, weight: "bold")[1/s] \
    #v(1mm)
    #text(weight: "bold")[Gustafson's Law] — problem grows with N: \
    #h(4mm) S(N) = N − s(N − 1) #h(6mm) (speedup stays roughly linear) \
    #v(1mm)
    #text(weight: "bold")[Universal Scalability Law] — adds a coherency penalty: \
    #h(4mm) C(N) = N / ( 1 + α(N−1) + βN(N−1) ) \
    #h(4mm) α = contention, β = coherency. #text(fill: red)[β > 0 means throughput eventually
    *falls* as N grows] — the retrograde region.
  ]
]
#v(2.5mm)

#formula("Availability")[
  #text(size: 8.6pt)[
    1 year = 365.25 × 24 × 60 = #text(fill: orange, weight: "bold")[525,960 minutes] \
    downtime/yr = (1 − A) × 525,960 \
    A = MTBF / (MTBF + MTTR) \
    #text(weight: "bold")[Serial dependencies:] A#sub[total] = A₁ × A₂ × … × A#sub[n] \
    #h(4mm) five services at 99.9% → 0.999⁵ = #text(fill: red, weight: "bold")[99.5%] \
    #text(weight: "bold")[Parallel redundancy:] A = 1 − (1 − A#sub[one])#super[n]
  ]
]
#v(2.5mm)

#formula("Quorums and replication")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Strong read:] R + W > N #h(6mm)
    #text(weight: "bold")[Write durability:] W > N/2 \
    #text(weight: "bold")[Raft/Paxos quorum:] ⌊N/2⌋ + 1 #h(4mm)
    tolerates ⌊(N−1)/2⌋ failures \
    #h(4mm) N=3 → tolerates 1 · N=5 → tolerates 2 · N=7 → tolerates 3 \
    #text(fill: purple)[Always odd N. N=4 tolerates the same as N=3 and costs more.]
  ]
]
#v(2.5mm)

#formula("Latency and queueing")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Little's Law:] L = λW #h(3mm)
    (items in system = arrival rate × time in system) \
    #h(4mm) 2,000 QPS × 50 ms = #text(fill: orange, weight: "bold")[100 concurrent requests] →
    size your pool from this, not from guesswork. \
    #v(1mm)
    #text(weight: "bold")[Utilisation and queueing (M/M/1):] W = 1 / (μ − λ) \
    #h(4mm) at 50% utilisation, queue wait ≈ service time \
    #h(4mm) at 90% → #text(fill: orange)[9×] #h(4mm) at 99% →
    #text(fill: red, weight: "bold")[99×]. #text(fill: red)[Never size for >70%.] \
    #v(1mm)
    #text(weight: "bold")[Tail amplification:] P(slow) = 1 − (1 − p)#super[N] \
    #h(4mm) N=100 fan-out at p99 → 1 − 0.99¹⁰⁰ =
    #text(fill: red, weight: "bold")[63.4%] of requests hit a slow call.
  ]
]
#v(2.5mm)

#formula("Error budgets and capacity")[
  #text(size: 8.6pt)[
    budget = (1 − SLO) × total requests \
    burn rate = (observed error rate) / (1 − SLO) \
    #h(4mm) 14.4× burns a 30-day budget in 2 days → page \
    #v(1mm)
    #text(weight: "bold")[QPS from users:] DAU × actions/day / 86,400, then × 3 for peak \
    #text(weight: "bold")[Storage:] rows × bytes/row × replication × (1 + index overhead) \
    #text(weight: "bold")[Birthday bound] (ID collision): ≈ 50% at √(2#super[bits]) items —
    #h(2mm) 64-bit → collisions near #text(fill: orange)[4 billion] IDs.
  ]
]
#pagebreak()

// ========================================================== APPENDIX B
#chapterhead("Appendices & Reference", "Appendix B · Capacity")
#reg(1, "B", "Capacity Cheat Sheet")
#anchor("appB")
#fmhead("Appendix B · Capacity Cheat Sheet")

#text(font: headfont, size: 10.5pt, fill: blue)[Latency numbers every engineer should know]
#v(2mm)
#table(
  columns: (1fr, auto, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#eef4fb") } else { none },
  text(font: headfont, size: 8.5pt, fill: blue)[Operation],
  text(font: headfont, size: 8.5pt, fill: blue)[Time],
  text(font: headfont, size: 8.5pt, fill: blue)[Relative],

  text(size: 8.3pt)[L1 cache reference], text(size: 8.3pt)[0.5 ns], text(size: 8.3pt)[1×],
  text(size: 8.3pt)[Branch mispredict], text(size: 8.3pt)[5 ns], text(size: 8.3pt)[10×],
  text(size: 8.3pt)[L2 cache reference], text(size: 8.3pt)[7 ns], text(size: 8.3pt)[14×],
  text(size: 8.3pt)[Mutex lock/unlock], text(size: 8.3pt)[25 ns], text(size: 8.3pt)[50×],
  text(size: 8.3pt)[Main memory reference], text(size: 8.3pt)[100 ns], text(size: 8.3pt)[200×],
  text(size: 8.3pt)[Compress 1 KB (Snappy)], text(size: 8.3pt)[3 μs], text(size: 8.3pt)[6k×],
  text(size: 8.3pt)[Send 1 KB over 1 Gbps], text(size: 8.3pt)[10 μs], text(size: 8.3pt)[20k×],
  text(size: 8.3pt)[SSD random read], text(size: 8.3pt, fill: green)[150 μs], text(size: 8.3pt)[300k×],
  text(size: 8.3pt)[Read 1 MB sequentially from memory], text(size: 8.3pt)[250 μs], text(size: 8.3pt)[500k×],
  text(size: 8.3pt)[Round trip within a datacentre], text(size: 8.3pt, fill: orange)[0.5 ms], text(size: 8.3pt)[1M×],
  text(size: 8.3pt)[Read 1 MB sequentially from SSD], text(size: 8.3pt)[1 ms], text(size: 8.3pt)[2M×],
  text(size: 8.3pt)[Disk seek (spinning)], text(size: 8.3pt, fill: red)[10 ms], text(size: 8.3pt)[20M×],
  text(size: 8.3pt)[Round trip CA ↔ Netherlands], text(size: 8.3pt, fill: red)[150 ms], text(size: 8.3pt)[300M×],
)
#v(2mm)
#key[
  The three that decide most architectures: #text(fill: green, weight: "bold")[memory is 100 ns],
  #text(fill: orange, weight: "bold")[same-DC network is 0.5 ms], and
  #text(fill: red, weight: "bold")[cross-continent is 150 ms]. A cross-region synchronous write is
  #underline(stroke: 1pt + red)[300,000× slower] than a memory read. That single ratio explains
  why multi-region active-active is hard.
]
#v(3mm)

#text(font: headfont, size: 10.5pt, fill: blue)[Powers of two, and what they mean]
#v(2mm)
#text(size: 8.6pt)[
  2¹⁰ = 1 thousand (KB) · 2²⁰ = 1 million (MB) · 2³⁰ = 1 billion (GB) ·
  2⁴⁰ = 1 trillion (TB) · 2⁵⁰ = 1 quadrillion (PB) \
  #v(1mm)
  #text(weight: "bold")[Useful conversions:] 1 day = 86,400 s · 1 month ≈ 2.6 M s ·
  1 year ≈ 31.5 M s · 1 year = 525,960 min \
  #text(weight: "bold")[Throughput:] 1 QPS sustained = 86,400/day ≈ 2.6 M/month ·
  1,000 QPS = 86.4 M/day \
  #text(weight: "bold")[Rule of thumb:] peak ≈ 3× average; design headroom ≈ 2× peak.
]
#v(3mm)

#text(font: headfont, size: 10.5pt, fill: blue)[Typical sizes]
#v(2mm)
#text(size: 8.6pt)[
  UUID 16 B · timestamp 8 B · typical DB row 100 B – 1 KB · small JSON response 1–10 KB ·
  web page 2 MB · 1 min of 1080p video ≈ 50 MB · 1 hour of telemetry at 100 Hz ≈ 3 MB/device \
  #note[Index overhead is commonly 10–30% of table size; replication multiplies everything by N.
  A "1 TB dataset" at N=3 with indexes is closer to #text(fill: orange)[4 TB] provisioned.]
]
#pagebreak()

// ========================================================== APPENDIX C
#chapterhead("Appendices & Reference", "Appendix C · Anti-Patterns")
#reg(1, "C", "Anti-Pattern Catalogue")
#anchor("appC")
#fmhead("Appendix C · Anti-Pattern Catalogue")

#text(size: 9pt)[
  Every anti-pattern named in the book, consolidated. In an interview, naming the failure mode
  before the interviewer does is worth more than naming the technology.
]
#v(3mm)

#table(
  columns: (auto, 1fr, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#fdf0ee") } else { none },
  text(font: headfont, size: 8.5pt, fill: red)[Anti-pattern],
  text(font: headfont, size: 8.5pt, fill: red)[Why it fails / the fix],
  text(font: headfont, size: 8.5pt, fill: red)[§],

  text(size: 8.2pt)[Just add more replicas],
  text(size: 8pt)[Replicas contend on the serial section; p99 rises, throughput flat.
    Measure the serial fraction first.],
  text(size: 8pt)[1.2],

  text(size: 8.2pt)[Sticky sessions as scaling],
  text(size: 8pt)[Uneven load, destructive deploys, broken autoscaling.
    Externalise state instead.],
  text(size: 8pt)[1.3],

  text(size: 8.2pt)[Blocking in the event loop],
  text(size: 8pt)[One sync call stalls every request on that loop.
    Worker pool for CPU work.],
  text(size: 8pt)[1.4],

  text(size: 8.2pt)[Promising nines you don't control],
  text(size: 8pt)[Your SLO cannot exceed your weakest synchronous dependency.],
  text(size: 8pt)[2.1],

  text(size: 8.2pt)[Chasing MTBF over MTTR],
  text(size: 8pt)[Both move availability identically; MTTR is far cheaper to halve.],
  text(size: 8pt)[2.2],

  text(size: 8.2pt)[The untested DR plan],
  text(size: 8pt)[Expired credentials, renamed services, 14-hour restores.
    Rehearse and publish the measured RTO.],
  text(size: 8pt)[2.3],

  text(size: 8.2pt)[\"We use eventual consistency\"],
  text(size: 8pt)[Stated system-wide it means no invariant was identified.
    Route invariant-bearing ops to a strong path.],
  text(size: 8pt)[3.3],

  text(size: 8.2pt)[Averaging percentiles],
  text(size: 8pt)[Percentiles are not linearly combinable. Merge histograms,
    then compute the quantile once.],
  text(size: 8pt)[4.3],

  text(size: 8.2pt)[Alerting on every symptom],
  text(size: 8pt)[On-call stops reading alerts. Page on error-budget burn only.],
  text(size: 8pt)[5.5],

  text(size: 8.2pt)[Breaker that only counts errors],
  text(size: 8pt)[Never trips for a #emph[hanging] dependency.
    Timeouts must count as failures.],
  text(size: 8pt)[6.1],

  text(size: 8.2pt)[Retry storms],
  text(size: 8pt)[Un-jittered retries at every layer amplify an outage 27×.
    Full jitter, retry budget, one layer.],
  text(size: 8pt)[6.4],

  text(size: 8.2pt)[LSM store as a work queue],
  text(size: 8pt)[Delete-heavy range scans read through tombstones.
    Use a real queue.],
  text(size: 8pt)[M1],

  text(size: 8.2pt)[Sharding before you need to],
  text(size: 8pt)[Inherits cross-shard joins and fan-out for a dataset that fits in RAM.],
  text(size: 8pt)[M2],

  text(size: 8.2pt)[Distributed lock without fencing],
  text(size: 8pt)[A paused holder writes after losing the lock.
    Fencing tokens checked at the resource.],
  text(size: 8pt)[M3],

  text(size: 8.2pt)[The dual write],
  text(size: 8pt)[DB write + queue publish is not atomic.
    Transactional outbox.],
  text(size: 8pt)[M4],

  text(size: 8.2pt)[Caching with no staleness budget],
  text(size: 8pt)[Redis added for speed, then the product cannot tolerate stale data.
    Pick the budget first.],
  text(size: 8pt)[M5],

  text(size: 8.2pt)[Gateway that grew business logic],
  text(size: 8pt)[Untestable Lua nobody owns, and a mistake takes down every service.],
  text(size: 8pt)[M6],

  text(size: 8.2pt)[The \"quick\" field rename],
  text(size: 8pt)[Breaks app builds 18 months old. A rename is an add + deprecate + wait.],
  text(size: 8pt)[M7],

  text(size: 8.2pt)[Kafka as a task queue],
  text(size: 8pt)[Offsets advance in order, so one bad job blocks the partition.],
  text(size: 8pt)[M8],

  text(size: 8.2pt)[Stateful conns with no drain plan],
  text(size: 8pt)[A deploy disconnects everyone at once; the reconnect storm is the outage.],
  text(size: 8pt)[M10],

  text(size: 8.2pt)[Push as a reliable transport],
  text(size: 8pt)[APNs/FCM are best-effort. Push a pointer, never the payload.],
  text(size: 8pt)[M11],

  text(size: 8.2pt)[Optimistic UI with no rollback],
  text(size: 8pt)[Rejected writes never surface; user and server diverge silently.],
  text(size: 8pt)[M12],

  text(size: 8.2pt)[Per-pod rate limiting],
  text(size: 8pt)[The real limit becomes N x limit and changes when you autoscale.],
  text(size: 8pt)[M13],

  text(size: 8.2pt)[UUIDv4 as a primary key],
  text(size: 8pt)[Random keys destroy B-tree insert locality. Use UUIDv7.],
  text(size: 8pt)[M14],

  text(size: 8.2pt)[Distance maths in SQL],
  text(size: 8pt)[Full scan, and wrong at latitude. Index a cell id instead.],
  text(size: 8pt)[M15],

  text(size: 8.2pt)[Proxying uploads through the API],
  text(size: 8pt)[Blocks workers on I/O; autoscaling never fires. Use presigned URLs.],
  text(size: 8pt)[M16],

  text(size: 8.2pt)[Search index as system of record],
  text(size: 8pt)[No transactions, and a cluster loss is data loss.],
  text(size: 8pt)[M17],

  text(size: 8.2pt)[Long-lived access tokens],
  text(size: 8pt)[A leak is unrevocable for the token lifetime.],
  text(size: 8pt)[M18],

  text(size: 8.2pt)[Instrumenting only the backend],
  text(size: 8pt)[The user's DNS, TLS and radio time is outside the measurement.],
  text(size: 8pt)[M19],

  text(size: 8.2pt)[Unbounded worker queue],
  text(size: 8pt)[Capacity burned on work whose clients timed out long ago.],
  text(size: 8pt)[M20],

  text(size: 8.2pt)[Tuning the backend, ignoring RTTs],
  text(size: 8pt)[Eight sequential calls dwarf any compute saving.],
  text(size: 8pt)[M21],

  text(size: 8.2pt)[Check-then-act in two statements],
  text(size: 8pt)[Passes every single-threaded test; races in production.],
  text(size: 8pt)[M22],

  text(size: 8.2pt)[Redlock for correctness],
  text(size: 8pt)[Assumes bounded pauses and clock drift. Neither holds.],
  text(size: 8pt)[M23],

  text(size: 8.2pt)[Feature flags never removed],
  text(size: 8pt)[Permanent untested branching; bugs reproduce only per-combination.],
  text(size: 8pt)[M24],

  text(size: 8.2pt)[Autoscaling on CPU for I/O work],
  text(size: 8pt)[Blocked workers show low CPU, so it scales DOWN under load.],
  text(size: 8pt)[M25],

  text(size: 8.2pt)[The canary nobody watches],
  text(size: 8pt)["Did it crash" catches nothing. Appearance of safety is worse than none.],
  text(size: 8pt)[M26],

  text(size: 8.2pt)[Active-active with no ownership],
  text(size: 8pt)[LWW discards writes, arbitrated by cross-datacentre clock skew.],
  text(size: 8pt)[M27],

  text(size: 8.2pt)[Tenant isolation in app code only],
  text(size: 8pt)[One missing predicate is a cross-tenant breach.],
  text(size: 8pt)[M28],

  text(size: 8.2pt)[Liveness probe checking the database],
  text(size: 8pt)[A DB blip restarts the whole fleet with cold caches.],
  text(size: 8pt)[M29],

  text(size: 8.2pt)[Optimising compute, ignoring egress],
  text(size: 8pt)[Months of work for a third of what two config changes would save.],
  text(size: 8pt)[M30],

  text(size: 8.2pt)[Deletion as a DB operation],
  text(size: 8pt)[Index, warehouse, backups and processors all still hold the data.],
  text(size: 8pt)[M31],

  text(size: 8.2pt)[Pure fan-out-on-write],
  text(size: 8pt)[One celebrity post = 50M writes, delaying everyone else.],
  text(size: 8pt)[M32],

  text(size: 8.2pt)[State machine made of cron jobs],
  text(size: 8pt)[Races, stuck states, and no one can say where an order is.],
  text(size: 8pt)[M33],

  text(size: 8.2pt)[Trusting a client because it attested],
  text(size: 8pt)[Attestation proves the binary once, not any later request.],
  text(size: 8pt)[M34],

  text(size: 8.2pt)[Big-bang migration window],
  text(size: 8pt)[Overruns, and rollback needs a restore. Use expand-contract.],
  text(size: 8pt)[M35],

  text(size: 8.2pt)[Synchronous analytics in the request path],
  text(size: 8pt)[A telemetry outage takes down checkout.],
  text(size: 8pt)[M36],
)
#pagebreak()

// ========================================================== APPENDIX D
#chapterhead("Appendices & Reference", "Appendix D · The Day Before")
#reg(1, "D", "The Day Before")
#anchor("appD")
#fmhead("Appendix D · The Day Before")

#text(size: 9pt)[
  Highest-yield material only. If you have one sitting left, read this page and nothing else.
]
#v(3mm)

#text(font: headfont, size: 10.5pt, fill: red)[The numbers to have memorised]
#v(1.5mm)
#text(size: 8.8pt)[
  1 year = #text(fill: orange, weight: "bold")[525,960 min] · 1 day = 86,400 s ·
  memory = 100 ns · same-DC RTT = 0.5 ms · cross-continent = 150 ms \
  99.9% = 43 min/month · 99.99% = 4.3 min/month ·
  peak ≈ 3× average · never size past 70% utilisation
]
#v(3mm)

#text(font: headfont, size: 10.5pt, fill: orange)[The estimation drill, every time]
#v(1.5mm)
#text(size: 8.8pt)[
  #text(weight: "bold")[1.] DAU × actions/day → /86,400 → average QPS →
  #text(weight: "bold")[2.] × 3 for peak →
  #text(weight: "bold")[3.] rows × bytes × replication × 1.3 for storage →
  #text(weight: "bold")[4.] Little's Law (L = λW) for pool sizing →
  #text(weight: "bold")[5.] state what breaks first.
  #linebreak()
  #note[Say the arithmetic out loud. An interviewer cannot credit reasoning they cannot hear,
  and a wrong number reasoned clearly scores better than a right number asserted.]
]
#v(3mm)

#text(font: headfont, size: 10.5pt, fill: green)[The framework, when you are stuck]
#v(1.5mm)
#text(size: 8.8pt)[
  Requirements → scale estimate → API → data model → high-level architecture → bottleneck →
  scaling → failure modes → trade-offs. #text(fill: purple)[Narrate which step you are on.]
]
#v(3mm)

#text(font: headfont, size: 10.5pt, fill: blue)[The eight things that are nearly always the answer]
#v(1.5mm)
#text(size: 8.8pt)[
  #text(weight: "bold")[1.] Cache it — but state the staleness budget first. \
  #text(weight: "bold")[2.] Shard it — but name the shard key and the hot-key mitigation. \
  #text(weight: "bold")[3.] Queue it — decouple a slow consumer from a fast producer. \
  #text(weight: "bold")[4.] Replicate it — reads scale, writes do not. \
  #text(weight: "bold")[5.] Make it idempotent — every retry depends on it. \
  #text(weight: "bold")[6.] Add a circuit breaker + timeout — slow is worse than down. \
  #text(weight: "bold")[7.] Degrade gracefully — classify every dependency optional/degraded/critical. \
  #text(weight: "bold")[8.] Measure it — golden signals, error budget, burn rate.
]
#v(3mm)

#text(font: headfont, size: 10.5pt, fill: purple)[Sentences that score]
#v(1.5mm)
#text(size: 8.8pt)[
  "What's the read:write ratio?" · "What staleness can this tolerate?" ·
  "Which of these has an invariant we must never violate?" ·
  "That's the bottleneck — here's what I'd measure to confirm." ·
  "I'd choose X, accepting Y as the cost."
  #linebreak()
  #text(fill: red)[Avoid:] naming a technology before stating the requirement it satisfies.
]
#v(3mm)

#anti("the three answers that lose offers")[
  #text(weight: "bold")[1.] "We'll use Kafka" before establishing throughput, ordering or replay
  needs. #text(weight: "bold")[2.] "It'll be eventually consistent" for an operation with a money
  invariant. #text(weight: "bold")[3.] Designing for 1 B users when asked about 10 k —
  over-engineering reads as poor judgement, not ambition.
]
#pagebreak()

// ========================================================== APPENDIX E
#chapterhead("Appendices & Reference", "Appendix E · Quick Reference")
#reg(1, "E", "Quick-Reference Card")
#anchor("appE")
#fmhead("Appendix E · Quick-Reference Card")

#grid(columns: (1fr, 1fr), gutter: 5mm,
  [
    #text(font: headfont, size: 10pt, fill: green)[Four Golden Signals]
    #v(1mm)
    #text(size: 8.3pt)[
      #text(weight: "bold")[Latency] — split success vs. failure \
      #text(weight: "bold")[Traffic] — demand, to interpret the rest \
      #text(weight: "bold")[Errors] — explicit *and* implicit \
      #text(weight: "bold")[Saturation] — the only leading indicator
    ]
    #v(3mm)
    #text(font: headfont, size: 10pt, fill: red)[Circuit breaker]
    #v(1mm)
    #text(size: 8.3pt)[
      CLOSED → (fail rate > threshold) → OPEN \
      OPEN → (cooldown) → HALF-OPEN \
      HALF-OPEN → ok → CLOSED · fail → OPEN \
      #text(fill: red)[Timeouts count as failures.]
    ]
    #v(3mm)
    #text(font: headfont, size: 10pt, fill: purple)[Consistency ladder]
    #v(1mm)
    #text(size: 8.3pt)[
      Linearizable → Sequential → Causal → Eventual \
      #text(fill: purple)[more coordination ← → more speed] \
      PACELC: P→A|C, Else→L|C
    ]
  ],
  [
    #text(font: headfont, size: 10pt, fill: orange)[Burn-rate pages]
    #v(1mm)
    #text(size: 8.3pt)[
      14.4× / 1 h + 5 min → #text(fill: red)[PAGE] \
      6× / 6 h + 30 min → #text(fill: red)[PAGE] \
      3× / 1 d + 2 h → ticket \
      1× / 3 d + 6 h → ticket
    ]
    #v(3mm)
    #text(font: headfont, size: 10pt, fill: blue)[Quorum]
    #v(1mm)
    #text(size: 8.3pt)[
      R + W > N → strong read \
      majority = ⌊N/2⌋+1 \
      N=3→1 fail · N=5→2 · N=7→3 \
      #text(fill: red)[odd N only]
    ]
    #v(3mm)
    #text(font: headfont, size: 10pt, fill: green)[Retry]
    #v(1mm)
    #text(size: 8.3pt)[
      `sleep = random(0, min(cap, base·2^n))` \
      Cap attempts · idempotency key \
      #text(fill: red)[retry at ONE layer only]
    ]
  ]
)
#v(4mm)
#key[
  If you remember one thing: #text(fill: red, weight: "bold")[state the requirement before the
  technology], and #text(fill: orange, weight: "bold")[show the arithmetic]. Those two habits
  carry more weight than any specific architecture.
]
#pagebreak()

// ========================================================== GLOSSARY
#chapterhead("Appendices & Reference", "Glossary")

