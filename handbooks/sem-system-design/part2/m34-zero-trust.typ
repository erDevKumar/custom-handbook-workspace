#import "/shared/lib/template.typ": *
#reg(1, "M34", "Zero-Trust & Client Attestation")
#chapterhead("Part 2 · Modules", "M34 · Zero-Trust Architecture")
#ix("Zero trust")
#ix("mTLS")
#ix("Client attestation")

#h1("M34 · Zero-Trust & Client Attestation", c: red)

#text[
  The perimeter model assumed that being inside the network meant being trusted. Zero trust
  discards that: #underline(stroke: 1pt + green)[every request is authenticated and authorised on
  its own merits], regardless of origin. Network position becomes a routing detail rather than a
  security control.
]
#v(2mm)

#h2("1 · Service identity with mTLS", c: blue)

#pfig("Fig M34.1 · identity on both hops — workload mTLS, then a device attestation that is only a signal")
#align(center, cetz.canvas(length: 0.76cm, {
  import cetz.draw: *
  pprereq(-0.4, 20.6, 2.9, "mesh CA issuing hour-long certs automatically · default-deny policy · the root CA expiry tracked as an owned operational risk")

  ppill(2.2, 0, "in", "mobile request", w: 3.8)
  pstep(7.4, 0, "a", "attest at session start", "Play Integrity · 500–2,000 ms", st-integ, n: 1, actor: "device", w: 6.2)
  pdec(13.6, -3.4, "d", "verdict ok?", w: 2.1)
  pstep(17.5, 0, "b", "attested token", "per request · ~0 ms", st-auto, n: 2, actor: "edge", w: 5.0)
  pstep(8.0, -3.4, "c", "mTLS A → B", "SPIFFE id · 1–2 ms/conn", st-auto, n: 3, actor: "sidecar", w: 5.2)
  ppill(2.0, -3.4, "out", "server validates anyway", c: green, w: 5.2)
  pstep(18.0, -6.6, "x", "step-up, not refusal", "elevated monitoring, fail open", st-dec, n: 4, actor: "", w: 5.8)

  line("in.east", "a.west", mark: (end: ">"), stroke: hot)
  line("a.east", "b.west", mark: (end: ">"), stroke: hot)
  plabel(13.3, 0, "once per session", c: green)
  line("b.east", (20.6, 0), (20.6, -3.4), "d.east", mark: (end: ">"), stroke: lookup)
  line("d.west", "c.east", mark: (end: ">"), stroke: hot)
  plabel(12.1, -3.4, "a signal, not a gate", c: green, dy: 0.62)
  line("c.west", "out.east", mark: (end: ">"), stroke: hot)
  plabel(4.6, -3.4, "default-deny policy", c: green, dy: 0.88)
  line("d.south", (13.6, -6.6), "x.west", mark: (end: ">"), stroke: except)
  content((15.5, -5.2), dlbl("rooted, or an outage", sz: 6.3pt, c: red))
  content((5.6, -6.6), dlbl("a stolen IP proves nothing; sidecars cost ~25–50 GB of RAM\nacross 500 pods, which is a line item in M30", sz: 6.5pt, c: purple))
}))
#pcards(
  [Hour-long certs rotated by the mesh CA — hand-managed certificates expire at 2am on a holiday. Default-deny policy with a test that an unauthorised call is refused.],
  [In: a device attestation at session start and a workload identity on every hop. Out: an authorised call, or a step-up challenge — never a flat refusal.],
  [SPIFFE / Istio or Linkerd · Apple App Attest and Play Integrity, ~10M attestations/day at 10M sessions · server-side validation of every claim],
)
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: blue, weight: "bold")[Mutual TLS] gives every workload a short-lived certificate
  carrying a cryptographic identity (SPIFFE). Both sides verify, so a compromised pod cannot
  impersonate another service merely by reaching it on the network. Authorisation policy is then
  written against #underline(stroke: 1pt + green)[identity] --- "the checkout service may call
  payments" --- rather than against IP ranges that change on every deploy.
  #note[The practical win is certificate rotation: a mesh issues hour-long certs automatically.
  Hand-managed service certificates expire at 2am on a public holiday, which is the single most
  common self-inflicted outage in this area.]
]
#v(2mm)

#h2("2 · Client attestation — proving the app is real", c: purple)

#text(size: 9pt)[
  A mobile API faces a harder problem than a service mesh: you cannot ship a secret in a binary
  that anyone can decompile. #text(fill: purple, weight: "bold")[Attestation] moves the proof to
  the platform. #text(fill: green, weight: "bold")[Apple DeviceCheck / App Attest] and
  #text(fill: green, weight: "bold")[Android Play Integrity] have the OS vouch, via hardware-backed
  keys, that the request comes from an unmodified build of your app on a genuine, non-rooted
  device.
]
#v(2mm)

