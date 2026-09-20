# AITP — Spec Errata: Prose vs. Byte-Pinned Vectors

> **Relocated and re-statused 2026-09-19 (issue #48).** This file lived at
> `plans/spec-errata-from-independent-verifier-2026-07.md`, excluded from git via
> `.gitignore:95`'s `plans/` rule — invisible to anyone who clones this repo, including
> the external audit that filed issue #48 after finding it asserted a broken world that
> had already been fixed. It is tracked here going forward, filename unchanged for
> stable inbound references (several cross-repo tracking issues cite it by name). The
> historical narrative below is otherwise unchanged — it is the working record of what
> was found and why each resolution was chosen — but every claim about *current* status
> has been re-verified against the trees as they stand today and corrected where stale.
> See the **Current status** section immediately below the original status line, and the
> checked-off **Action items** at the bottom.

*Errata 1–2 surfaced by the independent verifier, 2026-07. Errata 3–5 added 2026-08-24 from the cross-implementation signing-input audit (W-P5). Filename retained for stable inbound references.*

**Errata 1–2** surfaced while building **`aitp-verifier-py`**
([repo](https://github.com/agentidentitytrustprotocol/aitp-verifier-py)), the
independent second implementation of the AITP v0.2 verification core required by
`VERSIONING.md`'s Draft→Final "two independent implementations interoperate"
gate. That implementation was written from the RFC texts and JSON schemas only
(no code shared with `aitp-rs`), which is exactly why these surfaced: each is a
place where an implementation coding to the **prose** diverges from the
**byte-pinned conformance vectors**, or where the vectors cannot be
independently re-minted at all. Both block the two-implementation gate for the
affected fixtures.

**Errata 3–5** were found later (2026-08) by a direct cross-implementation audit
of the JCS signing inputs — *not* by a conformance run, because a conformance run
structurally cannot see them. Every fixture involved passes on both
implementations today while the two stacks hash different byte strings; the
mechanism is set out under Erratum 3, "Why the conformance suite is blind to
this," and it applies unchanged to Erratum 4.

**Retraction (2026-08-24).** An earlier revision of this file stated, of errata 1
and 2: *"Neither is a wire-format change to any shipped artifact — they are a
documentation correction and a test-vector completeness fix."* That sentence is
**withdrawn** as a statement about this document. It remains true of errata 1, 2
and 5. It is false of errata 3 and 4: each changes the bytes an issuer signs for
a shipped artifact, and each requires re-minting a real, committed signature
under `schemas/conformance/known-answer/`. The sentence is recorded here rather
than quietly deleted, because a standing assurance that this family of findings
is never a wire-format change is part of why the divergence went unexamined.

Status: **proposed** (all five) · Found-by: errata 1–2 — `aitp-verifier-py`
conformance run; errata 3–5 — cross-implementation signing-input audit (W-P5),
2026-08-24 · Reference clock and vectors: `schemas/conformance/known-answer/`.

## Current status (updated 2026-09-19, issue #48)

**All five errata are shipped.** Verified directly against the current trees, not
assumed from titles:

| Erratum | Spec-side | Reference-implementation side |
|---|---|---|
| 1 — pinned-key timestamp encoding | RFC-AITP-0002 §3.1 now specifies `timestamp_ascii_decimal` and carries the erratum sentence; `kat-pinned-key-proof-001` is pinned in `jcs-sha256.json` | `aitp-rs` #136, closed |
| 2 — `mh-002` attacker key | `kat-keypair-006-attacker` published in `known-answer/keypairs.json`; `PLACEHOLDERS.md`'s hint corrected | closed with the spec-side fix (no implementation change needed) |
| 3 — revocation snapshot inner body | `kat-revocation-001` and `signed-examples/revocation/kat-keypair-001-snapshot.json` both sign the inner body; RFC-AITP-0008 §1.5 states it | `aitp-rs` #82, closed |
| 4 — session bundle inner body | `kat-session-bundle-001` and `signed-examples/session-bundle/kat-keypair-001-bundle.json` both sign the inner body; RFC-AITP-0010 §3/§4.2/§5 and RFC-AITP-0001 §5.4.1 state the general rule | `aitp-rs` #82, closed |
| 5 — `max_hops` naming | n/a (implementation-only) | `aitp-rs` #82, closed |

The **"What is NOT yet cross-checked"** table below, as originally written, said the
two-implementation gate was **not** satisfied for revocation and session-bundle signing
inputs. That is no longer true: `aitp-rs` adopted the inner-body convention (its #82),
both implementations now agree, and a required cross-impl CI gate (`aitp-rs`'s
`cross-impl acceptance` job, invoking `aitp-verifier-py` across the language boundary)
runs both mint-here-verify-there directions on every PR. The gate's coverage is not yet
exhaustive — see `aitp-rs`#148 (manifest not covered by the gate) and `aitp-rs`#150 (a
path-filter and a directional-output gap in the gate's own CI wiring) — but those are
narrower, separately tracked follow-ups, not a reopening of errata 3 or 4.

This document is kept as the historical record of what was found and why each
resolution was chosen; it is no longer a live "proposed" list. New findings belong in a
new dated entry in `governance/DECISIONS.md` or a new errata file, not appended here.

---

## Erratum 1 — Pinned-key proof: timestamp is ASCII-encoded, not big-endian

### What the prose says

RFC-AITP-0002 §3.1 defines the pinned-key identity proof input as:

```
proof_input =
    "aitp-pinned-key-v1\0"
    || sender_aid_bytes      || "\0"
    || receiver_aid_bytes    || "\0"
    || message_id_bytes      || "\0"
    || timestamp_be_8_bytes  || "\0"
    || pop_nonce_decoded_bytes
proof = base64url(sign(agent_private_key, sha256(proof_input)))
```

with *"`timestamp_be_8_bytes` is the envelope's `timestamp` encoded as a
big-endian signed 64-bit integer."*

### What the golden vector actually is

The only concrete pinned pinned-key proof in the pack is `id-007`
(`schemas/conformance/id-007-*.json`): a real Ed25519 signature
(`vdLCEPGuUv…`) over the five-field input, produced by `kat-keypair-003`
(`dqFZ…`). Reconstructing that input and verifying the signature:

| Timestamp encoding | Verifies against the pinned `id-007` proof? |
|---|---|
| Big-endian signed 64-bit (`struct.pack(">q", ts)`) — **per the prose** | **No** |
| ASCII decimal string (`b"1711900000"`) | **Yes** |

The reference minter (`aitp-rs`) evidently emits the **ASCII decimal** form, and
the frozen golden vector encodes it. An implementation that follows the prose
literally fails `id-007` — and, more importantly, fails *every* cross-implementation
pinned-key handshake, since the two peers compute different signing bytes.

### Why it matters

The byte-pinned vector is the interop contract; the prose is the description of
it. They disagree, and today the vector wins in practice (it is what ships and
what `aitp-rs` produces). An independent implementer has no way to discover the
ASCII encoding except by reverse-engineering `id-007`.

### Proposed resolution

- **[Recommended] Amend RFC-AITP-0002 §3.1** to specify the timestamp as its
  **ASCII decimal string** (the canonical lowercase integer, no separators),
  matching the frozen vector and the reference minter. No wire change; no
  re-mint; no already-issued proof is invalidated.
  - Suggested wording: *"`timestamp_ascii_bytes` is the envelope's `timestamp`
    rendered as its base-10 ASCII decimal string (e.g. `1711900000` →
    `b"1711900000"`), matching the `message_id` field's string encoding."*
- **Add a pinned KAT** for the five-field proof input under
  `known-answer/` — `(sender, receiver, message_id, timestamp, pop_nonce) →
  proof_input bytes → sha256 → Ed25519 signature` with `kat-keypair-003` — so
  the encoding is unambiguous and machine-checkable, mirroring the existing
  `kat-manifest-pop-001` PoP vector. This is the single most valuable change:
  it converts "read the prose carefully" into "reproduce these bytes."
- *(Rejected alternative)* Re-mint the vectors + reference minter to big-endian
  and keep the prose. This breaks the frozen `id-007` vector and any proof
  already issued in the field; the vector, being deployed, should win.

**Shipped.** RFC-AITP-0002 §3.1 now specifies `timestamp_ascii_decimal` and
carries an erratum sentence citing this document; `kat-pinned-key-proof-001` is
pinned in `known-answer/jcs-sha256.json`, including the negative assertion that
the same signature does not verify under the old big-endian encoding.

---

## Erratum 2 — `mh-002` uses a one-shot key that cannot be independently re-minted

### The problem

`mh-002` (`schemas/conformance/mh-002-*.json`) tests
`MANIFEST_SIGNATURE_INVALID`. Its inline Manifest is signed by an "attacker"
peer whose AID is
`aid:pubkey:OzIbdL3LFp9yYMYFkru2PZtNYpQkoMWK_0ZAp18KKwY` — a key that is **not in
`known-answer/keypairs.json`**. The Manifest carries:

- `proof_of_possession.signature: __VALID_POP_SIG__` — a placeholder that must be
  signed by the attacker's **private** key;
- `signature: __TAMPERED_SIGNATURE__` — sign-then-flip-a-bit, also requiring that
  private key.

RFC-AITP-0003 §5 verifies the **proof-of-possession (step 3) before the Manifest
signature (step 4)**. So for the fixture to reach its intended
`MANIFEST_SIGNATURE_INVALID`, the PoP must first **pass** — which requires a
*valid* PoP signature from the attacker key. `PLACEHOLDERS.md` notes the key is
"generated deterministically from a fixture-only seed (e.g. `0xff × 32`)", but
`0xff × 32` is `kat-keypair-003` (`dqFZ…`), not `OzIbdL…`, and the actual seed
is not published anywhere — only the resulting public AID is pinned.

### Consequence

An independent runner that re-mints the pack from placeholders **cannot
reproduce `mh-002`'s valid PoP**, because it lacks the attacker's seed. A brute
search over the documented seed patterns (single-byte fills, `sha256` of
plausible strings, counters) does not recover it. `aitp-verifier-py` therefore
reports `mh-002` as an explicit **SKIP** — which means the two-implementation
gate is not actually exercised for this fixture. (A runner that consumes
*already-minted* fixtures is unaffected, since it receives the concrete
signatures; the gap is specific to independent re-minting, which is the whole
point of a second implementation.)

### Proposed resolution

- **[Recommended] Publish the attacker keypair** in
  `known-answer/keypairs.json` — e.g. `kat-keypair-006-attacker` with its seed,
  its `pubkey_b64url` = `OzIbdL3LFp9yYMYFkru2PZtNYpQkoMWK_0ZAp18KKwY`, and a note
  that it is an untrusted, non-KAT-role key used only by `mh-002`. Add it to the
  `PLACEHOLDERS.md` AID-role table. This is minimal, preserves the
  placeholder-minting model, and lets both implementations exercise the fixture.
- *(Alternative)* Ship `mh-002` **pre-minted** — concrete PoP + tampered
  signature bytes inline — so no attacker key is needed. Works, but breaks the
  uniform "everything is a placeholder resolved from KAT keys" runner path.
- *(Alternative)* Restructure `mh-002` so the failure is reachable without a
  valid attacker PoP (e.g. make the PoP itself the injected failure, or use a
  KAT-role sender). This changes *what* `mh-002` tests and is the least
  desirable.

Whichever is chosen, `PLACEHOLDERS.md`'s "`e.g. 0xff × 32`" hint should be
corrected — it currently points at an existing KAT key with a different AID.

**Shipped**, with a corrected AID and seed rather than the originally-proposed
one: `kat-keypair-006-attacker` (seed `0xAA × 32`) is published in
`known-answer/keypairs.json`, `mh-002`'s attacker AID now matches it, and
`PLACEHOLDERS.md`'s hint is corrected and cites this document.

---

## Erratum 3 — Revocation snapshot: the vectors pin the transport envelope, the prose specifies the inner body

### What the prose says

RFC-AITP-0008 §1.5, the `signature` row of the field table:

> The signing input is the **inner** `revocation_list` body — the
> `{"revocation_list": {...}, "signature": "..."}` envelope is the wire / HTTP
> transport shape, NOT part of the canonical signing bytes.

The same row already anticipates this migration: *"Implementations migrating from
rc.3-era code (which signed the wrapped form) MAY accept either canonical shape
during a transition window but MUST emit the inner form going forward."*

### What the golden vectors actually are

Both pinned artifacts sign the **wrapped** form. Recomputed 2026-08-24 (JCS per
RFC 8785; JCS-profile signature is `Ed25519(sk, sha256(canonical_bytes))`):

| Artifact | Signing input as pinned | JCS len | SHA-256 |
|---|---|---|---|
| `known-answer/jcs-sha256.json` → `kat-revocation-001` | `{"revocation_list": {…}}` — **wrapped** | 241 | `739feb36cc2530ad3188f6c3a9ee7459820533382ee24387a8c261787397e0d9` |
| …what RFC-0008 §1.5 specifies | inner `revocation_list` body | 221 | `dad7eb6db48c924ef30de7c20a6702715b512dd8aee12c9eed33139ba7008bfb` |
| `known-answer/signed-examples/revocation/kat-keypair-001-snapshot.json` | real Ed25519 signature — verifies over **wrapped** (268 B, `b4376892…`), fails over inner (248 B, `408df09e…`) | — | — |

And the two implementations split the same way:

| Implementation | Revocation signing input | Manifest signing input |
|---|---|---|
| `aitp-rs` `crates/aitp-tct/src/revocation.rs` (`RevocationListSigningView`) | **wrapped** | **inner** (`crates/aitp-manifest/src/builder.rs`, `ManifestSigningView`) |
| `aitp-verifier-py` `aitp_verifier/revocation.py:35` | **inner** | **inner** (`aitp_verifier/manifest.py:43`) |
| RFC prose | inner (§1.5) | inner (RFC-0003 §6.1) |

The Manifest is the control case, and it is decisive: **both** implementations
sign the inner Manifest, and both therefore disagree with `kat-manifest-001`,
which is wrapped exactly like `kat-revocation-001`. Nobody noticed, because for
the Manifest and the bundle no test drives a KAT vector through a *signing view*
— implementations only canonicalize whichever object the vector hands them. That
is the tell that the defect is in the vector file, not in one implementation.

For revocation, one test does exactly that, and it is the direct evidence that
the vector is what the code followed: `aitp-rs`
`crates/aitp-tct/src/revocation.rs:216-247` (`rfc_kat_canonical_bytes_match`)
canonicalizes through the live `RevocationListSigningView` and asserts the result
equals `kat-revocation-001`'s pinned hex and digest, under a comment reading
*"signed view is the wrapped `{"revocation_list": {...}}` form"*. The vector was
read as normative for the signing input, which is precisely how it should be read
given how the RFCs cite it — and precisely why it must be correct.

### Why the conformance suite is blind to this

`schemas/conformance/rev-003-success.json` carries
`"signature": "__VALID_A_SIG__"` — a **placeholder**. Each implementation's
minting tool substitutes it by signing under **its own** convention
(`aitp-verifier-py/aitp_verifier/minter.py:164-169` signs
`canonicalize(body)`), and its own verifier then checks it under that same
convention. Each stack is internally self-consistent, so `rev-001`…`rev-004` pass
on both sides while the wire formats disagree. Re-minting is the escape hatch: a
fixture that is re-signed before it is verified cannot detect a signing-input
divergence, only a canonicalization one.

This is a defect in the fixture **design**, not a missing fixture. The
`known-answer/signed-examples/` directory exists precisely to close it — its
README requires that files there "MUST verify under any conformant AITP v0.2
implementation, byte-for-byte, without any placeholder substitution". What is
missing is not the fixtures but a *second* execution of them:

| Signed example | `aitp-rs` | `aitp-verifier-py` | This repo's CI |
|---|---|---|---|
| `signed-examples/manifest/…-manifest.json` | verifies it — `crates/aitp-cli/tests/cli.rs:210-237` reads the file and pipes it through `aitp manifest verify` | **never executes it** — `tests/test_signed_examples.py` covers only the three compact-JWS artifacts | schema only (`scripts/validate-json.sh:261-265`) |
| `signed-examples/revocation/…-snapshot.json` | verifies it — `crates/aitp-tct/src/revocation.rs:249-276` pins its exact signature string and re-verifies | **never executes it** | schema only |

So each file *is* executed — by exactly one implementation, under that
implementation's own convention. The revocation snapshot passes in `aitp-rs`
because `aitp-rs` signs the same wrapped form the file was minted with. A fixture
executed by one side proves self-consistency, not interoperability; that is the
same property re-minting has, arrived at a different way.

The vector harness is weaker still. `aitp-rs`'s `signing_input` helper
(`crates/aitp-core/tests/kat.rs:14-30`, called at `:74`) **auto-detects** which
shape a vector's pinned bytes are in and adapts to it. Its own comment (`:62-73`)
states the rule: *"if the canonical hex starts with `{"<wrapper_key>"` we use the
wrapped form; otherwise unwrap once"*. It therefore passes
whichever form the vector carries and can never fail on this defect. Its own
comment asserts that the session-bundle and multi-hop vectors "are the *inner
signing body*", which is false: `kat-session-bundle-001`'s pinned bytes are the
wrapped 941. A test that adapts to its input is not a pin, and a comment that
describes a shape no vector uses is a third instance of the propagation-by-comment
mechanism described under Erratum 4.

Net: the detector was built, and every consumer of it either points away from the
bug or reshapes itself around it.

### Why it matters

An `aitp-rs` issuer and an `aitp-verifier-py` consumer hash different byte
strings, so the snapshot signature never validates across the pair. Under
`fail_closed` (`aitp_verifier/revocation.py:30,41-45`) a snapshot that fails to
verify is "no fresh snapshot", which surfaces as `TCT_REVOKED` — every TCT
checked against a cross-implementation snapshot is reported revoked. It fails
shut, not open: an availability failure, not a silent accept. But it is a
guaranteed one, on first contact, in the revocation path specifically.

### Proposed resolution

- **[Recommended] Regenerate the vectors to the inner body and re-mint the signed
  example.** `kat-revocation-001`'s `object` becomes the inner `revocation_list`
  value with recomputed canonical bytes and digest, and
  `signed-examples/revocation/kat-keypair-001-snapshot.json` is re-signed over the
  inner body. Prose is unchanged: RFC-0008 §1.5 already says inner and already
  sanctions this exact migration. `aitp-rs` moves to the inner signing view.
  Vectors MUST be produced by executing a reference implementation, never
  hand-transcribed — hand-transcription is the mechanism that produces this class
  of bug.
- **Fix `kat-manifest-001` in the same change.** It is wrong in exactly the same
  way and only escapes consequence because both implementations happen to ignore
  it. Leaving it is leaving a vector that contradicts RFC-0003 §6.1 and both
  implementations.
- **Make the vector file state its own answer.** Each vector carries an explicit
  machine-readable declaration of what its pinned bytes are the signing input
  *for*. Three RFCs demand byte-for-byte reproduction of this file from inside a
  signing section — RFC-AITP-0003 §6.1 (`:188`) and RFC-AITP-0008 §1.5 (`:87`)
  with the exact words "implementations MUST reproduce it byte-for-byte", and
  RFC-AITP-0001 §5.4.1 (`:382`) with "MUST reproduce both the canonical byte
  sequence and the digest byte-for-byte". (RFC-AITP-0010 cites the vector in §9
  without any such wording, which is its own gap — Erratum 4.) A file addressed
  that way must not leave the question of *which bytes* to the reader.
- **Execute the pinned values in CI.** Recompute every pinned canonical byte
  sequence and verify every pinned signature on every PR, and assert that no
  JCS-profile vector declares the envelope as its signing input. Without this the
  correction is a point fix and the next divergence lands the same way.
- *(Rejected alternative)* Amend RFC-0008 §1.5 to bless the wrapped form and keep
  the digests. This contradicts RFC-AITP-0003 §6.1, contradicts RFC-AITP-0011's
  stated convention that §1.5 itself cites, and contradicts both implementations'
  Manifest behavior — it would require re-minting the *correct* Manifest signed
  example to match a wrong vector. More artifacts change, more prose changes, and
  the outcome is worse.

**Shipped.** `kat-manifest-001`, `kat-revocation-001` and
`signed-examples/revocation/kat-keypair-001-snapshot.json` all sign the inner
body; every JCS-profile vector in `jcs-sha256.json` carries a `signing_input`
declaration read and asserted by `scripts/verify-known-answer.mjs`; `aitp-rs`
moved both signing views to the inner body in its #82. Both implementations now
agree, and a required cross-impl CI gate exercises both directions on committed
bytes (see **Current status** above).

---

## Erratum 4 — Session Trust Bundle: same divergence, and the rule is never stated

### What the prose says

RFC-AITP-0010 §3's field table (`:90`): *"Coordinator's signature over the
canonical `session_bundle` JSON (excluding `signature`)."* §4.2 step 4 (`:107`):
*"Sign the canonical JCS bytes of the body (excluding `signature`)."* §5's
verification step 6 (`:150`): *"verify `session_bundle.signature` against the
coordinator's key over the canonical body."*

Note what is missing. RFC-AITP-0003 §6.1 has a titled section, "What is signed,"
that says the wrapper is transport-only and verifiers MUST unwrap. RFC-AITP-0008
§1.5 says the same thing inside a field-table cell. **RFC-AITP-0010 does not say
it anywhere.** "The canonical `session_bundle` JSON" is exactly as readable as
"the object under the `session_bundle` key" as it is as "the inner body," and the
RFC displays the wrapped form throughout §3.

### What the golden vector actually is

| Artifact | Signing input as pinned | JCS len | SHA-256 |
|---|---|---|---|
| `kat-session-bundle-001.object` | `{"session_bundle": {…}}` — **wrapped** | 941 | `dc99e7252ab25d2896eb2468d32b8d33b48a62150525ece727038cc29b4f2640` |
| …the inner body | inner `session_bundle` value | 922 | `c577854d144c912e145e8ec6cbab09361ceb709a43be5cbd1ef538085b1aa5e5` |

`kat-session-bundle-001` also pins `coordinator_signature_b64url`, a **real
Ed25519 signature under `kat-keypair-001`**. Verified 2026-08-24: it validates
over the wrapped 941 bytes and fails over the inner 922. This is the fact that
settles what kind of file `jcs-sha256.json` is — a vector that commits a
signature over the wrapper is asserting the wrapper is the signing input,
whatever the file's title says. It cannot be treated as a pure canonicalization
vector and left alone.

| Implementation | Bundle signing input |
|---|---|
| `aitp-rs` `crates/aitp-session-bundle/src/builder.rs` (`BundleSigningView`) | **wrapped** |
| `aitp-verifier-py` `aitp_verifier/sessionbundle.py:51` | **inner** |

The `aitp-rs` builder's doc comment cites `kat-session-bundle-001` and describes
the choice as "same convention as the revocation snapshot." That is how a single
misread vector became two divergent artifacts: the comment is not a bug report,
it is the propagation path, and correcting the code without correcting the
comment leaves the mechanism intact.

### Why the conformance suite is blind to this

Identical to Erratum 3, and by the same placeholder.
`schemas/conformance/bundle-001-success.json`, `bundle-002`, `bundle-003` all
carry `"signature": "__VALID_A_SIG__"`, re-minted per-implementation before
verification. `bundle-001`'s own `$comment` describes the input as "the
JCS-canonical `session_bundle` bytes excluding nothing" — wording that reads as
an instruction to include the wrapper.

`PLACEHOLDERS.md`'s `__VALID_A_SIG__` row is the root of the ambiguity:
*"Context-dependent — typically an envelope signing input; minting tool resolves
from surrounding fixture shape."* A placeholder whose signing input is defined as
"whatever the minting tool decides" cannot detect two minting tools deciding
differently.

### Why it matters

Lower severity than Erratum 3 only because RFC-AITP-0010 is Draft and opt-in. The
failure mode is `BUNDLE_INVALID_SIGNATURE` on every cross-implementation bundle,
and per §5 a bundle whose signature does not validate MUST NOT be consumed
regardless of the validity of the TCTs inside it — so one convention mismatch
discards an entire session roster.

### Proposed resolution

- **[Recommended] Regenerate `kat-session-bundle-001` to the inner body and
  re-mint `coordinator_signature_b64url` over the inner bytes**, via a reference
  implementation. Move `aitp-rs`'s `BundleSigningView` to the inner form and
  correct the doc comment that cites the vector as the authority for the wrapped
  one.
- **State the rule in RFC-AITP-0010.** Add the unwrap sentence to §3's
  `signature` row and §4.2's construction step, matching RFC-AITP-0003 §6.1's
  wording, and add the general rule to RFC-AITP-0001 §5.4.1 where the JCS profile
  is defined: for every JCS-profile artifact carried inside a single-key transport
  wrapper, the wrapper key is routing metadata and is never part of the signing
  bytes. Stating it once centrally is what prevents a fourth instance; restating
  it at each signing site is what makes each RFC correct read standalone.
- **Narrow `__VALID_A_SIG__`** in `PLACEHOLDERS.md` from "context-dependent" to an
  explicit per-context table, and correct `rev-003` / `bundle-001`'s `$comment`
  text. These are where the ambiguity is written down.
- *(Rejected alternative)* Keep the wrapped form for the bundle only, on the
  grounds that RFC-AITP-0010 is Draft and never said otherwise, and define the
  wrapper as part of the bundle's signing input. This would make the session
  bundle the sole JCS-profile artifact whose wrapper is signed, contradicting the
  general rule RFC-AITP-0001 §5.4.1 should state, and would leave `aitp-rs`'s
  "same convention as the revocation snapshot" comment true only by accident once
  revocation moves. One convention across all three artifacts is worth more than
  one avoided re-mint of a Draft vector.

**Shipped**, and then corrected again: the schema/fixtures were flipped to inner
placement in PR #30 (spec issue #23), `aitp-rs` moved `BundleSigningView` to the
inner body in its #82, and RFC-AITP-0001 §5.4.1 now states the general
redistributable-vs-point-to-point placement principle (the sentence the original
"same convention as the revocation snapshot" comment lacked). A
`signed-examples/session-bundle/` fixture now exists (issue #32) so the bundle
gets the same verify-as-committed coverage as the manifest and revocation
snapshot, closing the last gap this erratum named.

---

## Erratum 5 — Spec and implementation name the hop limit differently

### The divergence

| Source | Name |
|---|---|
| RFC-AITP-0011 §2, where the knob is defined (lines 91, 103, 105) | `max_delegation_hops` |
| RFC-AITP-0011 §7 error table (191), §8 conformance (202), §9 security (224) | `max_delegation_hops` |
| RFC-AITP-0006 §9 (line 200) | `max_delegation_hops` |
| `aitp-rs` `crates/aitp-delegation/src/verifier.rs:41` | `max_hops` |
| `aitp-rs` `crates/aitp-delegation/src/verifier.rs:17-18` — the doc comment on the `DEFAULT_MAX_HOPS` constant (`:19`), which supplies the `max_hops` field at `:41` | `max_delegation_hops` (the implementation's own comment uses the spec name for the knob its code calls `max_hops`) |

Same class as errata 3 and 4 — the spec and the implementation using different
names for one normative thing — and the third instance of it in this document,
which is the reason it is recorded rather than filed as a nit.

### Why it matters (and why it is minor)

No bytes and no wire format depend on the knob's *name*, so nothing fails to
interoperate. The cost is in configuration and documentation: a deployment
following RFC-AITP-0011 §2 to raise the limit sets a key `aitp-rs` does not read,
silently keeping whatever default the construction path supplied —
`VerifyDelegationContext::new` sets `max_hops: 0`
(`crates/aitp-delegation/src/verifier.rs:60`, the v0.2 strict single-hop
default), while `DEFAULT_MAX_HOPS = 3` (`:19`) applies only on the opt-in
multi-hop path. So the silent outcome is 0 or 3 depending on how the context was
built, which is worse than a single wrong default. And
`DELEGATION_HOP_LIMIT_EXCEEDED`'s own definition (§7, line 191) is written in
terms of a name the implementation does not use.

### Proposed resolution

- **[Recommended] Rename in `aitp-rs`** — `max_hops` → `max_delegation_hops`. The
  spec name is published across two RFCs and appears in an error code's normative
  definition; the field is pre-1.0 and internal to the verifier's configuration
  struct.
- *(Rejected alternative)* Document `max_hops` in the RFC as an accepted alias.
  This entrenches two names for one knob permanently to avoid a rename in
  pre-1.0 code.

**Shipped.** Renamed to `max_delegation_hops` throughout `aitp-rs` in its #82.

---

## What already interoperates (byte-for-byte, independently reproduced)

`aitp-verifier-py` reproduces the following pinned vectors byte-for-byte, from a
codebase sharing no code with `aitp-rs`:

- `keypairs.json` — Ed25519 + P-256 seed → public key → AID
- `jwk-thumbprints.json` — RFC 7638 `cnf.jkt` (OKP + EC)
- `jcs-sha256.json` — **JCS canonicalization** of the pinned objects (Manifest,
  revocation, session bundle): given the object each vector carries, both
  implementations produce the same canonical bytes and the same SHA-256. Also the
  `kat-manifest-pop-001` PoP signature, which is a genuine cross-implementation
  signature check. **This is a canonicalization result and nothing more — see the
  next section.**
- `signed-examples/` — the **compact-JWS** artifacts only: TCT, grant voucher,
  delegation (verified; TCT also re-minted to the identical string). The two
  JCS-profile files in that directory are *not* covered — see below.
- `id-007` — the pinned-key proof (once the ASCII-timestamp encoding above is
  applied)

Conformance result: **51 of 53 fixtures pass, 0 fail**; the only two skips are
`mh-002` (Erratum 2) and `del-004` (legitimately v0.1-frozen, `required_for_v0_1`
only). Closing errata 1 and 2 takes `mh-002` from SKIP to PASS.

## What is NOT yet cross-checked (corrected 2026-08-24; superseded 2026-09-19 — see Current status above)

> **This section is historical.** As of 2026-09-19 both implementations sign the
> inner body for the manifest, revocation snapshot and session bundle, and a
> required cross-impl CI gate exercises both mint/verify directions on committed
> bytes for revocation and the session bundle. It is kept verbatim below because it
> is the record of what motivated errata 3 and 4's fixes; do not read it as
> current.

An earlier revision of this file listed `jcs-sha256.json` — "JCS canonical bytes
and SHA-256 (Manifest, revocation, session bundle)" — among the vectors
`aitp-verifier-py` reproduces "byte-for-byte, from a codebase sharing no code with
`aitp-rs`". Read as an **interoperability** claim, that was **wrong**, and it was
the most misleading line in this document: it told a reader the two
implementations had been cross-checked on these artifacts when in fact each had
only been checked against itself.

What actually happens is that both KAT harnesses canonicalize whichever object
the vector hands them and compare digests — `aitp-verifier-py`
`tests/test_kat.py:41-47` is a plain `jcs.canonicalize(v["object"])`, and
`aitp-rs` `crates/aitp-core/tests/kat.rs` reshapes itself to whichever form the
vector carries. Agreement on `canonicalize(X)` for a given `X` says nothing about
whether the two implementations choose the same `X` when they sign — and for
revocation snapshots and session bundles they do not (errata 3 and 4).

The one place a vector *is* driven through a real signing view is `aitp-rs`
`crates/aitp-tct/src/revocation.rs:216-247`, and it is a single-implementation
test: it confirms `aitp-rs` agrees with `kat-revocation-001`, which is exactly the
agreement that is wrong. A vector checked against one implementation's signing
view establishes that the implementation followed the vector, not that the vector
is right.

Not established by any test in either repository, as of 2026-08-24:

| Artifact | Signing input agreed? | Why it is untested |
|---|---|---|
| Manifest | Yes, in fact — both sign inner | `man-*` fixtures re-mint `__VALID_MANIFEST_SIG__` per-implementation. The committed signed example is verified by `aitp-rs` (`crates/aitp-cli/tests/cli.rs:210-237`) and never by `aitp-verifier-py`. The agreement between the two is real, but no test demonstrates it — and `kat-manifest-001` contradicts both. |
| Revocation snapshot | **No** — `aitp-rs` wrapped, `aitp-verifier-py` inner | `rev-*` fixtures re-mint `__VALID_A_SIG__` per-implementation. The committed signed example is executed only by `aitp-rs` (`crates/aitp-tct/src/revocation.rs:249-276`), under the same wrapped convention it was minted with, so it passes there and is never seen by the other side. |
| Session bundle | **No** — `aitp-rs` wrapped, `aitp-verifier-py` inner | `bundle-*` fixtures re-mint `__VALID_A_SIG__`; `kat-session-bundle-001`'s committed coordinator signature is verified by neither implementation, and `aitp-rs`'s KAT harness (`crates/aitp-core/tests/kat.rs:14-30`) selects the form from the pinned hex rather than pinning a form, so it cannot disagree with the vector. |

The two-implementation gate is therefore **not** satisfied for the JCS-profile
signing inputs, and no conformance result should be read as evidence that it is.
What would establish it: a signature minted by `aitp-rs` and verified by
`aitp-verifier-py` over committed bytes, and the reverse, with no re-minting on
either side.

**As of 2026-09-19, this is established** for the revocation snapshot and the
session bundle — both implementations independently converged on the inner body
(`aitp-rs`#82), and `aitp-rs`'s `cross-impl acceptance` CI job runs both
mint/verify directions against `aitp-verifier-py` on committed bytes for both
artifacts. The manifest is not yet covered by that gate (`aitp-rs`#148,
open) even though both implementations already agree on its signing input.

---

## Action items

### Errata 1–2

- [x] RFC-AITP-0002 §3.1: change `timestamp_be_8_bytes` → ASCII decimal string; regenerate the RFC's `Version:`/changelog note as an editorial erratum.
- [x] Add a `kat-pinned-key-proof-001` vector under `known-answer/` (five-field input → sha256 → signature with `kat-keypair-003`).
- [x] Add `kat-keypair-006-attacker` (seed + AID) to `known-answer/keypairs.json`; reference it in `PLACEHOLDERS.md`'s AID-role table.
- [x] Correct the `PLACEHOLDERS.md` "`0xff × 32`" attacker-seed hint.
- [x] Confirm both `aitp-rs` and `aitp-verifier-py` pass `mh-002` and `id-007` after the changes (the two-implementation gate).

### Errata 3–4 — spec repo (`agentidentitytrustprotocol`)

- [x] Regenerate `kat-manifest-001`, `kat-revocation-001`, `kat-session-bundle-001` to the inner artifact body; re-mint `kat-session-bundle-001.coordinator_signature_b64url` over the inner bytes. Generated by executing a reference implementation, never hand-transcribed.
- [x] Re-mint `signed-examples/revocation/kat-keypair-001-snapshot.json` over the inner `revocation_list` body.
- [x] Add a machine-readable signing-input declaration to each vector in `jcs-sha256.json`.
- [x] RFC-AITP-0001 §5.4.1: state the general wrapper-is-transport rule for the JCS profile; re-point the KAT note at the signing input.
- [x] RFC-AITP-0003 §6.1, RFC-AITP-0008 §1.5: re-point the "MUST reproduce it byte-for-byte" sentences at the inner body.
- [x] RFC-AITP-0010: add the unwrap rule to §3's `signature` row (line 90), §4.2 step 4 (line 107) and §5 step 6 (line 150); re-point the KAT paragraph in §9 Conformance Surface (line 205).
- [x] Execute the pinned values in CI — recompute every canonical byte sequence, verify every pinned signature, and reject any JCS-profile vector declaring the envelope as its signing input.
- [x] Correct `rev-003-success.json` / `bundle-001-success.json` `$comment` text and `PLACEHOLDERS.md`'s `__VALID_A_SIG__` row.
- [x] `signed-examples/README.md`: require the JCS-profile files be verified as committed, without re-minting.

### Observed but not filed (pre-existing, outside W-P5)

- [ ] RFC-AITP-0001 §5.4.1's opening sentence — *"All JCS-profile signatures
  (envelope, Manifest, revocation snapshot, handshake payloads) are computed over
  the **canonical JSON** form of the object"* (`:353`) — is not true of the
  **envelope**. §5.4 (`:231-236`) defines the envelope signing input as a
  pipe-composed string, `message_id + "|" + timestamp + "|" + sender.agent_id +
  "|" + hex(sha256(payload_canonical_json))`, which does not cover `version` or
  `message_type` and is not `canonical_json(envelope_without_signature)`. Same
  class as errata 3 and 4 — a general statement about signing inputs that one
  artifact does not obey — but it predates this work, no implementation appears to
  have been misled by it (both follow §5.4's explicit formula), and no byte
  changes. Recorded so it is not rediscovered a third time. **Not re-verified as
  part of the 2026-09-19 pass — still open as far as this document knows.**

- [ ] **Live contradiction between two tracked files** on the envelope signing
  input. `registries/media-types.md:9` describes it for `application/aitp+json`
  as "the inner payload in RFC 8785 (JCS) canonical JSON form";
  `schemas/conformance/PLACEHOLDERS.md`'s resolution table now says it is "a
  pipe-composed string, *not* canonical JSON of the envelope". RFC-AITP-0001 §5.4
  sides with PLACEHOLDERS.md, so the registry is the file to correct — but a
  reader can now see the disagreement, which is why this is filed as a
  contradiction rather than a stale line. The registry entry is not the envelope
  signing input, which RFC-AITP-0001 §5.4 defines
  as a pipe-composed string over `message_id`, `timestamp`, `sender.agent_id` and
  `hex(sha256(payload_canonical_json))`. The payload's canonical JSON is one
  *input to* that string, not the signing input itself. Same class as the §5.4.1
  opener above — a general statement about signing inputs that the envelope does
  not obey — pre-existing, no bytes affected, and outside W-P5's scope, which is
  the JCS artifact-name wrapper. Recorded rather than fixed so it is not
  rediscovered later as a new finding. **Not re-verified as part of the
  2026-09-19 pass — still open as far as this document knows.**

### Errata 3–5 — implementations

- [x] `aitp-rs`: move `RevocationListSigningView` (`crates/aitp-tct/src/revocation.rs:69`) and `BundleSigningView` (`crates/aitp-session-bundle/src/builder.rs:133`) to the inner body, and correct the doc comments citing the vectors as authority for the wrapped form — those comments are the propagation path.
- [x] `aitp-rs`: update the two tests that pin the wrapped form — `rfc_kat_canonical_bytes_match` (`crates/aitp-tct/src/revocation.rs:216-247`) and `spec_signed_example_snapshot_verifies` (`:249-276`). These are the tests that will go red when the vectors are regenerated, and that is the intended signal.
- [x] `aitp-rs`: replace the auto-detecting KAT harness (the `signing_input` helper at `crates/aitp-core/tests/kat.rs:14-30`, called at `:74`) with one that pins the declared signing input, and delete its comment claiming the session-bundle and multi-hop vectors pin "the *inner signing body*" — they do not. As written the harness cannot fail on this defect in either direction.
- [x] `aitp-rs`: rename `max_hops` → `max_delegation_hops` (`crates/aitp-delegation/src/verifier.rs:41`).
- [x] `aitp-verifier-py`: extend `tests/test_signed_examples.py` to cover the two JCS-profile signed examples.
- [x] Cross-implementation acceptance: a signature minted by `aitp-rs` and verified by `aitp-verifier-py` over committed bytes, **and the reverse**. Both directions, no re-minting. Nothing less closes errata 3 and 4. — satisfied for revocation and session bundle via `aitp-rs`'s `cross-impl acceptance` CI job; manifest coverage in that same gate remains open (`aitp-rs`#148).
