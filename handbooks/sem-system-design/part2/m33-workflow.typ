#import "/shared/lib/template.typ": *
#reg(1, "M33", "Workflow Orchestration & Durable Execution")
#chapterhead("Part 2 · Modules", "M33 · Durable Execution")
#ix("Durable execution")
#ix("Temporal")
#ix("Event history")

#h1("M33 · Workflow Orchestration", c: purple)

#text[
  Some business processes take days: an order that ships, a subscription that renews, a KYC check
  awaiting a human. A process that outlives the pod running it cannot live in memory, and
  rebuilding it from cron jobs and status columns is how teams accumulate
  #underline(stroke: 1pt + red)[state machines nobody can see].
]
#v(2mm)

#h2("1 · Durable execution — the event history", c: blue)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  swimlane(-0.4, -2.2, 18.4, 2.1, "REPLAY RECONSTRUCTS STATE — the worker holds nothing", purple,
    rgb("#f5eefa"))
  rnode(2.6, 1.2, "code", "workflow code", "looks synchronous", green, w: 4.0, h: 0.9)
  rnode(8.4, 1.2, "svc", "Temporal / Cadence", "schedules + persists", purple, w: 4.6, h: 0.9)
  cylinder(14.6, 1.2, "hist", "event history", purple, w: 4.0, h: 1.1)
  line("code.east", "svc.west", mark: (end: ">"), stroke: hot); badge(5.5, 1.7, "1", green)
  line("svc.east", "hist.west", mark: (end: ">"), stroke: hot); badge(11.5, 1.7, "2", green)

  content((2.6, -0.2), dlbl("worker dies", sz: 6.6pt, c: red))
  line("hist.south", (14.6, -0.9), (2.6, -0.9), "code.south", mark: (end: ">"), stroke: async)
  badge(8.6, -0.9, "3", purple)
  content((8.6, -1.5), dlbl("new worker replays the history -> resumes at the exact step",
    sz: 6.6pt, c: green))
}))
#v(1.5mm)

#text(size: 9pt)[
  The workflow function is written as ordinary sequential code --- call an activity, await the
  result, branch, sleep for three days, continue. The engine records every decision and result in
  an append-only #text(fill: purple, weight: "bold")[event history]. If the worker crashes, a new
  one #underline(stroke: 1pt + green)[replays the history] to rebuild local state, then continues
  from the first unexecuted step. Activities already completed are not re-run; their recorded
  results are returned.
  #note[The hard constraint this imposes: workflow code must be
  #text(fill: red, weight: "bold")[deterministic]. Replay must take the same branches it took
  originally, so `time.Now()`, `rand()`, map iteration order and direct network calls are all
  forbidden inside the workflow — they belong in activities, whose results are recorded.]
]
#v(2mm)

#h2("2 · When to use what", c: purple)

#table(
  columns: (auto, auto, 1fr, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.5pt, fill: purple)[Approach],
  text(font: headfont, size: 8.5pt, fill: purple)[Good for],
  text(font: headfont, size: 8.5pt, fill: purple)[Breaks when],
  text(font: headfont, size: 8.5pt, fill: purple)[Ops],

  text(size: 8.3pt)[Cron + status column],
  text(size: 8pt)[2–3 steps, tolerant of delay],
  text(size: 8pt, fill: red)[Branching, retries per step, visibility],
  text(size: 8.3pt, fill: green)[trivial],

  text(size: 8.3pt)[Queue chain],
  text(size: 8pt)[Linear pipelines],
  text(size: 8pt, fill: red)[No global view; compensation is manual (M4)],
  text(size: 8.3pt, fill: green)[low],

  text(size: 8.3pt)[Step Functions],
  text(size: 8pt)[AWS-native, JSON-defined],
  text(size: 8pt, fill: orange)[Logic in JSON; awkward to test and version],
  text(size: 8.3pt, fill: green)[managed],

  text(size: 8.3pt, fill: green)[Temporal / Cadence],
  text(size: 8pt)[Long-running, branching, human-in-the-loop],
  text(size: 8pt, fill: orange)[Determinism rules; a real cluster to run],
  text(size: 8.3pt, fill: orange)[significant],
)
#v(1.5mm)

