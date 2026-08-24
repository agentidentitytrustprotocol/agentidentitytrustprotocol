# Conformance Fixture Placeholder Convention

The fixtures under `schemas/conformance/*.json` use string placeholders
of the form `__UPPER_SNAKE__` for values that a runner or minting tool
must materialize at execution time. This file is the normative
specification for those placeholders.

A minting tool (e.g. `aitp-rs`'s `mint-conformance-fixtures` script)
walks each fixture, identifies placeholders by name, substitutes real
values per the rules below, and writes the result. A conformance
runner that consumes already-minted fixtures MUST NOT see any of these
tokens — if it does, the fixture is not yet migrated.

## Naming rule

Placeholders MUST match the regex `^__[A-Z][A-Z0-9_]+__$`. The
double-underscore boundaries make placeholders trivially greppable and
unambiguous against any base64url, hex, or UUID alphabet.

## Time placeholders

| Token | Meaning | Substitution |
|---|---|---|
| `__NOW__` | The runner's reference clock at execution time. | Unix seconds (integer). |
| `__NOW_MINUS_3600__` | One hour before `__NOW__`. | `__NOW__ - 3600` (integer). |
| `__NOW_PLUS_3600__` | One hour after `__NOW__`. | `__NOW__ + 3600` (integer). |
| `__NOW_PLUS_7200__` | Two hours after `__NOW__`. | `__NOW__ + 7200` (integer). Used by `tct-005` to put `tct.expires_at` past the issuer's `issuer_manifest.expires_at` (`__NOW_PLUS_3600__`) while keeping the TCT itself in the future. |

Additional `__NOW_MINUS_<seconds>__` and `__NOW_PLUS_<seconds>__`
tokens MAY be introduced as new fixtures need them; minting tools MUST
parse the trailing integer literally and substitute `__NOW__ ±
<seconds>`.

### Reference clock for byte-stable minting

Minting tools MUST anchor `__NOW__` to **`1711900000`** (the same
clock used by the rc.2 known-answer test vectors in
[`known-answer/jcs-sha256.json`](known-answer/jcs-sha256.json)).
Using the wall clock would produce different canonical bytes on every
mint; pinning `__NOW__` lets a re-mint be byte-stable across runs and
across implementations. Runners that consume already-minted fixtures
MUST treat the integer in the fixture as authoritative; they do not
compare it to wall time.

## AID role mapping

Most fixtures use placeholder AIDs of the form
`aid:pubkey:agent<X>_pubkey_AID_v01_placeholder_<X>...`. The minting
tool MUST replace these with the real AIDs derived from the pinned
known-answer keypairs. Fixtures keep the legacy untagged
`aid:pubkey:<43-char>` AID form (still valid in v0.2 per
RFC-AITP-0001 §5.3, implying Ed25519/`EdDSA`); P-256 fixtures use the
`aid:pubkey:p256:` form. The mapping is normative:

| Fixture role | KAT keypair | AID |
|---|---|---|
| `agentP256` (P-256 signer in `env-005` and other ES256 fixtures) | [`kat-keypair-005-p256`](known-answer/keypairs.json) | `aid:pubkey:p256:<44-char identifier pinned in keypairs.json>` |
| `agentA` (initiator / TCT issuer in most fixtures) | [`kat-keypair-001`](known-answer/keypairs.json) | `aid:pubkey:O2onvM62pC1io6jQKm8Nc2UyFXcd4kOmOsBIoYtZ2ik` |
| `agentB` (target / TCT subject) | [`kat-keypair-002`](known-answer/keypairs.json) | `aid:pubkey:A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg` |
| `agentC` (delegatee in single-hop, intermediate in multi-hop) | [`kat-keypair-003`](known-answer/keypairs.json) | `aid:pubkey:dqFZIESm5PURJlvKc6YE2QsFKdHfYCvjChmpJXZg0fU` |
| `agentD` (final delegatee in multi-hop chains) | [`kat-keypair-004`](known-answer/keypairs.json) | `aid:pubkey:iojj3XQJ8ZX9UtstPLpdcspnCb8dlBIb83SIAbQPb1w` |
| `issuingPeer` (alias of `agentA` in delegation fixtures) | `kat-keypair-001` | same as `agentA` |
| `worker_pubkey_AID_v01_placeholder_wwwwwwwww` (Manifest example) | `kat-keypair-002` | same as `agentB` |
| `verifier_pubkey_AID_v01_placeholder_vvvvvvv` / `victim_pubkey_AID_v01_placeholder_vvvvvvvvv` (verifier in `id-*`) | `kat-keypair-001` | same as `agentA` |
| `attacker_pubkey_AID_v01_placeholder_XXXXXXX` (`mh-002`) | A separate one-shot keypair NOT in `keypairs.json`. Generated deterministically from a fixture-only seed (e.g. `0xff` × 32) and inlined where needed. Tests trust-anchor + signature checks against an unknown peer. | n/a |

Identity-issuer keys (the OIDC issuers used by `__VALID_JWT__` and
`__VALID_JWT_FROM_UNKNOWN_ISSUER__`) are NOT drawn from
`keypairs.json` — they are minted at runtime by the tool and the
public key is inlined into the fixture's `accepted_trust_anchors` /
local `trust_anchors` so the verifier accepts (or rejects) the JWT
based on issuer-list membership alone.

## Operation key

Every fixture carries a top-level `input.operation` string telling
the conformance runner which conformance op to invoke against the
implementation under test. The operation registry:

| Fixture id prefix | `input.operation` | Notes |
|---|---|---|
| `env-*` | `verify_envelope` | Single envelope verification. |
| `man-*` | `verify_manifest` | Standalone Manifest verification (RFC-AITP-0003 §5). |
| `tct-*` | `verify_tct` | Standalone TCT verification (RFC-AITP-0005 §7.2/§10). The `tct_token` input is a compact JWS string. MAY accept an `input.issuer_manifest` object (at minimum `{aid, expires_at}`) — when present, the runner supplies it to the verifier as the resolved issuing-peer Manifest so the §10.4 conditional Manifest-expiry bound check fires. When absent, the §10.4 check is skipped (per the RFC's "MAY be skipped when the issuer Manifest is unavailable" clause). `tct-005` exercises the present-Manifest path; other `tct-*` fixtures rely on §7.2/§10.1–§10.3 alone. |
| `vch-*` | `verify_grant_voucher` | Standalone grant-voucher verification (RFC-AITP-0005 §8 / RFC-AITP-0006 §4 step 3): typ enforcement, AID-pinned alg, signature under the issuer's own key, claims checks. Inputs include `verifier_aid` (the voucher issuer's own AID). Voucher expiry surfaces as `DELEGATION_EXPIRED` (the voucher is only ever consumed in delegation context). |
| `del-*` | `verify_delegation_token` | Single-hop delegation verification (RFC-AITP-0006 §4). |
| `rev-*` | `verify_revocation_snapshot` or `verify_tct` | Revocation-layer fixtures. `rev-001`/`002`/`003` use `verify_revocation_snapshot` (RFC-AITP-0008 §1.5) to exercise the snapshot freshness / signature / lookup path directly. `rev-004` uses `verify_tct` (the standard TCT op) with `input.revocation_instrumented: true` and `expected.side_effects.revocation_lookup_called: false` to pin the RFC-AITP-0008 §3.3 ordering requirement — TCT signature verification MUST precede any network revocation lookup. Runners that cannot instrument the revocation source MUST SKIP the side-effect assertion (and thus the fixture, since it is core/required). |
| `id-*` | `verify_handshake_payload` | Verify a single inline-handshake `payload` (i.e. the result of step 6 in RFC-AITP-0004 §5.1). |
| `mh-*` (single-message) | `verify_handshake_payload` | Same as above. |
| `mh-*` (multi-step `sequence`) | per-step in the sequence | Each `sequence[i]` carries its own `operation`; typical values are `start_handshake` and `process_handshake_message`. |
| `tct-*` (multi-step `sequence`) | per-step in the sequence | Used by `tct-006` (downstream PoP exchange) and `tct-007` (PoP enforcement). Operations for `tct-006`: `issue_pop_challenge` (verifier produces a `pop_challenge` envelope), `produce_pop_response` (holder signs `sha256(base64url_decode(nonce))` with the subject key bound via `cnf.jkt` and emits a `pop_response` envelope), `verify_pop_response` (verifier checks envelope signature, `nonce_echo`, and `pop_signature` per RFC-AITP-0005 §6.2). Operations for `tct-007`: `authorize_capability_invocation` (verifier receives a capability invocation against a grant the issuing peer marks as PoP-required; verifier SHOULD respond by issuing a `pop_challenge`), `expect_pop_challenge_issued` (no-op step that asserts the verifier instrumentation observed a `pop_challenge` envelope being emitted; uses the `side_effects.pop_challenge_issued` assertion), `withhold_pop_response` (test harness deliberately does NOT return a `pop_response`; verifier MUST reject the original invocation with `POP_RESPONSE_INVALID` and MUST NOT authorize the capability — asserted via `side_effects.capability_authorized: false`). |
| `del-mh-*` | `verify_delegation_token` | Multi-hop delegation verification (RFC-AITP-0011 §3-§6). Inputs may include a `revocation_snapshots` array of `{issuer_aid, snapshot}` records that the runner MUST populate per-hop deny lists from before checking `voucher.src_jti` (and per-hop `jti`) revocation. Implementations that do not opt into RFC-AITP-0011 MUST return `DELEGATION_MULTIHOP_NOT_SUPPORTED` for any token carrying a `chain` claim. |
| `bundle-*` | `verify_session_bundle` | Session Trust Bundle verification (RFC-AITP-0010 §5). Inputs include `self_aid` (the receiving participant) and `now` (reference clock). Core (non-opted-in) implementations report `SKIP` rather than `FAIL` when this operation is encountered. |

A runner that encounters an unknown `operation` MUST return SKIP
rather than FAIL — that lets an implementation under test
self-document which conformance ops it does and does not support
without breaking the rest of the run.

## Signature placeholders (JCS-profile artifacts)

The minting tool produces real signatures using the
[known-answer keypairs](known-answer/keypairs.json). Every signature
placeholder in this table is replaced with the unpadded base64url
encoding of the signature over the appropriate canonical input
(RFC-AITP-0001 §5.4.1). These tokens apply to **JCS-profile**
artifacts only (envelopes, Manifests, revocation snapshots, handshake
payloads); the compact-JWS artifacts use the whole-token family in
the next section.

| Token | Signing key | Signing input |
|---|---|---|
| `__VALID_ENVELOPE_SIG__` | Sender's pinned signing key | Envelope signing input per RFC-AITP-0001 §5.4 |
| `__VALID_MANIFEST_SIG__` | Manifest agent's signing key | JCS canonical **inner** Manifest body excluding `signature` — never the `{"manifest": …}` wrapper (RFC-AITP-0003 §6.1) |
| `__VALID_POP_SIG__` | Manifest agent's signing key | `sha256(decoded_bytes(challenge))` (RFC-AITP-0003 §3.1) |
| `__VALID_A_SIG__` | Initiating peer (A)'s signing key | Resolved from the enclosing artifact, per the table below — **never** "whatever the minting tool decides". |
| `__VALID_B_SIG__` | Target peer (B)'s signing key | Same resolution table, signed by B. |
| `__LEGACY_PINNED_PROOF__` | Pinned-key holder's signing key (legacy two-field input) | Pre-v0.1 pinned-key proof signed over the two-field input `message_id`, a literal pipe, then `timestamp` (no domain prefix, no receiver, no `pop_nonce`). Used by `id-005` to assert rejection when the verifier replays the five-field reconstruction (RFC-AITP-0002 §3.1). The signature alphabet is real (Ed25519 over the legacy bytes) so the failure surfaces only at the input-reconstruction step, not at base64url decode. |
| `__VALID_JWT__` | Identity issuer's key | Compact JWT serialization with claims pinned by the surrounding fixture context. |
| `__VALID_JWT_FROM_UNKNOWN_ISSUER__` | Untrusted issuer's key | Same shape as `__VALID_JWT__` but signed by an issuer NOT in the verifier's `trust_anchors`. The signature is cryptographically valid; the policy check is what fails. |
| `__VALID_NONCE__` | n/a | Random 128-bit base64url string (22 chars, unpadded). The minting tool MAY use a per-fixture deterministic seed for reproducibility. |
| `__VALID_NONCE_ECHO__` | n/a | The exact `__VALID_NONCE__` value from the corresponding earlier message in the same handshake. |
| `__VALID_DOWNSTREAM_POP_SIG__` | TCT subject's signing key (the holder; the key encoded in the TCT's `sub` AID) | `sha256(base64url_decode(nonce))` where `nonce` is the `__VALID_NONCE__` issued by the verifier in the matching `pop_challenge` (RFC-AITP-0005 §6.1). Same convention as `__VALID_POP_SIG__`; named separately to disambiguate the downstream PoP exchange from Manifest PoP in fixtures that include both. |

