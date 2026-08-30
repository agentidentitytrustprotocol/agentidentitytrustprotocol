# Identity Types Registry

Registered values for `IdentityDescriptor.type`. New types are added via the [RFC process](../governance/RFC-PROCESS.md).

| ID | Description | Required fields | Status | Spec |
|---|---|---|---|---|
| `oidc` | OpenID Connect issuer with a JWT proof. | `issuer`, `subject`, `proof` (JWT) | Stable | [RFC-AITP-0002 §2](../rfcs/RFC-AITP-0002-identity.md#2-oidc-identity-type) |
| `pinned_key` | Locally pre-configured public key with a PoP signature. | `subject`, `public_key`, `proof` (sig binding sender AID, receiver AID, `message_id`, `timestamp`, and the handshake `pop_nonce` per [RFC-AITP-0002 §3.1](../rfcs/RFC-AITP-0002-identity.md#31-proof-format)) | Stable | [RFC-AITP-0002 §3](../rfcs/RFC-AITP-0002-identity.md#3-pinned-key-identity-type) |
| `did` | W3C Decentralized Identifier with Verifiable Credential. | TBD | Reserved (v0.3+) | [RFC-AITP-0002 §5](../rfcs/RFC-AITP-0002-identity.md#5-future-identity-types-v03) |
| `x509` | X.509 certificate chain (Web PKI). | TBD | Reserved (v0.3+) | [RFC-AITP-0002 §5](../rfcs/RFC-AITP-0002-identity.md#5-future-identity-types-v03) |
| `wallet` | Blockchain-wallet signature. | TBD | Reserved (v0.3+) | [RFC-AITP-0002 §5](../rfcs/RFC-AITP-0002-identity.md#5-future-identity-types-v03) |
