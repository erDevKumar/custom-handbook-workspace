#import "/shared/lib/template.typ": *
#reg(1, "M5", "Multi-Tier Caching & Invalidation")
#chapterhead("Part 2 · Modules", "M5 · Multi-Tier Caching")
#ix("Cache-aside")
#ix("Cache stampede")
#ix("XFetch")
#ix("Write-behind")

#h1("M5 · Multi-Tier Caching & Invalidation", c: green)

#text[
  A cache is a #text(fill: purple, weight: "bold")[bet]: you trade freshness for latency and
  load. Every tier exists because the tier beneath it is too slow or too expensive to hit on
  every request. The design question is never "should we cache" --- it is
  #underline(stroke: 1pt + green)[what staleness can this read tolerate].
]
#v(2mm)

#h2("1 · The tiers, and what each one costs", c: blue)

#pfig("Fig M5.1 · read path across four tiers, and what each one costs")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.9, 2.6, "every cached key has a declared staleness budget; ETags issued; a single-flight lock exists for the miss path")

  ppill(1.55, 0, "in", "GET /feed", w: 2.8)
  pstep(5.5, 0, "cdn", "CDN edge", "TTL 60s · 15ms", st-integ, n: 1, actor: "edge", w: 3.6)
  pstep(10.6, 0, "l1", "L1 in-process", "LRU 10k · 0.05ms", st-auto, n: 2, actor: "service", w: 4.0)
  pdec(15.3, 0, "hit", "L2 hit?", w: 1.6)
  ppill(19.35, 0, "out", "response", w: 2.8)

  pstep(15.3, -4.0, "org", "origin read", "Postgres · 40ms", st-dec, n: 3, actor: "service", w: 4.4)

  line("in.east", "cdn.west", mark: (end: ">"), stroke: hot)
  line("cdn.east", "l1.west", mark: (end: ">"), stroke: hot)
  plabel(7.9, 0, "no 304", c: green)
  line("l1.east", "hit.west", mark: (end: ">"), stroke: lookup)
  plabel(13.2, 0, "Redis", c: green)
  line("hit.east", "out.west", mark: (end: ">"), stroke: hot)
  plabel(17.75, 0, "yes · 95%", c: green, dy: 0.62)
  line("hit.south", "org.north", mark: (end: ">"), stroke: miss)
  plabel(17.1, -2.1, "miss · 5%", c: red, dy: 0)
  content((6.4, -4.2), dlbl("hit-path budget: 15 + 0.05 + 1 = 16ms p50.\nThe miss path costs 56ms and is single-flighted,\nso one expired key cannot become a stampede.", sz: 6.5pt, c: purple))
  content((10.3, -6.4), dlbl("the origin read populates L1 and L2 on the way back, so the next reader of the same key pays 1ms rather than 56ms", sz: 6.5pt, c: blue))
}))
#pcards(
  [A staleness budget per key class; ETag/`If-None-Match` on the client; Redis `SET NX` for single-flight],
  [In: `GET /feed` · Out: body or `304`. 95% of reads never reach Postgres; the 5% that do cost 56ms],
  [CDN (TTL 60s) · in-process LRU · Redis Cluster, 6 shards · Postgres primary · XFetch probabilistic refresh],
)
#v(2mm)

#h2("2 · Caching patterns compared", c: purple)

