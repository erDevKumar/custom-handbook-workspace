#import "/shared/lib/template.typ": *
#reg(1, "M8", "Event Streaming & Consumer Groups")
#chapterhead("Part 2 · Modules", "M8 · Event Streaming Internals")
#ix("Kafka partitions")
#ix("Consumer group")
#ix("ISR")
#ix("Exactly-once")

#h1("M8 · Event Streaming Internals", c: orange)

#text[
  A queue deletes a message once it is consumed. A #text(fill: orange, weight: "bold")[log] does
  not --- it keeps an ordered, immutable sequence and each consumer tracks its own position.
  That single difference is why Kafka supports replay, multiple independent consumers, and
  recovery from a bad deploy, and why it is not a drop-in replacement for a task queue.
]
#v(2mm)

#h2("1 · Partitions, offsets, consumer groups", c: blue)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  swimlane(-0.4, -1.3, 18.4, 3.0, "TOPIC: orders — 4 partitions", orange, rgb("#fdf7f2"))

  // partitions as segmented logs
  for (i, y) in ((0, 2.0), (1, 1.1), (2, 0.2), (3, -0.7)).enumerate() {
    let py = y.at(1)
    let pi = y.at(0)
    content((1.2, py), dlbl("P" + str(pi), sz: 7pt, c: orange))
    for k in range(7) {
      rect((2.2 + k * 1.0, py - 0.28), (3.1 + k * 1.0, py + 0.28),
        stroke: 0.8pt + luma(150), fill: if k < 5 { rgb("#fdece0") } else { white })
    }
    content((9.9, py), dlbl("→", sz: 8pt, c: luma(150)))
  }
  content((5.6, 2.75), dlbl("append-only · ordered WITHIN a partition · never deleted on read",
    sz: 6.4pt, c: purple))
  content((7.2, -1.05), dlbl("committed offset", sz: 6pt, c: green))

  rnode(13.8, 2.0, "c1", "consumer 1", "P0, P1", green, w: 3.4, h: 0.8)
  rnode(13.8, 0.65, "c2", "consumer 2", "P2", green, w: 3.4, h: 0.8)
  rnode(13.8, -0.7, "c3", "consumer 3", "P3", green, w: 3.4, h: 0.8)
  content((16.8, 0.65), dlbl("group A", sz: 6.5pt, c: green))
  content((13.8, -1.6), dlbl("one partition → at most ONE consumer in a group", sz: 6.4pt, c: red))
}))
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: blue, weight: "bold")[Ordering is per partition, never per topic.] Events land in
  a partition by `hash(key) % partitions`. All events for one `order_id` are ordered;
  two different orders have no relative ordering at all. If your logic needs ordering, the
  ordering key #underline(stroke: 1pt + green)[is] your partition key --- choose it first.

  #text(fill: green, weight: "bold")[Consumer groups] divide partitions among members. Adding a
  consumer beyond the partition count buys nothing: the extra sits
  #text(fill: red)[idle]. Partition count is therefore your
  #underline(stroke: 1pt + red)[maximum parallelism], and it is awkward to increase later
  because it rehashes keys to different partitions and breaks ordering across the change.

  #text(fill: purple, weight: "bold")[Zero-copy.] Brokers send segment bytes straight from page
  cache to socket via `sendfile(2)`, never copying into user space. This is why a broker can
  saturate a NIC on modest CPU --- and why anything that forces deserialisation on the broker
  (some transformations, SSL without kernel offload) collapses that advantage.
]
#v(2mm)

#h2("2 · Delivery guarantees", c: purple)

