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

#align(center, cetz.canvas(length: 0.8cm, {
  import cetz.draw: *
  swimlane(-0.4, -1.5, 18.4, 1.9, "FACTS → CONTRIBUTING FACTORS → SYSTEMIC CHANGE", purple,
    rgb("#f5eefa"))
  let ph(x, n, l, s, c) = rnode(x, 0.9, n, l, s, c, w: 3.3, h: 1.0)
  ph(2.2, "a", "1 · timeline", "facts, no blame", blue)
  ph(6.0, "b", "2 · detection gap", "4 h unnoticed", red)
  ph(9.8, "c", "3 · contributing", "plural, always", purple)
  ph(13.6, "d", "4 · actions", "owners + dates", green)
  ph(17.2, "e", "5 · verify", "did it land?", orange)
  for (x, y) in (("a","b"),("b","c"),("c","d"),("d","e")) {
    line(x + ".east", y + ".west", mark: (end: ">"), stroke: hot)
  }
  content((9.0, -0.5), dlbl("the 4-hour DETECTION gap is a bigger finding than the deploy itself",
    sz: 6.6pt, c: red))
  content((9.0, -1.15), dlbl("\"human error\" is never a root cause — it is where the analysis stopped",
    sz: 6.5pt, c: purple))
}))
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
