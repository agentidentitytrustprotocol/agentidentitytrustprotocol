# Formal model

A symbolic model of the AITP `aitp/0.3` handshake, TCT use, TCT renewal and single-hop delegation, checked with the [Tamarin prover](https://tamarin-prover.com). It is modelled from the RFC text (spec v0.3.3-draft), not from any implementation. A short note on what the results mean is in [REPORT.md](REPORT.md); the latest results are in [results/summary.md](results/summary.md).

## Running it

You need Tamarin 1.12.0 and Maude 3.5.1. `formal/run-lemmas.py` refuses other versions.

```sh
make formal          # prove every lemma, rewrite formal/results/summary.md
make formal-check    # prove every lemma, fail if a result drifted from the summary
```

`run-lemmas.py` proves one lemma at a time, in its own process, under a time cap: 180 s per lemma and 1080 s for the suite by default. It also caps the GHC runtime at 2 threads and a 4 GB heap (`--cores`, `--heap`). A lemma that does not finish within its cap is reported as **inconclusive**, never as verified, and inconclusive lemmas are not merged. CI ([`.github/workflows/formal.yml`](../.github/workflows/formal.yml)) runs `make formal-check` on every change to `formal/**`, `rfcs/RFC-AITP-000[1-6]*` or `rfcs/RFC-AITP-0013*`. The check compares the theory, lemma, result and Tamarin columns; wall time and spec commit are informational.

Proof search uses the goal-ranking oracle [`tamarin/oracles/aitp.py`](tamarin/oracles/aitp.py) (`--heuristic=o`). The runner passes it automatically.

## Files

| File | Contents |
|---|---|
| [`tamarin/common.splib`](tamarin/common.splib) | Restrictions, the OIDC identity provider, agent registration, Manifests, adversary enrollment, key reveal |
| [`tamarin/handshake.splib`](tamarin/handshake.splib) | The four handshake messages (RFC-AITP-0004 §3, §5) |
| [`tamarin/holder.splib`](tamarin/holder.splib) | The holder side of downstream PoP (RFC-AITP-0005 §6.1) |
| [`tamarin/tct.splib`](tamarin/tct.splib) | A TCT presented back to its issuer, and TCT renewal |
| [`tamarin/aitp-handshake.spthy`](tamarin/aitp-handshake.spthy) | Handshake lemmas P1, P2, P4 |
| [`tamarin/aitp-tct.spthy`](tamarin/aitp-tct.spthy) | TCT binding and renewal lemmas P3 |
| [`tamarin/aitp-delegation.spthy`](tamarin/aitp-delegation.spthy) | Delegation lemmas P5 |

## Lemma ↔ RFC section map

Every security lemma assumes the agents it names are honest and that their keys are not revealed. The `exec_*` lemmas are sanity checks: each must find a trace. A model bug that makes a rule unreachable would otherwise let the security lemmas hold vacuously.

| Lemma | Property | RFC sections |
|---|---|---|
| `exec_honest_handshake` | Two honest agents complete a handshake | RFC-AITP-0004 §2, §3 |
| `exec_adversary_peer` | An honest agent completes a handshake with an adversary-held AID that has a valid Manifest and ID token | RFC-AITP-0004 §2, §5; RFC-AITP-0002 §2.2 |
| `P1_agreement_responder` | When B completes, A ran the handshake with B on the same nonces and the same TCT for B | RFC-AITP-0004 §5.1, §5.3 |
| `P1_agreement_responder_injective` | No two responder sessions complete on the same run | RFC-AITP-0004 §5.1, §5.3; RFC-AITP-0001 §5.5 |
| `P1_agreement_initiator` | When A completes with B, B ran the handshake with A on the same nonces and both TCTs | RFC-AITP-0004 §5.2, §5.4 |
| `P1_agreement_initiator_injective` | No two initiator sessions complete on the same run | RFC-AITP-0004 §5.2, §5.4; RFC-AITP-0001 §5.5 |
| `P2_key_confirmation_responder` | B accepts A's round-2 PoP only if A's key signed B's `pop_nonce` | RFC-AITP-0004 §3.3, §5.3 step 4; RFC-AITP-0001 §5.4.2 |
| `P2_key_confirmation_initiator` | A accepts B's PoP only if B's key signed A's `pop_nonce` | RFC-AITP-0004 §3.4, §5.4 step 4; RFC-AITP-0001 §5.4.2 |
| `P4_envelope_authentic` | Every accepted envelope from an honest sender was sent by that sender | RFC-AITP-0001 §5.4 |
| `P4_envelope_accepted_once` | A receiver accepts each `message_id` at most once | RFC-AITP-0001 §5.5 |
| `P4_hello_single_session` | One MUTUAL_HELLO opens at most one responder session | RFC-AITP-0004 §5.1 step 1; RFC-AITP-0001 §5.5 |
| `exec_tct_use` | A TCT issued in a handshake is presented back to its issuer and accepted | RFC-AITP-0005 §6.1, §6.2, §10.5 |
| `exec_renewal` | A TCT issued in a handshake is renewed | RFC-AITP-0013 §3, §4 |
| `P3_tct_issued_to_presenter` | A TCT its issuer accepts back was issued by it, to that presenter (`sub` = `aud`, `cnf.jkt`), with those grants | RFC-AITP-0005 §3, §5.2, §10.5 items 1-2 |
| `P3_presenter_pop` | The accepted presenter itself signed the issuer's fresh challenge | RFC-AITP-0005 §6.2; §10.5 items 3-4 |
| `P3_renewal_requested_by_holder` | An accepted renewal was requested by the holder, of that issuer, with that `pop_nonce` | RFC-AITP-0013 §3.1, §4 step 3 |
| `P3_renewal_nonce_once` | The issuer accepts each renewal `pop_nonce` once | RFC-AITP-0013 §4 step 5, §5 |
| `exec_delegation` | Honest A, B and C complete a delegation of one of two vouchered grants | RFC-AITP-0006 §2-§4 |
| `P5_scope_within_voucher` | When A accepts C under scope S, A itself issued B a voucher whose grants contain S | RFC-AITP-0006 §4 steps 3-4, 6, §5.3; RFC-AITP-0005 §8 |
| `P5_delegator_signed` | B itself delegated exactly scope S to C for audience A | RFC-AITP-0006 §4 steps 1-2, §5.1-§5.2 |
| `P5_delegatee_pop` | C itself signed A's fresh challenge | RFC-AITP-0006 §4 step 9; RFC-AITP-0005 §6.2 |

### TCT renewal input

The model uses the renewal PoP input of RFC-AITP-0013 §3.1: the tag, the issuer AID, the current TCT's `jti` and the nonce.

```
pop_signature = sign(holder_key, <'aitp-renewal-pop-v1', issuer AID, current TCT jti, pop_nonce>)
```

## Modelling limits

The results hold for the model, not beyond it.

- **Time.** Timestamps, `exp`, `expires_at` and the 300 s window are abstracted. The `message_id` deny list plus the window become the restriction `DenyList`: a receiver accepts a given `message_id` once. Every token is always unexpired.
- **JCS and base64url.** They are treated as injective encodings, so a signed object is a tuple. Encoding ambiguities are covered by the KATs and fuzzing, not by this model.
- **Algorithm confusion.** Signatures use Tamarin's built-in `signing` theory: one ideal signature scheme, no `alg` header, no key-type confusion. RFC-AITP-0009 §1.12 is out of scope.
- **Honest OIDC IdP.** One identity provider, trusted by every agent, whose key is never revealed. The adversary can enroll at it under subjects of its own.
- **Finite grants.** Grants are public names; a grant set has one or two members, and subset is a fixed relation.
- **No Manifest rotation.** An agent has one key for its lifetime. Rotation and emergency rotation (RFC-AITP-0003 §8) are not modelled; compromise is a `Reveal` of the long-term key.
- **No DoS.** Rate limits and resource exhaustion are out of scope.
- **Other abstractions.** Revocation is not modelled. The handshake carries only the signature of the ID token and the `jti` and signature of each TCT: the receiver rebuilds the claims it already knows, which keeps the terms small. The issuer grants exactly what the peer requested. Multi-hop delegation (RFC-AITP-0011) is out of scope.

## Follow-ups

There are no inconclusive lemmas in the merged theories. Open items:

- Model revocation (RFC-AITP-0008) and Manifest rotation.
- Model the rest of RFC-AITP-0013: the renewal response envelope and the holder checks of §6.1.
