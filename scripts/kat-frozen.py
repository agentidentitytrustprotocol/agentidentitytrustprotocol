#!/usr/bin/env python3
"""Compute the per-vector manifest of the frozen known-answer set, or check it.

Run by `make kat-frozen` (print the manifest) and `make kat-frozen-check`
(part of `make validate` and so of CI). Standard library only.

The frozen set is every known-answer entry that does not carry
`"draft": true` (schemas/conformance/known-answer/README.md, "Draft
vectors"). An entry is:

  * each object in the `vectors` array of a top-level
    `schemas/conformance/known-answer/*.json` file, keyed by its `id`;
  * each `signed-examples/**/*.json` file as a whole, keyed by its path
    relative to the known-answer directory (for example
    `signed-examples/tct/kat-keypair-001-issues-002.json`).

Each frozen entry maps to sha256(JCS(entry)), the SHA-256 of its RFC 8785
canonical form, as lowercase hex. Hashing the parsed entry makes the value
independent of whitespace, member order and line endings, so it is the same
on every platform. The overall digest is sha256(JCS(vectors)), taken over
the id-sorted manifest object. The printed JSON is exactly what
`schemas/conformance/known-answer/FROZEN.json` holds once the frozen set is
recorded, at Release Candidate.

A file-level digest would not work: draft vectors share files such as
jcs-sha256.json with frozen ones, so adding one would change it.

--check compares the current tree against FROZEN.json:

  * every id FROZEN.json lists must still exist, with the same hash;
  * no id FROZEN.json lists may now carry `"draft": true`;
  * FROZEN.json's own `digest` must match its `vectors`;
  * new ids, draft or not, pass: the stability rule is additions only.

Without FROZEN.json, --check prints the manifest digest and passes.

Usage:
    python3 scripts/kat-frozen.py [--kat-dir DIR] [--check] [--quiet]

--kat-dir defaults to schemas/conformance/known-answer. With --quiet,
--check prints only failures and one summary line.
"""

import argparse
import hashlib
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_KAT_DIR = os.path.join(ROOT, "schemas", "conformance", "known-answer")
FROZEN_NAME = "FROZEN.json"
SIGNED_DIR = "signed-examples"
MANIFEST_VERSION = 1


class KatError(Exception):
    pass


# ── RFC 8785 JCS for strings, integers, booleans, null, arrays, objects ─────
#
# The known-answer files use no floating-point numbers; one appearing is an
# error rather than a guess at ES6 number formatting.

def _jcs_str(s):
    out = ['"']
    for ch in s:
        o = ord(ch)
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append("\\\\")
        elif ch == "\b":
            out.append("\\b")
        elif ch == "\f":
            out.append("\\f")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif o < 0x20:
            out.append("\\u%04x" % o)
        elif 0xD800 <= o <= 0xDFFF:
            raise KatError("lone surrogate in string")
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def _jcs(x):
    if x is None:
        return "null"
    if x is True:
        return "true"
    if x is False:
        return "false"
    if isinstance(x, int):
        if abs(x) > 2**53 - 1:
            raise KatError("integer %d exceeds 2^53-1" % x)
        return str(x)
    if isinstance(x, float):
        raise KatError("floating-point number in a known-answer entry")
    if isinstance(x, str):
        return _jcs_str(x)
    if isinstance(x, list):
        return "[" + ",".join(_jcs(e) for e in x) + "]"
    if isinstance(x, dict):
        keys = sorted(x, key=lambda k: k.encode("utf-16-be"))
        return "{" + ",".join(_jcs_str(k) + ":" + _jcs(x[k]) for k in keys) + "}"
    raise KatError("unsupported JSON value type %s" % type(x).__name__)


def jcs(v):
    return _jcs(v).encode("utf-8")


def sha256_hex(b):
    return hashlib.sha256(b).hexdigest()


# ── Collect the entries ─────────────────────────────────────────────────────

def _load(path):
    def no_dup(pairs):
        obj = {}
        for k, v in pairs:
            if k in obj:
                raise KatError("%s: duplicate member %r" % (path, k))
            obj[k] = v
        return obj
    with open(path, "r", encoding="utf-8", newline="") as fh:
        return json.load(fh, object_pairs_hook=no_dup)