### Resolving `__VALID_A_SIG__` / `__VALID_B_SIG__`

These two placeholders appear in more than one kind of artifact, so the signing
input depends on which artifact encloses them. It is **fully determined** by that
artifact — it is not a minting-tool choice. An earlier revision of this file
described them as "context-dependent … minting tool resolves from surrounding
fixture shape," which licensed two minting tools to pick different conventions.
Both then verified their own output and passed, while their wire formats
disagreed. That is exactly how the revocation and session-bundle signing inputs
diverged between implementations (see the signing-input entry in
[`CHANGELOG.md`](../../CHANGELOG.md)).

| Enclosing artifact | Signing input |
|---|---|
| `snapshot` (a `{"revocation_list": …, "signature": …}` object) | JCS canonical form of the **inner `revocation_list` body**. The `signature` is a sibling of the body, not a member of it, so nothing is removed before canonicalizing. RFC-AITP-0008 §1.5. |
| `session_bundle` (a `{"session_bundle": …}` object) | JCS canonical form of the **inner `session_bundle` body**, excluding its `signature` member. RFC-AITP-0010 §3. |
| an envelope | The envelope signing input of RFC-AITP-0001 §5.4 — a pipe-composed string, *not* canonical JSON of the envelope. |

**General rule for every JCS-profile artifact carried inside an artifact-name
wrapper** (`{"manifest": …}`, `{"revocation_list": …}`, `{"session_bundle": …}`):
the wrapper key is transport routing metadata and is never part of the signing
bytes (RFC-AITP-0001 §5.4.1). Sign the inner body; add the wrapper only when
transmitting. A minting tool that canonicalizes the wrapper produces artifacts
that verify only against itself.

