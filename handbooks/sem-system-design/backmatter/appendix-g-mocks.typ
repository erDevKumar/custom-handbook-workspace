#import "/shared/lib/template.typ": *
#reg(1, "G", "Three Mock Interviews")
#chapterhead("Appendices & Reference", "Appendix G · Mock Interviews")
#pagebreak(weak: true)

#anchor("appG")
#fmhead("Appendix G · Three Mock Interviews")

#text(size: 9pt)[
  Three transcripts at increasing difficulty, each showing the interviewer's prompt, the
  clarifications a strong candidate asks, where the conversation turns, and what is being
  evaluated. #underline(stroke: 1pt + green)[Read the clarifying questions first and try to
  produce them yourself] before reading on — that skill, not the architecture, is what the first
  five minutes measure.
]
#v(3mm)

// ============================================================ MOCK 1
#h2("G.1 · Mock 1 — Design a URL shortener (45 min)", c: green)

#text(size: 8.8pt)[
  #text(fill: purple, weight: "bold")[Prompt.] "Design a URL shortener like bit.ly."

  #text(fill: green, weight: "bold")[Clarifications a strong candidate asks:] How many URLs
  created per day, and how many redirects? (100k created, 100M redirects — a
  #underline(stroke: 1pt + green)[1,000:1 read:write ratio], which decides everything.) Do links
  expire? Custom aliases? Analytics? Must the short code be unguessable?

  #text(fill: orange, weight: "bold")[Scale, said out loud.] 100M redirects/day ÷ 86,400 =
  #text(weight: "bold")[1,157 QPS] average, ×3 peak = #text(weight: "bold")[3,500 QPS].
  Creates: 100,000 ÷ 86,400 ≈ #text(weight: "bold")[1.2 QPS]. Storage over 5 years:
  100k × 365 × 5 = 182M rows × 500 B = #text(fill: green, weight: "bold")[91 GB] — fits on one
  machine.

  #text(fill: blue, weight: "bold")[The turn.] The read:write ratio means this is a
  #underline(stroke: 1pt + green)[caching problem, not a database problem]. The working set of
  popular links is small; a cache in front of a single Postgres handles 3,500 QPS comfortably. A
  candidate who shards the database here has not read the numbers.

  #text(fill: purple, weight: "bold")[Key generation.] Base62 of a counter (short, sequential,
  #text(fill: red)[enumerable]) versus a random 7-character code
  (62#super[7] ≈ 3.5 × 10¹², unguessable, needs a collision check). Say which you chose
  #underline(stroke: 1pt + green)[and why] — if links are private, enumerable codes are a data
  leak (M14).

  #text(fill: green, weight: "bold")[Expected follow-ups.] "What if one link goes viral?"
  (hot key — cache it at the edge, S11.) "How do you handle analytics without slowing redirects?"
  (fire-and-forget to a queue, never synchronous — M36.) "301 or 302?"
  (#text(weight: "bold")[302] — a 301 is cached by browsers forever and you lose both analytics
  and the ability to change the target.)

  #text(fill: red, weight: "bold")[Being evaluated:] do you read the numbers before designing, do
  you resist over-engineering, and do you know a redirect is a cache lookup.
]
#v(3mm)

// ============================================================ MOCK 2
#h2("G.2 · Mock 2 — Design a notification system (45 min)", c: orange)

#text(size: 8.8pt)[
  #text(fill: purple, weight: "bold")[Prompt.] "Design a system that sends notifications to
  10 million users across push, email and SMS."

  #text(fill: green, weight: "bold")[Clarifications.] Transactional, marketing, or both? (Both —
  so #underline(stroke: 1pt + red)[priority separation] is required.) What delivery guarantee?
  Do users control channel preferences? What is the largest single campaign? Is ordering required?

  #text(fill: orange, weight: "bold")[Scale.] A 10M-user campaign at 4 KB =
  #text(weight: "bold")[40 GB egress]. To finish in 10 minutes: 10,000,000 ÷ 600 =
  #text(fill: orange, weight: "bold")[16,667 sends/s]. Transactional baseline: perhaps 500/s,
  but #underline(stroke: 1pt + green)[latency-critical].

  #text(fill: red, weight: "bold")[The turn — and most candidates miss it.] The campaign is not
  the hard part; the #underline(stroke: 1pt + red)[app-open spike it causes] is. If 5% of
  recipients open within 2 minutes: 0.05 × 10M ÷ 120 =
  #text(fill: red, weight: "bold")[4,167 QPS] of cold-start traffic arriving at your API. The
  notification system is a load generator aimed at your own backend (M11).
  #text(fill: green)[Mitigation: stagger delivery over 30–60 minutes.]

  #text(fill: blue, weight: "bold")[Architecture.] Trigger → fan-out worker (resolves user →
  device tokens, applies preferences and quiet hours) → #text(weight: "bold")[separate priority
  queues] → channel-specific senders. A password reset must never queue behind a marketing blast
  — that is a security incident, not a latency issue.

  #text(fill: green, weight: "bold")[Expected follow-ups.] "Guarantee delivery?"
  (#underline(stroke: 1pt + red)[You cannot] — APNs and FCM are best-effort. Guarantee the state
  is correct and fetchable when the app opens.) "Avoid duplicates?" (Idempotency key per
  (user, event), plus platform collapse keys.) "A user has 5 devices and 3 are stale?"
  (Delete on `410 Gone` — dead tokens corrupt every delivery metric you have.)

  #text(fill: red, weight: "bold")[Being evaluated:] do you think past the send to the
  consequences, do you separate priorities, and are you honest about best-effort delivery.
]
#v(3mm)

