# Conformance Test Fixtures

AITP conformance fixtures are JSON files that describe a scenario, the input,
and the expected agent behavior. Any compliant implementation MUST produce the
specified outcome for each fixture.

---

## Structure

```
conformance/
├── README.md
├── env-*.json   Envelope-level checks (RFC-AITP-0001, RFC-AITP-0007)
├── man-*.json   Manifest verification (RFC-AITP-0003)
├── mh-*.json    Mutual Handshake scenarios (RFC-AITP-0004)
├── id-*.json    Identity binding failures (RFC-AITP-0002)
├── tct-*.json   Trust Context Token verification (RFC-AITP-0005, RFC-AITP-0008)
└── del-*.json   Single-hop delegation (RFC-AITP-0006)
```

---

## Fixture Format

Every fixture MUST carry the following metadata block as its leading
fields. The block exists so a v0.1 conformance runner can know — without
parsing scenario content — whether a fixture is required for v0.1, an
opt-in draft feature, or out of scope entirely.

```json
{
  "id": "unique-fixture-id",
  "rfc": "RFC-AITP-NNNN",
  "status": "core | draft | extension | reserved",
  "required_for_v0_1": true,
  "feature": null,
  "description": "Human-readable description of the scenario",
  "tags": ["happy-path | failure | security | edge-case"],
  "input": { ... },
  "expected": {
    "outcome": "success | failure",
    "error_code": "ERROR_CODE (if failure)",
    "grants": ["capability (if success)"]
  }
}
```

### Metadata fields

| Field | Type | Meaning |
|---|---|---|
| `id` | string | Fixture id (e.g. `mh-success-001`). |
| `rfc` | string | Most-specific RFC the fixture exercises (e.g. `RFC-AITP-0006`). |
| `status` | enum | One of `core`, `draft`, `extension`, `reserved`. See enforcement rules below. |
| `required_for_v0_1` | bool | Whether a v0.1 implementation MUST pass this fixture. Always `false` for `draft` / `extension` fixtures. |
| `feature` | string \| null | When `status != "core"`, the named opt-in feature flag a runner uses to enable this fixture (e.g. `experimental-session-bundle`). `null` for core fixtures. |

### Conformance runner enforcement rules

A v0.1 conformance runner MUST apply the following rules to the metadata
block before executing a fixture:

- `status: "core"` + `required_for_v0_1: true` → **MUST execute.** A
  `OP_NOT_SUPPORTED` result or runner SKIP MUST be reported as a failure
  for this fixture.
- `status: "draft"` → **MUST SKIP** unless the runner has explicitly
  opted into the named `feature` (and, by extension, draft conformance
  for the cited RFC). Failing a v0.1 implementation for not implementing
  a draft fixture is non-conformant runner behavior.
- `status: "extension"` → **MUST SKIP** in the v0.1 default runner. May
  be exercised only when the runner is explicitly testing the named
  extension feature.
- `status: "reserved"` → MUST be ignored by every runner; reserved status
  exists only so a fixture id slot can be claimed before the underlying
  RFC normative text lands.

Any fixture missing the metadata block, or carrying invalid values for
these fields, MUST cause the runner to fail loudly rather than silently
skip — the metadata is a load-bearing input to interop testing.

### Multi-step `sequence` form

Fixtures that exercise stateful behavior (e.g. replay detection across two sends, or a downstream PoP exchange across challenge/response) use a `sequence` array inside `input` instead of a single `expected` block. Each entry is one step:

```json
{
  "input": {
    "sequence": [
      { "step": 1, "operation": "...", "message_id": "...", "expected": { "outcome": "success" } },
      { "step": 2, "operation": "...", "message_id": "...", "expected": { "outcome": "failure", "error_code": "REPLAY_DETECTED" } }
    ]
  }
}
```

The runner MUST execute each step in order against the same implementation instance and assert the per-step `expected` outcome. Each step carries its own `operation` field — see PLACEHOLDERS.md "Operation key" for the per-prefix operation registry.

Sequence fixtures MAY also carry sibling fields inside `input` that provide context shared across all steps. For example, `tct-006-pop-challenge-response.json` carries `input.tct_token` alongside `input.sequence` because every step in the sequence operates against the same TCT (the consuming peer issues a challenge for it; the holder produces a response over its `binding.cnf`; the verifier checks both). Sibling context fields are part of the fixture input and the runner MUST make them available to every step.

`mh-001` (replay detection) and `tct-006` (downstream PoP) are the v0.1 fixtures using this form.

---

