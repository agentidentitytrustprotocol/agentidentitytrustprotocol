# Signed Example Artifacts (Reserved)

This directory holds **real, cryptographically valid** AITP artifacts
minted from the pinned known-answer keypairs in
[`../keypairs.json`](../keypairs.json). It is the canonical location
for cross-implementation interop fixtures — files here MUST verify
under any conformant AITP v0.1 implementation, byte-for-byte, without
any placeholder substitution.

This directory is currently **empty**. The artifacts are produced by
running an AITP implementation's minting tool against the pinned
seeds; the spec repo cannot mint them itself because the spec is not
an implementation. The first real population is tracked at
`agentidentitytrustprotocol/agentidentitytrustprotocol#5` (paired with
`aitp-rs` BLOCKED-SPEC-EXAMPLE).

## Why a separate directory

The sibling files under `examples/` use placeholder signature strings
so they remain human-readable and unambiguously not-real-keys. That is
useful for documentation but cannot serve as an interop test fixture —
a verifier rejects placeholder signatures, by design.

This directory closes that gap with the same canonical objects but
real signatures. An implementation that fails to verify any artifact
in here is non-conformant.

## Expected layout

When populated, the directory will hold:

```
signed-examples/
├── README.md                               (this file)
├── manifest/
│   └── kat-keypair-001-manifest.json       Manifest signed by kat-keypair-001
├── tct/
│   └── kat-keypair-001-issues-002.json     Peer-issued TCT, kat-keypair-001 → 002
├── delegation/
│   └── single-hop-001-002-002.json         Single-hop delegation token
└── revocation/
    └── kat-keypair-001-snapshot.json       Signed revocation snapshot (empty entries)
```

Each file MUST:

1. Use only AIDs from [`../keypairs.json`](../keypairs.json).
2. Validate against the corresponding JSON Schema under `schemas/json/`.
3. Be byte-identical to a re-mint produced by any conformant
   implementation given the same input parameters
   (issued_at, expires_at, jti, scope, etc.).

## Reproducibility

The minting input for each artifact (chosen `jti`, `issued_at`,
`expires_at`, capabilities, etc.) MUST be documented inside the file
itself via a `_kat_input` companion object so a re-minter can recover
the exact byte sequence without out-of-band knowledge. Example:

```json
{
  "_kat_input": {
    "issuer_seed_id": "kat-keypair-001",
    "subject_seed_id": "kat-keypair-002",
    "jti": "550e8400-e29b-41d4-a716-446655440000",
    "issued_at": 1711900000,
    "expires_at": 1711903600,
    "grants": ["macp.mode.task.v1"]
  },
  "tct": { ... }
}
```

`_kat_input` is **not** part of the signed object — it sits beside the
signed wrapper at the top level of the file.

## Stability

Once a file is populated, its byte sequence is stable for the AITP
v0.1 lifecycle. Editing it (other than to fix a verified divergence
from the spec) is a breaking change to the conformance suite.
