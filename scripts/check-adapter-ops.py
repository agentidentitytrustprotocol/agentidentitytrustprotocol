#!/usr/bin/env python3
"""Check that schemas/conformance/ADAPTER.md names every fixture operation.

Collects each fixture's `input.operation` and every per-step `operation` in
the `sequence` form, and fails if an operation used by a non-reserved fixture
is not named in ADAPTER.md as a backticked table cell (| `op` |). Operations
used by a `required_for_core` fixture are reported separately: those are the
ones the core claim depends on (K1.3 acceptance criterion 1).

Usage: scripts/check-adapter-ops.py [--quiet]
"""

import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIXTURES = os.path.join(ROOT, "schemas", "conformance")
ADAPTER = os.path.join(FIXTURES, "ADAPTER.md")


def fixture_ops(fixture):
    inp = fixture.get("input") or {}
    ops = set()
    if isinstance(inp.get("operation"), str):
        ops.add(inp["operation"])
    for step in inp.get("sequence") or []:
        if isinstance(step.get("operation"), str):
            ops.add(step["operation"])
    return ops


def main():
    quiet = "--quiet" in sys.argv[1:]
    with open(ADAPTER, encoding="utf-8") as f:
        documented = set(re.findall(r"^\|\s*`([a-z0-9_]+)`\s*\|", f.read(), re.M))

    core, other = {}, {}
    for path in sorted(glob.glob(os.path.join(FIXTURES, "*.json"))):
        with open(path, encoding="utf-8") as f:
            fixture = json.load(f)
        if fixture.get("status") == "reserved":
            continue
        ops = fixture_ops(fixture)
        if not ops:
            print(f"{os.path.basename(path)}: no operation found", file=sys.stderr)
            return 1
        bucket = core if fixture.get("required_for_core") is True else other
        for op in ops:
            bucket.setdefault(op, []).append(fixture["id"])

    failed = False
    for label, used in (("required_for_core", core), ("non-core", other)):
        for op in sorted(set(used) - documented):
            failed = True
            ids = ", ".join(used[op][:5])
            print(
                f"ADAPTER.md does not name op `{op}`, used by {label} fixture(s): {ids}",
                file=sys.stderr,
            )
    if failed:
        return 1
    if not quiet:
        print(
            f"ADAPTER.md names all {len(core)} required_for_core ops "
            f"and all {len(set(other) - set(core))} other fixture ops"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
