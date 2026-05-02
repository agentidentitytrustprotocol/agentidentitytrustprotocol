# Phase Final Report — AITP v0.1.0 Simplification Pass

**Date:** 2026-05-02
**Scope:** Editorial simplification pass before tagging `v0.1.0`. No
architectural changes. The TCT audience model (Model A, holder
receipt), delegation scope, per-grant PoP policy, and the 12-RFC
layout are unchanged.

---

## Summary

17 tasks completed across three tiers. All Tier 1 (correctness),
Tier 2 (simplification), and Tier 3 (polish) tasks shipped. The full
validation gauntlet passes:

- 7/7 JSON Schemas pass Draft 2020-12 meta-validation.
- 25/25 example + conformance fixture files validate against their
  schemas.
- All AIDs in examples and conformance fixtures are exactly 43
  characters.
- No padded base64url (`==`) in protocol values across `examples/`,
  `schemas/conformance/`, `docs/`, `rfcs/`.
- No `.DS_Store` or `__MACOSX/` in the tree.
- All internal Markdown links resolve.
- `make release` produces a clean archive (verified by checking the
  resulting zip's contents — zero `.git/`, `__MACOSX/`, `.DS_Store`,
  `node_modules/`, `.claude/`, `CLAUDE.md`, or `plans/` entries).

---

## Tier 1 — Correctness fixes

### F1. Unknown-fields contradiction resolved

- **`README.md`** Compatibility model section now reads: "Unknown JSON
  fields outside explicit `extensions` namespaces MUST be rejected.
  Unknown keys *inside* `extensions` MUST be ignored. See RFC-AITP-0001
  §7."
- **`VERSIONING.md`** "Backward-compatible addition" entry corrected
  with the same language.
- The remaining (correct) line in VERSIONING.md "Forward / backward
  compatibility" was already aligned with RFC-0001 §7 — no change
  needed.

### F2. Pinned-key proof input strengthened (RFC-0002 §3)

The pinned-key proof input was `message_id|timestamp_string`, which
binds neither sender nor receiver. A captured signature could be
replayed against any other peer with the same `pinned_keys` config.

The proof input is now:

```
proof_input =
    "aitp-pinned-key-v1\0"
    || sender_aid_bytes      || "\0"
    || receiver_aid_bytes    || "\0"
    || message_id_bytes      || "\0"
    || timestamp_be_8_bytes  || "\0"
    || pop_nonce_decoded_bytes
```

with each field documented (UTF-8 encoding rules, big-endian 8-byte
timestamp, raw decoded `pop_nonce`). Verification steps in §3.2
updated. Security Considerations §6 updated to call out the legacy
two-field input as forbidden.

### F3. RFC-0004 §9 over-promising removed

§9 ("Integration with Multi-Agent Sessions") previously claimed the
Session Trust Bundle distributes bilateral TCTs to all participants —
but RFC-0010 is Reserved with no normative content. §9 is now a single
paragraph deferring participant-to-participant propagation to RFC-0010.
Added "Multi-agent session bundles" as an explicit non-goal in §12.

### F4. RFC-0007 fail_mode reference fixed

§3 ("Failure Handling") incorrectly told operators to apply
`revocation_policy.mode` for key resolution failures. The trust-anchors
schema has had `key_resolution.fail_mode` (default `fail_closed`) all
along. §3 now uses the correct field and explains the distinction:
`key_resolution.fail_mode` for key resolution, `revocation_policy.mode`
for revocation lookup.

### F5. RFC-0012 signing-input contradiction fixed

§5's bullet "they are simply not part of the signed trust input"
contradicted physics — `extensions` is a property of the signed object,
so JCS canonicalization includes it. The bullet now reads "ignored for
trust decisions" and explicitly notes that the field IS part of the
signed object.

### F6. RFC-0001 §8 endpoint table trimmed

