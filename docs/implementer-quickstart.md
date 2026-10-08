# Implementer Quickstart

A one-page reading order for someone building an AITP peer agent. The
authoritative source is the RFC set; this page just sequences them with
context so you don't end up reading them backwards. For SDKs, an
independent verifier, and other implementation-side material, see
[`docs/ecosystem.md`](ecosystem.md).

---

## The headline v0.2 change: two signing profiles

AITP v0.2 signs artifacts under **two profiles**
([RFC-AITP-0001 §5.4](../rfcs/RFC-AITP-0001-core.md#54-signature)):

- **Compact JWS** ([RFC-AITP-0001 §5.4.5](../rfcs/RFC-AITP-0001-core.md#545-compact-jws-profile-portable-trust-artifacts))
  for the portable trust artifacts — the TCT, the grant voucher and the
  delegation token. The signature covers the exact transmitted bytes;
  there is no canonicalization step. The header is exactly `alg` + `typ`,
  `typ` is pinned per artifact, and `alg` is derived from the signer's
  AID, never read from the token.
- **JCS embedded signature** ([RFC-AITP-0001 §5.4.1](../rfcs/RFC-AITP-0001-core.md#541-signing-input-jcs-profile))
  for everything exchanged only between full AITP stacks — envelopes,
  Manifests, revocation snapshots, session trust bundles and handshake
  payloads.

If you are porting an earlier implementation, the TCT field-by-field
migration table is [RFC-AITP-0005 §2.1](../rfcs/RFC-AITP-0005-tct.md#21-mapping-from-the-v01-tct).

---

## Read in this order

1. **[`docs/architecture.md`](architecture.md)** — orient first. The
   problem, the shape, the flows, where state lives, and the big
   invariant.

2. **[RFC-AITP-0001 Core](../rfcs/RFC-AITP-0001-core.md)** — primitives.
   The signed envelope, replay protection (`message_id` dedup +
   timestamp window), the two signing profiles above, base64url rules,
   error codes, and the AID grammar (§5.3): the algorithm-tagged
   `aid:pubkey:ed25519:…` / `aid:pubkey:p256:…` forms, plus the legacy
   untagged `aid:pubkey:<43-char>` Ed25519 form from v0.1, which
   implementations MUST still parse. Implement the envelope first.

3. **[RFC-AITP-0002 Identity](../rfcs/RFC-AITP-0002-identity.md)** —
   proofs. OIDC (the JWT carries `aud`, a `nonce` equal to the handshake
   `pop_nonce`, and `cnf.jkt` — §2.2) and pinned-key (with the
   five-field handshake-bound proof input — §3.1). The verifying party is
   always another peer, never a third party.

4. **[RFC-AITP-0003 Manifest](../rfcs/RFC-AITP-0003-manifest.md)** —
   discovery. The signed self-description served at
   `/.well-known/aitp-manifest`. Verify in the order listed in §5; the
   bootstrap order matters.

5. **[RFC-AITP-0004 Mutual Handshake](../rfcs/RFC-AITP-0004-mutual-handshake.md)**
   — the protocol's hot path. Four messages, two round trips. §5
   defines the verification sequence; §4 defines the TCT-issuance and
   grant-intersection rules. The round-2 commit payloads (§3.3, §3.4)
   carry the TCT and, optionally, its companion `grant_voucher`.

6. **[RFC-AITP-0005 TCT](../rfcs/RFC-AITP-0005-tct.md)** — the output
   artifact: a compact JWS (`typ` `aitp-tct+jwt`) signed by the issuing
   peer, audience-bound, capability-scoped, with a top-level `cnf.jkt`
   claim for downstream PoP (§3). Verified locally using only the issuing
   peer's Manifest key, your own AID, and the current time, in the order
   of §7.2. §8 defines the **grant voucher** (`typ` `aitp-grant+jwt`),
   minted alongside the TCT so the subject can later delegate.

7. **[RFC-AITP-0006 Delegation](../rfcs/RFC-AITP-0006-delegation.md)** —
   single-hop. The delegation token embeds the grant voucher; verify
   `scope ⊆ voucher.grants` (§4 step 6). Multi-hop is RFC-AITP-0011
   (opt-in, see below); a core implementation MUST reject a delegation
   token carrying a `chain` claim with `DELEGATION_MULTIHOP_NOT_SUPPORTED`
   (§4, "Multi-hop guard").

8. **[RFC-AITP-0007 Key Resolution](../rfcs/RFC-AITP-0007-key-resolution.md)**
   — operational. Manifest-first for peer keys; cache → pinned →
   well-known for issuer keys. Read §3 carefully:
   `key_resolution.fail_mode` and `revocation_policy.mode` are
   different fields with different semantics.

9. **[RFC-AITP-0008 Revocation](../rfcs/RFC-AITP-0008-revocation.md)** —
   operational. Per-issuing-peer JTI deny lists. Each agent revokes
   only what it issued; consumers consult the issuer's deny list.
   Revoking a TCT also kills its voucher and every delegation derived
   from it (§1.1).

10. **[RFC-AITP-0009 Security](../rfcs/RFC-AITP-0009-security.md)** —
    review what you've learned. The threat model is the integration
    test for whether you understood the protocol.

### Status and opt-in RFCs

Per the [RFC index](../rfcs/README.md), RFCs 0001–0011 are **Draft**
(see [governance/RFC-PROCESS.md](../governance/RFC-PROCESS.md) for the
lifecycle). Of those, RFC-AITP-0010 (Session Trust Bundle) and
RFC-AITP-0011 (Multi-hop Delegation) are **opt-in**: Draft normative
text, outside v0.2 core conformance. RFC-AITP-0012 (Extensions) is
**Reserved** — its contents are non-normative for `aitp/0.2` — and
RFC-AITP-0013 (TCT Renewal Extension) is a **Planned** stub. Core
conformance does not require implementing 0010–0013, but the
[RFC-AITP-0012](../rfcs/RFC-AITP-0012-extensions.md) §5–§6 constraints (ignore
unknown keys inside `extensions`/`ext`; make no trust decision from
`zk`/`tee`/`sd_grant`) and the `chain`-claim rejection above still apply.

---

## Implementation gotcha: always decode before hashing

Every PoP signing input hashes the *decoded raw bytes* of the nonce or
challenge, never the base64url string:
`hash_input = sha256(base64url_decode(nonce_or_challenge))`. The rule,
and the four code paths it covers (Manifest PoP, handshake PoP,
downstream TCT PoP, pinned-key identity proof), is
[RFC-AITP-0001 §5.4.2](../rfcs/RFC-AITP-0001-core.md#542-pop-signing-input-convention).
Hashing the ASCII form is internally consistent but fails
cross-implementation verification; run `kat-manifest-pop-001` in
[`schemas/conformance/known-answer/jcs-sha256.json`](../schemas/conformance/known-answer/jcs-sha256.json)
through all four paths.

---

## Companions

- [`docs/integration-guide.md`](integration-guide.md) — consuming a
  peer-issued TCT: the RFC-AITP-0005 §7.2 verification order, error
  codes, PoP, and links to maintained verifier code.
- [`docs/ecosystem.md`](ecosystem.md) — which sibling repository owns
  SDK usage, the independent verifier, deployment, and tooling.
- [`docs/operational-guidance.md`](operational-guidance.md) —
  non-normative patterns for renewal, rotation, cache TTLs, and rate
  limiting.
- [`docs/threat-model.md`](threat-model.md) — distilled threat surface.
- [`docs/GLOSSARY.md`](GLOSSARY.md) — terminology quick reference.

---

## Conformance

What a conformant v0.2 implementation MUST do is
[RFC-AITP-0001 §10](../rfcs/RFC-AITP-0001-core.md#10-conformance). In
short, verify against:

- [`schemas/json/`](../schemas/json/) — canonical JSON Schemas.
- [`schemas/conformance/`](../schemas/conformance/README.md) — pass/fail
  behavioral fixtures. The core surface is `env-*`, `man-*`, `mh-*`,
  `id-*`, `tct-*`, `vch-*`, `del-*` and `rev-*`. The `del-mh-*` and
  `bundle-*` fixtures belong to the opt-in RFCs: a core implementation
  rejects `del-mh-*` tokens with `DELEGATION_MULTIHOP_NOT_SUPPORTED` and
  reports the `bundle-*` operations as `SKIP`, not `FAIL`
  (RFC-AITP-0001 §10 item 9).
- [`schemas/conformance/known-answer/`](../schemas/conformance/known-answer/README.md)
  — the mandatory known-answer tests: the JCS signing-input vectors
  (`kat-manifest-001`, `kat-revocation-001`), the PoP vector
  `kat-manifest-pop-001`, and the
  [`signed-examples/`](../schemas/conformance/known-answer/signed-examples/README.md)
  set — compact-JWS TCT, grant voucher and delegation, plus the JCS
  Manifest and revocation snapshot, verified as committed
  (RFC-AITP-0001 §10 item 8). The multi-hop and session-bundle vectors
  are required only if you opt into RFC-AITP-0011 / RFC-AITP-0010.

How an implementation is wired to the suite is documented by the
implementations themselves: see
[aitp-rs conformance](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/conformance.md)
and the
[aitp-verifier-py conformance coverage](https://github.com/agentidentitytrustprotocol/aitp-verifier-py/blob/main/README.md#conformance-coverage).

`make validate` checks this repository itself (schemas, fixtures,
known-answer values and documentation coherence); it runs locally and in
CI. Adding a fixture? Read the contract in
[`schemas/conformance/README.md`](../schemas/conformance/README.md#fixture-input-validation).
The documentation-coherence stages are described in the header of
[`scripts/check-doc-coherence.sh`](../scripts/check-doc-coherence.sh).
