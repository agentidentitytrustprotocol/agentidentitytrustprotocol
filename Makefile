.PHONY: help validate json-validate json-schema-validate kat-verify doc-coherence clean install-tools docs release

# AITP ships as JSON only (RFC-AITP-0001 §5.1). There are two signing
# profiles (RFC-AITP-0001 §5.4): RFC 8785 (JCS) canonical JSON is the
# signing input for the protocol-internal artifacts (envelope, Manifest,
# revocation snapshot, session bundle, handshake payloads; §5.4.1), and
# RFC 7515 compact JWS carries the portable trust artifacts (TCT, grant
# voucher, delegation token; §5.4.5).

# ── Default ───────────────────────────────────────────────────────────────────

help:
	@echo "AITP Development Commands"
	@echo
	@echo "Validation:"
	@echo "  make validate              Run all v0.2 validations (JSON only)"
	@echo "  make json-schema-validate  Validate JSON Schemas (meta-validation)"
	@echo "  make json-validate         Validate JSON examples and conformance fixtures,"
	@echo "                             incl. the map-driven fixture-input cross-check"
	@echo "                             (scripts/fixture-validation-map.json)"
	@echo "  make kat-verify            Recompute and verify every pinned known-answer value"
	@echo "  make doc-coherence         Eight-stage doc coherence check: RFC version claims,"
	@echo "                             intra-repo anchor links, RFC section citations,"
	@echo "                             fixture error codes, mirrored schema definitions,"
	@echo "                             the RFC status ladder, stale v0.1 vocabulary,"
	@echo "                             and sibling-repo link form"
	@echo "                             (stages documented in scripts/check-doc-coherence.sh)"
	@echo
	@echo "Docs:"
	@echo "  make docs                  Print the docs reading order"
	@echo
	@echo "Utilities:"
	@echo "  make install-tools         Install required development tools (ajv-cli)"
	@echo "  make release               Build the release archive from committed (tracked) files"
	@echo "  make clean                 No-op (no generated artifacts)"

# ── Validation ────────────────────────────────────────────────────────────────

validate: json-schema-validate json-validate kat-verify doc-coherence
	@echo "✓ All v0.2 validations passed"

json-schema-validate:
	@echo "Validating JSON Schemas (meta-validation)..."
	@./scripts/validate-json-schema.sh

json-validate:
	@echo "Validating JSON examples and conformance fixtures..."
	@./scripts/validate-json.sh

# Schema validation proves these files are well-formed. This proves the values
# inside them are correct: canonical bytes recomputed, keys re-derived, every
# pinned signature verified. Requires Node (already needed for ajv).
kat-verify:
	@echo "Verifying pinned known-answer values (canonical bytes + signatures)..."
	@node scripts/verify-known-answer.mjs --quiet

# rfcs/README.md and VERSIONING.md are prose, not generated from the RFC
# headers -- this is the mechanical check that stops them from drifting the
# way schemas/fixtures did before PR #22 and PR #30.
doc-coherence:
	@echo "Checking RFC version claims, intra-repo anchor links, section citations, fixture error codes, mirrored schema definitions, the RFC status ladder, stale v0.1 vocabulary, and sibling-repo link form..."
	@./scripts/check-doc-coherence.sh

# ── Docs ─────────────────────────────────────────────────────────────────────

docs:
	@echo "AITP reading order:"
	@echo
	@echo "Orientation (non-normative):"
	@echo "   1. README.md"
	@echo "   2. manifesto/manifesto.md"
	@echo "   3. docs/architecture.md"
	@echo "   4. docs/GLOSSARY.md"
	@echo
	@echo "Normative v0.2 core RFCs (Draft):"
	@echo "   5. rfcs/RFC-AITP-0001-core.md"
	@echo "   6. rfcs/RFC-AITP-0002-identity.md"
	@echo "   7. rfcs/RFC-AITP-0003-manifest.md"
	@echo "   8. rfcs/RFC-AITP-0004-mutual-handshake.md"
	@echo "   9. rfcs/RFC-AITP-0005-tct.md"
	@echo "  10. rfcs/RFC-AITP-0006-delegation.md"
	@echo "  11. rfcs/RFC-AITP-0007-key-resolution.md"
	@echo "  12. rfcs/RFC-AITP-0008-revocation.md"
	@echo "  13. rfcs/RFC-AITP-0009-security.md"
	@echo
	@echo "Guides (non-normative; the RFCs win on any disagreement):"
	@echo "  14. docs/discovery.md"
	@echo "  15. docs/integration-guide.md"
	@echo "  16. docs/implementer-quickstart.md"
	@echo "  17. docs/operational-guidance.md"
	@echo "  18. docs/threat-model.md"
	@echo "  19. docs/non-goals.md"
	@echo "  20. docs/ecosystem.md   (sibling repos: SDKs, verifier, playground, MCP)"
	@echo
	@echo "Opt-in drafts (Draft normative text; NOT part of v0.2 core conformance):"
	@echo "   - rfcs/RFC-AITP-0010-session-trust-bundle.md"
	@echo "   - rfcs/RFC-AITP-0011-multihop-delegation.md"
	@echo
	@echo "Reserved (non-normative for aitp/0.2):"
	@echo "   - rfcs/RFC-AITP-0012-extensions.md"
	@echo
	@echo "Planned (stub reserving the number):"
	@echo "   - rfcs/RFC-AITP-0013-tct-renewal-extension.md"
	@echo
	@echo "Conformance (read after the RFCs):"
	@echo "   - schemas/conformance/README.md"
	@echo "   - schemas/conformance/PLACEHOLDERS.md"

# ── Clean ────────────────────────────────────────────────────────────────────

clean:
	@echo "Nothing to clean (no generated artifacts)."

# ── Release archive ──────────────────────────────────────────────────────────
#
# The release archive is built with `git archive` from HEAD, so it contains
# exactly the tracked files of the committed tree under a single top-level
# folder named ${RELEASE_NAME}/. Anything untracked or ignored (local notes,
# temp/, plans/, __pycache__/, .env, editor files, ...) can never leak into
# it, there is no exclusion list to maintain, and the result does not depend
# on what the working-tree directory happens to be called. Uncommitted
# changes are NOT included: commit first. The zip is written next to the
# repository (one level up) so it never lands inside the tree.

RELEASE_NAME ?= agentidentitytrustprotocol
RELEASE_VERSION ?= v0.2.0-draft
RELEASE_ARCHIVE := ../$(RELEASE_NAME)-$(RELEASE_VERSION).zip

release:
	@echo "Building release archive $(RELEASE_ARCHIVE) from HEAD (tracked files only)..."
	@if ! git diff --quiet HEAD -- 2>/dev/null; then \
		echo "Note: uncommitted changes to tracked files are NOT included (archive is built from HEAD)."; \
	fi
	@git archive --format=zip --prefix="$(RELEASE_NAME)/" -o "$(RELEASE_ARCHIVE)" HEAD
	@echo "✓ Wrote $(RELEASE_ARCHIVE)"

# ── Tooling install ──────────────────────────────────────────────────────────

install-tools:
	@echo "Installing development tools..."
	@echo
	@echo "Installing ajv-cli and ajv-formats..."
	@if command -v npm >/dev/null 2>&1; then \
		npm install -g ajv-cli ajv-formats; \
	else \
		echo "Please install Node.js and npm, then run: npm install -g ajv-cli ajv-formats"; \
	fi
	@echo
	@echo "✓ Tool installation complete"