#table(
  columns: (auto, 1fr, auto, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.5pt, fill: purple)[Pattern],
  text(font: headfont, size: 8.5pt, fill: purple)[Mechanism / cost],
  text(font: headfont, size: 8.5pt, fill: purple)[Stale risk],
  text(font: headfont, size: 8.5pt, fill: purple)[Use when],

  text(size: 8.3pt)[Cache-aside],
  text(size: 8pt)[App checks cache, loads DB on miss, populates. Simplest; first read always misses.],
  text(size: 8pt, fill: orange)[TTL window],
  text(size: 8pt)[default choice],

  text(size: 8.3pt)[Read-through],
  text(size: 8pt)[Cache itself loads on miss. App code is simpler; the cache needs DB access.],
  text(size: 8pt, fill: orange)[TTL window],
  text(size: 8pt)[uniform access],

  text(size: 8.3pt)[Write-through],
  text(size: 8pt)[Write hits cache and DB synchronously. Cache never stale; every write pays both.],
  text(size: 8pt, fill: green)[none],
  text(size: 8pt)[read-heavy, write-rare],

  text(size: 8.3pt)[Write-behind],
  text(size: 8pt)[Write to cache, flush to DB async. Fastest writes; #text(fill: red)[data loss if cache dies]],
  text(size: 8pt, fill: red)[durability],
  text(size: 8pt)[metrics, counters],

  text(size: 8.3pt)[Refresh-ahead],
  text(size: 8pt)[Proactively refresh hot keys before expiry. No miss penalty; wasted work on cold keys.],
  text(size: 8pt, fill: green)[low],
  text(size: 8pt)[predictable hot set],
)
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("Hit rate is a capacity dependency, not an optimisation")[
  #text(size: 8.6pt)[
    100M users, 20% DAU, 10 reads/day #sym.arrow.r 20,000,000 × 10 =
    #text(weight: "bold")[200M reads/day] #sym.arrow.r 200,000,000 / 86,400 =
    #text(fill: orange, weight: "bold")[2,315 QPS] average, ×3 peak =
    #text(fill: orange, weight: "bold")[7,000 QPS].
    #linebreak() #v(1mm)
    At #text(fill: green)[95%] hit rate: origin sees 0.05 × 7,000 =
    #text(fill: green, weight: "bold")[350 QPS] — one replica handles it.
    #linebreak()
    At #text(fill: red)[60%] hit rate: origin sees 0.40 × 7,000 =
    #text(fill: red, weight: "bold")[2,800 QPS] — an #text(weight: "bold")[8×] jump that takes
    the replica down.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Memory sizing:] 1M hot keys × 2 KB =
    #text(fill: orange, weight: "bold")[2 GB] working set. Add ~25% Redis overhead and headroom
    #sym.arrow.r provision #text(weight: "bold")[4 GB] per shard replica.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Cache stampede (dogpile).] A hot key expires; 5,000
  concurrent requests all miss and issue the same query. The DB saturates and every one of them
  times out --- including the request that would have refilled the cache.
  #text(fill: green)[Fix:] a per-key mutex so exactly one request refills, or
  #text(fill: purple, weight: "bold")[XFetch] probabilistic early expiry --- each reader rolls
  `now - delta × beta × log(rand())  >  expiry`, so refreshes desynchronise naturally.

  #text(fill: red, weight: "bold")[Thundering herd on deploy.] All pods restart with empty L1;
  the fleet hits L2 at once and whatever L2 misses reaches the DB simultaneously.
  #text(fill: green)[Fix:] stagger the rollout, pre-warm the top-N keys, and let L2 survive the
  deploy --- that is half the reason it exists.

  #text(fill: red, weight: "bold")[Hot key.] One key takes a disproportionate share of traffic
  and saturates its single Redis shard. #text(fill: green)[Fix:] replicate that key to an L1 in
  every pod, or salt it across N sub-keys.

  #text(fill: red, weight: "bold")[Redis unreachable.] Without a plan, every read blocks on a
  1ms call now taking 30s. #text(fill: green)[Fix:] short timeout, circuit breaker, fall through
  to origin at a reduced rate --- degraded, not down.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: How do you invalidate a cache?]
  #linebreak()
  TTL expiry (simple, bounded staleness), explicit delete on write (precise, but you must find
  every write path), or versioned keys (`user:42:v7` --- no deletion needed, old versions age
  out). #note[Testing: do you know TTL is a #underline(stroke: 1pt + green)[staleness budget]
  you chose, not a default you accepted? The strong answer names the product requirement first.]

  #text(fill: green, weight: "bold")[Q: What is a cache stampede and how do you prevent it?]
  #linebreak()
  Concurrent misses on one expiring hot key all hitting the DB. Prevent with a per-key refill
  lock or probabilistic early expiry. #note[Testing: whether you have operated a cache under
  load. The failure is counter-intuitive — the cache working correctly is what causes it.]

  #text(fill: green, weight: "bold")[Q: Why have both L1 and L2?]
  #linebreak()
  L1 removes the network hop entirely (0.05ms vs 1ms) but is per-pod and small; L2 is shared, so
  one fill serves the fleet and survives deploys. #note[Testing: can you justify the added
  complexity with numbers rather than "it's faster"?]
]
#v(2mm)

#anti("caching without a staleness budget")[
  Teams add Redis because reads are slow, then discover the product cannot tolerate
  #text(fill: red)[60-second stale] balances. Decide the budget
  #underline(stroke: 1pt + green)[first]: a price ticker tolerates 1s; a wallet balance
  tolerates #text(fill: red)[0ms] and must read the primary. The staleness budget selects the
  tier --- not the other way round.
]
