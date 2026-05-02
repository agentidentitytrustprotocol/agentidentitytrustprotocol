# RFC-AITP-0012
# Extensions (ZK, TEE) — Reserved

**Document:** RFC-AITP-0012
**Version:** 0.1.0-reserved
**Status:** Reserved

---

## Abstract

AITP v0.1 reserves the `extensions` field on protocol payloads for two extension families: zero-knowledge proofs (ZK) and Trusted Execution Environment attestations (TEE). This RFC pins the field names, the registration model, and the future milestones so that v0.1 implementations do not collide with future extensions.

The contents of this RFC are **non-normative** for v0.1. They become normative in a future version.

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

## 4. Compatibility

A v0.1 peer receiving an envelope or Manifest with an `extensions` object MUST ignore unknown keys. A v0.1 peer MUST NOT make a trust decision based on `extensions.zk` or `extensions.tee`. Production deployments that need these guarantees today should run an implementation that adopts the future, normative version of this RFC.

---

## 5. Security Considerations

The contents of `extensions.zk` and `extensions.tee` are non-normative for v0.1. Implementations MUST treat extension data as advisory metadata and MUST NOT make a trust decision based on it. A future, normative version of this RFC will specify the security model for each extension family. Pending that work, the following constraints are already in force:

- **No silent trust elevation.** A v0.1 peer MUST NOT grant additional capabilities or extend a TCT's lifetime because a peer presented `extensions.zk` or `extensions.tee` data.
- **Unknown extensions ignored for trust decisions.** Unknown keys under `extensions` MUST NOT cause a verification failure (RFC-AITP-0001 §7). They are still part of the *signed object* — the JCS canonical form covers the entire `extensions` field if present, and removing a key would change the signing input and break the signature. v0.1 implementations MUST NOT grant additional authority based on extension content. Future RFCs may make specific extension keys normative.
- **Vendor namespacing.** Vendor extensions under reverse-domain prefixes (`extensions.com.example.feature`) inherit the same constraints. Vendors MUST NOT use vendor namespaces to inject implicit trust signals.
- **Replay surface.** Once an extension is normative, its inputs (e.g. ZK proof public inputs, TEE attestation nonces) MUST be bound to the same handshake nonce or envelope `message_id` that protects the rest of the payload.

## 6. References

- [RFC-AITP-0001 Core](RFC-AITP-0001-core.md)
- [RFC-AITP-0009 Security](RFC-AITP-0009-security.md)
