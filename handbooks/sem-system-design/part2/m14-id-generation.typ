#import "/shared/lib/template.typ": *
#reg(1, "M14", "Globally Unique ID Generation")
#chapterhead("Part 2 · Modules", "M14 · Unique ID Generation")
#ix("Snowflake ID")
#ix("UUIDv7")
#ix("ULID")

#h1("M14 · Globally Unique ID Generation", c: blue)

#text[
  An ID scheme looks trivial until it is in a billion rows and a hundred clients. The three
  properties in tension are #text(fill: green, weight: "bold")[uniqueness without
  coordination], #text(fill: orange, weight: "bold")[sortability], and
  #text(fill: purple, weight: "bold")[index locality] --- and the last one is the property
  teams discover too late.
]
#v(2mm)

#h2("1 · The options", c: blue)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  content((8.8, 2.9), dlbl("SNOWFLAKE — 64 bits", sz: 8pt, c: blue))
  let seg(x1, x2, lbl, bits, c) = {
    rect((x1, 1.6), (x2, 2.4), stroke: 1.2pt + c, fill: white)
    content(((x1 + x2) / 2, 2.15), dlbl(lbl, sz: 6.4pt, c: ink))
    content(((x1 + x2) / 2, 1.82), dlbl(bits, sz: 5.8pt, c: c))
  }
  seg(0.6, 2.0, "sign", "1", luma(140))
  seg(2.0, 9.4, "timestamp (ms since epoch)", "41 bits", orange)
  seg(9.4, 12.6, "machine id", "10 bits", blue)
  seg(12.6, 16.8, "sequence", "12 bits", green)
  content((5.7, 1.1), dlbl("~69 years of ms", sz: 6.2pt, c: orange))
  content((11.0, 1.1), dlbl("1,024 nodes", sz: 6.2pt, c: blue))
  content((14.7, 1.1), dlbl("4,096 per ms per node", sz: 6.2pt, c: green))
  bracket(0.6, 16.8, 0.3, "time-ordered prefix -> new rows append to the right of a B-tree", purple)
}))
#v(2mm)

#table(
  columns: (auto, auto, auto, auto, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#eef4fb") } else { none },
  text(font: headfont, size: 8.5pt, fill: blue)[Scheme],
  text(font: headfont, size: 8.5pt, fill: blue)[Size],
  text(font: headfont, size: 8.5pt, fill: blue)[Sortable],
  text(font: headfont, size: 8.5pt, fill: blue)[Coord.],
  text(font: headfont, size: 8.5pt, fill: blue)[Notes],

  text(size: 8.3pt)[Auto-increment],
  text(size: 8.3pt)[8 B], text(size: 8.3pt, fill: green)[yes], text(size: 8.3pt, fill: red)[DB],
  text(size: 8pt, fill: red)[Single point of allocation; leaks row counts; breaks on sharding],

  text(size: 8.3pt)[UUIDv4],
  text(size: 8.3pt)[16 B], text(size: 8.3pt, fill: red)[no], text(size: 8.3pt, fill: green)[none],
  text(size: 8pt, fill: red)[Random — destroys B-tree locality. The default that hurts],

  text(size: 8.3pt, fill: green)[UUIDv7],
  text(size: 8.3pt)[16 B], text(size: 8.3pt, fill: green)[yes], text(size: 8.3pt, fill: green)[none],
  text(size: 8pt, fill: green)[ms timestamp + randomness. Standard (RFC 9562). Prefer this],

  text(size: 8.3pt)[ULID],
  text(size: 8.3pt)[16 B], text(size: 8.3pt, fill: green)[yes], text(size: 8.3pt, fill: green)[none],
  text(size: 8pt)[Same idea, base32 text form. Pre-dates v7],

  text(size: 8.3pt)[Snowflake],
  text(size: 8.3pt)[8 B], text(size: 8.3pt, fill: green)[yes], text(size: 8.3pt, fill: orange)[node id],
  text(size: 8pt)[Compact and ordered; needs node-id assignment and clock discipline],
)
#v(2mm)

#key[
  #text(fill: red, weight: "bold")[UUIDv4 as a primary key is the expensive mistake.] Random
  values scatter inserts across the whole index, so every insert dirties a different page and
  the working set becomes the entire index rather than its right edge. On a billion-row table
  this is the difference between a cached hot page and a disk read per insert.
  #underline(stroke: 1pt + green)[UUIDv7 fixes it without giving up decentralised generation.]
]
#v(2mm)

#h2("2 · Capacity and collision arithmetic", c: orange)

