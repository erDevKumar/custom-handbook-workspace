#import "/shared/lib/template.typ": *
#reg(1, "F", "The Interview Playbook")
#chapterhead("Appendices & Reference", "Appendix F · Interview Playbook")
#pagebreak(weak: true)

#anchor("appF")
#fmhead("Appendix F · The Interview Playbook")

#text(size: 9pt)[
  Everything above is material. This is #underline(stroke: 1pt + green)[method]: how to spend the
  minutes you are given, what to say when you do not know, and the mistakes that lose offers from
  candidates who knew the content.
]
#v(3mm)

#h2("F.1 · Time allocation", c: blue)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  let track(y, total, segs) = {
    content((1.4, y), dlbl(total, sz: 7.5pt, c: ink))
    let x = 3.0
    for s in segs {
      rect((x, y - 0.3), (x + s.at(1), y + 0.3), stroke: 0.9pt + s.at(2), fill: white)
      content((x + s.at(1) / 2, y + 0.02), dlbl(s.at(0), sz: 5.9pt, c: ink))
      content((x + s.at(1) / 2, y - 0.52), dlbl(s.at(3), sz: 5.4pt, c: s.at(2)))
      x = x + s.at(1) + 0.1
    }
  }
  track(2.0, "30 min", (
    ("reqs", 2.0, green, "0–5"), ("scale", 1.4, orange, "5–8"),
    ("API+data", 1.8, blue, "8–12"), ("architecture", 4.2, purple, "12–22"),
    ("scale+fail", 1.8, red, "22–26"), ("trade-offs", 1.8, green, "26–30")))
  track(0.5, "45 min", (
    ("reqs", 2.4, green, "0–6"), ("scale", 1.8, orange, "6–10"),
    ("API+data", 2.4, blue, "10–16"), ("architecture", 5.4, purple, "16–29"),
    ("deep dive", 2.4, red, "29–37"), ("fail+trade", 2.4, green, "37–45")))
  track(-1.0, "60 min", (
    ("reqs", 2.8, green, "0–8"), ("scale", 1.8, orange, "8–12"),
    ("API+data", 2.8, blue, "12–19"), ("architecture", 6.0, purple, "19–35"),
    ("deep dive", 3.2, red, "35–47"), ("ops+trade", 3.0, green, "47–60")))
  bracket(3.0, 16.4, -2.0, "architecture is always the largest block — but never the first one", purple)
}))
#v(2mm)

#key[
  #text(fill: red, weight: "bold")[Spend the first five minutes asking, not answering.] The
  single most common failure is drawing boxes before establishing what the system must do. An
  interviewer who has to interrupt you to supply a requirement has already formed an impression.
]
#v(2mm)

#h2("F.2 · The framework, every time", c: green)

#text(size: 8.9pt)[
  #text(weight: "bold")[1 · Requirements.] Functional (what it does) and non-functional (how
  fast, how available, how much data, how long retained). Ask about scale explicitly — "how many
  users, and what is the read:write ratio?"

  #text(weight: "bold")[2 · Scale estimate.] DAU × actions/day ÷ 86,400 → average QPS → ×3 for
  peak. Storage: rows × bytes × replication × 1.3. #underline(stroke: 1pt + green)[Say the
  arithmetic out loud.]

  #text(weight: "bold")[3 · API.] Three or four endpoints with their shapes. This grounds the
  rest of the discussion in something concrete.

  #text(weight: "bold")[4 · Data model.] Entities, and the
  #text(fill: red, weight: "bold")[partition key] — the decision you cannot reverse (M2).

  #text(weight: "bold")[5 · High-level architecture.] Boxes and arrows. Narrate the request path
  end to end before adding anything.

  #text(weight: "bold")[6 · Identify the bottleneck] #underline(stroke: 1pt + green)[yourself],
  before being asked. This is the strongest single move available in the format.

  #text(weight: "bold")[7 · Scale it.] Cache, shard, queue, replicate — each justified by the
  bottleneck you named.

  #text(weight: "bold")[8 · Failure modes.] What breaks, how you detect it, how it degrades.

  #text(weight: "bold")[9 · Trade-offs.] State what you gave up. Every design costs something,
  and naming it is what distinguishes a senior answer.
]
#v(2mm)