Pinned signing inputs for all three live in
[`known-answer/jcs-sha256.json`](known-answer/jcs-sha256.json), each declaring
`signing_input: "body"`, and are executed by `make kat-verify`.

**Retired in v0.2** (used only by fixtures frozen in the v0.1 token
shape, e.g. `del-004`): `__VALID_TCT_SIG__`,
`__VALID_ISSUING_PEER_SIG__`, `__VALID_GRANT_PROOF_SIG__`. The v0.2
TCT and delegation token are compact JWS strings — there is no
embedded signature field to substitute. Minting tools MUST still
recognize these tokens when minting the frozen v0.1 fixtures.

## Compact-JWS token placeholders (v0.2 portable trust artifacts)

The v0.2 TCT, grant voucher, and delegation token are opaque compact
JWS strings (RFC-AITP-0001 §5.4.5). They are placeheld as **whole
tokens**, not per-field signatures.

**Claims-sibling convention.** A string field `X` whose value is a
`__JWS_*__` token MUST have a sibling field `X_claims` (same JSON
object level) carrying the decoded payload claims to mint. The minter:

1. resolves `__JWS_*__` tokens **innermost-first** (a delegation's
   claims may contain `"voucher": "__JWS_GRANT_VOUCHER__"` with its own
   `voucher_claims` sibling inside the claims object);