#formula("Throughput, and when collisions matter")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Snowflake ceiling:] 4,096 ids/ms/node × 1,000 ms =
    #text(fill: orange, weight: "bold")[4.096M ids/s per node], × 1,024 nodes =
    #text(weight: "bold")[4.2 billion/s]. The sequence is the real limit — exceed 4,096 in one
    millisecond and the generator must #underline(stroke: 1pt + green)[block until the next ms].
    #linebreak() #v(1mm)
    #text(weight: "bold")[41-bit ms timestamp:] 2⁴¹ ms = 2.2 × 10¹² ms ≈
    #text(fill: orange, weight: "bold")[69.7 years] from your chosen epoch. Pick the epoch
    deliberately and write it down — it is a 70-year decision.
    #linebreak() #v(1mm)
    #text(weight: "bold")[UUIDv4 collision (birthday bound):] 122 random bits, 50% collision at
    √(2¹²²) ≈ #text(fill: green, weight: "bold")[2.3 × 10¹⁸] ids. Collision is
    #underline(stroke: 1pt + green)[not] the reason to avoid v4 — index locality is.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Index cost, measured:] inserting 10M rows with a random key touches
    ~10M distinct pages; with a time-ordered key it touches the rightmost page repeatedly. On a
    16 GB buffer pool the first is #text(fill: red, weight: "bold")[I/O-bound], the second is
    memory-bound.
  ]
]
#v(2mm)

#h2("3 · The offline client problem", c: purple)

#text(size: 9pt)[
  A mobile client creating a record offline cannot ask the server for an id. Two viable
  approaches. #text(fill: green, weight: "bold")[Client-generated UUIDv7] --- the client mints
  the real id and the server accepts it, which makes the create operation naturally idempotent
  (a retry carries the same id and upserts). #text(fill: orange, weight: "bold")[Temporary
  local id] --- the client uses a negative or prefixed id, the server assigns the real one, and
  the client rewrites local references on sync.
  #note[Prefer client-generated ids. Temporary-id remapping means every foreign key written
  while offline must be rewritten on reconnect, and anything that escaped the device in the
  meantime — an analytics event, a crash report, a shared link — now references an id that no
  longer exists.]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Clock moves backwards.] NTP corrects a Snowflake node's clock
  backwards and it begins reissuing ids already used.
  #text(fill: green)[Fix:] persist the last-issued timestamp; if `now < last`,
  #underline(stroke: 1pt + green)[refuse to issue] until the clock catches up. Fail loudly ---
  silently issuing duplicates corrupts data that looks fine.

  #text(fill: red, weight: "bold")[Duplicate node ids.] Two instances get the same machine id
  from a stale config or a reused container index, so both emit identical ids at the same
  millisecond. #text(fill: green)[Fix:] allocate node ids from a coordination service (etcd,
  ZooKeeper) with a lease, never from a config file or a pod ordinal that can repeat.

  #text(fill: red, weight: "bold")[Sequential ids leak business data.] `/orders/10452` tells a
  competitor your order count, and tomorrow's increment tells them your daily volume.
  #text(fill: green)[Fix:] never expose sequential internal ids externally — use a separate
  opaque public identifier.

  #text(fill: red, weight: "bold")[Enumeration attacks.] Sequential ids let an attacker walk
  your entire dataset. #text(fill: green)[Fix:] unguessable external ids
  #underline(stroke: 1pt + red)[plus] per-object authorisation. The id is not the access
  control.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Why not UUIDv4 for a primary key?]
  #linebreak()
  Randomness destroys B-tree insert locality: every insert lands on a different page, so the
  working set becomes the whole index. Use UUIDv7. #note[Testing: do you say "collisions"? That
  is the wrong answer — v4 collisions are negligible. The real cost is I/O.]

  #text(fill: green, weight: "bold")[Q: Design an ID generator for 1M ids/second.]
  #linebreak()
  Snowflake: timestamp + node id + sequence, node ids leased from etcd, clock-regression guard,
  sequence rollover blocking to the next millisecond. #note[Testing: whether you handle clock
  regression unprompted — it is the failure that silently corrupts.]

  #text(fill: green, weight: "bold")[Q: How does a client create records offline?]
  #linebreak()
  Client-generated UUIDv7, which doubles as the idempotency key for the create.
  #note[Testing: the link between id generation and idempotency. They are the same problem seen
  from two directions.]
]
#v(2mm)

#anti("exposing auto-increment ids in a public API")[
  `GET /api/users/1042` tells anyone that you have roughly 1,042 users; polling it daily gives
  your growth rate. Worse, a missing authorisation check turns the sequence into a
  #text(fill: red, weight: "bold")[complete data export] — an attacker simply counts upward.
  This is consistently among the most-exploited API flaws in the wild.
  #text(fill: green)[Fix:] opaque external ids (UUIDv7 or a hashed alias) and object-level
  authorisation on every request. Treat #underline(stroke: 1pt + red)[guessability and
  permission as separate concerns] — unguessable ids are obfuscation, not security.
]
