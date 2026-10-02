#import "/shared/lib/template.typ": *
#reg(1, "M18", "Authentication & Identity")
#chapterhead("Part 2 · Modules", "M18 · Authentication & Identity")
#ix("OAuth 2.0")
#ix("PKCE")
#ix("JWT")
#ix("Refresh token rotation")

#h1("M18 · Authentication & Identity", c: red)

#text[
  Two words that get conflated and must not be.
  #text(fill: blue, weight: "bold")[Authentication] establishes who the caller is.
  #text(fill: red, weight: "bold")[Authorisation] decides what they may do.
  OAuth 2.0 is a #underline(stroke: 1pt + green)[delegated authorisation] framework; OIDC is the
  thin identity layer on top of it. Using OAuth alone to "log in" is the classic mistake.
]
#v(2mm)

#h2("1 · Authorisation code flow with PKCE", c: blue)

#align(center, cetz.canvas(length: 0.82cm, {
  import cetz.draw: *
  swimlane(-0.4, -2.3, 18.4, 2.3, "OAuth 2.0 + PKCE — the only correct flow for mobile/SPA", blue,
    rgb("#f4f8fd"))
  rnode(2.6, 1.2, "app", "app", "no secret possible", purple, w: 3.4, h: 0.9)
  rnode(8.4, 1.2, "auth", "auth server", "verifies challenge", blue, w: 4.0, h: 0.9)
  rnode(14.6, 1.2, "api", "resource API", "validates token", green, w: 4.0, h: 0.9)

  line("app.east", "auth.west", mark: (end: ">"), stroke: hot); badge(5.5, 1.75, "1", green)
  content((5.5, 0.55), dlbl("code_challenge = S256(verifier)", sz: 6.1pt, c: blue))
  line("auth.west", (6.4, -0.1), (2.6, -0.1), "app.south", mark: (end: ">"), stroke: lookup)
  badge(4.5, -0.1, "2", green)
  content((5.5, -0.65), dlbl("auth code (useless alone)", sz: 6.1pt, c: purple))
  line("app.south", (2.6, -1.3), (8.4, -1.3), "auth.south", mark: (end: ">"), stroke: hot)
  badge(5.5, -1.3, "3", green)
  content((5.5, -1.85), dlbl("code + verifier -> tokens", sz: 6.1pt, c: green))
  line("app.north", (2.6, 2.0), (14.6, 2.0), "api.north", mark: (end: ">"), stroke: hot)
  badge(8.6, 2.0, "4", green)
  content((11.8, 0.55), dlbl("Bearer access token", sz: 6.1pt, c: green))
  bracket(0.6, 17.4, -2.6, "PKCE binds the code to the client that requested it — a stolen code is useless", purple)
}))
#v(1.5mm)

#text(size: 9pt)[
  #text(fill: purple, weight: "bold")[Why PKCE exists.] A mobile app cannot keep a client
  secret --- anyone can unpack the binary. Without PKCE, an attacker who intercepts the
  authorisation code (via a registered custom URL scheme, say) can redeem it. PKCE has the client
  generate a random `verifier`, send only its SHA-256 `challenge` up front, and present the
  verifier at redemption. #underline(stroke: 1pt + green)[The code is worthless to anyone who
  did not originate the request.] Mandatory for all public clients under OAuth 2.1.
]
#v(2mm)

#h2("2 · JWT vs. opaque tokens", c: purple)

#table(
  columns: (auto, 1fr, 1fr),
  stroke: (x, y) => (
    top: if y == 0 { 1.4pt + ink } else if y == 1 { 1.1pt + ink } else { 0.5pt + luma(190) },
    bottom: 0.5pt + luma(190), left: none, right: none),
  fill: (x, y) => if y == 0 { rgb("#f5eefa") } else { none },
  text(font: headfont, size: 8.5pt, fill: purple)[Aspect],
  text(font: headfont, size: 8.5pt, fill: purple)[JWT (self-contained)],
  text(font: headfont, size: 8.5pt, fill: purple)[Opaque (reference)],

  text(size: 8.3pt)[Validation],
  text(size: 8pt, fill: green)[Local signature check — no network call],
  text(size: 8pt, fill: orange)[Lookup in a store on every request],

  text(size: 8.3pt)[Revocation],
  text(size: 8pt, fill: red)[#underline(stroke: 1pt + red)[Impossible] before expiry without a blocklist],
  text(size: 8pt, fill: green)[Delete the row — effective immediately],

  text(size: 8.3pt)[Size],
  text(size: 8pt, fill: orange)[0.5–2 KB on every request],
  text(size: 8pt, fill: green)[~32 bytes],

  text(size: 8.3pt)[Claims],
  text(size: 8pt, fill: green)[Carried in the token],
  text(size: 8pt, fill: orange)[Fetched with the lookup],

  text(size: 8.3pt)[Failure mode],
  text(size: 8pt, fill: red)[A leaked token is valid until it expires],
  text(size: 8pt, fill: orange)[The token store is on the critical path],
)
#v(1.5mm)