2. removes each `*_claims` companion from the claims object before
   serializing the payload (the companions are minting inputs, never
   wire bytes);
3. builds the protected header as exactly `{"alg": <derived from the
   claims' iss AID per RFC-AITP-0001 §5.4.5>, "typ": <per the token
   kind below>}` unless the token variant says otherwise;
4. signs with the keypair mapped to the `iss` AID (AID role table
   above);
5. substitutes the compact string and leaves the **top-level**
   `X_claims` sibling in place in the fixture for auditability —
   runners MUST ignore `*_claims` fields when present at the fixture
   `input` level.

| Token | `typ` | Recipe |
|---|---|---|
| `__JWS_TCT__` | `aitp-tct+jwt` | Standard mint from the claims sibling. |
| `__JWS_GRANT_VOUCHER__` | `aitp-grant+jwt` | Standard mint. When this token is placed in a field a verifier treats as a TCT (e.g. `tct-010`), the expected outcome is `TOKEN_TYP_MISMATCH`. |
| `__JWS_DELEGATION__` | `aitp-delegation+jwt` | Standard mint; resolves a nested `voucher` placeholder first. |
| `__JWS_TCT_TAMPERED_SIG__` | `aitp-tct+jwt` | Mint normally, then flip the **least-significant bit of the last raw signature byte** before base64url-encoding the third segment (same recipe as `__TAMPERED_SIGNATURE__`). Expected: `TCT_SIGNATURE_INVALID`. |
| `__JWS_DELEGATION_TAMPERED_SIG__` | `aitp-delegation+jwt` | Same tamper recipe on the outer delegation JWS. Expected: `DELEGATION_INVALID_SIGNATURE`. |
| `__JWS_VOUCHER_TAMPERED_SIG__` | `aitp-grant+jwt` | Same tamper recipe on the embedded voucher JWS. Expected: `DELEGATION_INVALID_VOUCHER`. |
| `__JWS_TCT_ALG_NONE__` | `aitp-tct+jwt` | Header `{"alg":"none","typ":"aitp-tct+jwt"}`; payload from the claims sibling; third segment = base64url of 64 zero bytes (86 chars, so the failure is the `alg` check, not segment syntax). Expected: `TOKEN_ALG_MISMATCH`. |
| `__JWS_TCT_WRONG_ALG__` | `aitp-tct+jwt` | Header `{"alg":"ES256","typ":"aitp-tct+jwt"}` while the `iss` AID is Ed25519; sign with the `iss` Ed25519 key over the signing input (deterministic bytes; the signature is never checked because the `alg` pin rejects first). Expected: `TOKEN_ALG_MISMATCH`. |
| `__ANY_JWS__` | n/a | Any syntactically valid three-segment compact JWS; used for fields a fixture never verifies because rejection happens earlier (e.g. `chain` entries in the core multi-hop structural rejection). RECOMMENDED: a real `__JWS_DELEGATION__` mint so cross-fixture minter paths stay uniform. |
| `__COMPUTED_CHAIN_HASH__` | n/a | The correct RFC-AITP-0011 §5 digest-array `chain_hash` over the minted `chain` JWS strings. Cannot be pinned in the fixture (it depends on the minted bytes); the minter MUST compute it after resolving every chain entry. Distinct from the ignored-value `__ANY_CHAIN_HASH__`, which marks a hash no verifier checks. Used by `del-mh-001/002/004`. |

