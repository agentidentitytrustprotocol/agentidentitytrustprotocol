# Message Types Registry

Registered values for the envelope `message_type` ([RFC-AITP-0001 §5.2](../rfcs/RFC-AITP-0001-core.md#52-fields)). The envelope schema ([`aitp-envelope.schema.json`](../schemas/json/aitp-envelope.schema.json)) enumerates exactly these values, so an envelope carrying any other `message_type` fails schema validation with `INVALID_ENVELOPE`.

> **Authentication (informative).** This registry adds no requirement. In v0.2 the envelope signature covers `message_id`, `timestamp`, `sender.agent_id` and the payload digest, not `message_type` ([RFC-AITP-0001 §5.4](../rfcs/RFC-AITP-0001-core.md#54-signature)). For `identity_presentation`, [RFC-AITP-0002 §3.4](../rfcs/RFC-AITP-0002-identity.md#34-one-way-pinned-key-admission-optional-profile-pinned-admission) (rule 2 and check-order step 4) states what the verifier checks and which code it returns.

| Value | Sender → receiver | Payload | Status | Spec |
|---|---|---|---|---|
| `mutual_hello` | Initiator → target | `MutualHello` | Stable | [RFC-AITP-0004 §3.1](../rfcs/RFC-AITP-0004-mutual-handshake.md#31-mutual_hello) |
| `mutual_hello_ack` | Target → initiator | `MutualHelloAck` | Stable | [RFC-AITP-0004 §3.2](../rfcs/RFC-AITP-0004-mutual-handshake.md#32-mutual_hello_ack) |
| `mutual_commit` | Initiator → target | `MutualCommit` | Stable | [RFC-AITP-0004 §3.3](../rfcs/RFC-AITP-0004-mutual-handshake.md#33-mutual_commit) |
| `mutual_commit_ack` | Target → initiator | `MutualCommitAck` | Stable | [RFC-AITP-0004 §3.4](../rfcs/RFC-AITP-0004-mutual-handshake.md#34-mutual_commit_ack) |
| `tct` | Issuing peer → subject | No payload shape is defined in v0.2. The handshake delivers TCTs inside `mutual_commit` / `mutual_commit_ack`, and the TCT format is [RFC-AITP-0005](../rfcs/RFC-AITP-0005-tct.md) | Stable | [RFC-AITP-0001 §5.2](../rfcs/RFC-AITP-0001-core.md#52-fields) (listed only) |
| `pop_challenge` | Consuming peer → TCT subject | `{tct_jti, nonce}` | Stable | [RFC-AITP-0005 §6.1](../rfcs/RFC-AITP-0005-tct.md#61-downstream-pop-exchange) |
| `pop_response` | TCT subject → consuming peer | `{tct_jti, nonce_echo, pop_signature}` | Stable | [RFC-AITP-0005 §6.1](../rfcs/RFC-AITP-0005-tct.md#61-downstream-pop-exchange) |
| `identity_presentation` | Presenter → verifier | Exactly `{identity, pop_nonce}`: a `pinned_key` descriptor and the challenge nonce | Provisional | [RFC-AITP-0002 §3.4](../rfcs/RFC-AITP-0002-identity.md#34-one-way-pinned-key-admission-optional-profile-pinned-admission) |
| `error` | Either side | `AitpError` | Stable | [RFC-AITP-0001 §5.6](../rfcs/RFC-AITP-0001-core.md#56-error-envelope) |

Statuses use the shared [status values](README.md#status-values).

The `pinned-admission` challenge (RFC-AITP-0002 §3.4) is deliberately not a message type: it is issued out of band, not in an envelope.

## Adding a message type

A new value changes the envelope schema's `enum`, so it needs a normative home. Open a PR that:

- adds a row above with the exact value, direction, payload shape, [status](README.md#status-values) and defining RFC section;
- adds the value to the `message_type` enum in `schemas/json/aitp-envelope.schema.json`, and to the RFC-AITP-0001 §5 list and §5.2 field table;
- bumps the version of each RFC whose normative text changes ([VERSIONING.md](../VERSIONING.md#change-classes)).

Values use lowercase snake_case and MUST NOT collide with an existing row.
