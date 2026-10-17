# jti Domain Tag Registry

Domain tags for derived identifiers. A TCT `jti`, an envelope `message_id`, or any other AITP identifier in the UUID v4 layout MAY take its bits from a hash instead of a CSPRNG ([RFC-AITP-0005 §2.2](../rfcs/RFC-AITP-0005-tct.md#22-identifier-layout-jti)):

```
h  = SHA-256(domain_tag_bytes || 0x00 || input_bytes)
id = h[0..16], with h[6] = (h[6] & 0x0f) | 0x40 and h[8] = (h[8] & 0x3f) | 0x80,
     rendered as lowercase hyphenated 8-4-4-4-12 hex
```

The domain tag separates one use of the construction from every other, so that two issuers, or two features of one issuer, that happen to hash the same `input_bytes` never produce the same identifier. This registry lists the tags in use, so that a new tag can be checked against them before it ships.

> **Stability:** Registering a tag records a use; it does not make that use part of core conformance. A verifier never sees the tag and cannot tell a derived identifier from a random one, and MUST NOT try (RFC-AITP-0005 §2.2). Renaming or removing a tag changes every identifier derived under it, so a registered tag is never reassigned to a different derivation input; a changed input takes a new tag (by convention, the next `-vN` suffix).

## Tag format

A tag is printable ASCII (`0x21`–`0x7E`): no spaces and no `0x00`. Tags SHOULD end in a version suffix (`-v1`). AITP-owned tags start with `aitp-`; other owners SHOULD start their tags with a name they control (a project or vendor name).

**Why the `0x00` separator.** Tags are variable-length and some tags are prefixes of others (`a` and `ab`). Without a separator, tag `a` with input `b…` and tag `ab` with input `…` concatenate to the same preimage, and so to the same identifier. Because no tag contains `0x00`, the first `0x00` byte in the preimage always marks the end of the tag: two different tags can never yield the same preimage, whatever their inputs. This is the convention RFC-AITP-0002 §3.1 uses for `proof_input`.

## Registered tags

| Tag | Owner | Derivation input (`input_bytes`) | Use | Status |
|---|---|---|---|---|
| `aitp-kat-derived-uuid-v1` | AITP | The bytes the vector's `input_hex` encodes (for `kat-derived-uuid-001`, the ASCII string `kat-derived-uuid-001/input`) | Test and known-answer use only: pins the construction in [`kat-derived-uuid-001`](../schemas/conformance/known-answer/jcs-sha256.json). MUST NOT be used for production identifiers. | Provisional |
| `aitp-kat-attestation-v1` | AITP | The UTF-8 bytes of the id of the known-answer vector that carries the token | Test and known-answer use only: deterministic `jti` values for self-attestation TCT vectors. MUST NOT be used for production identifiers. | Provisional |
| `seam-tct-jti-v1` | zer07 Labs ([seam-runtime](https://github.com/zer07labs/seam-runtime)) | `u32_BE(len(id)) \|\| id \|\| i64_BE(seal_ms)`: the record id's byte length as a 4-byte big-endian unsigned integer, the record id bytes, then the seal time in milliseconds as an 8-byte big-endian signed integer | TCT `jti` for re-mintable record commitments | Provisional |
| `seam-pop-mid-v1` | zer07 Labs ([seam-runtime](https://github.com/zer07labs/seam-runtime)) | The ASCII bytes of the base64url challenge nonce, as transmitted (not its decoded bytes) | Envelope `message_id` derived from a single-use challenge nonce | Provisional |

Statuses use the shared [status values](README.md#status-values).

## Adding a tag

Open a PR adding a row above. Include:

- the exact tag string, checked against every row above, including prefix relationships;
- the owner (project or vendor), with a link;
- the exact derivation input, byte for byte, including integer widths and byte order;
- what the identifier is used for;
- the [status](README.md#status-values) (`Proposed`, `Provisional`, `Stable`, or `Deprecated`).

The input MUST be unique per identifier for that owner (RFC-AITP-0005 §2.2): the issuer guarantees that distinct tokens never share an `input_bytes`. A tag whose input cannot meet that rule is not registrable.
