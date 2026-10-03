#import "/shared/lib/template.typ": *
#reg(1, "M11", "Push Notification Infrastructure")
#chapterhead("Part 2 · Modules", "M11 · Push Notifications")
#ix("APNs")
#ix("FCM")
#ix("Push notification")

#h1("M11 · Push Notification Infrastructure", c: orange)

#text[
  Push is the only channel that reaches a user whose app is closed, and it is the one piece of
  your delivery path you #underline(stroke: 1pt + red)[do not control]. APNs and FCM decide
  whether, when and if a message arrives. Everything here is about behaving well inside somebody
  else's system.
]
#v(2mm)

#h2("1 · The delivery pipeline", c: blue)

#pfig("Fig M11.1 · push delivery pipeline — priority queues, and the 410 that must delete a token")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.3, 20.9, 2.6, "APNs `.p8` JWT refreshed hourly; FCM service account; separate queues and worker pools per priority class")

  ppill(1.7, 0, "in", "campaign", w: 3.1)
  pstep(6.0, 0, "fan", "resolve to tokens", "fan-out worker · 20k/s", st-man, n: 1, actor: "platform", w: 4.2)
  pstep(10.8, 0, "q", "priority queues", "txn | marketing · HTTP/2", st-auto, n: 2, actor: "scheduler", w: 4.4)
  pdec(15.4, 0, "ok", "token\nstill live?", w: 1.6)
  ppill(19.2, 0, "out", "device wakes", w: 3.1)

  pstep(15.4, -4.0, "del", "DELETE the token", "410 Gone / UNREGISTERED", st-dec, n: 3, actor: "platform", w: 5.0)

  line("in.east", "fan.west", mark: (end: ">"), stroke: hot)
  line("fan.east", "q.west", mark: (end: ">"), stroke: hot)
  line("q.east", "ok.west", mark: (end: ">"), stroke: hot)
  line("ok.east", "out.west", mark: (end: ">"), stroke: hot)
  plabel(17.65, 0, "yes", c: green, dy: 0.62)
  line("ok.south", "del.north", mark: (end: ">"), stroke: except)
  plabel(17.1, -2.1, "no", c: red, dy: 0)
  content((6.4, -4.2), dlbl("one shared queue puts a 10M-device marketing blast\nin front of every login code. Separate queues, pools\nand rate budgets are the cheapest win in this pipeline.", sz: 6.5pt, c: red))
  content((10.3, -6.4), dlbl("delivery is best-effort on both platforms: APNs silently throttles priority 5, and Doze defers FCM `normal` indefinitely", sz: 6.5pt, c: purple))
}))
#pcards(
  [An hourly-refreshed APNs JWT; FCM OAuth2; a per-class rate budget; a token table you will delete rows from],
  [In: a trigger · Out: best-effort delivery, 4 KB cap. A `410`/`UNREGISTERED` is an instruction to delete the token now],
  [APNs over HTTP/2 with `apns-priority` 10/5 · FCM HTTP v1 · separate txn and marketing queues · token store],
)
#v(2mm)

#text(size: 9pt)[
  #text(fill: purple, weight: "bold")[Priority is the whole design.] A password-reset push and a
  "50% off this weekend" push must not share a queue. Marketing blasts are bursty and enormous;
  transactional messages are small, rare and urgent. One queue means a 10M-device campaign
  delays every login code behind it. #note[Separate queues, separate worker pools, separate rate
  budgets. The cheapest reliability win in the entire pipeline.]

  #text(fill: red, weight: "bold")[Token hygiene is not optional.] Tokens expire when an app is
  reinstalled, a device is wiped, or the user disables notifications. A `410 Gone` from APNs or
  `UNREGISTERED` from FCM means #underline(stroke: 1pt + green)[delete the token immediately].
  Fleets that ignore this accumulate dead tokens for years, inflating cost and corrupting every
  delivery metric you have.
]
#v(2mm)

#h2("2 · APNs and FCM compared", c: purple)

#table(
  columns: (auto, 1fr, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.5pt, fill: purple)[Aspect],
  text(font: headfont, size: 8.5pt, fill: purple)[APNs (iOS)],
  text(font: headfont, size: 8.5pt, fill: purple)[FCM (Android)],

  text(size: 8.3pt)[Auth],
  text(size: 8pt)[JWT from a `.p8` key, refreshed hourly],
  text(size: 8pt)[OAuth2 service account],

  text(size: 8.3pt)[Transport],
  text(size: 8pt)[HTTP/2, long-lived multiplexed connections],
  text(size: 8pt)[HTTP v1 REST],

  text(size: 8.3pt)[Priority],
  text(size: 8pt)[`apns-priority` 10 (immediate) / 5 (power-aware)],
  text(size: 8pt)[`high` / `normal`],

  text(size: 8.3pt)[Throttling],
  text(size: 8pt, fill: red)[Silently throttles priority-5 and repeated background pushes],
  text(size: 8pt, fill: red)[Doze mode defers `normal` indefinitely],

  text(size: 8.3pt)[Dead token],
  text(size: 8pt)[`410 Gone`],
  text(size: 8pt)[`UNREGISTERED` / `INVALID_ARGUMENT`],

  text(size: 8.3pt)[Payload cap],
  text(size: 8pt)[4 KB],
  text(size: 8pt)[4 KB],

  text(size: 8.3pt)[Guarantee],
  text(size: 8pt, fill: red)[Best-effort. No delivery guarantee, ever],
  text(size: 8pt, fill: red)[Best-effort, plus OEM battery managers],
)
#v(2mm)