**Array extension of the claims-sibling rule.** A `chain` claim is an
array of `__JWS_DELEGATION__` tokens with an equal-length sibling
`chain_claims` array at the same level inside the outer token's claims
object; `chain_claims[i]` is the decoded claims for `chain[i]` and may
itself contain a nested `voucher`/`voucher_claims` pair (resolved
innermost-first). Likewise, a session-bundle participant entry carries
`"tct": "__JWS_TCT__"` with a `tct_claims` sibling inside the same
participant object. The minter strips every `*_claims` companion before
serializing/signing wire bytes — note the session-bundle schema's
`additionalProperties: false` on participant entries makes this
mandatory, not just conventional. In handshake fixtures,
`__VALID_NONCE_ECHO__` inside a received payload resolves to the
`__VALID_NONCE__` minted for the same peer block's `self_pop_nonce_*`
field.

## Failure-injection placeholders

These represent values that look well-formed but trigger a specific
failure path. The minting tool produces them by manipulating a
known-good signed object — the surrounding fixture documents which
property should be broken.

| Token | What's broken | Expected error path |
|---|---|---|
| `__TAMPERED_SIGNATURE__` | Sign properly, then flip the **least-significant bit of the last raw signature byte** before base64url-encoding. | `MANIFEST_SIGNATURE_INVALID` (manifest), `INVALID_SIGNATURE` (envelope). |
| `__TAMPERED_SIG__` | Same recipe; shorter alias used by older fixtures. | `TCT_SIGNATURE_INVALID`. |

