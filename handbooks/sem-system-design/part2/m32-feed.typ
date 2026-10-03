#import "/shared/lib/template.typ": *
#reg(1, "M32", "Social Graph & Feed Architecture")
#chapterhead("Part 2 · Modules", "M32 · Feed & Timeline")
#ix("Fan-out on write")
#ix("Fan-out on read")
#ix("Cursor pagination")

#h1("M32 · Social Graph & Feed Architecture", c: blue)

#text[
  A feed is a ranked merge of content from everyone you follow, and it must render in under a
  second for someone following two thousand accounts. The entire design space reduces to one
  question: do you compute the feed when content is #underline(stroke: 1pt + green)[written], or
  when it is #underline(stroke: 1pt + green)[read]?
]
#v(2mm)

#h2("1 · Fan-out on write vs. on read", c: blue)

#pfig("Fig M32.1 · one post through the hybrid fan-out, and where the celebrity path forks")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.4, 20.6, 2.9, "follower counts materialised and current · timelines hold post ids only, never bodies · sorted sets capped by ZREMRANGEBYRANK")

  ppill(2.2, 0, "in", "user posts", w: 3.4)
  pstep(7.2, 0, "a", "persist the post", "Postgres · 1 insert", st-auto, n: 1, actor: "post svc", w: 4.6)
  pdec(12.2, 0, "d", "> 100k followers?", w: 2.6)
  pstep(17.6, 0, "b", "fan-out worker", "~200 ZADDs · 2M/s fleet", st-auto, n: 2, actor: "push path", w: 5.0)
  pstep(17.6, -3.4, "c", "merge at read", "~21 lookups · all cached", st-man, n: 3, actor: "", w: 5.0)
  ppill(10.4, -3.4, "out", "ranked timeline page", c: green, w: 5.0)
  pstep(4.2, -3.4, "x", "no fan-out at all", "1 insert, not 50M", st-dec, n: 4, actor: "", w: 4.8)

  line("in.east", "a.west", mark: (end: ">"), stroke: hot)
  line("a.east", "d.west", mark: (end: ">"), stroke: hot)
  line("d.east", "b.west", mark: (end: ">"), stroke: hot)
  plabel(14.3, 0, "no", c: green, dy: 0.62)
  line("b.south", "c.north", mark: (end: ">"), stroke: lookup)
  plabel(18.6, -1.8, "read time", c: green, dy: 0.0)
  line("c.west", "out.east", mark: (end: ">"), stroke: hot)
  plabel(14.2, -3.4, "cursor", c: purple)
  line("d.south", (12.2, -1.9), (4.2, -1.9), "x.north", mark: (end: ">"), stroke: except)
  plabel(8.4, -1.9, "yes — celebrity", c: red, dy: -0.45)
  line("x.east", "out.west", mark: (end: ">"), stroke: miss)
  plabel(7.3, -3.4, "merged in", c: red, dy: -0.5)
  content((4.6, -5.4), dlbl("pure push: one 50M-follower post = 8 minutes of fan-out,\nand every other user's posts queue behind it", sz: 6.5pt, c: red))
}))
#pcards(
  [Follower counts current enough to classify an account on every post. Timelines store post ids only — a deleted post must vanish from 200,000 copies at once.],
  [In: one post plus the author's follower count. Out: ZADDs into ordinary followers' lists, or nothing at all for a celebrity, merged back in at read.],
  [Postgres for posts · Redis sorted sets, 100M × 800 entries ≈ 1.28 TB · Kafka-driven fan-out workers · opaque base64 cursors, never OFFSET],
)
#v(1.5mm)

#table(
  columns: (auto, auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#eef4fb") } else { none },
  text(font: headfont, size: 8.5pt, fill: blue)[],
  text(font: headfont, size: 8.5pt, fill: blue)[Write cost],
  text(font: headfont, size: 8.5pt, fill: blue)[Read cost],
  text(font: headfont, size: 8.5pt, fill: blue)[Breaks when],

  text(size: 8.3pt)[On write (push)],
  text(size: 8.3pt, fill: red)[O(followers)],
  text(size: 8.3pt, fill: green)[O(1)],
  text(size: 8pt, fill: red)[A celebrity posts — 50M inserts for one action],

  text(size: 8.3pt)[On read (pull)],
  text(size: 8.3pt, fill: green)[O(1)],
  text(size: 8.3pt, fill: red)[O(following)],
  text(size: 8pt, fill: red)[A user follows 5,000 accounts — 5,000 lookups per refresh],

  text(size: 8.3pt, fill: green)[Hybrid],
  text(size: 8.3pt, fill: green)[O(normal followers)],
  text(size: 8.3pt, fill: green)[O(celebrities followed)],
  text(size: 8pt, fill: green)[Nothing — this is what production systems run],
)
#v(1.5mm)

#key[
  #text(fill: green, weight: "bold")[The hybrid is the answer, and the threshold is the design.]
  Push to followers for ordinary accounts; for accounts above a follower threshold, do not fan
  out at all --- pull their posts at read time and merge. A user's timeline becomes
  #underline(stroke: 1pt + green)[their precomputed list merged with the handful of celebrities
  they follow]. Both pathological cases disappear.
]
#v(2mm)

