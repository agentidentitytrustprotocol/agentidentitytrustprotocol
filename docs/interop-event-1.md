# Interop event #1

The first AITP interop event: a virtual, asynchronous week in which every implementation runs the conformance suite at one spec commit, talks to the hosted interop peer where it can, and verifies what the other implementations produce. This page is the plan: the format, the test matrix, the result template and the logistics.

AITP is pre-1.0 and has one maintainer. The four implementations that exist today are all by that maintainer (see [ecosystem.md](ecosystem.md)). Among them, the event shows independence of code, not of authorship. Its real purpose is to give an implementation by someone else a fixed week, a fixed spec commit and a fixed set of checks to measure itself against.

## When

**Monday 9 November 2026, 00:00 UTC, to Sunday 15 November 2026, 23:59 UTC.**

The event runs on the current draft, before the release candidate. The core RFCs are still in public review until at least 2027-01-10 ([VERSIONING.md](../VERSIONING.md)), so results from this week feed straight into that review. A later event will repeat the matrix on the release candidate. The announcement goes on GitHub Discussions and on [agentidentitytrustprotocol.io](https://agentidentitytrustprotocol.io).

## Format

- **Virtual and asynchronous.** There is no call to join and no time zone to match. Participants run the checks whenever they like during the week and post results as they go.
- **One week**, Monday 00:00 UTC to Sunday 23:59 UTC.
- **One spec commit:** `8c6725bf33955748d0bec03684cae7d3b358d33a` on main (8 commits after `v0.3.4-draft`). Every run uses `schemas/conformance/` at that commit, and the report's `spec.commit` and `fixtures_dir_digest` prove it.
- **Open to anyone.** A partial implementation is welcome, a verifier-only one included. It runs the rows of the matrix it supports and reports the rest as not run.

## The implementations and what each one does

The matrix only asks an implementation to do what it actually does. The three verifiers sign nothing in production and open no network connections of their own, so they cannot run a handshake. They take part by verifying artifacts that another implementation produced.

| Implementation | Issues artifacts | Runs a handshake | Verifies | Network I/O |
|---|---|---|---|---|
| [aitp-rs](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/README.md) | Yes | Initiator (`aitp handshake`, `aitp echo`) and responder (`aitp serve --interop`, the code the hosted peer runs) | Yes | Yes |
| [aitp-verifier-py](https://github.com/agentidentitytrustprotocol/aitp-verifier-py/blob/main/README.md) | No. Its minter signs conformance fixtures with the published known-answer keys only. | No | Yes | None |
| [aitp-verifier-ts](https://github.com/agentidentitytrustprotocol/aitp-verifier-ts/blob/main/README.md) | No. Its signing helpers are for tests and the adapter only. | No | Yes | None |
| [aitp-verifier-go](https://github.com/agentidentitytrustprotocol/aitp-verifier-go/blob/main/README.md) | No. Test-only signing with the known-answer keys lives in the adapter only. | No | Yes | Only through a transport the caller supplies |

Which conformance claims each one passes, and at which spec commit, is in each implementation's own README and its published report. This page does not restate them.

## The test matrix

### A. Conformance suite

Every implementation runs the fixtures at the event commit through an adapter ([ADAPTER.md](../schemas/conformance/ADAPTER.md)) and emits one conformance report.

| | aitp-rs | aitp-verifier-py | aitp-verifier-ts | aitp-verifier-go | Your implementation |
|---|---|---|---|---|---|
| Core claim `AITP v0.3`, no draft features | Run | Run | Run | Run | Run |
| Extension claims (`pinned-admission`, `self-attestation`) | Each one it implements | Each one it implements | Each one it implements | Each one it implements | Each one it implements |
| Draft features | Optional, in a separate run | Optional, in a separate run | Optional, in a separate run | Optional, in a separate run | Optional, in a separate run |

Run the core claim without draft features: an enabled draft feature can negate a core assertion and block the core claim ([conformance-badge.md, Claims](conformance-badge.md#claims)).

### B. Against the hosted interop peer

The hosted peer is `https://interop.agentidentitytrustprotocol.io`. It is aitp-rs's `aitp serve --interop`, documented in [interop-peer.md](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/interop-peer.md). It accepts `pinned_key` identities only, so a handshake needs the initiator's key to be enrolled first. It grants only `aitp.interop.echo`.

| Check | aitp-rs | aitp-verifier-py | aitp-verifier-ts | aitp-verifier-go | Your implementation |
|---|---|---|---|---|---|
| B1. Enrol a key, run the Mutual Handshake as initiator, present the issued TCT at `/echo` with proof of possession | Run (`aitp enroll`, `aitp echo`) | Not applicable: no initiator | Not applicable: no initiator | Not applicable: no initiator | Run, if it has an initiator |
| B2. Verify the peer's signed Manifest, fetched once and saved to a file | Run (`aitp manifest verify`) | Run | Run | Run | Run |
| B3. Verify the peer's revocation-list snapshot against the key from that Manifest | Run | Run | Run | Run | Run |

B1 for aitp-rs is aitp-rs against itself. It checks that the deployed peer works; it is not cross-implementation evidence. B1 means something only for an initiator written by someone else.

### C. Against each other

Rows are the producer, columns the verifier. A cell is run only where the producer issues that artifact and the verifier verifies it.

| Produced by ↓ · verified by → | aitp-rs | aitp-verifier-py | aitp-verifier-ts | aitp-verifier-go | Your implementation |
|---|---|---|---|---|---|
| aitp-rs (`xcheck-mint`: the artifact classes aitp-rs signs, Ed25519 and P-256, with one-change negatives) | Same code, not counted | Run | Run | Run | Run |
| aitp-verifier-py (test-key session bundle, committed in aitp-rs) | Run (draft feature) | — | — | — | Optional |
| aitp-verifier-ts | Issues nothing | — | — | — | — |
| aitp-verifier-go | Issues nothing | — | — | — | — |
| Your implementation, if it issues artifacts | Run | Run | Run | Run | Same code, not counted |

The three verifiers meet each other only at the known-answer vectors and the fixtures (row A). There is nothing for one verifier to hand another. The aitp-rs → verifier cells are what each verifier's CI already runs ([aitp-rs testing, cross-implementation acceptance](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/testing.md#cross-implementation-acceptance-xcheck)). During the event they are run again at the event commit.

## The result template

The result template is the existing **conformance report, `report_version` `"1"`**, defined in [conformance-badge.md](conformance-badge.md) and validated by [`aitp-conformance-report.schema.json`](../schemas/json/aitp-conformance-report.schema.json). The event adds no format.

- **Row A** is one report per run. Include `provenance.ci_run_url` when the run is public.
- **Rows B and C** are not in report v1, which covers the fixtures only. Report each cell you ran as pass or fail, with the command and a link to its log, in your sign-up thread.

Before posting a report, check it against the event commit:

```sh
python3 scripts/check-conformance-report.py conformance.json --fixtures-dir schemas/conformance
```

## Logistics

### Signing up

Reply to the event announcement in the [Announcements category of GitHub Discussions](https://github.com/agentidentitytrustprotocol/agentidentitytrustprotocol/discussions/categories/announcements). There is no issue template for the event, and you don't need to open an issue. Say:

- the implementation's name, language and repository;
- which roles it plays: issuer, handshake initiator, handshake responder, verifier;
- which claims and draft features you plan to run.

Sign up any time before or during the week. Questions go to the same thread.

### What participants run

1. **Row A.** Run your adapter under a conformance runner at the event commit. With aitp-rs's `aitp-conformance` runner ([aitp-rs conformance](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/conformance.md)):

   ```sh
   aitp-conformance run --target <your adapter> \
     --fixtures-dir <spec>/schemas/conformance --profile core \
     --report conformance.json
   ```

   Add `--feature aitp-pinned-admission` or `--feature aitp-self-attestation` for an extension claim you implement. A runner of your own is fine if it emits a valid report.
2. **Row B.** Fetch and save the peer's published artifacts once, then verify them with your implementation:

   ```sh
   aitp manifest fetch https://interop.agentidentitytrustprotocol.io > peer-manifest.json
   curl -s https://interop.agentidentitytrustprotocol.io/.well-known/aitp-revocation-list > peer-revocation-list.json
   ```

   The peer re-signs its Manifest every 12 hours and each signature is valid for 24, so verify with the fetch time as the current time. If you have an initiator, enrol and run the handshake and `/echo` using the wire formats in [interop-peer.md](https://github.com/agentidentitytrustprotocol/aitp-rs/blob/main/docs/interop-peer.md).
3. **Row C.** If you verify, run the aitp-rs `xcheck-mint` output through your verifier. If you issue artifacts, attach a set (with the public keys needed to verify it), and the maintainer runs it through the others.

The hosted peer keeps enrolments in memory, so a redeploy clears them: enrol again. It limits enrolments to a burst of 5 per client address, then one every 12 minutes. If it is down, its [status endpoint](https://interop.agentidentitytrustprotocol.io/status) says so, and `make demo` in aitp-rs runs both peers locally.

### How results are published

- Participants post reports and cell results in their sign-up thread during the week.
- After the week, the maintainer checks every report with `scripts/check-conformance-report.py` at the event commit. A results page then lands in this repository by pull request. It holds one matrix with every cell's result, links to each report and log, and the spec commit.
- Results are published as they are, failures included. A failure caused by ambiguous spec text becomes an issue in this repository. A failure in an implementation is reported to that implementation's repository.
- Reports are not signed. They are trusted because anyone can rerun them from the spec commit, the fixture digest and the linked CI run ([conformance-badge.md](conformance-badge.md#the-report)).

With one maintainer, replies during the week may take a day or more.