The tamper recipe is pinned so re-mints reproduce byte-for-byte. Any
implementation that mutates a different bit will produce a different
signature string and break cross-mint determinism.
| `__INVALID_POP_SIG__` | PoP signature over the wrong input (e.g. the wrong challenge). | `MANIFEST_POP_FAILED`. |
| `__INVALID_POP_SIG_OVER_WRONG_NONCE__` | PoP signature whose input used a different `pop_nonce` than the receiving peer expects. | `POP_VERIFICATION_FAILED`. |
| `__JWT_MISSING_AUD_CLAIM__` | Otherwise-valid OIDC JWT with the `aud` claim removed. | `IDENTITY_FAILED`. |
| `__JWT_AUD_TARGETS_DIFFERENT_PEER__` | OIDC JWT whose `aud` is some other peer's AID. | `IDENTITY_FAILED`. |
| `__JWT_MISSING_CNF_JKT_CLAIM__` | OIDC JWT with `cnf.jkt` removed. | `IDENTITY_FAILED`. |
| `__CAPTURED_PROOF_FROM_ORIGINAL_HANDSHAKE__` | A pinned-key proof signed over a *different* (sender, receiver, message_id, timestamp, pop_nonce) tuple than the one in this fixture. Tests cross-peer replay (RFC-AITP-0002 §3.1). | `IDENTITY_FAILED`. |

## Ignored-value placeholders (structural-rejection fixtures)

A small set of placeholders mark fields whose value is never inspected
by a v0.1 implementation because the fixture rejects on an earlier
structural check. The minting tool MUST still emit a syntactically
valid value (so the fixture passes JSON-schema and length validation),
but the bytes are not required to be cryptographically meaningful —
no signature is verified against them.

| Token | Field | Why it's ignored | Minter substitution |
|---|---|---|---|
| `__ANY_CHAIN_STEP_SIG__` | `delegation.chain[i].signature` (v0.1 shape) | v0.1-frozen fixture only (`del-004`): v0.1 implementations reject any delegation token with a non-empty `chain` field at the structural check before any per-hop signature work. | Any 86-char unpadded base64url string. RECOMMENDED: a real Ed25519 signature under `kat-keypair-001` over the JCS-canonical chain-step body, so the same minter path produces it. |
| `__ANY_CHAIN_HASH__` | `chain_hash` | `chain_hash` is recomputed during multi-hop verification, which a core (non-opted-in) implementation never reaches. Used by `del-004` (v0.1 shape) and the v0.2 structural-rejection sibling. | Any 43-char unpadded base64url (32 bytes); RECOMMENDED: the correctly computed hash so the value is internally consistent even though no verifier checks it. |
| `__ANY_DELEGATION_SIG__` | outer `delegation.signature` (v0.1 shape) | v0.1-frozen fixture only (`del-004`): the outer signature is not verified before the structural rejection. | Any 86-char unpadded base64url string; RECOMMENDED: a real Ed25519 signature so cross-fixture minter paths stay uniform. |
| `__ANY_JWS__` | `chain[i]` entries (v0.2 shape) | Core v0.2 implementations reject any delegation token carrying a `chain` claim with `DELEGATION_MULTIHOP_NOT_SUPPORTED` before processing entries. | See the compact-JWS table above. |

A runner that exercises the multi-hop opt-in (`feature:
experimental-multihop-delegation`) does verify these fields and uses
the `del-mh-*` fixture set, where the equivalent fields are real
minted compact JWS strings rather than the `__ANY_*__` ignored
variants.

## Adding new placeholders

A new placeholder requires:

1. A row in this file (table above + a one-line description of what it
   represents).
2. A minting-tool implementation that materializes it.
3. A test in the runner that asserts the substituted value still
   triggers the documented expected outcome.

Placeholders MUST NOT shadow real protocol values. Specifically, no
fixture field whose schema requires a fixed-length base64url or UUID
may be filled with an `__UPPER_SNAKE__` token at runtime — minting MUST
happen before validation.

## Stability

The placeholder table is **versioned with the protocol**. The v0.1
names remain frozen for the fixtures that stay in the v0.1 token shape
(`del-004` and the historical record); they are never renamed, only
retired. The v0.2 additions are the compact-JWS token family above.
Renaming any active placeholder requires the RFC process; new names
can be added freely. A minting tool that does not recognize a
placeholder MUST fail fast rather than emit the literal string, since
unsubstituted placeholders would slip past schema validation only to
produce confusing runtime failures.