#h2("F.3 · How to draw quickly", c: purple)

#text(size: 8.9pt)[
  Left to right: #text(fill: purple)[client] → #text(fill: blue)[edge] →
  #text(fill: green)[service] → #text(fill: orange)[storage]. Four columns, consistent every
  time, so you never spend thought on layout.
  #linebreak()
  Draw the #underline(stroke: 1pt + green)[happy path first and completely], then add caches,
  queues and replicas as you justify them. A diagram that grows in response to stated problems
  reads as reasoning; a diagram that arrives complete reads as memorisation.
  #note[Label arrows with the protocol and the latency budget — `gRPC, 5 ms`. It takes two
  seconds and signals that you think in budgets rather than in boxes.]
]
#v(2mm)

#h2("F.4 · Saying \"I don't know\"", c: orange)

#text(size: 8.9pt)[
  #text(fill: red, weight: "bold")[Never bluff.] Interviewers probe exactly where you are vague,
  and a confident wrong answer about something they know well is far more damaging than an
  admission.
  #linebreak() #v(1mm)
  #text(fill: green, weight: "bold")[The three-part recovery:]
  #text(weight: "bold")[1.] Say what you do not know, precisely —
  "I haven't operated Pulsar at scale."
  #text(weight: "bold")[2.] Say what you do know that is adjacent —
  "I know Kafka's partition model well, and I'd expect similar trade-offs around ordering."
  #text(weight: "bold")[3.] Say how you would find out —
  "I'd benchmark both against our ordering requirement before committing."
  #linebreak()
  #underline(stroke: 1pt + green)[This frequently scores better than knowing the answer], because
  it demonstrates how you behave in the 90% of real work that is unfamiliar.
]
#v(2mm)

#h2("F.5 · Mistakes that lose offers", c: red)

#text(size: 8.8pt)[
  #text(fill: red, weight: "bold")[1.] Naming a technology before stating the requirement it
  satisfies. "We'll use Kafka" before establishing throughput, ordering or replay needs.
  #linebreak()
  #text(fill: red, weight: "bold")[2.] Designing for 1B users when asked about 10k.
  Over-engineering reads as poor judgement, not ambition.
  #linebreak()
  #text(fill: red, weight: "bold")[3.] Silence while thinking. The interviewer cannot credit
  reasoning they cannot hear — narrate.
  #linebreak()
  #text(fill: red, weight: "bold")[4.] Ignoring the interviewer's hints. "What happens if that
  node fails?" is not curiosity; it is a prompt.
  #linebreak()
  #text(fill: red, weight: "bold")[5.] No numbers. "It'll scale" is not an answer; "2,315 QPS
  average, 7,000 peak, so four shards" is.
  #linebreak()
  #text(fill: red, weight: "bold")[6.] Perfect-world design with no failure discussion.
  #linebreak()
  #text(fill: red, weight: "bold")[7.] #text(weight: "bold")[For SEM candidates specifically:]
  answering only as an engineer. You are also expected to address team structure, rollout
  sequencing, blast radius and what you would tell stakeholders —
  #underline(stroke: 1pt + green)[Part 3's execution sections exist for this].
]
#v(2mm)

#h2("F.6 · Final checklist", c: green)

#text(size: 8.8pt)[
  Before the architecture: #text(fill: green)[requirements stated · scale estimated out loud ·
  partition key named].
  #linebreak()
  During: #text(fill: green)[happy path first · bottleneck identified by me · every addition
  justified by a named problem].
  #linebreak()
  Before finishing: #text(fill: green)[failure modes covered · trade-offs stated · what I would
  monitor · what I would build first].
  #linebreak() #v(1mm)
  #text(fill: purple, weight: "bold")[The closing sentence that works:] "If I were building this,
  I'd start with #emph[X] because it's the riskiest assumption, and I'd want to validate it before
  committing to the rest."
]

