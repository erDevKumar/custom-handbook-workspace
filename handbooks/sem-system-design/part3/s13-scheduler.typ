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

#pfig("Fig S13.1 · a billion timers at ms accuracy — bucket for scale, wheel for precision, enqueue to fire")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.7, 3.0, "handlers idempotent on timer id (S4); cancellation is a tombstone checked at fire time; buckets hash-sharded")

  ppill(2.25, 0, "sch", "schedule(t, payload)", w: 4.3)
  pstep(7.25, 0, "bkt", "bucket by minute", "timers:14:33:shard-7", st-auto, n: 1, actor: "store", w: 4.8)
  pdec(12.11, 0, "fat", "bucket over\n100k timers?")
  pstep(16.97, 0, "jit", "jitter on schedule", "spread 09:00 over 2min", st-man, n: 2, actor: "product", w: 4.8)

  pstep(16.6, -3.8, "ld", "pre-fetch T−10s", "one minute, not 50M", st-auto, n: 3, actor: "loader", w: 4.8)
  pstep(10.8, -3.8, "wh", "in-memory wheel", "ms accurate · a cache", st-auto, n: 4, actor: "firing node", w: 4.8)
  pstep(5.0, -3.8, "enq", "enqueue, not run", "at-least-once · SQS", st-integ, n: 5, actor: "firing node", w: 4.8)
  ppill(5.0, -7.2, "hdl", "handler dedupes on timer id", w: 5.6)
  ppill(16.6, -7.2, "safe", "nothing lost — bucket is durable", w: 5.6)

  line("sch.east", "bkt.west", mark: (end: ">"), stroke: hot)
  line("bkt.east", "fat.west", mark: (end: ">"), stroke: hot)
  line("fat.east", "jit.west", mark: (end: ">"), stroke: except)
  plabel(14.0, 0, "yes", c: red, dy: 0.44)
  line("fat.south", (12.11, -1.9), (16.6, -1.9), "ld.north", mark: (end: ">"), stroke: hot)
  plabel(14.1, -1.9, "no — load the due minute", c: green, dy: 0.34)
  line("ld.west", "wh.east", mark: (end: ">"), stroke: hot)
  line("wh.west", "enq.east", mark: (end: ">"), stroke: hot)
  line("enq.south", "hdl.north", mark: (end: ">"), stroke: async)
  line("wh.south", (10.8, -7.2), "safe.west", mark: (end: ">"), stroke: lookup)
  plabel(13.0, -7.2, "node dies mid-minute → reload", c: purple, dy: 0.46)

  ploop("jit.south", "bkt.south", -5.6, "re-bucket the jittered times, then re-check the depth", c: blue)
}))
#pcards(
  [Timer ids stable across a re-fire; tombstones, not deletes, for cancellation; buckets sharded by hash; a published drain window where jitter is refused],
  [In: 50M pending timers, 10,000 fires/s capacity · Out: one minute-bucket read per second regardless of total pending, millisecond firing from the wheel, at-least-once enqueue the handler deduplicates],
  [Minute-bucketed sharded store (`timers:HH:MM:shard-N`) · pre-fetching loader at T−10s · in-memory hierarchical timer wheel · SQS/Kafka execution queue · idempotent handlers (S4)],
)
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