// ============================================================ MOCK 3
#h2("G.3 · Mock 3 — Payments platform with a region failure (60 min, SEM)", c: red)

#text(size: 8.8pt)[
  #text(fill: purple, weight: "bold")[Prompt.] "Design a payments platform handling 50,000
  transactions per second. Then: your primary region fails during peak. Walk me through the next
  hour — as the engineering manager, not the on-call engineer."

  #text(fill: green, weight: "bold")[Clarifications.] What is the acceptable data loss (RPO)?
  (For payments: #text(fill: red, weight: "bold")[zero] — which forces synchronous replication
  and prices every write.) Regulatory regime? Card-present or online? Who owns the
  failover decision today?

  #text(fill: orange, weight: "bold")[Scale and the cost of RPO = 0.] 50,000 TPS × 2 ledger
  entries = #text(weight: "bold")[100,000 row-writes/s]. Synchronous cross-region quorum adds
  #text(fill: red, weight: "bold")[~70 ms to every write, permanently] — the PACELC ELSE branch
  (Part 1 §3.3). State that trade explicitly; it is the central design decision.

  #text(fill: blue, weight: "bold")[Design.] Idempotency at every hop (S4), double-entry
  append-only ledger with a continuously-checked balance invariant (CS3), transactional outbox for
  downstream events (M9), and #underline(stroke: 1pt + green)[region-partitioned account
  ownership] so cross-region write conflicts are impossible by construction (M27).

  #text(fill: red, weight: "bold")[The second half is the real interview.] Expected from an SEM:
  #linebreak()
  #h(3mm)#text(weight: "bold")[Decision.] Who declares failover, against what pre-agreed
  threshold? (If this needs a VP at 3am, your RTO is two hours — S10.)
  #linebreak()
  #h(3mm)#text(weight: "bold")[Data.] Which writes are lost in the lag window, and what is the
  reconciliation plan? Name the number before the incident.
  #linebreak()
  #h(3mm)#text(weight: "bold")[Fencing.] The old primary must never accept writes again, or you
  have built a split-brain (S5).
  #linebreak()
  #h(3mm)#text(weight: "bold")[Team.] Commander, operator, scribe, comms — and the commander does
  not type.
  #linebreak()
  #h(3mm)#text(weight: "bold")[Communication.] Customers, regulator (there is a clock), and
  executives — each with different content, all honest about data loss.
  #linebreak()
  #h(3mm)#text(weight: "bold")[Afterwards.] Blameless post-mortem, contributing factors not a
  culprit, actions with owners and dates, verified at 30 and 90 days (S15).

  #text(fill: red, weight: "bold")[Being evaluated:] whether you can hold the technical design and
  the organisational response in the same answer. Strong engineers who answer only the first half
  are routinely assessed as #underline(stroke: 1pt + red)[not yet ready for the manager role] —
  the architecture was never the discriminator.
]
#v(2mm)

#key[
  Across all three: the clarifying questions do more work than the architecture. In Mock 1 the
  read:write ratio decides the design; in Mock 2 the hidden load is the app-open spike; in Mock 3
  the RPO requirement prices every write in the system.
  #underline(stroke: 1pt + green)[Ask first, then design.]
]

