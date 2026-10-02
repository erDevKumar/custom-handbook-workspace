#import "/shared/lib/template.typ": *
#reg(1, "S13", "Distributed timer firing millions of actions")
#chapterhead("Part 3 · Interview Scenarios", "S13 · Distributed Scheduler")

#h1("S13 · A Distributed Timer at Scale", c: purple)

#text[
  #text(fill: purple, weight: "bold")[The prompt.] Millions of discrete scheduled actions ---
  reminders, payment retries, auction closes, trial expiries --- must fire with sub-second
  accuracy. Some are scheduled a year out, some ten seconds out, and a million may be due in the
  same second.
]
#v(2mm)

#h2("1 · The dilemma and its root cause", c: red)

#text(size: 9pt)[
  The obvious design --- a table of due times polled every second --- fails on two axes at once.
  The #underline(stroke: 1pt + red)[query] (`WHERE fire_at <= now()`) scans a growing index on
  every tick, and the #underline(stroke: 1pt + red)[claim] (marking rows as taken so two workers
  do not both fire) serialises on the same hot rows.

  #text(fill: purple, weight: "bold")[Root cause.] Treating "what is due now" as a
  #emph[query] rather than as a #emph[data structure]. Timers have strong temporal locality:
  almost everything due in the next minute is irrelevant to everything due next year, and the
  storage layout should reflect that.
]
#v(2mm)

#formula("Why polling collapses, and what time-bucketing fixes")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Naive poll:] 50M pending timers, poll every second.
    `SELECT ... WHERE fire_at <= now() AND claimed = false` touches an index of 50M entries
    #underline(stroke: 1pt + red)[every second] — 86,400 scans/day over a growing index, plus
    update contention on claim.
    #linebreak() #v(1mm)
    #text(fill: green, weight: "bold")[Time-bucketed:] partition by the minute the timer is due.
    `timers:2026-10-02T14:33`. The poll reads #underline(stroke: 1pt + green)[one bucket] — the
    current minute — regardless of how many timers exist in total. 50M pending becomes
    irrelevant to the hot path.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Two-tier for accuracy:] a minute bucket gives minute granularity. Load
    the due minute into an #text(fill: purple)[in-memory timer wheel] a few seconds early and
    fire from there with millisecond precision.
    #linebreak() #v(1mm)
    #text(weight: "bold")[The thundering second:] 1M timers due at exactly 09:00:00 (everyone
    scheduled "9am"). At 10,000 fires/s that is #text(fill: red, weight: "bold")[100 seconds] to
    drain. #text(fill: green)[Fix:] jitter at schedule time — spread "9am" reminders across
    09:00:00–09:02:00 — or accept and publish the drain window. Round-number scheduling is a
    human habit that becomes a load spike.
  ]
]
#v(2mm)

#h2("2 · The design", c: green)

#align(center, cetz.canvas(length: 0.8cm, {
  import cetz.draw: *
  swimlane(-0.4, -1.6, 18.4, 2.1, "BUCKETED STORAGE → TIMER WHEEL → AT-LEAST-ONCE FIRE", purple,
    rgb("#f5eefa"))
  cylinder(2.6, 1.1, "db", "bucketed store", purple, w: 4.0, h: 1.1)
  content((2.6, 0.2), dlbl("key: minute · sharded", sz: 6.2pt, c: purple))
  rnode(7.8, 1.1, "ld", "loader", "pre-fetch T-10s", blue, w: 3.4, h: 0.95)
  rnode(12.4, 1.1, "wh", "timer wheel", "in-memory, ms accurate", green, w: 4.4, h: 0.95)
  rnode(16.8, 1.1, "q", "execution queue", "at-least-once", orange, w: 3.4, h: 0.95)
  line("db.east", "ld.west", mark: (end: ">"), stroke: hot); badge(5.7, 1.65, "1", green)
  line("ld.east", "wh.west", mark: (end: ">"), stroke: hot);  badge(10.3, 1.65, "2", green)
  line("wh.east", "q.west", mark: (end: ">"), stroke: hot);   badge(14.8, 1.65, "3", green)
  content((9.0, -0.6), dlbl("the wheel is a CACHE — losing a node loses nothing, the bucket is durable",
    sz: 6.6pt, c: green))
  content((9.0, -1.25), dlbl("fire = enqueue, never execute inline. Slow handlers must not delay the clock",
    sz: 6.5pt, c: red))
}))
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: green, weight: "bold")[Firing means enqueueing, never executing.] The scheduler's
  only job is to put a message on a queue at the right moment. If it executes the action inline, a
  slow handler delays every subsequent timer and the clock itself becomes unreliable. This
  separation also makes the scheduler trivially horizontally scalable.

  #text(fill: green, weight: "bold")[At-least-once, with idempotent handlers.] A node may fire and
  die before recording the fire. Accept duplicates and require handlers to deduplicate on the
  timer id (S4) — exactly-once firing across a distributed system is the same impossibility as
  exactly-once delivery.

  #text(fill: purple, weight: "bold")[Shard buckets by hash so no single minute is one hot key.]
  `timers:14:33:shard-7` lets twelve workers drain one busy minute in parallel. Without this, the
  thundering second becomes a thundering single-partition (S11).

  #text(fill: orange, weight: "bold")[Cancellation is a tombstone, not a delete.] A timer may
  already be loaded into a wheel when it is cancelled, so the check happens
  #underline(stroke: 1pt + green)[at fire time] against a cancellation set — otherwise cancelled
  reminders still arrive.
]
#v(2mm)

