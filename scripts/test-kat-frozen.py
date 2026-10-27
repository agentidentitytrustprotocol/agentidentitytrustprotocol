#!/usr/bin/env python3
"""Scripted cases for scripts/kat-frozen.py --check, each on a temp copy.

Run by `make kat-frozen-test`, which is part of `make validate` and so of CI.
Standard library only. Each case copies schemas/conformance/known-answer into
a temporary directory, writes a FROZEN.json there from the current manifest,
applies one change, runs `kat-frozen.py --check --kat-dir <copy>`, and
requires the expected exit status and message. The repository tree is never modified.

Usage: scripts/test-kat-frozen.py
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KAT = os.path.join(ROOT, "schemas", "conformance", "known-answer")
TOOL = os.path.join(ROOT, "scripts", "kat-frozen.py")

FROZEN_VECTOR = ("jwk-thumbprints.json", "kat-jwk-thumb-001")
DRAFT_VECTOR = ("jcs-sha256.json", "kat-renewal-pop-001")
SIGNED = "signed-examples/tct/kat-keypair-001-issues-002.json"


def run(kat_dir, *extra):
    return subprocess.run([sys.executable, TOOL, "--kat-dir", kat_dir, *extra],
                          capture_output=True, text=True)


def load(path):
    with open(path, encoding="utf-8") as fh:
        return json.load(fh)


def dump(path, doc, indent=2):
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(doc, fh, indent=indent, ensure_ascii=False)
        fh.write("\n")


def edit_vector(d, fname, vid, fn):
    path = os.path.join(d, fname)
    doc = load(path)
    for i, v in enumerate(doc["vectors"]):
        if v["id"] == vid:
            doc["vectors"][i] = fn(v)
            break
    else:
        raise AssertionError("%s not in %s" % (vid, fname))
    doc["vectors"] = [v for v in doc["vectors"] if v is not None]
    dump(path, doc)


def append_vector(d, fname, entry):
    path = os.path.join(d, fname)
    doc = load(path)
    doc["vectors"].append(entry)
    dump(path, doc)


# ── Mutations ───────────────────────────────────────────────────────────────

def nothing(d):
    pass


def flip_last(s):
    return s[:-1] + ("A" if s[-1] != "A" else "B")


def mutate_frozen(d):
    # Edit the pinned output (the RFC 7638 thumbprint) of a frozen vector.
    edit_vector(d, *FROZEN_VECTOR, lambda v: dict(v, jkt=flip_last(v["jkt"])))


def delete_frozen(d):
    edit_vector(d, *FROZEN_VECTOR, lambda v: None)


def append_new(d):
    append_vector(d, FROZEN_VECTOR[0], {"id": "kat-test-new-001", "note": "appended"})


def append_new_draft(d):
    append_vector(d, DRAFT_VECTOR[0], {"id": "kat-test-new-draft-001", "draft": True})


def mutate_draft(d):
    edit_vector(d, *DRAFT_VECTOR, lambda v: dict(v, mutated=True))


def tag_frozen_draft(d):
    edit_vector(d, *FROZEN_VECTOR, lambda v: dict(v, draft=True))


def reformat(d):
    # Whitespace, member order and line endings do not change sha256(JCS(entry)).
    path = os.path.join(d, FROZEN_VECTOR[0])
    doc = load(path)
    doc["vectors"] = [dict(reversed(list(v.items()))) for v in doc["vectors"]]
    text = json.dumps(doc, indent=7, ensure_ascii=True).replace("\n", "\r\n")
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(text)


def mutate_signed(d):
    path = os.path.join(d, SIGNED)
    doc = load(path)
    doc["tct_token"] = flip_last(doc["tct_token"])
    dump(path, doc)


def delete_signed(d):
    os.remove(os.path.join(d, SIGNED))


def add_signed(d):
    dump(os.path.join(d, "signed-examples", "tct", "kat-test-new.json"), {"tct_token": "x"})


def frozen_lists_draft(d):
    # FROZEN.json itself must never list a draft id.
    path = os.path.join(d, "FROZEN.json")
    m = load(path)
    m["vectors"][DRAFT_VECTOR[1]] = "00" * 32
    m["vectors"] = dict(sorted(m["vectors"].items()))
    m["digest"] = recompute_digest(m["vectors"])
    dump(path, m)


def frozen_bad_digest(d):
    path = os.path.join(d, "FROZEN.json")
    m = load(path)
    m["digest"] = "00" * 32
    dump(path, m)


def no_frozen(d):
    os.remove(os.path.join(d, "FROZEN.json"))


def recompute_digest(vectors):
    import importlib.util
    spec = importlib.util.spec_from_file_location("kat_frozen", TOOL)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.sha256_hex(mod.jcs(vectors))


CASES = [
    # (name, mutation, expected exit status, text the output must contain)
    ("unchanged copy passes", nothing, 0, "0 new non-draft id(s)"),
    ("mutating a frozen vector fails", mutate_frozen, 1, "kat-jwk-thumb-001: frozen vector changed"),
    ("deleting a frozen id fails", delete_frozen, 1, "kat-jwk-thumb-001: frozen id removed"),
    ("appending a new vector passes", append_new, 0, "1 new non-draft id(s)"),
    ("appending a new draft vector passes", append_new_draft, 0, "(7 draft excluded)"),
    ("changing a draft vector passes", mutate_draft, 0, "0 new non-draft id(s)"),
    ("tagging a frozen vector draft fails", tag_frozen_draft, 1, "kat-jwk-thumb-001: frozen id carries"),
    ("reformatting a vector file passes", reformat, 0, "0 new non-draft id(s)"),
    ("mutating a frozen signed example fails", mutate_signed, 1, SIGNED + ": frozen vector changed"),
    ("deleting a frozen signed example fails", delete_signed, 1, SIGNED + ": frozen id removed"),
    ("adding a new signed example passes", add_signed, 0, "1 new non-draft id(s)"),
    ("a draft id listed in FROZEN.json fails", frozen_lists_draft, 1, "kat-renewal-pop-001: frozen id carries"),
    ("a FROZEN.json digest that does not match its vectors fails", frozen_bad_digest, 1, "digest does not match"),
    ("no FROZEN.json passes (compute and print only)", no_frozen, 0, "no FROZEN.json yet"),
]


def main():
    failures = 0
    with tempfile.TemporaryDirectory(prefix="kat-frozen-test-") as tmp:
        for i, (name, mutate, want, text) in enumerate(CASES):
            d = os.path.join(tmp, "case-%02d" % i)
            shutil.copytree(KAT, d)
            if os.path.exists(os.path.join(d, "FROZEN.json")):
                os.remove(os.path.join(d, "FROZEN.json"))
            gen = run(d)
            if gen.returncode != 0:
                print("✗ %s: could not compute the manifest\n%s" % (name, gen.stderr))
                failures += 1
                continue
            with open(os.path.join(d, "FROZEN.json"), "w", encoding="utf-8", newline="\n") as fh:
                fh.write(gen.stdout)
            mutate(d)
            res = run(d, "--check", "--quiet")
            ok = res.returncode == want and text in res.stdout
            print("%s %s (exit %d, expected %d)" % ("✓" if ok else "✗", name, res.returncode, want))
            if not ok:
                failures += 1
                sys.stdout.write(res.stdout + res.stderr)
    if failures:
        print("✗ kat-frozen-test: %d of %d case(s) failed" % (failures, len(CASES)))
        return 1
    print("✓ kat-frozen-test: all %d cases gave the expected result" % len(CASES))
    return 0


if __name__ == "__main__":
    sys.exit(main())
