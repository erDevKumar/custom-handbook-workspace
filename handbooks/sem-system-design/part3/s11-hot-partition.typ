#import "/shared/lib/template.typ": *
#reg(1, "S11", "Celebrity hot-partition problem")
#chapterhead("Part 3 · Interview Scenarios", "S11 · Hot Partitions")

#h1("S11 · The Celebrity Hot Partition", c: orange)

#text[
  #text(fill: purple, weight: "bold")[The prompt.] One account with 90 million followers posts.
  The shard holding that row saturates while every other shard idles. Reads for that post are 40%
  of total traffic. Sharding cannot help — the key maps to exactly one partition by definition.
]
#v(2mm)

#h2("1 · The dilemma and its root cause", c: red)

#text(size: 9pt)[
  Consistent hashing (M2) distributes #underline(stroke: 1pt + green)[keys] evenly. It says
  nothing about #underline(stroke: 1pt + red)[traffic per key]. When one key carries a
  disproportionate share of load, every partitioning scheme fails identically, because they all
  agree that one key lives in one place.

  #text(fill: purple, weight: "bold")[Root cause.] Real-world popularity is power-law
  distributed, while hash partitioning assumes uniformity. The design was validated against test
  data where the largest account had a thousand followers.
]
#v(2mm)

#formula("The skew, and the two independent problems")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Read skew:] 500,000 reads/s total, 40% for one post =
    #text(fill: red, weight: "bold")[200,000 reads/s] against a single partition sized for
    perhaps #text(weight: "bold")[20,000/s]. A #text(weight: "bold")[10×] overload on one shard
    while 15 others run at 30%.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Write skew (the counter):] every like increments one row.
    #text(fill: red, weight: "bold")[50,000 likes/s] on one row is 50,000 serialised
    read-modify-writes against a single lock — the database will do perhaps
    #text(weight: "bold")[2,000/s] (M22). The queue is unbounded and latency climbs without limit.
    #linebreak() #v(1mm)
    #text(fill: green, weight: "bold")[These need different fixes.] Reads are solved by
    #underline(stroke: 1pt + green)[replication] (copy the data everywhere); writes are solved by
    #underline(stroke: 1pt + green)[decomposition] (split the counter into N shards and sum on
    read). Conflating them produces a design that fixes half the problem.
  ]
]
#v(2mm)

#h2("2 · The solution", c: green)

#pfig("Fig S11.1 · one viral key — detection routes reads out of the shard and decomposes the write")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.7, 3.0, "a frequency sketch running continuously, not a celebrity list; approximate counts fine for likes, not balances")

  ppill(2.45, 0, "viral", "40% of reads, one post", c: red, w: 4.7)
  pstep(7.66, 0, "sk", "frequency sketch", "10× on one shard", st-start, n: 1, actor: "detector", w: 4.8)
  pdec(12.51, 0, "kind", "read skew or\nwrite skew?")
  pstep(17.37, 0, "rd", "pin to L1 + CDN", "TTL 5s · ~0 hit the shard", st-auto, n: 2, actor: "every pod", w: 4.8)

  pstep(16.6, -3.8, "wr", "100 counter rows", "post:123:likes:0..99", st-auto, n: 3, actor: "like svc", w: 4.8)
  pstep(10.6, -3.8, "sum", "read = SUM(N)", "1s cache · 500/s a row", st-auto, n: 4, actor: "read svc", w: 4.8)
  ppill(4.4, -3.8, "served", "200k reads/s, 500/s per row", w: 5.6)
  ppill(4.4, -7.2, "resh", "resharding fails here", c: red, w: 4.5)

  line("viral.east", "sk.west", mark: (end: ">"), stroke: miss)
  line("sk.east", "kind.west", mark: (end: ">"), stroke: hot)
  line("kind.east", "rd.west", mark: (end: ">"), stroke: hot)
  plabel(14.3, 0, "reads", c: green, dy: 0.44)
  line("kind.south", (12.51, -1.9), (16.6, -1.9), "wr.north", mark: (end: ">"), stroke: hot)
  plabel(14.0, -1.9, "writes — decompose the row", c: orange, dy: 0.34)
  line("wr.west", "sum.east", mark: (end: ">"), stroke: lookup)
  line("sum.west", "served.east", mark: (end: ">"), stroke: hot)
  line("sum.south", (10.6, -7.2), "resh.east", mark: (end: ">"), stroke: except)
  plabel(7.9, -7.2, "every scheme routes one key to one owner", c: red, dy: 0.5)

  ploop("rd.south", "sk.south", -5.6, "re-measure continuously — demote the key when its rate falls back", c: blue)
}))
#pcards(
  [Continuous per-key rate tracking; a CDN in front of the read path; a product decision that the like count may be a second stale],
  [In: 500,000 reads/s with 40% on one post, and 50,000 likes/s on one row · Out: ~0 hot-key reads reach the shard, and 500 writes/s per counter row instead of 50,000 serialised ones],
  [Count-min sketch detector · per-pod L1 cache (M5) · CDN edge with a 5s TTL · 100 sharded counter rows · 1s cached SUM · automatic promote and demote],
)
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: green, weight: "bold")[Reads — promote the hot key out of the shard entirely.]
  Detect it (a frequency sketch over recent access counts), then pin it into every pod's L1 cache
  (M5) and push it to the CDN with a short TTL. Two hundred thousand reads per second become two
  hundred thousand #underline(stroke: 1pt + green)[memory lookups], and the shard sees almost
  none. A 5-second TTL is invisible to a user reading a viral post.

  #text(fill: orange, weight: "bold")[Writes — decompose the contended row.] Replace one counter
  with #text(weight: "bold")[N] counter rows (`post:123:likes:0` … `:99`). Each like increments a
  random shard, so contention drops by a factor of N. Reads sum the shards and cache the total for
  a second. #note[The displayed count is now approximate for up to a second. For a like counter
  that is entirely acceptable — and it is worth saying explicitly in an interview that you
  #underline(stroke: 1pt + green)[chose] approximate counting, because the same technique would be
  wrong for an account balance.]

  #text(fill: purple, weight: "bold")[Detect automatically, do not special-case by hand.] A
  maintained list of "celebrity accounts" will always be out of date — the problem arises precisely
  when someone unexpected goes viral. Track per-key request rates continuously and promote keys
  above a threshold into the hot path #text(fill: green)[within seconds], automatically.
]
#v(2mm)

