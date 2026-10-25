#!/usr/bin/env python3
"""Check an AITP conformance report beyond what its JSON Schema can express.

    check-conformance-report.py REPORT [--fixtures-dir DIR]
    check-conformance-report.py --digest DIR

The schema (schemas/json/aitp-conformance-report.schema.json) checks shape and
rules out a gate that passed over a blocking result. This script recomputes
the rest from `results` and fails on any mismatch:

  * every result `id` is unique;
  * `totals` equal the counts over `results`;
  * each gate name appears once, "AITP v0.3" is evaluated, and so is every
    extension claim whose feature is in `features_enabled`;
  * each gate's `passed` and `blocking` equal what its criteria compute
    (docs/conformance-badge.md);
  * an extension or draft fixture whose feature is not enabled is `skip`.

With --fixtures-dir (the schemas/conformance/ directory at `spec.commit`) it
also checks `fixtures_dir_digest`, that `results` covers exactly the
non-reserved fixtures, and that `status`, `feature` and `required_for_core`
were copied correctly. A matrix or badge generator should run that form.

--digest prints the `fixtures_dir_digest` of DIR and exits.

Standard library only. Exit status 0 = consistent, 1 = not.
"""

import argparse
import hashlib
import json
import os
import sys
from collections import Counter

CORE_CLAIM = "AITP v0.3"
# Extension claim string (RFC-AITP-0001 §10) -> the fixture feature it gates on.
FEATURE_CLAIMS = {
    "AITP v0.3 pinned-admission": "aitp-pinned-admission",
    "AITP v0.3 self-attestation": "aitp-self-attestation",
}
OUTCOMES = ("pass", "fail", "skip", "excluded_by_role")
TIERS = ("core", "extension", "draft")


def fixtures_dir_digest(directory):
    """sha256 over the sha256sum-format listing of the top-level *.json files."""
    names = sorted(
        (n for n in os.listdir(directory)
         if n.endswith(".json") and os.path.isfile(os.path.join(directory, n))),
        key=lambda n: n.encode("utf-8"),
    )
    listing = bytearray()
    for name in names:
        with open(os.path.join(directory, name), "rb") as handle:
            file_hash = hashlib.sha256(handle.read()).hexdigest()
        listing += f"{file_hash}  {name}\n".encode("utf-8")
    return "sha256:" + hashlib.sha256(bytes(listing)).hexdigest()


def gate_blocking(name, report):
    """Fixture ids that block `name`, in results order."""
    results = report["results"]
    if name == CORE_CLAIM:
        return [r["id"] for r in results
                if r["status"] == "core" and r["required_for_core"] and r["outcome"] != "pass"]
    feature = FEATURE_CLAIMS[name]
    return [r["id"] for r in results
            if r["feature"] == feature and r["outcome"] != "pass"]


def gate_passes(name, report):
    if name == CORE_CLAIM:
        return not gate_blocking(name, report)
    feature = FEATURE_CLAIMS[name]
    covered = any(r["feature"] == feature for r in report["results"])
    return (feature in report["features_enabled"] and covered
            and not gate_blocking(name, report))


def check(report, fixtures_dir=None):
    errors = []
    results = report["results"]
    enabled = set(report["features_enabled"])

    ids = Counter(r["id"] for r in results)
    for fixture_id, count in sorted(ids.items()):
        if count > 1:
            errors.append(f"result id {fixture_id!r} appears {count} times")

    for tier in TIERS:
        for outcome in OUTCOMES:
            want = sum(1 for r in results if r["status"] == tier and r["outcome"] == outcome)
            have = report["totals"][tier][outcome]
            if have != want:
                errors.append(f"totals.{tier}.{outcome} is {have}; results give {want}")

    for r in results:
        if r["status"] != "core" and r["feature"] not in enabled and r["outcome"] != "skip":
            errors.append(f"{r['id']}: feature {r['feature']!r} is not enabled, so the "
                          f"outcome must be skip, not {r['outcome']}")

    names = Counter(g["name"] for g in report["gates"])
    for name, count in sorted(names.items()):
        if count > 1:
            errors.append(f"gate {name!r} appears {count} times")
    expected_gates = {CORE_CLAIM} | {c for c, f in FEATURE_CLAIMS.items() if f in enabled}
    for name in sorted(expected_gates - set(names)):
        errors.append(f"gate {name!r} was not evaluated")

    for gate in report["gates"]:
        name = gate["name"]
        want_passed = gate_passes(name, report)
        if gate["passed"] != want_passed:
            errors.append(f"gate {name!r} says passed={str(gate['passed']).lower()}; "
                          f"the criteria give {str(want_passed).lower()}")
        want_blocking = gate_blocking(name, report)
        if gate.get("blocking", []) != want_blocking:
            errors.append(f"gate {name!r} blocking is {gate.get('blocking', [])}; "
                          f"the criteria give {want_blocking}")

    if fixtures_dir:
        digest = fixtures_dir_digest(fixtures_dir)
        if report["fixtures_dir_digest"] != digest:
            errors.append(f"fixtures_dir_digest is {report['fixtures_dir_digest']}; "
                          f"{fixtures_dir} gives {digest}")
        fixtures = {}
        for name in os.listdir(fixtures_dir):
            path = os.path.join(fixtures_dir, name)
            if name.endswith(".json") and os.path.isfile(path):
                with open(path, encoding="utf-8") as handle:
                    fixture = json.load(handle)
                if fixture["status"] != "reserved":
                    fixtures[fixture["id"]] = fixture
        by_id = {r["id"]: r for r in results}
        for fixture_id in sorted(set(fixtures) - set(by_id)):
            errors.append(f"fixture {fixture_id} has no result")
        for fixture_id in sorted(set(by_id) - set(fixtures)):
            errors.append(f"result {fixture_id} names no fixture in {fixtures_dir}")
        for fixture_id in sorted(set(by_id) & set(fixtures)):
            for key in ("status", "feature", "required_for_core"):
                if by_id[fixture_id][key] != fixtures[fixture_id][key]:
                    errors.append(f"{fixture_id}: {key} is {by_id[fixture_id][key]!r}; "
                                  f"the fixture says {fixtures[fixture_id][key]!r}")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("report", nargs="?", help="conformance report JSON file")
    parser.add_argument("--fixtures-dir", help="schemas/conformance/ at spec.commit")
    parser.add_argument("--digest", metavar="DIR", help="print the fixtures_dir_digest of DIR")
    args = parser.parse_args()

    if args.digest:
        print(fixtures_dir_digest(args.digest))
        return 0
    if not args.report:
        parser.error("REPORT is required unless --digest is given")

    with open(args.report, encoding="utf-8") as handle:
        report = json.load(handle)
    try:
        errors = check(report, args.fixtures_dir)
    except (KeyError, TypeError) as exc:
        errors = [f"report is not schema-shaped ({exc!r}); validate it against "
                  f"aitp-conformance-report.schema.json first"]
    for error in errors:
        print(f"    ✗ {error}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