The five-row table listed three deployment-defined endpoints
(`<tct_verify_endpoint>`, `<delegation_verify_endpoint>`,
`<tct_revoked_endpoint>`) as if they were normatively advertised — but
the Manifest only carries `handshake_endpoint`. Trimmed to the two
required endpoints; added a callout that the others are deployment-
defined and MAY be advertised under `extensions`.

### F7. Release hygiene

- Added a CI step in `.github/workflows/ci.yml` that fails the build if
  any `.DS_Store` or `__MACOSX/` is found in the working tree.
- Created `RELEASING.md` documenting the sanctioned procedure.
- Added a Releasing section to `governance/RFC-PROCESS.md` cross-
  referencing it.
- Verified the Makefile `release` target excludes all junk paths.
- Verified `make release` produces a clean archive (sample run
  produced a zip with zero junk entries).

---

## Tier 2 — Simplification

### S1. why-aitp + overview merged into architecture

`docs/architecture.md` is now the single non-normative orientation
document. It contains:

1. The problem (from why-aitp.md, with comparison table).
2. The shape (from overview.md).
3. Flows (preserved from architecture.md).
4. Transports.
5. Where state lives.
6. The big invariant.
7. What each RFC adds.
8. Design rationale: why four messages? (moved from RFC-0004 §11.1).
9. What AITP does not do.
10. Reading order for implementers.

`docs/why-aitp.md` and `docs/overview.md` deleted. README and Makefile
reading order updated.

### S2. RFC-0004 §1 condensed; rationale moved out

§1 went from four named subsections to a four-item normative list. The
"Why four messages (not two)?" rationale moved to architecture.md as a
new §8. §11 security subsections renumbered 11.2 → 11.1, 11.3 → 11.2,
11.4 → 11.3, 11.5 → 11.4 (no cross-references in other RFCs use these
numbers).

### S3. RFC-0004 §8 reduced to one normative paragraph

§8 ("Handshake Renewal") is now: "TCTs expire per `expires_at`. Peers
MAY initiate a fresh Mutual Handshake before expiry to renew trust.
There is no in-band renewal message in v0.1. Agents MUST NOT use an
expired peer TCT. See `docs/operational-guidance.md` for non-normative
renewal patterns." Operational discussion (5-minute renewal window,
race conditions, why no in-band shortcut) moved to the new
`docs/operational-guidance.md`.

### S4. RFC-0001 §6 reduced to a cross-reference

§6 was content duplicated by RFC-0003 (discovery-time screening) and
RFC-0004 §4 (handshake-time grant intersection). It is now a one-
paragraph cross-reference. Section numbering preserved (no renumber)
because §7, §8 are referenced from registries/error-codes.md and other
RFCs.

### S5. Manifest `description` field removed

`description` and `display_name` both said "not used in trust
decisions" and served the same purpose. Kept `display_name`. Updated:

- `rfcs/RFC-AITP-0003-manifest.md` schema example and §3.2 table.
- `schemas/json/aitp-manifest.schema.json` properties and example.
- `examples/manifest/agent-b-manifest.json`.

No conformance fixture used the field.

### S6. Mutual-handshake transcript moved to non-normative/

`examples/mutual-handshake/peer-signed-full-flow.json` →
`examples/non-normative/peer-signed-full-flow.json`. New
`examples/non-normative/README.md` explains that files in this
directory do NOT individually validate against the JSON schemas.
`scripts/validate-json.sh` and `examples/README.md` updated. The
`examples/mutual-handshake/` directory was removed.

### S7. Error code naming convention documented

Added to `registries/error-codes.md`:

> "Code naming convention. Object-level failures use the
> `<OBJECT>_<FAILURE>` form (e.g., `MANIFEST_SIGNATURE_INVALID`,
> `TCT_EXPIRED`). Envelope-level failures use bare codes (e.g.,
> `INVALID_SIGNATURE`, `REPLAY_DETECTED`)."