#table(
  columns: (auto, 1fr, auto, auto),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.5pt, fill: purple)[Control],
  text(font: headfont, size: 8.5pt, fill: purple)[Stops],
  text(font: headfont, size: 8.5pt, fill: purple)[Defeated by],
  text(font: headfont, size: 8.5pt, fill: purple)[Verdict],

  text(size: 8.3pt)[API key in app],
  text(size: 8pt)[Nothing — extractable in minutes],
  text(size: 8.3pt, fill: red)[`strings`],
  text(size: 8.3pt, fill: red)[theatre],

  text(size: 8.3pt)[Cert pinning],
  text(size: 8pt)[Casual proxy interception],
  text(size: 8.3pt, fill: orange)[Frida on a rooted device],
  text(size: 8.3pt, fill: orange)[speed bump],

  text(size: 8.3pt, fill: green)[Play Integrity / App Attest],
  text(size: 8pt)[Emulators, repackaged apps, most bot farms],
  text(size: 8.3pt, fill: orange)[Real devices at scale],
  text(size: 8.3pt, fill: green)[raises cost],

  text(size: 8.3pt, fill: green)[Server-side validation],
  text(size: 8pt)[Everything the client claims],
  text(size: 8.3pt, fill: green)[nothing],
  text(size: 8.3pt, fill: green)[the real control],
)
#v(1.5mm)

#key[
  Attestation #underline(stroke: 1pt + green)[raises the attacker's cost]; it never establishes
  trust. Every control on the device can eventually be bypassed by someone sufficiently
  motivated, so attestation is a #text(fill: orange, weight: "bold")[signal] feeding a risk score
  --- not a gate whose pass means the request is safe. The server still validates every claim as
  if the client were hostile, because sometimes it is.
]
#v(2mm)

#h2("3 · Capacity arithmetic", c: orange)

#formula("mTLS and attestation overhead")[
  #text(size: 8.6pt)[
    #text(weight: "bold")[mTLS handshake:] ~1–2 ms extra per #emph[new] connection, plus
    certificate verification. With connection pooling and keep-alive this amortises to
    #underline(stroke: 1pt + green)[near zero] per request — but a service that opens a fresh
    connection per call pays it every time.
    #linebreak()
    #text(weight: "bold")[Sidecar cost:] each proxy adds ~0.5–1 ms p99 and consumes
    ~50–100 MB RAM plus a fraction of a core. Across #text(weight: "bold")[500 pods] that is
    #text(fill: orange, weight: "bold")[~25–50 GB of RAM] spent on the mesh — a real line item
    (M30), and the reason sidecar-less meshes exist.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Attestation:] a Play Integrity verdict takes
    #text(fill: red, weight: "bold")[500–2,000 ms] and is rate-limited by the platform. It cannot
    sit on every request.
    #linebreak()
    #text(fill: green)[Correct pattern:] attest once at session start, issue a short-lived
    attested token, and have subsequent requests present the token. 10M daily sessions #sym.arrow.r
    #text(fill: green, weight: "bold")[10M attestations/day] rather than per-request, and the
    latency lands on login rather than on the hot path.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[Certificate expiry.] The mesh CA cert expires and every
  service-to-service call fails simultaneously --- a total outage from a calendar event.
  #text(fill: green)[Fix:] automated rotation with alerting well before expiry, and treat the
  root CA's expiry date as a tracked operational risk with an owner.

  #text(fill: red, weight: "bold")[Attestation as a hard gate.] Play Integrity has an outage, or
  a legitimate user is on a device that fails the check (a custom ROM, a corporate-managed phone),
  and they #underline(stroke: 1pt + red)[cannot use the app at all].
  #text(fill: green)[Fix:] treat the verdict as a risk signal — allow the session with elevated
  monitoring or a step-up challenge rather than a flat refusal, and fail open when the attestation
  service itself is unreachable.

  #text(fill: red, weight: "bold")[Trusting client-side validation.] The app checks that the
  amount is positive, so the server does not. An attacker using a modified client posts a negative
  amount. #text(fill: green)[Fix:] the client validates for
  #underline(stroke: 1pt + green)[user experience]; the server validates for correctness. Always
  both, never only the first.

  #text(fill: red, weight: "bold")[Mesh policy that fails open.] A misconfigured or missing policy
  silently permits all traffic. #text(fill: green)[Fix:] default-deny with explicit allow rules,
  and a test asserting that an unauthorised service-to-service call is refused.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: How do you stop a bot farm abusing your mobile API?]
  #linebreak()
  Layer it: attestation at session start as a risk signal, per-identity rate limiting (M13),
  behavioural detection, and server-side validation of everything. Accept that you raise cost
  rather than achieve prevention. #note[Testing: do you promise to stop it? The honest answer is
  that you make it uneconomic — which is also the correct one.]

  #text(fill: green, weight: "bold")[Q: What does mTLS give you that TLS does not?]
  #linebreak()
  The server verifies the client's identity too, so authorisation can be written against
  cryptographic workload identity instead of network location.
  #note[Testing: the shift from perimeter to identity. Mentioning automatic rotation shows
  operational experience.]

  #text(fill: green, weight: "bold")[Q: Is certificate pinning worth it?]
  #linebreak()
  It stops casual interception and complicates debugging; a rooted device with Frida defeats it.
  Worth it for high-value apps, with a remote kill switch in case a pin must change.
  #note[Testing: proportionality, and awareness that a bad pin can brick your app in the field.]
]
#v(2mm)

#anti("trusting the client because it attested")[
  The API verifies a Play Integrity token and, having established that the app is genuine, skips
  server-side validation on the requests that follow --- accepting the client's claimed price,
  claimed user id, and claimed permissions. An attacker obtains a valid attestation from a real
  device, then replays or modifies requests under that session. Attestation proved the
  #underline(stroke: 1pt + red)[app binary] was genuine at one moment; it proved nothing about any
  individual request afterwards. #text(fill: green)[Fix:] attestation adjusts a risk score and
  nothing more. Every request is still authenticated, authorised and validated server-side as
  though the client were hostile.
]
