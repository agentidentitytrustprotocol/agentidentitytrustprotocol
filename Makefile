.PHONY: help validate json-validate json-schema-validate kat-verify doc-coherence clean install-tools docs release

# AITP ships as JSON only. The canonical wire format and signing input
# is RFC 8785 (JCS) canonical JSON. See RFC-AITP-0001 §5.4.1.

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
	@echo "  make doc-coherence         Check RFC version claims and intra-repo anchor links"
	@echo
	@echo "Docs:"
	@echo "  make docs                  Print the docs reading order"
	@echo
	@echo "Utilities:"
	@echo "  make install-tools         Install required development tools (ajv-cli)"
	@echo "  make release               Build the sanctioned release archive"
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
	@echo "Checking RFC version claims and intra-repo anchor links..."
	@./scripts/check-doc-coherence.sh

# ── Docs ─────────────────────────────────────────────────────────────────────

docs:
	@echo "AITP reading order:"
	@echo
	@echo "Normative (v0.2):"
	@echo "   1. README.md"
	@echo "   2. manifesto/manifesto.md"
	@echo "   3. docs/architecture.md"
	@echo "   4. docs/GLOSSARY.md"
	@echo "   5. rfcs/RFC-AITP-0001-core.md"
	@echo "   6. rfcs/RFC-AITP-0002-identity.md"
	@echo "   7. rfcs/RFC-AITP-0003-manifest.md"
	@echo "   8. rfcs/RFC-AITP-0004-mutual-handshake.md"
	@echo "   9. rfcs/RFC-AITP-0005-tct.md"
	@echo "  10. rfcs/RFC-AITP-0006-delegation.md"
	@echo "  11. rfcs/RFC-AITP-0007-key-resolution.md"
	@echo "  12. rfcs/RFC-AITP-0008-revocation.md"
	@echo "  13. rfcs/RFC-AITP-0009-security.md"
	@echo "  14. docs/discovery.md"
	@echo "  15. docs/integration-guide.md"
	@echo "  16. docs/implementer-quickstart.md"
	@echo "  17. docs/operational-guidance.md"
	@echo
	@echo "Opt-in drafts (Draft normative text; NOT part of v0.2 core conformance):"
	@echo "   - rfcs/RFC-AITP-0010-session-trust-bundle.md"
	@echo "   - rfcs/RFC-AITP-0011-multihop-delegation.md"
	@echo
	@echo "Reserved (no normative content):"
	@echo "   - rfcs/RFC-AITP-0012-extensions.md"
	@echo
	@echo "Conformance (read after the RFCs):"
	@echo "   - schemas/conformance/README.md"
	@echo "   - schemas/conformance/PLACEHOLDERS.md"

# ── Clean ────────────────────────────────────────────────────────────────────

clean:
	@echo "Nothing to clean (no generated artifacts)."

# ── Release archive ──────────────────────────────────────────────────────────
#
# Sanctioned way to produce a release archive. Excludes VCS metadata, macOS
# resource forks, working directories, and any AI-assistant scratch files.
# Run from the parent directory of the repo (so the archive contains the
# repo as a top-level folder).

RELEASE_NAME ?= agentidentitytrustprotocol
RELEASE_VERSION ?= v0.2.0-draft

release:
	@echo "Building release archive ${RELEASE_NAME}-${RELEASE_VERSION}.zip..."
	@cd .. && zip -r "${RELEASE_NAME}-${RELEASE_VERSION}.zip" "${RELEASE_NAME}" \
		-x "*/.git/*" \
		-x "*/__MACOSX/*" \
		-x "*/.DS_Store" \
		-x "*/temp/*" \
		-x "*/.claude/*" \
		-x "*/CLAUDE.md" \
		-x "*/plans/*" \
		-x "*/node_modules/*"
	@echo "✓ Wrote ../${RELEASE_NAME}-${RELEASE_VERSION}.zip"

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
