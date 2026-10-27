# Extension Key Registry

The Manifest (`extensions` object) and other AITP wire artifacts permit
agents to advertise non-normative capabilities or out-of-band endpoints
without colliding with normative fields. This registry pins the keys
that AITP-defined extensions use, so independent implementations
discover each other's optional features without ad-hoc string matching.

| Key | Object | Type | RFC | Status |
|---|---|---|---|---|
| `rfc-aitp-0005.verify_uri` | Manifest `extensions` | HTTPS URL | [RFC-AITP-0005](../rfcs/RFC-AITP-0005-tct.md) | Provisional |
| `rfc-aitp-0005.renew_uri` | Manifest `extensions` | HTTPS URL | [RFC-AITP-0013 §2](../rfcs/RFC-AITP-0013-tct-renewal-extension.md#2-discovery) (Draft, opt-in) | Provisional |
| `rfc-aitp-0006.delegation_verify_uri` | Manifest `extensions` | HTTPS URL | [RFC-AITP-0006](../rfcs/RFC-AITP-0006-delegation.md) | Provisional |
| `rfc-aitp-0008.revocation_list_uri` | Manifest `extensions` | HTTPS URL of the issuer's `ListRevoked` endpoint. REQUIRED in the Manifest of every peer that issues TCTs; a verifier MUST NOT reject a Manifest solely for its absence | [RFC-AITP-0008 §1.4](../rfcs/RFC-AITP-0008-revocation.md#14-distribution), [RFC-AITP-0005 §11](../rfcs/RFC-AITP-0005-tct.md#11-peer-issued-tct-verification-api) | Provisional |
| `rfc-aitp-0010.bundle_uri` | Manifest `extensions` | HTTPS URL | [RFC-AITP-0010 §4.3](../rfcs/RFC-AITP-0010-session-trust-bundle.md) (Draft; opt-in) | Provisional |
| `rfc-aitp-0006.sd_voucher` | Grant voucher `ext` claim | JSON object | [RFC-AITP-0006 §5.4](../rfcs/RFC-AITP-0006-delegation.md#54-privacy-the-voucher-discloses-bs-full-grant-profile) — reserved for a future selective-disclosure (SD-JWT-style) voucher profile; carries no semantics yet | Proposed |
| `rfc-aitp-0014.a2a_interfaces` | Manifest `extensions` | array of HTTPS URLs: the exact A2A `AgentInterface.url` values at which the agent accepts AITP-authenticated A2A requests | [RFC-AITP-0014 §4.1](../rfcs/RFC-AITP-0014-a2a-agent-card.md#41-the-a2a-interfaces-manifest-key) (Draft; opt-in) | Proposed |

## Rules

- All values MUST be HTTPS URLs except in localhost development mode
  (`http://localhost*` or `http://127.0.0.1*`), where deployments MAY
  use plain HTTP for testing.
- Extension keys MUST follow the `rfc-aitp-NNNN.<short_name>` form when
  they are introduced by an AITP RFC. Keys outside that namespace SHOULD
  use vendor-prefixed reverse-domain names (e.g. `com.example.feature`,
  per [README.md naming conventions](README.md#naming-conventions)).
- Unknown extension keys MUST be ignored by consumers
  ([RFC-AITP-0001 §7](../rfcs/RFC-AITP-0001-core.md#7-compatibility-model)).
  Treating an unknown key as a hard failure is non-conformant.
- An extension key being present in this registry does NOT make the
  underlying extension part of core conformance. The cited RFC controls
  conformance scope. The one core key today is
  `rfc-aitp-0008.revocation_list_uri`, which RFC-AITP-0005 §11 and
  RFC-AITP-0008 §1.4 require every TCT issuer to advertise.

## Adding a key

Open a PR adding a row above. Include:

- the key string,
- which wire object hosts it,
- the value type (URL, integer, JSON object, etc.),
- the RFC or document that defines its semantics,
- the [status](README.md#status-values) (`Proposed`, `Provisional`,
  `Stable`, or `Deprecated`).