## Running Conformance Tests

Implementations MUST provide a conformance runner that:

1. Accepts a fixture directory path.
2. Executes each fixture against the implementation.
3. Reports pass/fail per fixture ID.

The runner interface is implementation-defined.

---

## Fixture Index

### Envelope and key resolution (RFC-AITP-0001, RFC-AITP-0007)

| ID | Description | Outcome |
|---|---|---|
| `env-001` | Envelope timestamp older than tolerance window | failure: TIMESTAMP_EXPIRED |
| `env-002` | Caller invokes a capability not present in the active TCT | failure: POLICY_VIOLATION |
| `env-003` | Issuer key cannot be resolved (Manifest unreachable, OIDC offline) | failure: KEY_RESOLUTION_FAILED |
| `env-004` | Replayed envelope `message_id` rejected by deny list | failure: REPLAY_DETECTED |

### Manifest (RFC-AITP-0003)

| ID | Description | Outcome |
|---|---|---|
| `man-001` | Manifest `expires_at` is in the past at fetch time | failure: MANIFEST_EXPIRED |
| `man-002` | Manifest declares an unsupported `version` | failure: MANIFEST_VERSION_UNKNOWN |
| `man-003` | Cached Manifest past `expires_at` is rejected even if otherwise valid | failure: MANIFEST_EXPIRED |

### Mutual Handshake (RFC-AITP-0004)

| ID | Description | Outcome |
|---|---|---|
| `mh-success-001` | Both peers complete MUTUAL_COMMIT with valid TCTs | success |
| `mh-001` | Replayed MUTUAL_HELLO (duplicate message_id) rejected | failure: REPLAY_DETECTED |
| `mh-002` | Manifest signature invalid → rejected | failure: MANIFEST_SIGNATURE_INVALID |
| `mh-003` | Manifest PoP failed → rejected | failure: MANIFEST_POP_FAILED |
| `mh-004` | Peer issuer not in accepted_trust_anchors | failure: INCOMPATIBLE_TRUST_ANCHORS |
| `mh-005` | pop_nonce_echo mismatch | failure: NONCE_MISMATCH |
| `mh-006` | Peer-issued TCT audience ≠ self AID | failure: AUDIENCE_MISMATCH |
| `mh-007` | Peer-issued TCT grants exceed offered_capabilities | failure: GRANT_OVERFLOW |
| `mh-008` | Peer PoP signature invalid | failure: POP_VERIFICATION_FAILED |
| `mh-009` | Peer's identity type not in own `accepted_identity_types` | failure: INCOMPATIBLE_TRUST_ANCHORS |

### Identity Binding (RFC-AITP-0002)

| ID | Description | Outcome |
|---|---|---|
| `id-001` | OIDC JWT missing `aud` claim | failure: IDENTITY_FAILED |
| `id-002` | OIDC JWT `aud` targets a different peer's AID | failure: IDENTITY_FAILED |
| `id-003` | OIDC JWT missing `cnf.jkt` claim | failure: IDENTITY_FAILED |
| `id-004` | Pinned-key proof captured from one handshake replayed against a different receiver/message/nonce | failure: IDENTITY_FAILED |
| `id-005` | Pinned-key legacy proof (pre-rc.3 binding) rejected | failure: IDENTITY_FAILED |
| `id-006` | Pinned-key proof signed over the wrong `pop_nonce` rejected | failure: IDENTITY_FAILED |
| `id-007` | Pinned-key proof from an untrusted public key rejected | failure: IDENTITY_FAILED |

### Trust Context Token (RFC-AITP-0005, RFC-AITP-0008)

| ID | Description | Outcome |
|---|---|---|
| `tct-002` | Expired peer-issued TCT rejected | failure: TCT_EXPIRED |
| `tct-003` | TCT signature does not validate under the issuer's key | failure: TCT_SIGNATURE_INVALID |
| `tct-004` | TCT `jti` listed in the issuing peer's revocation list | failure: TCT_REVOKED |
| `tct-005` | TCT `expires_at` is after the issuing peer's Manifest `expires_at` | failure: TCT_EXPIRED |
| `tct-006` | Downstream PoP `pop_challenge` / `pop_response` exchange round-trips successfully | success |

### Revocation (RFC-AITP-0008)

| ID | Description | Outcome |
|---|---|---|
| `rev-001` | Stale revocation snapshot under `fail_closed` mode rejects the request | failure: TCT_REVOKED |
| `rev-002` | Stale revocation snapshot under `soft_fail` mode allows a configured safe-subset of grants | success (degraded) |
| `rev-003` | Fresh signed snapshot, JTI not in entries → not revoked | success |

