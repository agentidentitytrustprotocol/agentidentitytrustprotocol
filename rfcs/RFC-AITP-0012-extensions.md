# RFC-AITP-0012
# Extensions (ZK, TEE) — Reserved

**Document:** RFC-AITP-0012
**Version:** 0.2.0-reserved
**Status:** Reserved

---

## Abstract

AITP v0.2 reserves the `extensions` field on protocol payloads for extension families: zero-knowledge proofs (ZK), Trusted Execution Environment attestations (TEE), and a selective-disclosure grant voucher (§4). This RFC pins the field names, the registration model, and the future milestones so that v0.2 implementations do not collide with future extensions.

The contents of this RFC are **non-normative** for v0.2. They become normative in a future version.

---

## 1. Extension Container

Any AITP payload MAY carry an `extensions` object. Unknown extension keys MUST be ignored.

```json
{
  "extensions": {
    "zk": { ... },
    "tee": { ... }
  }
}
```

Extensions are namespaced. Vendor-specific extensions SHOULD use reverse-domain notation under `extensions` (e.g. `extensions.com.example.feature`).

### 1.1 The `ext` claim on compact-JWS artifacts

On the compact-JWS portable trust artifacts — the TCT, the grant voucher, and the delegation token ([RFC-AITP-0001 §5.4.5](RFC-AITP-0001-core.md#545-compact-jws-profile-portable-trust-artifacts)) — the OPTIONAL `ext` private claim mirrors this `extensions` slot. The same namespacing and reservation rules apply to keys inside `ext`: unknown keys inside `ext` MUST be ignored (unknown claims *outside* `ext` MUST be rejected, per RFC-AITP-0005 §2 and RFC-AITP-0006). Extension families reserved in this RFC are reserved under both spellings: `extensions.<key>` on JCS-signed protocol payloads (envelope, Manifest) and `ext.<key>` on JWS claims objects.

---

## 2. Zero-Knowledge Proofs (`extensions.zk`)

```json
{
  "extensions": {
    "zk": {
      "proofs": [
        {
          "circuit": "compliance_v1",
          "public_inputs": {},
          "proof": "<base64url>",
          "verifier": "groth16"
        }
      ]
    }
  }
}
```

### Use cases

- Prove compliance with a policy without revealing the underlying data.
- Prove a payment amount is below a threshold without revealing the amount.
- Prove set membership without revealing the element.

### Reserved circuits

| Circuit ID | Description |
|---|---|
| `compliance_v1` | Generic compliance predicate. |
| `no_pii_leak_v1` | Data pipeline contains no PII. |
| `payment_threshold_v1` | Payment amount below threshold. |

Verifier implementations for these circuits will be specified in a future RFC.

---

## 3. Trusted Execution Environment (`extensions.tee`)

```json
{
  "extensions": {
    "tee": {
      "platform": "sgx | sev | trustzone",
      "quote": "<base64url attestation quote>",
      "measurement": "<sha256 of expected binary>",
      "nonce": "<challenge nonce>"
    }
  }
}
```

### Use cases

- Attest that an agent is running a specific, unmodified binary.
- Provide hardware-rooted identity for edge agents.
- Enable remote attestation for regulated environments.

---

## 4. Selective-Disclosure Grant Voucher (`ext.sd_grant`)

The grant voucher (RFC-AITP-0005 §8) embedded in a delegation token discloses the delegator's **complete** grant profile to the delegate and to every downstream verifier — see the privacy note in [RFC-AITP-0006 §5.4](RFC-AITP-0006-delegation.md#54-privacy-the-voucher-discloses-bs-full-grant-profile). This RFC reserves the `sd_grant` extension key as the hook for an SD-JWT-style ([draft-ietf-oauth-selective-disclosure-jwt](https://datatracker.ietf.org/doc/draft-ietf-oauth-selective-disclosure-jwt/)) selective-disclosure voucher: the issuing peer signs hashed grant disclosures, and the delegator reveals only the delegated subset.

```json
{
  "ext": {
    "sd_grant": {
      "sd_alg": "sha-256",
      "disclosures": ["<base64url disclosure>", "..."]
    }
  }
}
```

### Use cases

- Delegate a subset of capabilities without revealing the delegator's full grant profile to the delegate or downstream verifiers.
- Audit-friendly delegation: the issuing peer can still verify every disclosed grant against its own signature.

The voucher shape above is illustrative only. The concrete disclosure format, the `typ` value for a selective-disclosure voucher, and its verification rules will be specified in a future RFC. Until then, v0.2 peers MUST NOT make a trust decision based on `ext.sd_grant` (§5).

---

## 5. Compatibility

A v0.2 peer receiving an envelope or Manifest with an `extensions` object — or a JWS artifact with an `ext` claim — MUST ignore unknown keys inside it. A v0.2 peer MUST NOT make a trust decision based on `extensions.zk`, `extensions.tee`, or `ext.sd_grant`. Production deployments that need these guarantees today should run an implementation that adopts the future, normative version of this RFC.

---

## 6. Security Considerations

The contents of `extensions.zk`, `extensions.tee`, and `ext.sd_grant` are non-normative for v0.2. Implementations MUST treat extension data as advisory metadata and MUST NOT make a trust decision based on it. A future, normative version of this RFC will specify the security model for each extension family. Pending that work, the following constraints are already in force:

- **No silent trust elevation.** A v0.2 peer MUST NOT grant additional capabilities or extend a TCT's lifetime because a peer presented `extensions.zk`, `extensions.tee`, or `ext.sd_grant` data.
- **Unknown extensions ignored for trust decisions.** Unknown keys under `extensions` (and inside the JWS `ext` claim) MUST NOT cause a verification failure (RFC-AITP-0001 §7). They are still part of the *signed object* — the JCS canonical form covers the entire `extensions` field if present, and on a compact-JWS artifact the `ext` claim is covered by the signature over the transmitted bytes; removing a key would change the signing input and break the signature. v0.2 implementations MUST NOT grant additional authority based on extension content. Future RFCs may make specific extension keys normative.
- **Vendor namespacing.** Vendor extensions under reverse-domain prefixes (`extensions.com.example.feature`) inherit the same constraints. Vendors MUST NOT use vendor namespaces to inject implicit trust signals.
- **Replay surface.** Once an extension is normative, its inputs (e.g. ZK proof public inputs, TEE attestation nonces) MUST be bound to the same handshake nonce or envelope `message_id` that protects the rest of the payload.

## 7. References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0005 Trust Context Token](RFC-AITP-0005-tct.md)
- [RFC-AITP-0006 Single-Hop Delegation](RFC-AITP-0006-delegation.md)
- [RFC-AITP-0009 Security](RFC-AITP-0009-security.md)
- [SD-JWT — Selective Disclosure for JWTs (draft-ietf-oauth-selective-disclosure-jwt)](https://datatracker.ietf.org/doc/draft-ietf-oauth-selective-disclosure-jwt/)