#key[
  Durable execution earns its operational cost when a process has
  #underline(stroke: 1pt + green)[long waits, many steps, per-step retry policies, and a need to
  answer "where is order 12345 right now"]. Below that bar, a queue and a status column are the
  correct, boring answer — and reaching for a workflow engine is the over-engineering this
  handbook keeps warning about.
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("History growth and the replay cost")[
  #text(size: 8.6pt)[
    Each activity contributes several events (scheduled, started, completed). A 20-step workflow
    with retries easily reaches #text(fill: orange, weight: "bold")[100+ events].
    #linebreak()
    100,000 workflows/day × 100 events × 1 KB =
    #text(fill: orange, weight: "bold")[10 GB/day] of history. At 30-day retention that is
    #text(weight: "bold")[300 GB] in the persistence store — size Cassandra or Postgres behind
    Temporal accordingly.
    #linebreak() #v(1mm)
    #text(fill: red, weight: "bold")[The long-running trap:] a workflow that loops forever — a
    subscription that renews monthly for years — accumulates history without bound. Replay cost
    grows linearly, and most engines enforce a hard history limit.
    #linebreak()
    #text(fill: green)[Fix:] `continue-as-new` — the workflow completes and immediately starts a
    fresh instance carrying forward only the state it needs, resetting the history to zero. Any
    workflow with an unbounded loop
    #underline(stroke: 1pt + green)[must] use it.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Throughput:] a Temporal cluster handles thousands of workflow
    state-transitions per second, but each transition is a persisted write — the
    #underline(stroke: 1pt + red)[database behind it] is the real ceiling, not the engine.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Non-deterministic workflow code.] Someone adds
  `if time.Now().Hour() < 12` inside a workflow. On replay the hour differs, the branch differs,
  and the engine detects a history mismatch and #underline(stroke: 1pt + red)[fails the workflow
  permanently]. #text(fill: green)[Fix:] all non-determinism lives in activities; use the
  engine's deterministic clock and random APIs.

  #text(fill: red, weight: "bold")[Breaking change to running workflows.] A deploy reorders steps
  while thousands of workflows are mid-flight; their histories no longer match the new code.
  #text(fill: green)[Fix:] versioned workflow definitions (`GetVersion` patching), so old
  instances continue on old logic while new ones use the new path. This is the operational
  discipline that durable execution demands.

  #text(fill: red, weight: "bold")[Activities that are not idempotent.] An activity is retried
  after an ambiguous timeout and charges twice. #text(fill: green)[Fix:] idempotency keys on
  every activity with an external side effect — the engine guarantees
  #underline(stroke: 1pt + green)[at-least-once] execution, never exactly-once.

  #text(fill: red, weight: "bold")[Unbounded history.] Covered above; `continue-as-new`.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Design an order fulfilment process spanning days.]
  #linebreak()
  A durable workflow: reserve stock, charge, await warehouse confirmation (possibly days), ship,
  notify — with per-step retry policies, compensations on failure (M4), and the state queryable by
  order id. #note[Testing: do you recognise that the process outlives any single process? The
  weak answer is a cron job scanning a status column.]

  #text(fill: green, weight: "bold")[Q: Why must workflow code be deterministic?]
  #linebreak()
  Because state is reconstructed by replaying history; a different branch on replay means the
  rebuilt state does not match reality. #note[Testing: understanding of the replay model, which
  is the whole mechanism.]

  #text(fill: green, weight: "bold")[Q: When would you not use Temporal?]
  #linebreak()
  Short, linear, high-throughput processes — a queue and a status column are simpler and cheaper
  to operate. #note[Testing: resisting the shiny tool. Naming the operational cost unprompted is
  the senior signal.]
]
#v(2mm)

#anti("the state machine made of cron jobs")[
  An order process is implemented as a `status` column plus six cron jobs, each scanning for rows
  in a particular state and advancing them. It works until it does not: two jobs race and advance
  the same order twice; a job dies mid-batch leaving orders in a state nothing handles; retry
  logic is copy-pasted and subtly different in each job; and
  #underline(stroke: 1pt + red)[nobody can answer "why is order 12345 stuck"] without reading six
  codebases and a week of logs. The state machine is real but exists
  #text(fill: red, weight: "bold")[only in the engineers' heads].
  #text(fill: green)[Fix:] make the process explicit — a durable workflow if it is long and
  branching, or at minimum one owner per transition with an auditable history of what moved when.
]