#h2("2 · Capacity arithmetic", c: orange)

#formula("Why pure push dies, and what the hybrid costs")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Pure push:] average 200 followers, 10,000 posts/s #sym.arrow.r
    10,000 × 200 = #text(fill: orange, weight: "bold")[2M timeline inserts/s]. Already large but
    tractable with sharded Redis.
    #linebreak()
    #text(fill: red, weight: "bold")[The celebrity:] one account with 50M followers posts once
    #sym.arrow.r #text(fill: red, weight: "bold")[50M inserts] for a single action. At 100k
    inserts/s that is #text(fill: red, weight: "bold")[8 minutes] of fan-out — during which some
    followers have the post and others do not, and the write queue is saturated for everyone else.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Hybrid with a 100k-follower threshold:] perhaps 0.01% of accounts
    qualify. Their posts cost #text(fill: green, weight: "bold")[1 insert] each; a reader merges
    their own precomputed list with ~20 celebrity lookups
    #sym.arrow.r #text(fill: green, weight: "bold")[~21 reads] per refresh, all cached.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Storage:] 100M users × 800 timeline entries × 16 B (post id + score) =
    #text(fill: orange, weight: "bold")[1.28 TB] in Redis sorted sets. Cap the list — nobody
    scrolls past a few hundred items, and older content can be served by pull.
  ]
]
#v(2mm)

#h2("3 · Cursor pagination, not offsets", c: purple)

#text(size: 9pt)[
  A feed is a list that grows at the head, so `OFFSET 20` is wrong the moment a new post arrives
  --- the user sees a duplicate or misses an item. #text(fill: green, weight: "bold")[Opaque
  cursors] encode the sort position (`score + id`, base64-encoded) and the query becomes
  `WHERE (score, id) < (cursor)`, which is both correct under concurrent inserts and
  index-friendly.
  #note[Make the cursor #underline(stroke: 1pt + green)[opaque] — a base64 blob, not a visible
  timestamp. Clients that parse a cursor will depend on its format, and you can never change the
  sort order again. Keep the sort key stable and unique (score plus a tiebreaker id), or
  pagination skips rows when scores tie.]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[The celebrity write storm.] Covered above; without a hybrid it
  saturates the fan-out tier and delays every other user's posts.
  #text(fill: green)[Fix:] threshold-based pull for large accounts.

  #text(fill: red, weight: "bold")[Timeline rebuild on follow.] A user follows 500 accounts in
  one session and each triggers a backfill of their timeline.
  #text(fill: green)[Fix:] backfill asynchronously and incrementally; show the merged pull result
  immediately while the push list warms.

  #text(fill: red, weight: "bold")[Deleted content lingering.] A post is deleted but already sits
  in 200,000 precomputed timelines. #text(fill: green)[Fix:] store only
  #underline(stroke: 1pt + green)[post ids] in timelines and hydrate content at read time, so a
  deleted post vanishes everywhere at once. Never denormalise post bodies into timelines.

  #text(fill: red, weight: "bold")[Unbounded timeline growth.] Sorted sets grow forever and Redis
  memory becomes the constraint. #text(fill: green)[Fix:] `ZREMRANGEBYRANK` to cap each list at a
  few hundred entries; serve deeper history from the database by cursor.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Design Twitter's timeline.]
  #linebreak()
  Hybrid fan-out: push to ordinary followers into per-user Redis sorted sets, pull for accounts
  above a follower threshold, merge at read, hydrate content by id, paginate by opaque cursor.
  #note[Testing: do you reach the hybrid #underline(stroke: 1pt + green)[and name the threshold
  as the key parameter]? Pure push or pure pull both fail on a named case.]

  #text(fill: green, weight: "bold")[Q: Why not `OFFSET` for pagination?]
  #linebreak()
  The list shifts as new posts arrive, producing duplicates and gaps, and deep offsets scan
  everything skipped. #note[Testing: correctness, not just performance — the duplicate is the
  user-visible bug.]

  #text(fill: green, weight: "bold")[Q: Store post content or post ids in the timeline?]
  #linebreak()
  Ids, hydrated at read. Denormalised content cannot be edited or deleted consistently across
  millions of copies. #note[Testing: whether you anticipate deletion and editing, which is where
  denormalisation becomes unrecoverable.]
]
#v(2mm)

#anti("pure fan-out-on-write at any scale")[
  The design is elegant: every post is pushed into each follower's timeline, so reads are a single
  lookup. It performs beautifully in testing, where the largest test account has 500 followers.
  Then a celebrity with 50M followers posts, and one action becomes
  #text(fill: red, weight: "bold")[50 million writes]. The fan-out queue backs up for minutes,
  #underline(stroke: 1pt + red)[every other user's posts are delayed behind it], and the same
  account posting five times in a minute makes the backlog unrecoverable.
  #text(fill: green)[Fix:] a follower threshold above which accounts are never fanned out, and a
  read-time merge of those accounts. The threshold is a tuning parameter you will revisit; the
  hybrid structure is not optional.
]
