# Formal model: technical note

This note summarises what the Tamarin model of AITP `aitp/0.3` proves. The model, the lemma ↔ RFC section map and the full list of modelling limits are in [README.md](README.md). Per-lemma results, with the Tamarin version, spec commit and wall time, are in [results/summary.md](results/summary.md). CI regenerates them on every change to the modelled RFCs.

## Scope

The model covers, from the RFC text of spec v0.3.3-draft:

- the four-message Mutual Handshake of RFC-AITP-0004 over the signed envelopes of RFC-AITP-0001, with OIDC-bound identities (RFC-AITP-0002 §2) and Manifests (RFC-AITP-0003);
- a TCT presented back to its issuer under downstream PoP (RFC-AITP-0005 §6, §10.5);
- TCT renewal (RFC-AITP-0013), with the renewal PoP input of RFC-AITP-0013 §3.1, `<'aitp-renewal-pop-v1', issuer AID, current TCT jti, pop_nonce>`;
- single-hop delegation with a grant voucher (RFC-AITP-0006, RFC-AITP-0005 §8).

The adversary controls the network, can register its own AIDs with valid Manifests, can enroll at the identity provider under subjects of its own, and can reveal any honest agent's long-term key.

## Results

Every lemma in the merged theories is verified. No lemma is inconclusive.

| Property | Lemmas | Meaning |
|---|---|---|
| P1 mutual injective agreement | `P1_agreement_*` | When either party completes a handshake with an honest, uncompromised peer, the peer ran the same handshake with it, on the same nonces and TCTs, and each completed session matches exactly one peer session. |
| P2 key confirmation | `P2_key_confirmation_*` | A round-2 PoP is accepted only if the peer's key signed the receiver's `pop_nonce`. |
| P3 TCT key and audience binding, renewal | `P3_*` | A TCT accepted back by its issuer was issued by it to the presenter; the presenter itself answered the issuer's fresh challenge; an accepted renewal was requested by the holder, of that issuer; each renewal nonce is accepted once. |
| P4 replay resistance | `P4_*` | Accepted envelopes from honest senders are authentic, each `message_id` is accepted once, and one MUTUAL_HELLO opens at most one responder session. |
| P5 single-hop delegation non-escalation | `P5_*` | A accepts C under scope S only if A issued B a voucher containing S, B delegated exactly S to C for audience A, and C proved possession of its key. |

Executability lemmas (`exec_*`) find a trace for an honest handshake, a handshake with an adversary-held peer, TCT use, renewal and delegation, so the security lemmas do not hold vacuously.

## What the results do not say

- They hold for the model. Time, encodings (JCS, base64url), algorithm choice, revocation, Manifest rotation and DoS are abstracted or out of scope; see [README.md § Modelling limits](README.md#modelling-limits).
- They say nothing about implementations. Conformance fixtures, KATs and fuzzing cover those.
- Grants are a small finite set, and there is one honest identity provider.

## Reproducing

```sh
make formal          # Tamarin 1.12.0 and Maude 3.5.1
```