#key[
  Push is #text(fill: red, weight: "bold")[best-effort by contract]. Never build a flow whose
  correctness depends on a push arriving. It is a #underline(stroke: 1pt + green)[hint to open
  the app], not a transport. The app must be able to fetch the same state on foreground, because
  on a Chinese OEM with an aggressive battery manager, the push may simply never arrive.
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("A 10M-device campaign")[
  #text(size: 8.6pt)[
    10,000,000 devices, 4 KB payload #sym.arrow.r
    #text(fill: orange, weight: "bold")[40 GB] of egress for one campaign.
    #linebreak()
    A single HTTP/2 connection to APNs sustains ~1,000 sends/s. To finish in 10 minutes:
    10,000,000 / 600 = #text(fill: orange, weight: "bold")[16,667 sends/s] #sym.arrow.r
    #text(fill: green, weight: "bold")[~17 concurrent connections], plus headroom
    #sym.arrow.r provision 25.
    #linebreak() #v(1mm)
    #text(weight: "bold")[The real constraint is the response, not the send.] If 5% of recipients
    open the app within 2 minutes: 0.05 × 10,000,000 / 120 =
    #text(fill: red, weight: "bold")[4,167 QPS] of cold-start API traffic arriving in a spike.
    #underline(stroke: 1pt + red)[The campaign is a load test you scheduled against yourself.]
    #linebreak() #v(1mm)
    #text(weight: "bold")[Mitigation:] stagger delivery across 30–60 minutes. The marketing team
    loses nothing; your API keeps a flat load curve instead of a cliff.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[The self-inflicted thundering herd.] The campaign sends in
  90 seconds; every recipient who taps opens a cold app that calls six endpoints. Your API tier
  sees its yearly peak with no warning. #text(fill: green)[Fix:] rate-limit the campaign itself
  and treat send rate as a capacity decision, not a marketing preference.

  #text(fill: red, weight: "bold")[Dead-token accumulation.] Years of ignored `410 Gone`
  responses leave 30% of the token table unreachable. Delivery rate looks catastrophic and
  nobody can tell whether it is a real problem. #text(fill: green)[Fix:] delete on the failure
  response, and run a periodic sweep for tokens with no successful delivery in 90 days.

  #text(fill: red, weight: "bold")[Duplicate notifications.] A retry after an ambiguous timeout
  sends twice; the user sees the same alert repeatedly.
  #text(fill: green)[Fix:] a collapse key (`apns-collapse-id`, FCM `collapse_key`) so the
  platform replaces rather than stacks, plus a dedupe window keyed by (device, event).

  #text(fill: red, weight: "bold")[Silent delivery failure.] Pushes stop arriving on Android for
  one OEM. No error is returned --- the battery manager simply drops them.
  #text(fill: green)[Fix:] measure delivery as #underline(stroke: 1pt + green)[app-confirmed
  receipt], not as the provider's 200 OK. The gap between the two is the only honest metric.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: Design a system to notify 10M users.]
  #linebreak()
  Fan out from a trigger into priority-separated queues, resolve tokens, send over pooled HTTP/2,
  handle `410` by deleting, and #underline(stroke: 1pt + green)[stagger delivery] so the
  resulting app-open spike does not overwhelm the API. #note[Testing: do you think past the send?
  The interesting engineering is the traffic that comes #emph[back].]

  #text(fill: green, weight: "bold")[Q: How do you guarantee a notification is delivered?]
  #linebreak()
  You cannot. APNs and FCM are explicitly best-effort. You guarantee the
  #emph[state] is correct and fetchable when the app next opens.
  #note[Testing: candidates who promise delivery have not read the platform docs. The right
  answer reframes the requirement.]

  #text(fill: green, weight: "bold")[Q: Transactional and marketing push on the same
  infrastructure?]
  #linebreak()
  Same senders, strictly separate queues and rate budgets, with transactional pre-empting.
  #note[Testing: whether you anticipate head-of-line blocking — a login code stuck behind a
  10M-device blast is a security incident, not a latency issue.]
]
#v(2mm)

#anti("treating push as a reliable transport")[
  A payments app sends the transaction receipt #emph[only] as a push payload and writes nothing
  server-side. Users on battery-restricted Android builds never receive it, iOS users who
  disabled notifications never receive it, and anyone offline at send time never receives it.
  Support cannot resend because the content #text(fill: red)[was never stored anywhere].
  #text(fill: green)[Fix:] push carries a pointer, never the payload. Persist the content, send
  a notification that says it exists, and let the app fetch it.
]