#key[
  Sub-second accuracy and a billion pending timers are not in tension once you
  #underline(stroke: 1pt + green)[separate storage from scheduling]. Durable buckets handle scale
  and survive restarts; a small in-memory wheel handles precision for the next few seconds. Each
  structure does the one thing it is good at.
]
#v(2mm)

#h2("3 · SEM execution strategy", c: purple)

#text(size: 8.9pt)[
  #text(fill: purple, weight: "bold")[Define accuracy as an SLO, per class.] Not everything needs
  sub-second: #text(fill: green)["payment retries within 1 s, marketing reminders within 60 s,
  trial expiries within 5 min."] Most timers are the cheap kind, and admitting that lets you give
  the expensive guarantee only where it is paid for.

  #text(fill: purple, weight: "bold")[Build vs buy, stated honestly.] Temporal (M33), a cloud
  scheduler, or Quartz may cover this entirely. Build only when scale or latency genuinely
  exceeds them — and say so in the interview. #note[The senior answer names the managed option
  first, then the specific requirement that rules it out. Reaching straight for a custom
  distributed scheduler signals the instinct this handbook keeps warning about.]

  #text(fill: purple, weight: "bold")[Blast radius.] The scheduler is tier-0 for everything that
  depends on it. A bug that fires every timer at once is a
  #underline(stroke: 1pt + red)[self-inflicted DDoS against your own downstream services] —
  cap the fire rate globally and per tenant, and make that cap a hard limit rather than a
  configuration nobody checks.

  #text(fill: purple, weight: "bold")[Monitor the right number.] Not throughput —
  #text(weight: "bold")[firing delay] (fired_at − scheduled_at) at p50, p99 and max. A rising
  p99 delay is the only early warning that the loader is falling behind, and it precedes visible
  failure by minutes.

  #text(fill: purple, weight: "bold")[Rehearse the recovery.] If the service is down for ten
  minutes, millions of timers come due during the gap. On restart it must drain the backlog
  #underline(stroke: 1pt + green)[at a throttled rate], not fire everything instantly. Test that
  path deliberately; it is the behaviour that turns a brief outage into a downstream catastrophe.
]
#v(2mm)

#anti("polling a jobs table every second")[
  `SELECT * FROM jobs WHERE run_at <= NOW() AND status = 'pending' LIMIT 100` on a loop. It works
  beautifully with 10,000 rows. At 50 million it scans a vast index every second, the `UPDATE ...
  SET status = 'running'` serialises every worker on the same hot rows, and adding workers
  #underline(stroke: 1pt + red)[reduces] throughput through lock contention (M22). The database
  that also serves production traffic now spends its I/O budget on a polling loop, and the
  symptom presents as unrelated application slowness.
  #text(fill: green)[Fix:] bucket by due time so the query touches only the current window, shard
  the buckets, and fire from an in-memory wheel. The polling table is the right answer at small
  scale and an architectural dead end at large scale — know which you are building for.
]