### Delegation (RFC-AITP-0006)

| ID | Description | Outcome |
|---|---|---|
| `del-001` | Single-hop happy path — A→B→C with scope ⊆ grant_proof.capabilities | success |
| `del-003` | Scope exceeds grant_proof capabilities | failure: DELEGATION_SCOPE_EXCEEDED |
| `del-004` | A delegation token with a non-empty `chain` field MUST be rejected by v0.1 implementations as a structural check, before any per-hop signature work | failure: DELEGATION_MULTIHOP_NOT_SUPPORTED |

### Multi-hop Delegation (RFC-AITP-0011, post-v0.1)

These fixtures exercise the multi-hop delegation extension. v0.1 implementations MUST reject any token with a non-empty `chain` field with `DELEGATION_MULTIHOP_NOT_SUPPORTED` (RFC-AITP-0006 §9). v0.2 implementations that opt in follow RFC-AITP-0011 verification rules.

| ID | Description | Outcome |
|---|---|---|
| `del-mh-001` | 3-hop chain (A→B→C→D) — all signatures, transitive scope, chain_hash, and outer signature valid | success |
| `del-mh-002` | 3-hop chain where chain[1] introduces a capability not in chain[0] — transitive scope check rejects | failure: DELEGATION_SCOPE_EXCEEDED |
| `del-mh-003` | 3-hop chain with tampered `chain_hash` — recomputed value mismatches | failure: DELEGATION_CHAIN_HASH_MISMATCH |
| `del-mh-004` | 3-hop chain where `chain[1].source_tct_jti` is in chain[1].issuer's deny list | failure: DELEGATION_SOURCE_TCT_REVOKED |

### Session Trust Bundle (RFC-AITP-0010, post-v0.1)

Bundle fixtures use the same opt-in posture as multi-hop. v0.1 implementations are not required to support session bundles.

| ID | Description | Outcome |
|---|---|---|
| `bundle-001` | 2-participant bundle, fresh, valid coordinator signature, receiver is in participants | success |
| `bundle-002` | Bundle is byte-valid but receiver's AID is not in `participants[*].aid` | failure: BUNDLE_NOT_MEMBER |
| `bundle-003` | Bundle's `expires_at` is in the past (with consistent embedded TCT expiry) | failure: BUNDLE_EXPIRED |

Additions and edge-case fixtures (replay during MUTUAL_COMMIT, identity-issuer key rotation, partial chain verification, etc.) are welcome via PR.

---

## Pre-v0.1 fixture renames

Earlier drafts of AITP used `hs-*` (handshake) fixture IDs. The Mutual Handshake restructure (RFC-AITP-0004) renamed them to `mh-*` and split a single happy-path into a dedicated success fixture. External citations of the old IDs map as follows:

| Old ID | New ID | Notes |
|---|---|---|
| `hs-001-oidc-direct-tct` | `mh-success-001` | Happy-path mutual handshake; OIDC identity is one of several success paths covered by `id-*` fixtures. |
| `hs-004-replay-rejected` | `mh-001` | Replayed `MUTUAL_HELLO` rejected via `REPLAY_DETECTED`. |

No `hs-*` IDs are reserved for v0.1 or later.

---

## Placeholder convention

Many fixtures contain string tokens of the form `__UPPER_SNAKE__`
(e.g. `__VALID_ENVELOPE_SIG__`, `__NOW__`,
`__JWT_MISSING_AUD_CLAIM__`). These are not literal values: they mark
positions where a minting tool must substitute real data
(signatures, timestamps, JWTs, captured-proof bytes) before the
fixture is fed to a conformance runner. Every placeholder used in this
directory is defined normatively in [`PLACEHOLDERS.md`](PLACEHOLDERS.md),
which also pins:

- The mapping from fixture role names (`agentA`, `agentB`, `agentC`,
  …) to the [pinned KAT keypairs](known-answer/keypairs.json).
- The reference clock for `__NOW__` (`1711900000`) so re-mints are
  byte-stable.
- The runner-facing `input.operation` registry per fixture id prefix.
- The pinned tamper recipe for `__TAMPERED_*__` (sign-then-flip-LSB
  of the last raw signature byte) so failure-injection placeholders
  reproduce.

Minted (real-signature) versions of these fixtures will live alongside
the placeholder originals once an implementation produces them. See
[`known-answer/signed-examples/`](known-answer/signed-examples/) for
the reserved location.