#key[
  #text(fill: green, weight: "bold")[The standard compromise:] a short-lived JWT access token
  (5–15 minutes, validated locally) plus a long-lived opaque refresh token (stored server-side
  and revocable). Revocation latency equals access-token lifetime, which is the knob you tune.
  #underline(stroke: 1pt + red)[A 24-hour JWT is a 24-hour window in which a stolen token works
  and you cannot stop it.]
]
#v(2mm)

#h2("3 · Refresh token rotation", c: green)

#text(size: 9pt)[
  Every refresh issues a #text(fill: green, weight: "bold")[new] refresh token and invalidates
  the old one. If an old token is ever presented again, either it was stolen and replayed, or the
  legitimate client lost the response --- and you cannot tell which.
  #text(fill: red, weight: "bold")[Treat it as compromise: revoke the entire token family] and
  force re-authentication.
  #note[This creates a real failure case: a mobile client that refreshes and then loses
  connectivity before storing the new token is locked out and must log in again. Mitigate with a
  short grace window in which the previous token is still accepted
  #underline(stroke: 1pt + green)[once], not indefinitely.]
]
#v(2mm)

#formula("Token store sizing and validation cost")[
  #text(size: 8.6pt)[
    10M MAU, average 2 devices #sym.arrow.r
    #text(fill: orange, weight: "bold")[20M active refresh tokens], ×200 B =
    #text(weight: "bold")[4 GB] — comfortably in Redis.
    #linebreak()
    Access tokens at 15 min #sym.arrow.r each device refreshes 4×/hour #sym.arrow.r
    20,000,000 × 4 / 3,600 = #text(fill: orange, weight: "bold")[22,222 refreshes/s] at steady
    state. #underline(stroke: 1pt + red)[That is a significant service in its own right] — size
    and shard it accordingly, and rate-limit per identity.
    #linebreak() #v(1mm)
    #text(weight: "bold")[Lifetime trade-off:] 5 min #sym.arrow.r 66k refreshes/s and a 5-minute
    revocation window; 60 min #sym.arrow.r 5.5k refreshes/s and a 60-minute window. Pick from the
    #text(fill: purple)[threat model], not from convenience.
  ]
]
#v(2mm)

#h2("4 · Failure modes", c: red)

#text(size: 9pt)[
  #text(fill: red, weight: "bold")[`alg: none`.] A naive verifier reads the algorithm from the
  token header, and an attacker sets it to `none` with no signature.
  #text(fill: green)[Fix:] pin the expected algorithm server-side; never trust the header. Also
  reject HS256 where RS256 is expected --- the classic confusion attack passes the public key as
  an HMAC secret.

  #text(fill: red, weight: "bold")[Tokens in `localStorage`.] Any XSS on the page exfiltrates
  them. #text(fill: green)[Fix:] `HttpOnly`, `Secure`, `SameSite` cookies for web; iOS
  #text(fill: purple)[Keychain] and Android #text(fill: purple)[Keystore / EncryptedSharedPreferences]
  for mobile — never plain app storage or a logfile.

  #text(fill: red, weight: "bold")[No key rotation.] One signing key used for years; a single
  leak compromises everything retroactively. #text(fill: green)[Fix:] publish a JWKS endpoint
  with `kid` in the header, rotate on a schedule, and keep the previous key valid for one token
  lifetime.

  #text(fill: red, weight: "bold")[Clock skew rejects valid tokens.] A server 60 s ahead rejects
  freshly-issued tokens as not-yet-valid. #text(fill: green)[Fix:] allow a small `nbf`/`exp`
  leeway (30–60 s) and keep NTP healthy.
]
#v(2mm)

#h2("5 · Interview guide", c: green)

#text(size: 8.8pt)[
  #text(fill: green, weight: "bold")[Q: How do you revoke a JWT?]
  #linebreak()
  You cannot, by design. You either keep lifetimes short enough that expiry is the revocation, or
  add a blocklist — which reintroduces the lookup JWTs were meant to avoid.
  #note[Testing: do you know the limitation you are buying? Candidates who claim JWTs are
  revocable have not operated them.]

  #text(fill: green, weight: "bold")[Q: Why PKCE for a mobile app?]
  #linebreak()
  Public clients cannot hold a secret, so an intercepted authorisation code would otherwise be
  redeemable by anyone. PKCE binds the code to the originating client.
  #note[Testing: whether you understand the threat rather than reciting the acronym.]

  #text(fill: green, weight: "bold")[Q: Where does a mobile app store tokens?]
  #linebreak()
  Keychain on iOS, Keystore-backed storage on Android — hardware-backed where available, never
  plain preferences and never in logs. #note[Testing: platform-specific security knowledge.
  Worth saying that crash reporters routinely upload storage unless configured not to.]
]
#v(2mm)

#anti("the long-lived access token")[
  To avoid the complexity of refresh, a team issues 30-day JWTs. A token leaks through a logged
  URL, a crash report, or an exploited XSS. For #text(fill: red, weight: "bold")[30 days] the
  attacker has full access, you cannot revoke it, you cannot detect use (it validates locally, so
  there is no server-side record of it being presented), and the only remedy is rotating the
  signing key — which logs out #underline(stroke: 1pt + red)[every user on every device].
  #text(fill: green)[Fix:] 15-minute access tokens with rotating refresh tokens. The complexity
  you avoided is exactly the mechanism that contains the breach.
]
