#import "/shared/lib/template.typ": *
#reg(1, "S15", "Post-mortem after 4-hour data corruption")
#chapterhead("Part 3 · Interview Scenarios", "S15 · Post-Incident Leadership")

#h1("S15 · Leading the Post-Mortem", c: purple)

#text[
  #text(fill: purple, weight: "bold")[The prompt.] A bad deploy corrupted customer data for four
  hours before detection. Recovery took another six. Customers noticed. The CEO wants to know what
  happened and why it will not recur. Run the post-mortem and the remediation.
]
#v(2mm)

#h2("1 · The dilemma", c: red)

#text(size: 9pt)[
  Every incentive pushes toward the wrong output. Leadership wants a cause and a date;
  the engineer who deployed wants the ground to open; other teams want to be excluded from scope.
  The pressure produces a document naming a person and a one-line fix, which is
  #underline(stroke: 1pt + red)[comfortable and useless] — it changes nothing structural, so the
  class of failure recurs with different names in it.

  #text(fill: purple, weight: "bold")[Your actual job] is to convert a painful event into
  permanent organisational change, and to protect the psychological safety that makes the next
  incident reportable. A team that learns incidents are career-threatening stops reporting them
  early, which is the only time they are cheap.
]
#v(2mm)

#h2("2 · Running it", c: green)

#pfig("Fig S15.1 · the post-mortem as a process — the detection gap is the finding, and the actions are the output")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.7, 3.0, "blameless by policy, not by tone; reconstruction kept separate from analysis, so no narrative forms first")

  ppill(2.9, 0, "inc", "4h corruption + 6h recovery", c: red, w: 5.6)
  pstep(8.55, 0, "tl", "timeline of facts", "who knew what, when", st-man, n: 1, actor: "facilitator", w: 4.8)
  pstep(13.81, 0, "gap", "the detection gap", "500 recs/min unseen", st-man, n: 2, actor: "facilitator", w: 4.8)
  pdec(17.0, -3.8, "one", "only one\ncause found?")
  pstep(11.2, -3.8, "fac", "contributing set", "no CI test, weak canary", st-man, n: 3, actor: "the team", w: 4.8)
  pstep(5.2, -3.8, "act", "owners + dates", "specific, or decoration", st-auto, n: 4, actor: "eng manager", w: 4.8)
  pstep(5.2, -7.2, "ver", "verify at 30/90d", "publicly, or they decay", st-man, n: 5, actor: "eng manager", w: 4.8)
  ppill(17.0, -7.2, "human", "\"human error\" — reopen", c: red, w: 4.7)

  line("inc.east", "tl.west", mark: (end: ">"), stroke: miss)
  line("tl.east", "gap.west", mark: (end: ">"), stroke: hot)
  line("gap.south", (13.81, -2.0), (17.0, -2.0), "one.north", mark: (end: ">"), stroke: lookup)
  plabel(14.8, -2.0, "2,500 records, not 120,000", c: green, dy: 0.34)
  line("one.south", "human.north", mark: (end: ">"), stroke: except)
  plabel(16.9, -5.5, "yes — the analysis stopped early", c: red, dy: 0.0)
  line("one.west", "fac.east", mark: (end: ">"), stroke: hot)
  plabel(14.6, -2.6, "no — plural", c: green, dy: 0.0)
  line("fac.west", "act.east", mark: (end: ">"), stroke: hot)
  line("act.west", (0.9, -3.8), (0.9, -7.2), "ver.west", mark: (end: ">"), stroke: hot)

  ploop("human.west", "fac.south", -8.9, "re-ask: why did the system permit it, and why did nothing catch it", c: blue)
}))
#pcards(
  [A blameless policy the team believes, because early reports are the cheap ones; logs, deploy records and chat transcripts preserved; a priority someone will defend in a planning meeting],
  [In: 120,000 records corrupted, 8,000 customers contacted, 340 support hours, 0.3% cohort churn · Out: plural contributing factors, dated and owned actions, and a verified completion review at 30 and 90 days],
  [Deploy and audit logs · chat transcript reconstruction · data-integrity monitoring as the top action · CI schema-compatibility test · canary with business checks (S12) · rehearsed restore runbook],
)
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: blue, weight: "bold")[1 · Timeline first, interpretation later.] Reconstruct from
  logs, deploy records and chat transcripts: what happened, when, who knew what at each point.
  Facts only. Separating reconstruction from analysis prevents the narrative from forming before
  the evidence does.

  #text(fill: red, weight: "bold")[2 · Interrogate the detection gap hardest.] Four hours of
  undetected corruption is the finding with the highest leverage. Why did no alert fire? Was there
  no data-integrity check, or did one fire into a channel nobody watches? Every hour of detection
  delay multiplied the recovery cost, and detection is usually cheaper to fix than prevention.

  #text(fill: purple, weight: "bold")[3 · Contributing factors are always plural.] A single cause
  is a sign the analysis stopped early. Here, plausibly: no schema-compatibility test in CI; a
  canary that only checked for crashes (S12); no integrity monitoring; a runbook that did not
  cover partial corruption; and an on-call engineer who had never rehearsed a restore.
  #underline(stroke: 1pt + green)[Remove any one and the outcome changes] — which is precisely
  what makes them worth listing.

  #text(fill: green, weight: "bold")[4 · Actions with owners, dates, and a priority that is
  defended.] Vague actions ("improve testing") are decoration. Specific, assigned, dated actions
  are the only output that matters.

  #text(fill: orange, weight: "bold")[5 · Verify completion, publicly.] Review the action list at
  30 and 90 days. #note[The most common organisational failure is not a bad post-mortem — it is a
  good post-mortem whose actions are silently deprioritised once the pain fades. Tracking
  completion is the difference between a learning organisation and one that writes documents.]
]
#v(2mm)