#table(
  columns: (auto, auto, 1fr, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.5pt, fill: purple)[Guarantee],
  text(font: headfont, size: 8.5pt, fill: purple)[Mechanism],
  text(font: headfont, size: 8.5pt, fill: purple)[Cost / caveat],
  text(font: headfont, size: 8.5pt, fill: purple)[Use],

  text(size: 8.3pt)[At-most-once],
  text(size: 8pt)[Commit offset #emph[before] processing],
  text(size: 8pt, fill: red)[Crash = message lost],
  text(size: 8pt)[metrics],

  text(size: 8.3pt)[At-least-once],
  text(size: 8pt)[Commit #emph[after] processing],
  text(size: 8pt, fill: orange)[Duplicates on retry — consumer must be idempotent],
  text(size: 8pt, fill: green)[default],

  text(size: 8.3pt)[Exactly-once],
  text(size: 8pt)[Idempotent producer + transactions],
  text(size: 8pt, fill: red)[Only within Kafka. A side effect outside it is still at-least-once],
  text(size: 8pt)[stream joins],
)
#v(2mm)

#key[
  "Exactly-once" means #underline(stroke: 1pt + green)[exactly-once state update inside Kafka],
  not exactly-once delivery to the outside world. The moment your consumer charges a card or
  sends an email, you are back to at-least-once and you need an
  #text(fill: orange, weight: "bold")[idempotency key]. Claiming otherwise in an interview is a
  tell.
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("Partition count and retention, worked")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Throughput:] target 50,000 events/s; one consumer handles 5,000/s
    #sym.arrow.r need #text(fill: orange, weight: "bold")[10 partitions] minimum. Add headroom
    for a slow consumer and future growth #sym.arrow.r provision
    #text(fill: green, weight: "bold")[24] (divisible by many consumer counts).
    #linebreak() #v(1mm)
    #text(weight: "bold")[Storage:] 50,000/s × 1 KB × 86,400 =
    #text(weight: "bold")[4.3 TB/day] raw. ×3 replication = #text(weight: "bold")[13 TB/day].
    At 7-day retention #sym.arrow.r #text(fill: red, weight: "bold")[91 TB] of broker disk.
    #linebreak()
    #note[Retention is a cost decision, not a default. 7 days of replay capability on a 50k/s
    topic is 91 TB; 1 day is 13 TB. Ask what replay window the business actually needs.]
    #linebreak() #v(1mm)
    #text(weight: "bold")[Consumer lag budget:] if a consumer falls behind by 10 minutes at
    50,000/s, it must process #text(fill: red, weight: "bold")[30M backlogged events] to catch
    up — at 5,000/s per consumer that is 100 minutes with the full group. Lag recovery is
    #underline(stroke: 1pt + red)[asymmetric]; falling behind is far faster than catching up.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Rebalance storms.] A consumer misses a heartbeat, the group
  rebalances, partitions are reassigned, in-flight work is lost and reprocessed --- which makes
  the next heartbeat late, triggering another rebalance.
  #text(fill: green)[Fix:] `max.poll.interval.ms` above your worst-case processing time,
  cooperative sticky assignment so only moving partitions pause, and static membership so a pod
  restart does not trigger a full reshuffle.

  #text(fill: red, weight: "bold")[ISR shrink and silent data loss.] A replica falls behind and
  leaves the in-sync set. With `acks=1` the leader acknowledges alone; if it then dies, those
  writes are gone. #text(fill: green)[Fix:] `acks=all` with
  `min.insync.replicas=2` on a replication factor of 3 — writes fail loudly rather than
  disappearing quietly.

  #text(fill: red, weight: "bold")[Hot partition.] One key --- a single large merchant ---
  dominates traffic, so one partition and therefore one consumer is saturated while the rest
  idle. #text(fill: green)[Fix:] composite key, or route that tenant to a dedicated topic.

  #text(fill: red, weight: "bold")[Poison message.] One unparseable event fails forever, the
  offset never advances, and the partition stalls behind it.
  #text(fill: green)[Fix:] a retry topic with a bounded attempt count, then a
  #text(fill: purple)[dead-letter topic], and alert on DLQ depth — a silent DLQ is just a slower
  data-loss bug.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Kafka or RabbitMQ?]
  #linebreak()
  Kafka for an ordered, replayable log with many independent consumers and high throughput;
  RabbitMQ for per-message routing, priorities and acknowledgement semantics on individual
  tasks. #note[Testing: do you know Kafka is a #underline(stroke: 1pt + green)[log], not a
  queue? "Do you need to replay, and do multiple teams need the same stream?" is the question
  that decides it.]

  #text(fill: green, weight: "bold")[Q: How many partitions should a topic have?]
  #linebreak()
  Enough for target throughput ÷ per-consumer throughput, plus headroom — increasing later
  rehashes keys and breaks ordering across the change.
  #note[Testing: whether you know the decision is hard to reverse. Over-provisioning modestly is
  cheap; under-provisioning is a migration.]

  #text(fill: green, weight: "bold")[Q: How do you guarantee ordering?]
  #linebreak()
  Only within a partition, so the entity you need ordered must be the partition key. Global
  ordering needs a single partition, which caps you at one consumer.
  #note[Testing: do you recognise that global ordering and parallelism are mutually exclusive?
  Candidates often promise both.]
]
#v(2mm)

#anti("using Kafka as a task queue")[
  A team puts jobs on a topic and expects per-message retry, priorities and individual
  acknowledgement. Kafka has none of those: offsets advance
  #underline(stroke: 1pt + red)[in order], so one slow or failing job blocks every message
  behind it in that partition. Workarounds pile up — retry topics, offset juggling, manual
  commits — rebuilding a worse queue on top of a log. #text(fill: green)[Fix:] use a queue
  (SQS, RabbitMQ, Temporal) for task dispatch; use Kafka when you need an ordered, replayable
  event history that several consumers read independently.
]