All existing codes already follow this convention; no refactoring
was needed.

### S8. Releasing section added to RFC-PROCESS.md

Six-step procedure (CHANGELOG bump → version headers → `make validate`
→ `make release` → tag → push) with a cross-reference to RELEASING.md.

---

## Tier 3 — Polish

### P1. `docs/implementer-quickstart.md`

One-page reading order for someone building an AITP peer agent. Lists
each RFC with a one-paragraph context, explicitly tells implementers
to skip RFCs 0010–0012, and points to the operational/integration
companions.

### P2. Concept Index in GLOSSARY.md

A 19-row table mapping each AITP concept (AID, Envelope, JCS, Replay
protection, Identity binding, OIDC identity, Pinned-key identity,
Manifest, identity_hint, Mutual Handshake, Grant intersection, TCT,
binding.cnf, JTI, Delegation, Key resolution, Revocation, extensions,
PoP, Trust anchor) to a one-line definition and an anchor in the
authoritative RFC.

---

## Validation gauntlet results

| Check | Result |
|---|---|
| `make validate` | ✓ 25/25 JSON files validated |
| Draft 2020-12 schema meta-validation (7 schemas) | ✓ all pass |
| AID length (43 chars) across `examples/` + `schemas/conformance/` | ✓ all pass |
| No padded base64url (`==`) in `examples/`, `schemas/conformance/`, `docs/`, `rfcs/` | ✓ none found |
| No `.DS_Store` or `__MACOSX/` in tree | ✓ none found |
| Internal markdown links resolve | ✓ all pass |
| `make release` produces clean zip | ✓ verified — zero junk entries |

---

## Files changed

### Modified

- `.github/workflows/ci.yml` — added release-junk CI check.
- `CHANGELOG.md` — added v0.1.0 entry.
- `Makefile` — reading-order updated for merged docs.
- `README.md` — repository tree, reading order, unknown-fields rule.
- `VERSIONING.md` — unknown-fields rule.
- `docs/architecture.md` — rewritten as the single orientation doc.
- `docs/GLOSSARY.md` — added Concept Index.
- `examples/README.md` — non-normative directory documented.
- `examples/manifest/agent-b-manifest.json` — `description` removed.
- `governance/RFC-PROCESS.md` — Releasing section added.
- `registries/capabilities.md` — stability header (already in place).
- `registries/error-codes.md` — naming convention documented.
- `rfcs/RFC-AITP-0001-core.md` — §6 cross-reference, §8 endpoint table.
- `rfcs/RFC-AITP-0002-identity.md` — §3 pinned-key proof input,
  §6 security note.
- `rfcs/RFC-AITP-0003-manifest.md` — `description` removed.
- `rfcs/RFC-AITP-0004-mutual-handshake.md` — §1 condensed, §8 trimmed,
  §9 trimmed, §11 renumbered, §12 non-goal added.
- `rfcs/RFC-AITP-0007-key-resolution.md` — §3 fail_mode disambiguated.
- `rfcs/RFC-AITP-0012-extensions.md` — §5 signing-input bullet fixed.
- `schemas/conformance/README.md` — fixture rename mapping.
- `schemas/json/aitp-manifest.schema.json` — `description` removed.
- `scripts/validate-json.sh` — non-normative directory.

### Added

- `RELEASING.md`
- `docs/implementer-quickstart.md`
- `docs/operational-guidance.md`
- `examples/non-normative/README.md`
- `examples/non-normative/peer-signed-full-flow.json` (moved)
- `phase-final-report.md` (this file)

### Removed

- `docs/why-aitp.md` (merged into architecture.md)
- `docs/overview.md` (merged into architecture.md)
- `examples/mutual-handshake/` (relocated to non-normative)

---

## Stop here

Per the task brief, this report is the end of the AI iteration. The
diff and the resulting `make release` archive are ready for human
review. Do **not** publish to GitHub Releases or announce until
review is complete.