#formula("Quantify, so the remediation gets funded")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[Impact:] 4 h corruption + 6 h recovery = 10 h.
    #linebreak()
    120,000 customer records affected; 8,000 customers contacted;
    #text(fill: red, weight: "bold")[340 support hours]; 0.3% churn in the affected cohort over
    the following month.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Detection economics:] corruption rate ~500 records/min. Detection at
    5 minutes instead of 4 hours would have meant
    #text(fill: green, weight: "bold")[2,500 records instead of 120,000] — a
    #text(weight: "bold")[48×] reduction in impact from one integrity check.
    #linebreak()
    #underline(stroke: 1pt + green)[That single number is what funds the remediation.] "We should
    have better monitoring" does not get prioritised; "a 48× impact reduction for two weeks of
    work" does.
  ]
]
#v(2mm)

#key[
  #text(fill: red, weight: "bold")["Human error" is not a root cause.] It is the point at which
  the investigation stopped. The real questions are why the system permitted that action, why
  nothing caught it, and why recovery took six hours. People will always make mistakes;
  #underline(stroke: 1pt + green)[the system's job is to make mistakes cheap].
]
#v(2mm)

#h2("3 · SEM execution strategy", c: purple)

#text(size: 8.9pt)[
  #text(fill: purple, weight: "bold")[Blameless means blameless in practice, not in the template.]
  Name roles, not people, in the written document. Say "the on-call engineer" rather than a name.
  If the person who ran the deploy is visibly supported in the review, your team will report the
  next incident in minute one instead of hour three — and that single behavioural change is worth
  more than any action item on the list.

  #text(fill: purple, weight: "bold")[Prioritise detection over prevention.] You cannot prevent
  every defect; you can always shorten the time to notice. In this incident, prevention (a
  compatibility test) and detection (an integrity check) both matter — but detection generalises
  to #underline(stroke: 1pt + green)[failures you have not imagined yet], which is where the real
  return is.

  #text(fill: purple, weight: "bold")[Communicating upward.] Leadership wants three things, in
  this order: is it fixed, how bad was it, and will it recur. Give them:
  #text(fill: green)["Contained and corrected. 120,000 records, 8,000 customers contacted
  directly. Five systemic actions, two complete, three by 15 November. The highest-leverage one
  cuts detection time from four hours to five minutes."] Specific, quantified, dated — and no
  defensiveness.

  #text(fill: purple, weight: "bold")[Communicating outward.] Customers affected by data
  corruption must be told directly, with what happened, what was corrected, and what they should
  check. Discovering it themselves later is
  #underline(stroke: 1pt + red)[permanently more damaging] than being told promptly.

  #text(fill: purple, weight: "bold")[Make the output reusable.] Tag incidents by contributing
  factor. After a year, the pattern across post-mortems — "six of our last ten incidents involved
  an untested migration" — is a far stronger argument for platform investment than any single
  review.
]
#v(2mm)

#anti("the post-mortem that names a person and a one-line fix")[
  The document concludes: #text(fill: red)["Root cause: engineer deployed a migration without
  testing. Action: be more careful."] It is signed off quickly because it is comfortable —
  leadership has a cause, other teams are out of scope, and no roadmap time is required. Nothing
  changes. Six months later the same class of failure recurs with a different name attached, and
  this time the engineer involved #underline(stroke: 1pt + red)[delays reporting it by two hours]
  because they watched what happened to their colleague. The organisation has traded a
  two-week fix for a permanent detection penalty.
  #text(fill: green)[Fix:] contributing factors, not a culprit; systemic actions with owners and
  dates; verified completion; and visible support for whoever was holding the pager.
]