def collect(kat_dir):
    """Return {id: (is_draft, sha256(JCS(entry)))} over every entry."""
    entries = {}

    def add(eid, entry, where):
        if eid in entries:
            raise KatError("duplicate known-answer id %r (%s)" % (eid, where))
        entries[eid] = (entry.get("draft") is True, sha256_hex(jcs(entry)))

    for name in sorted(os.listdir(kat_dir)):
        path = os.path.join(kat_dir, name)
        if not name.endswith(".json") or name == FROZEN_NAME or not os.path.isfile(path):
            continue
        doc = _load(path)
        vectors = doc.get("vectors") if isinstance(doc, dict) else None
        if not isinstance(vectors, list):
            raise KatError("%s: no top-level \"vectors\" array" % name)
        for i, v in enumerate(vectors):
            if not isinstance(v, dict) or not isinstance(v.get("id"), str) or not v["id"]:
                raise KatError("%s: vectors[%d] has no string \"id\"" % (name, i))
            add(v["id"], v, name)

    signed = os.path.join(kat_dir, SIGNED_DIR)
    if os.path.isdir(signed):
        for dirpath, dirnames, filenames in os.walk(signed):
            dirnames.sort()
            for name in sorted(filenames):
                if not name.endswith(".json"):
                    continue
                path = os.path.join(dirpath, name)
                rel = os.path.relpath(path, kat_dir).replace(os.sep, "/")
                doc = _load(path)
                if not isinstance(doc, dict):
                    raise KatError("%s: not a JSON object" % rel)
                add(rel, doc, rel)
    return entries


def manifest(entries):
    vectors = {k: entries[k][1] for k in sorted(entries) if not entries[k][0]}
    return {
        "manifest_version": MANIFEST_VERSION,
        "hash": "sha256(JCS(entry))",
        "digest": sha256_hex(jcs(vectors)),
        "vectors": vectors,
    }


def render(m):
    return json.dumps(m, indent=2, sort_keys=False, ensure_ascii=True) + "\n"


# ── Check against FROZEN.json ───────────────────────────────────────────────

def check(entries, frozen_path):
    frozen = _load(frozen_path)
    errors = []
    if not isinstance(frozen, dict) or not isinstance(frozen.get("vectors"), dict):
        return ["%s: no \"vectors\" object" % FROZEN_NAME]
    if frozen.get("manifest_version") != MANIFEST_VERSION:
        errors.append("%s: manifest_version %r, expected %d"
                      % (FROZEN_NAME, frozen.get("manifest_version"), MANIFEST_VERSION))
    fv = frozen["vectors"]
    if frozen.get("digest") != sha256_hex(jcs(fv)):
        errors.append("%s: digest does not match its own vectors" % FROZEN_NAME)
    for eid in sorted(fv):
        want = fv[eid]
        if eid not in entries:
            errors.append("%s: frozen id removed" % eid)
            continue
        is_draft, got = entries[eid]
        if is_draft:
            errors.append("%s: frozen id carries \"draft\": true" % eid)
        if got != want:
            errors.append("%s: frozen vector changed (FROZEN %s, now %s)" % (eid, want, got))
    return errors


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--kat-dir", default=DEFAULT_KAT_DIR)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    try:
        entries = collect(args.kat_dir)
        m = manifest(entries)
    except (KatError, OSError, ValueError) as e:
        print("✗ kat-frozen: %s" % e, file=sys.stderr)
        return 1

    drafts = sum(1 for d, _ in entries.values() if d)
    summary = "%d frozen entries (%d draft excluded), digest %s" % (len(m["vectors"]), drafts, m["digest"])

    if not args.check:
        sys.stdout.write(render(m))
        print("kat-frozen: " + summary, file=sys.stderr)
        return 0

    frozen_path = os.path.join(args.kat_dir, FROZEN_NAME)
    if not os.path.isfile(frozen_path):
        print("kat-frozen: no %s yet (it is recorded at Release Candidate); computed %s" % (FROZEN_NAME, summary))
        return 0
    try:
        errors = check(entries, frozen_path)
    except (KatError, OSError, ValueError) as e:
        errors = [str(e)]
    for e in errors:
        print("✗ " + e)
    if errors:
        print("✗ kat-frozen: %d error(s) against %s" % (len(errors), FROZEN_NAME))
        return 1
    new = sorted(set(m["vectors"]) - set(_load(frozen_path)["vectors"]))
    if not args.quiet:
        for eid in new:
            print("  new non-draft id, not yet in %s: %s" % (FROZEN_NAME, eid))
    print("✓ kat-frozen: every %s id present and unchanged; %d new non-draft id(s); %s"
          % (FROZEN_NAME, len(new), summary))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