#key[
  #underline(stroke: 1pt + green)[Hot keys are a caching and decomposition problem, not a
  sharding problem.] Rebalancing, resharding and adding capacity all fail, because every one of
  them still routes a single key to a single owner. The fix is to stop that key from reaching the
  owner at all.
]
#v(2mm)

#h2("3 · SEM execution strategy", c: purple)

#text(size: 8.9pt)[
  #text(fill: purple, weight: "bold")[Make it automatic, because it is unpredictable.] The viral
  post is by definition the one nobody planned for. Automatic detection and promotion is the
  difference between a system that absorbs virality and one that pages someone every time it
  happens. Build the detector before you need it.

  #text(fill: purple, weight: "bold")[Blast radius.] A hot partition degrades
  #underline(stroke: 1pt + red)[every tenant or user on that shard], not just the celebrity.
  That is what makes it urgent: one account's popularity becomes thousands of unrelated users'
  outage. Per-shard saturation alerting catches it before the complaints do.

  #text(fill: purple, weight: "bold")[Pre-agree the approximation.] Product must accept, in
  advance, that counts on viral content may be seconds stale and slightly approximate. Obtaining
  that agreement during an incident is impossible; obtaining it in a design review takes five
  minutes. Frame it as #text(fill: green)["exact counts at the cost of the feature being
  unavailable under load, or approximate counts that always work."]

  #text(fill: purple, weight: "bold")[Rehearse with synthetic virality.] Load-test with a
  realistic power-law key distribution, not a uniform one. A uniform benchmark
  #underline(stroke: 1pt + red)[cannot reproduce this failure], which is exactly why it reaches
  production.

  #text(fill: purple, weight: "bold")[The architectural lesson.] Any system with user-generated
  popularity needs a hot-key strategy from the first design review. It is not an optimisation to
  add later; retrofitting it under incident pressure is how teams end up special-casing individual
  account ids in production code.
]
#v(2mm)

#anti("adding shards to fix a hot key")[
  The shard is overloaded, so the team doubles the shard count and rebalances — a multi-hour,
  risky operation under incident conditions. The hot key
  #text(fill: red, weight: "bold")[lands on exactly one of the new shards] and that shard is
  immediately overloaded, because the key's traffic was never divisible. Meanwhile the rebalance
  itself has moved terabytes, invalidated caches fleet-wide, and
  #underline(stroke: 1pt + red)[made the incident worse] while consuming the team's attention for
  hours. #text(fill: green)[Fix:] cache the key out of the data path and decompose contended
  counters. Resharding addresses uneven key #emph[distribution]; it can never address uneven
  traffic to a single key.
]
