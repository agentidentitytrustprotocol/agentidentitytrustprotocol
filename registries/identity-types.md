# Identity Types Registry

Registered values for `IdentityDescriptor.type`. New types are added via the [RFC process](../governance/RFC-PROCESS.md).

| ID | Description | Required fields | Status | Spec |
|---|---|---|---|---|
| `oidc` | OpenID Connect issuer with a JWT proof. | `issuer`, `subject`, `proof` (JWT) | Stable | [RFC-AITP-0002 §2](../rfcs/RFC-AITP-0002-identity.md#2-oidc-identity-type) |
| `pinned_key` | Locally pre-configured Ed25519 or P-256 public key with a PoP signature; `issuer` MUST be absent. | `subject`, `public_key`, `proof` (sig binding sender AID, receiver AID, `message_id`, `timestamp`, and the handshake `pop_nonce` per [RFC-AITP-0002 §3.1](../rfcs/RFC-AITP-0002-identity.md#31-proof-format)) | Stable | [RFC-AITP-0002 §3](../rfcs/RFC-AITP-0002-identity.md#3-pinned-key-identity-type) |
| `spiffe` | SPIFFE workload identity: a SPIFFE ID proven by a JWT-SVID or an X509-SVID that chains to the local SPIFFE bundle of its trust domain; `issuer` and `public_key` MUST be absent. | `subject` (SPIFFE ID), `svid_type`, `proof`; `x5c` for `x509-svid` | Proposed | [RFC-AITP-0002 §6](../rfcs/RFC-AITP-0002-identity.md#6-spiffe-identity-type) |
| `did` | W3C Decentralized Identifier with Verifiable Credential. | TBD | Reserved (future revision) | [RFC-AITP-0002 §5](../rfcs/RFC-AITP-0002-identity.md#5-future-identity-types) |
| `x509` | X.509 certificate chain (Web PKI). A SPIFFE X509-SVID is not `x509`; it is `spiffe` with `svid_type` `x509-svid`. | TBD | Reserved (future revision) | [RFC-AITP-0002 §5](../rfcs/RFC-AITP-0002-identity.md#5-future-identity-types) |
| `wallet` | Blockchain-wallet signature. | TBD | Reserved (future revision) | [RFC-AITP-0002 §5](../rfcs/RFC-AITP-0002-identity.md#5-future-identity-types) |
