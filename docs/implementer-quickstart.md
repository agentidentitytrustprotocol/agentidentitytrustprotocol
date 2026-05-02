# Implementer Quickstart

A one-page reading order for someone building an AITP peer agent. The
authoritative source is the RFC set; this page just sequences them with
context so you don't end up reading them backwards.

---

## Read in this order

1. **[`docs/architecture.md`](architecture.md)** — orient first. The
   problem, the shape, the flows, where state lives, and the big
   invariant. Skip nothing here; it makes the RFCs ~30 % faster to read.

2. **[RFC-AITP-0001 Core](../rfcs/RFC-AITP-0001-core.md)** — primitives.
   The signed envelope, replay protection (`message_id` dedup +
   timestamp window), JCS canonical signing input, base64url rules,
   error codes, and the `aid:pubkey:<43-char>` format. Implement the
   envelope first.

3. **[RFC-AITP-0002 Identity](../rfcs/RFC-AITP-0002-identity.md)** —
   proofs. OIDC (with `aud` and `cnf.jkt`) and pinned-key (with the
   five-field handshake-bound proof input). The verifying party is
   always another peer, never a third party.

4. **[RFC-AITP-0003 Manifest](../rfcs/RFC-AITP-0003-manifest.md)** —
   discovery. The signed self-description served at
   `/.well-known/aitp-manifest`. Verify in the order listed in §5; the
   bootstrap order matters.

5. **[RFC-AITP-0004 Mutual Handshake](../rfcs/RFC-AITP-0004-mutual-handshake.md)**
   — the protocol's hot path. Four messages, two round trips. §5
   defines the verification sequence; §4 defines the TCT-issuance and
   grant-intersection rules.

6. **[RFC-AITP-0005 TCT](../rfcs/RFC-AITP-0005-tct.md)** — the output
   artifact. Signed by the issuing peer, audience-bound, capability-
   scoped, with `binding.cnf` for downstream PoP. Verified locally
   using only the issuing peer's Manifest key, your own AID, and the
   current time.

7. **[RFC-AITP-0006 Delegation](../rfcs/RFC-AITP-0006-delegation.md)** —
   single-hop. Multi-hop is reserved for RFC-AITP-0011 and is NOT in
   v0.1. Verify scope ⊆ grant_proof.capabilities at every hop.

8. **[RFC-AITP-0007 Key Resolution](../rfcs/RFC-AITP-0007-key-resolution.md)**
   — operational. Manifest-first for peer keys; cache → pinned →
   well-known for issuer keys. Read §3 carefully:
   `key_resolution.fail_mode` and `revocation_policy.mode` are
   different fields with different semantics.

9. **[RFC-AITP-0008 Revocation](../rfcs/RFC-AITP-0008-revocation.md)** —
   operational. Per-issuing-peer JTI deny lists. Each agent revokes
   only what it issued; consumers consult the issuer's deny list.

10. **[RFC-AITP-0009 Security](../rfcs/RFC-AITP-0009-security.md)** —
    review what you've learned. The threat model is the integration
    test for whether you understood the protocol.

**Skip RFC-AITP-0010, 0011, and 0012** until v0.2. They are reserved;
no normative text is published. Implementations MUST NOT depend on
their contents.

---

## Companions

- [`docs/integration-guide.md`](integration-guide.md) — Python
  pseudocode for verifying a peer-issued TCT (signature, audience,
  expiry, unknown-field rejection).
- [`docs/operational-guidance.md`](operational-guidance.md) —
  non-normative patterns for renewal, rotation, cache TTLs, and rate
  limiting.
- [`docs/threat-model.md`](threat-model.md) — distilled v0.1 threat
  surface.
- [`docs/GLOSSARY.md`](GLOSSARY.md) — terminology quick reference.

---

## Conformance

When implementing, verify against:

- [`schemas/json/`](../schemas/json/) — canonical JSON Schemas.
- [`schemas/conformance/`](../schemas/conformance/) — pass/fail behavioral
  fixtures (`env-*`, `man-*`, `mh-*`, `id-*`, `tct-*`, `del-*`).

`make validate` runs the schema and example checks locally.
