#!/usr/bin/env python3
"""Independently recompute the P-256 and signature-strictness known answers.

Run by `make kat-independent`, which is part of `make validate` and so of CI.
It needs `python-ecdsa`, pinned with hashes in `scripts/requirements-kat.txt`
(`python3 -m pip install --require-hashes -r scripts/requirements-kat.txt`).
`scripts/verify-known-answer.mjs` (`make kat-verify`) is the other checker and
depends on nothing beyond Node's standard library.

The split is the same one regen-known-answer.py describes, with a third
implementation added. The P-256 vectors (RFC-AITP-0001 §5.4.6, §5.4.7) are
produced outside regen-known-answer.py, because aitp-verifier-py signs
Ed25519 only. This script recomputes every one of them from the committed
human-readable inputs with code that shares nothing with the Node checker:

  * P-256: python-ecdsa (pure Python, RFC 6979 deterministic k). Not OpenSSL,
    not pyca/cryptography, not RustCrypto.
  * Ed25519: RFC 8032 §6 reference arithmetic, written out below.
  * JCS: a small RFC 8785 serializer for the value types these vectors use.

For each P-256 signature it re-signs with RFC 6979 and low-S normalization
and requires the committed bytes exactly; it verifies strictly; and it
requires every double-hash negative to be a valid signature over
sha256(sha256(preimage)) that does not verify over the single-hash input.

The envelope examples (RFC-AITP-0001 §5.4 sig_input_v2, issue #87) are covered
for both algorithms: kat-envelope-001-p256 and kat-envelope-002-ed25519 are
re-signed from their envelopes, each v1 (pipe-input) negative is re-signed over
the retired input and must not verify over sig_input_v2, and env-007 to env-010
are checked against kat-envelope-002-ed25519: env-007 verifies, and the
committed signature fails over each of the three changed envelopes. rev-010 and
bundle-008 carry the committed kat-keypair-001 snapshot and bundle signatures
over bodies whose `version` was changed after signing: each signature verifies
over the signed example and fails over the fixture.

Usage:
    python3 scripts/recompute-known-answer-independent.py [--quiet]

With --quiet only failing checks and the summary are printed.

It only reads files in this repository. Exit status is 0 when every check
passes and 1 otherwise.
"""

from __future__ import annotations

import base64
import hashlib
import json
import sys
from pathlib import Path

try:
    import ecdsa
    from ecdsa.util import sigdecode_string
except ImportError:  # pragma: no cover
    sys.exit("python-ecdsa is required: python3 -m pip install --require-hashes -r scripts/requirements-kat.txt")

REPO = Path(__file__).resolve().parent.parent
CONF = REPO / "schemas" / "conformance"
KAT = CONF / "known-answer"
SIGNED = KAT / "signed-examples"
# The current revision literal, read from the schema rather than restated here.
AITP_VERSION = json.loads((REPO / "schemas/json/aitp-envelope.schema.json").read_text(encoding="utf-8"))["properties"]["version"]["const"]

QUIET = "--quiet" in sys.argv[1:]

# Coverage floor, as EXPECTED_MIN_CHECKS in verify-known-answer.mjs: a check that
# silently stops running (commented out, a loop that ends early, a gate that no
# longer matches) fails the run. Raise it in the same commit that adds checks;
# lower it only on purpose, and say why.
EXPECTED_MIN_CHECKS = 251

failures = 0
checks = 0


def section(title: str) -> None:
    if not QUIET:
        print(title)


def check(name: str, cond: bool) -> None:
    global failures, checks
    checks += 1
    if not cond or not QUIET:
        print(("  ok   " if cond else "  FAIL ") + name)
    if not cond:
        failures += 1


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def b64d(s: str) -> bytes:
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def b64e(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def H(b: bytes) -> bytes:
    return hashlib.sha256(b).digest()


# ── RFC 8785 JCS for strings, integers, booleans, null, arrays, objects ─────

def jcs(v) -> bytes:
    def ser(x) -> str:
        if x is None:
            return "null"
        if x is True:
            return "true"
        if x is False:
            return "false"
        if isinstance(x, int):
            return str(x)
        if isinstance(x, float):
            raise ValueError("floats are not used by these vectors")
        if isinstance(x, str):
            return json.dumps(x, ensure_ascii=False)
        if isinstance(x, list):
            return "[" + ",".join(ser(e) for e in x) + "]"
        if isinstance(x, dict):
            keys = sorted(x, key=lambda k: k.encode("utf-16-be"))
            return "{" + ",".join(json.dumps(k, ensure_ascii=False) + ":" + ser(x[k]) for k in keys) + "}"
        raise TypeError(type(x))
    return ser(v).encode("utf-8")


# ── Ed25519, RFC 8032 §6 reference arithmetic ───────────────────────────────

p = 2**255 - 19
L = 2**252 + 27742317777372353535851937790883648493
d_ = -121665 * pow(121666, p - 2, p) % p
SQRT_M1 = pow(2, (p - 1) // 4, p)
IDENT = (0, 1, 1, 0)


def _xrecover(y: int):
    xx = (y * y - 1) * pow(d_ * y * y + 1, p - 2, p) % p
    x = pow(xx, (p + 3) // 8, p)
    if (x * x - xx) % p:
        x = x * SQRT_M1 % p
    if (x * x - xx) % p:
        return None
    return x


def _add(P, Q):
    A = (P[1] - P[0]) * (Q[1] - Q[0]) % p
    B_ = (P[1] + P[0]) * (Q[1] + Q[0]) % p
    C = 2 * P[3] * Q[3] * d_ % p
    D = 2 * P[2] * Q[2] % p
    E, F, G, Hh = B_ - A, D - C, D + C, B_ + A
    return (E * F % p, G * Hh % p, F * G % p, E * Hh % p)


def _mul(s: int, P):
    Q = IDENT
    while s:
        if s & 1:
            Q = _add(Q, P)
        P = _add(P, P)
        s >>= 1
    return Q


def _eq(P, Q) -> bool:
    return (P[0] * Q[2] - Q[0] * P[2]) % p == 0 and (P[1] * Q[2] - Q[1] * P[2]) % p == 0


def _enc(P) -> bytes:
    zi = pow(P[2], p - 2, p)
    x, y = P[0] * zi % p, P[1] * zi % p
    return int.to_bytes(y | ((x & 1) << 255), 32, "little")


def _dec(b: bytes, strict: bool):
    """Decode a point. strict rejects y >= p and x = 0 with the sign bit set."""
    raw = int.from_bytes(b, "little")
    y, sign = raw & ((1 << 255) - 1), raw >> 255
    if y >= p:
        if strict:
            return None
        y %= p
    x = _xrecover(y)
    if x is None:
        return None
    if x == 0 and sign:
        if strict:
            return None
    if (x & 1) != sign:
        x = p - x
    return (x, y, 1, x * y % p)


_By = 4 * pow(5, p - 2, p) % p
_Bx = _xrecover(_By)
_Bx = p - _Bx if _Bx & 1 else _Bx  # the base point has even ("positive") x
BASE = (_Bx, _By, 1, _Bx * _By % p)


def ed_public(seed: bytes) -> bytes:
    h = hashlib.sha512(seed).digest()
    a = int.from_bytes(h[:32], "little") & ((1 << 254) - 8) | (1 << 254)
    return _enc(_mul(a, BASE))


def ed_sign(seed: bytes, m: bytes) -> bytes:
    h = hashlib.sha512(seed).digest()
    a = int.from_bytes(h[:32], "little") & ((1 << 254) - 8) | (1 << 254)
    A = _enc(_mul(a, BASE))
    r = int.from_bytes(hashlib.sha512(h[32:] + m).digest(), "little") % L
    R = _enc(_mul(r, BASE))
    k = int.from_bytes(hashlib.sha512(R + A + m).digest(), "little") % L
    return R + int.to_bytes((r + k * a) % L, 32, "little")


def ed_verify_lax(A: bytes, m: bytes, sig: bytes) -> bool:
    """What a permissive verifier accepts: S reduced mod L, cofactored equation."""
    Ap, Rp = _dec(A, False), _dec(sig[:32], False)
    if Ap is None or Rp is None:
        return False
    S = int.from_bytes(sig[32:], "little") % L
    k = int.from_bytes(hashlib.sha512(sig[:32] + A + m).digest(), "little") % L
    return _eq(_mul(8, _mul(S, BASE)), _mul(8, _add(Rp, _mul(k, Ap))))


def ed_verify_strict(A: bytes, m: bytes, sig: bytes) -> bool:
    """RFC-AITP-0001 §5.4.7: S < L, canonical points, no small-order key,
    cofactorless equation [S]B = R + [k]A."""
    S = int.from_bytes(sig[32:], "little")
    if S >= L:
        return False
    Ap, Rp = _dec(A, True), _dec(sig[:32], True)
    if Ap is None or Rp is None:
        return False
    if _eq(_mul(8, Ap), IDENT):
        return False
    k = int.from_bytes(hashlib.sha512(sig[:32] + A + m).digest(), "little") % L
    return _eq(_mul(S, BASE), _add(Rp, _mul(k, Ap)))


# ── P-256 via python-ecdsa ───────────────────────────────────────────────────

N = ecdsa.NIST256p.order


def p256_signing_key(scalar_hex: str):
    return ecdsa.SigningKey.from_secret_exponent(int(scalar_hex, 16) % N, curve=ecdsa.NIST256p)


def p256_vk_from_aid(aid: str):
    return ecdsa.VerifyingKey.from_string(b64d(aid.removeprefix("aid:pubkey:p256:")), curve=ecdsa.NIST256p)


def p256_sign(sk, digest: bytes) -> bytes:
    """e = digest (§5.4.6), RFC 6979 k, low-S (§5.4.7). Returns raw R||S."""
    raw = sk.sign_digest_deterministic(digest, hashfunc=hashlib.sha256)
    r, s = sigdecode_string(raw, N)
    s = min(s, N - s)
    return r.to_bytes(32, "big") + s.to_bytes(32, "big")


def p256_verify_lax(vk, digest: bytes, raw: bytes) -> bool:
    try:
        return vk.verify_digest(raw, digest)
    except ecdsa.BadSignatureError:
        return False


def p256_verify_strict(vk, digest: bytes, raw: bytes) -> bool:
    r, s = sigdecode_string(raw, N)
    if not (0 < r < N and 0 < s < N) or s > N // 2:
        return False
    return p256_verify_lax(vk, digest, raw)


def untag(sig: str, alg: str) -> bytes:
    prefix = alg + "."
    if not sig.startswith(prefix):
        raise ValueError(f"expected {prefix} prefix: {sig!r}")
    return b64d(sig[len(prefix):])


def p256_signature(name: str, sk, vk, preimage: bytes, sig: str, double_hash: str | None) -> None:
    d = H(preimage)
    check(f"{name}: signature re-signs byte for byte (RFC 6979, low-S)", "p256." + b64e(p256_sign(sk, d)) == sig)
    check(f"{name}: signature verifies strictly over d = sha256(preimage)", p256_verify_strict(vk, d, untag(sig, "p256")))
    if double_hash is not None:
        dh = untag(double_hash, "p256")
        check(f"{name}: double-hash negative does NOT verify over d", not p256_verify_strict(vk, d, dh))
        check(f"{name}: double-hash negative is sign(sha256(d))", "p256." + b64e(p256_sign(sk, H(d))) == double_hash)


def proof_input(sender: str, receiver: str, message_id: str, timestamp: int, pop_nonce: str) -> bytes:
    """RFC-AITP-0002 §3.1 pinned-key proof input (ASCII-decimal timestamp)."""
    return b"\0".join([b"aitp-pinned-key-v1", sender.encode(), receiver.encode(),
                       message_id.encode(), str(timestamp).encode(), b64d(pop_nonce)])


def derived_uuid(tag: str, inp: str) -> str:
    """RFC-AITP-0005 §2.2 derived identifier: SHA-256(tag || 0x00 || input)[0..16], v4 bits set."""
    b = bytearray(H(tag.encode() + b"\0" + inp.encode())[:16])
    b[6] = (b[6] & 0x0F) | 0x40
    b[8] = (b[8] & 0x3F) | 0x80
    x = b.hex()
    return f"{x[:8]}-{x[8:12]}-{x[12:16]}-{x[16:20]}-{x[20:]}"


def jwk_thumbprint(jwk: dict) -> str:
    """RFC 7638: SHA-256 over the required members in lexicographic order, no whitespace."""
    return b64e(H(jcs(jwk)))


def main() -> int:
    global failures
    keypairs = {k["id"]: k for k in load(KAT / "keypairs.json")["vectors"]}
    jcsv = {v["id"]: v for v in load(KAT / "jcs-sha256.json")["vectors"]}
    strict = {v["id"]: v for v in load(KAT / "signature-strictness.json")["vectors"]}

    section("── keypairs ──")
    k5 = keypairs["kat-keypair-005-p256"]
    sk = p256_signing_key(k5["private_scalar_hex"])
    vk = sk.get_verifying_key()
    aid5 = "aid:pubkey:p256:" + b64e(vk.to_string("compressed"))
    check("kat-keypair-005-p256 compressed point and AID",
          vk.to_string("compressed").hex() == k5["pubkey_compressed_hex"] and k5["aid"] == aid5)
    check("kat-keypair-005-p256 AID decodes to the same key", p256_vk_from_aid(aid5).to_string() == vk.to_string())
    t1, k1 = keypairs["kat-keypair-001-tagged"], keypairs["kat-keypair-001"]
    seed1 = bytes.fromhex(t1["seed_hex"])
    A1 = ed_public(seed1)
    check("kat-keypair-001-tagged pubkey", b64e(A1) == t1["pubkey_b64url"] == k1["pubkey_b64url"])
    check("kat-keypair-001-tagged aid / untagged_aid",
          t1["aid"] == "aid:pubkey:ed25519:" + b64e(A1) and t1["untagged_aid"] == "aid:pubkey:" + b64e(A1) == k1["aid"])

    section("── jcs-sha256.json P-256 vectors ──")
    v = jcsv["kat-p256-jcs-sign-001"]
    pre = jcs(v["preimage_json"])
    check("kat-p256-jcs-sign-001 preimage", pre.hex() == v["preimage_hex"] and len(pre) == v["preimage_len_bytes"])
    check("kat-p256-jcs-sign-001 sha256", H(pre).hex() == v["sha256_hex"] and b64e(H(pre)) == v["sha256_b64url"])
    check("kat-p256-jcs-sign-001 signer", v["signer_aid"] == aid5 and v["signature"] == "p256." + v["signature_b64url"])
    p256_signature("kat-p256-jcs-sign-001", sk, vk, pre, v["signature"], v["double_hash_signature_MUST_NOT_verify"])
    r, s = sigdecode_string(untag(v["signature"], "p256"), N)
    high = untag(v["high_s_sibling_MUST_NOT_verify"], "p256")
    check("kat-p256-jcs-sign-001 high-S sibling is (R, n - S)", high == r.to_bytes(32, "big") + (N - s).to_bytes(32, "big"))
    check("kat-p256-jcs-sign-001 high-S sibling verifies lax", p256_verify_lax(vk, H(pre), high))
    check("kat-p256-jcs-sign-001 high-S sibling rejected strict", not p256_verify_strict(vk, H(pre), high))

    v = jcsv["kat-manifest-pop-002-p256"]
    pre = b64d(v["challenge"])
    check("kat-manifest-pop-002-p256 decoded challenge", pre.hex() == v["decoded_hex"] and H(pre).hex() == v["sha256_hex"])
    check("kat-manifest-pop-002-p256 signer", v["signer_aid"] == aid5 and v["signature"] == "p256." + v["signature_b64url"])
    p256_signature("kat-manifest-pop-002-p256", sk, vk, pre, v["signature"], v["double_hash_signature_MUST_NOT_verify"])

    section("── jcs-sha256.json pinned-key proofs (RFC-AITP-0002 §3.1) ──")
    v = jcsv["kat-pinned-key-proof-002-p256"]
    pre = proof_input(v["sender_aid"], v["receiver_aid"], v["message_id"], v["timestamp"], v["pop_nonce"])
    check("kat-pinned-key-proof-002-p256 proof_input",
          pre.hex() == v["proof_input_hex"] and len(pre) == v["proof_input_len_bytes"] == 199)
    check("kat-pinned-key-proof-002-p256 sha256", H(pre).hex() == v["sha256_hex"] and b64e(H(pre)) == v["sha256_b64url"])
    check("kat-pinned-key-proof-002-p256 signer",
          v["sender_aid"] == v["signer_aid"] == aid5 and v["signature"] == "p256." + v["signature_b64url"])
    p256_signature("kat-pinned-key-proof-002-p256", sk, vk, pre, v["signature"], v["double_hash_signature_MUST_NOT_verify"])

    k3 = keypairs["kat-keypair-003"]
    seed3 = bytes.fromhex(k3["seed_hex"])
    A3 = ed_public(seed3)
    check("kat-keypair-003 pubkey", b64e(A3) == k3["pubkey_b64url"])
    v1 = jcsv["kat-pinned-key-proof-001"]
    pre1 = proof_input(v1["sender_aid"], v1["receiver_aid"], v1["message_id"], v1["timestamp"], v1["pop_nonce"])
    check("kat-pinned-key-proof-001 re-signs byte for byte", b64e(ed_sign(seed3, H(pre1))) == v1["signature_b64url"])
    v = jcsv["kat-pinned-key-proof-003-tagged-ed25519"]
    pre = proof_input(v["sender_aid"], v["receiver_aid"], v["message_id"], v["timestamp"], v["pop_nonce"])
    check("kat-pinned-key-proof-003 proof_input",
          pre.hex() == v["proof_input_hex"] and len(pre) == v["proof_input_len_bytes"] == 201)
    check("kat-pinned-key-proof-003 sha256", H(pre).hex() == v["sha256_hex"] and b64e(H(pre)) == v["sha256_b64url"])
    check("kat-pinned-key-proof-003 sender is the tagged kat-keypair-003 AID",
          v["sender_aid"] == v["signer_aid"] == "aid:pubkey:ed25519:" + b64e(A3))
    sig3 = b64d(v["signature_b64url"])
    check("kat-pinned-key-proof-003 re-signs byte for byte", ed_sign(seed3, H(pre)) == sig3)
    check("kat-pinned-key-proof-003 verifies strictly", ed_verify_strict(A3, H(pre), sig3))
    check("kat-pinned-key-proof-003 differs from -001, whose proof does not verify here",
          pre != pre1 and not ed_verify_strict(A3, H(pre), b64d(v1["signature_b64url"])))

    section("── jcs-sha256.json SPIFFE X509-SVID proof (RFC-AITP-0002 §6.4.1) ──")
    v = jcsv["kat-spiffe-x509-proof-001"]
    pinned = proof_input(v["sender_aid"], v["receiver_aid"], v["message_id"], v["timestamp"], v["pop_nonce"])
    pre = b"aitp-spiffe-x509-v1" + pinned[len(b"aitp-pinned-key-v1"):]
    check("kat-spiffe-x509-proof-001 proof_input",
          pre.hex() == v["proof_input_hex"] and len(pre) == v["proof_input_len_bytes"] == 194)
    check("kat-spiffe-x509-proof-001 sha256", H(pre).hex() == v["sha256_hex"] and b64e(H(pre)) == v["sha256_b64url"])
    check("kat-spiffe-x509-proof-001 signer is kat-keypair-003, not the sender",
          v["signer_aid"] == "aid:pubkey:" + b64e(A3) and v["sender_aid"] != v["signer_aid"]
          and v["sender_aid"] == keypairs["kat-keypair-002"]["aid"])
    sigx = b64d(v["signature_b64url"])
    check("kat-spiffe-x509-proof-001 re-signs byte for byte", ed_sign(seed3, H(pre)) == sigx)
    check("kat-spiffe-x509-proof-001 verifies strictly", ed_verify_strict(A3, H(pre), sigx))
    check("kat-spiffe-x509-proof-001 does not verify over the pinned-key input (domain separation)",
          len(pinned) == 193 and not ed_verify_strict(A3, H(pinned), sigx))
    f25 = load(CONF / "id-025-spiffe-x509-svid-success.json")
    e25 = f25["input"]["envelope"]
    check("id-025: tuple and literal proof are kat-spiffe-x509-proof-001",
          e25["sender"]["agent_id"] == v["sender_aid"] and f25["input"]["self_aid"] == v["receiver_aid"]
          and e25["message_id"] == v["message_id"] and e25["timestamp"] == v["timestamp"]
          and e25["payload"]["pop_nonce"] == v["pop_nonce"]
          and e25["payload"]["identity"]["proof"] == v["signature_b64url"]
          and e25["payload"]["identity"]["svid_type"] == "x509-svid"
          and f25["expected"]["outcome"] == "success")

    section("── pinned-key fixtures: each proof against its own tuple ──")
    for name, kind in [
        ("id-010-pinned-key-p256-success.json", "p256"),
        ("id-011-pinned-key-p256-untagged-proof-rejected.json", "untagged"),
        ("id-011b-oidc-typed-descriptor-with-pinned-proof-rejected.json", "ed25519"),
        ("id-012-pinned-key-p256-uncompressed-key-rejected.json", "uncompressed"),
        ("id-017-pinned-key-ed25519-success.json", "ed25519"),
        ("id-018-pinned-key-issuer-present-rejected.json", "ed25519"),
        ("mh-009-identity-type-mismatch-rejected.json", "ed25519"),
    ]:
        fx = load(CONF / name)
        env = fx["input"]["envelope"]
        idn = env["payload"]["identity"]
        snd = env["sender"]["agent_id"]
        pre = proof_input(snd, fx["input"]["self_aid"], env["message_id"], env["timestamp"], env["payload"]["pop_nonce"])
        check(f"{name}: trust_store contains the sender", snd in fx["input"].get("trust_store", []))
        if kind == "ed25519":
            check(f"{name}: Ed25519 proof verifies over the fixture tuple",
                  snd == k3["aid"] and ed_verify_strict(A3, H(pre), b64d(idn["proof"])))
            continue
        check(f"{name}: sender is kat-keypair-005-p256", snd == aid5)
        if kind == "untagged":
            check(f"{name}: proof is untagged", "." not in idn["proof"])
            check(f"{name}: raw bytes verify under P-256 (only the tag is wrong)",
                  p256_verify_strict(vk, H(pre), b64d(idn["proof"])))
        else:
            check(f"{name}: p256. proof verifies over the fixture tuple",
                  p256_verify_strict(vk, H(pre), untag(idn["proof"], "p256")))
        if kind == "uncompressed":
            unc = vk.to_string("uncompressed")
            check(f"{name}: public_key is the 65-byte uncompressed point 04 || X || Y",
                  len(unc) == 65 and unc[0] == 4 and idn["public_key"] == b64e(unc) and len(idn["public_key"]) == 87)
        else:
            check(f"{name}: public_key is the compressed AID key", idn["public_key"] == b64e(vk.to_string("compressed")))

    section("── signature-strictness.json ──")
    v = strict["sig-001-ed25519-small-order-key-rejected"]
    A, m, sg = b64d(v["public_key_b64url"]), bytes.fromhex(v["message_hex"]), b64d(v["signature_b64url"])
    check("sig-001 key is small-order", _eq(_mul(8, _dec(A, True)), IDENT))
    check("sig-001 lax accepts", ed_verify_lax(A, m, sg))
    check("sig-001 strict rejects", not ed_verify_strict(A, m, sg))
    v = strict["sig-002-ed25519-noncanonical-s-rejected"]
    m, good, bad = bytes.fromhex(v["message_hex"]), b64d(v["valid_signature_b64url"]), b64d(v["signature_b64url"])
    check("sig-002 signer is kat-keypair-001", v["signer_aid"] == k1["aid"])
    check("sig-002 valid signature re-signs", ed_sign(seed1, m) == good)
    check("sig-002 valid signature verifies strict", ed_verify_strict(A1, m, good))
    check("sig-002 bad = (R, S + L)",
          bad[:32] == good[:32] and int.from_bytes(bad[32:], "little") == int.from_bytes(good[32:], "little") + L)
    check("sig-002 lax accepts", ed_verify_lax(A1, m, bad))
    check("sig-002 strict rejects", not ed_verify_strict(A1, m, bad))
    v = strict["sig-003-p256-high-s-rejected"]
    jv = jcsv["kat-p256-jcs-sign-001"]
    check("sig-003 matches kat-p256-jcs-sign-001",
          v["low_s_signature"] == jv["signature"] and v["signature"] == jv["high_s_sibling_MUST_NOT_verify"]
          and v["sha256_hex"] == jv["sha256_hex"] and v["signer_aid"] == aid5)
    d = bytes.fromhex(v["sha256_hex"])
    check("sig-003 lax accepts", p256_verify_lax(vk, d, untag(v["signature"], "p256")))
    check("sig-003 strict rejects", not p256_verify_strict(vk, d, untag(v["signature"], "p256")))

    section("── envelope signing input v2 (RFC-AITP-0001 §5.4, issue #87) ──")
    strip = lambda o: {k: x for k, x in o.items() if k != "signature"}

    def env_v2(e) -> bytes:
        """sig_input_v2 = "aitp-envelope-v2" || 0x00 || JCS(envelope without signature)."""
        return b"aitp-envelope-v2\0" + jcs(strip(e))

    def env_v1(e) -> str:
        """The retired pipe-composed input, kept only to check the v1 negatives."""
        return f"{e['message_id']}|{e['timestamp']}|{e['sender']['agent_id']}|{H(jcs(e['payload'])).hex()}"

    def preimage_fields(name, f, pre):
        check(f"{name}: signing_input, sig_input_v2_hex, length and sha256 recompute from the envelope",
              f["signing_input"] == "sig_input_v2" and pre.hex() == f["sig_input_v2_hex"]
              and len(pre) == f["sig_input_v2_len_bytes"] and H(pre).hex() == f["sig_input_v2_sha256_hex"])

    f = load(SIGNED / "envelope" / "kat-keypair-005-envelope.json")
    env = f["envelope"]
    pre = env_v2(env)
    mnv = f["_must_not_verify"]
    check("kat-envelope-001-p256: kat_id and signer", f["_kat_input"]["kat_id"] == "kat-envelope-001-p256"
          and env["sender"]["agent_id"] == aid5)
    preimage_fields("kat-envelope-001-p256", f, pre)
    p256_signature("kat-envelope-001-p256", sk, vk, pre, env["signature"], mnv["double_hash_signature"])
    v1 = env_v1(env)
    check("kat-envelope-001-p256: v1_signature re-signs over v1_sig_input and verifies there",
          mnv["v1_sig_input"] == v1 and "p256." + b64e(p256_sign(sk, H(v1.encode()))) == mnv["v1_signature"]
          and p256_verify_strict(vk, H(v1.encode()), untag(mnv["v1_signature"], "p256")))
    check("kat-envelope-001-p256: v1_signature does NOT verify over sig_input_v2",
          not p256_verify_strict(vk, H(pre), untag(mnv["v1_signature"], "p256")))
    fixture = load(CONF / "env-005-p256-envelope-success.json")["input"]["envelope"]
    check("kat-envelope-001-p256 equals env-005 input apart from signature", jcs(strip(env)) == jcs(strip(fixture)))

    f = load(SIGNED / "envelope" / "kat-keypair-001-envelope.json")
    env = f["envelope"]
    pre = env_v2(env)
    mnv = f["_must_not_verify"]
    sig = b64d(env["signature"])
    check("kat-envelope-002-ed25519: kat_id, signer and non-empty extensions",
          f["_kat_input"]["kat_id"] == "kat-envelope-002-ed25519" and env["sender"]["agent_id"] == k1["aid"]
          and bool(env.get("extensions")))
    preimage_fields("kat-envelope-002-ed25519", f, pre)
    check("kat-envelope-002-ed25519: signature re-signs byte for byte over d = sha256(sig_input_v2)",
          ed_sign(seed1, H(pre)) == sig)
    check("kat-envelope-002-ed25519: signature verifies strictly", ed_verify_strict(A1, H(pre), sig))
    v1 = env_v1(env)
    v1sig = b64d(mnv["v1_signature"])
    check("kat-envelope-002-ed25519: v1_signature re-signs over v1_sig_input and verifies there",
          mnv["v1_sig_input"] == v1 and ed_sign(seed1, H(v1.encode())) == v1sig
          and ed_verify_strict(A1, H(v1.encode()), v1sig))
    check("kat-envelope-002-ed25519: v1_signature does NOT verify over sig_input_v2",
          not ed_verify_strict(A1, H(pre), v1sig) and not ed_verify_lax(A1, H(pre), v1sig))

    f7 = load(CONF / "env-007-extensions-unknown-key-accepted.json")
    e7 = f7["input"]["envelope"]
    check("env-007: envelope equals kat-envelope-002-ed25519, committed signature included, verifies",
          e7 == env and ed_verify_strict(A1, H(env_v2(e7)), b64d(e7["signature"]))
          and f7["expected"]["outcome"] == "success")
    for fname, member, code in [
        ("env-008-extensions-tampered-rejected.json", "extensions", "INVALID_SIGNATURE"),
        ("env-009-message-type-substituted-rejected.json", "message_type", "INVALID_SIGNATURE"),
        ("env-010-version-altered-rejected.json", "version", "UNKNOWN_VERSION"),
    ]:
        fx = load(CONF / fname)
        e = fx["input"]["envelope"]
        changed = sorted(k for k in set(e) | set(e7) if e.get(k) != e7.get(k))
        others_same = {k: v for k, v in fx["input"].items() if k != "envelope"} == \
            {k: v for k, v in f7["input"].items() if k != "envelope"}
        sg = b64d(e["signature"])
        check(f"{fx['id']}: only {member} differs from env-007; same signature; expects {code}",
              changed == [member] and others_same and e["signature"] == e7["signature"]
              and fx["expected"]["outcome"] == "failure" and fx["expected"]["error_code"] == code)
        check(f"{fx['id']}: signature does NOT verify over its sig_input_v2 (strict or lax)",
              not ed_verify_strict(A1, H(env_v2(e)), sg) and not ed_verify_lax(A1, H(env_v2(e)), sg))
        check(f"{fx['id']}: the v1 signature still verifies over its v1 input (the change is invisible to v1)",
              ed_verify_strict(A1, H(env_v1(e).encode()), v1sig))

    section("── signed examples (P-256) ──")

    f = load(SIGNED / "manifest" / "kat-keypair-005-manifest.json")
    body = f["manifest"]
    check("manifest signer", body["aid"] == aid5)
    p256_signature("manifest", sk, vk, jcs(strip(body)), body["signature"], f["_must_not_verify"]["double_hash_signature"])
    pop = body["proof_of_possession"]
    check("manifest PoP challenge derivation",
          pop["challenge"] == b64e(H(b"kat-keypair-005-manifest proof_of_possession.challenge")[:16]))
    p256_signature("manifest PoP", sk, vk, b64d(pop["challenge"]), pop["signature"],
                   f["_must_not_verify"]["double_hash_pop_signature"])

    f = load(SIGNED / "revocation" / "kat-keypair-005-snapshot.json")
    check("revocation signer", f["revocation_list"]["issuer"] == aid5)
    p256_signature("revocation", sk, vk, jcs(f["revocation_list"]), f["signature"], f["_must_not_verify"]["double_hash_signature"])

    f = load(SIGNED / "tct" / "kat-keypair-005-issues-002.json")
    h64, p64, s64 = f["tct_token"].split(".")
    check("ES256 TCT header", json.loads(b64d(h64)) == {"alg": "ES256", "typ": "aitp-tct+jwt"})
    check("ES256 TCT payload == decoded_claims", json.loads(b64d(p64)) == f["decoded_claims"])
    dbl = f["_must_not_verify"]["double_hash_jws"].split(".")
    check("ES256 TCT double-hash token reuses header.payload", dbl[:2] == [h64, p64])
    p256_signature("ES256 TCT", sk, vk, f"{h64}.{p64}".encode(), "p256." + s64, "p256." + dbl[2])

    section("── self-attestation TCTs (RFC-AITP-0005 §5.3), re-minted from their inputs ──")
    att_tag = "aitp-kat-attestation-v1"
    for rel, vid, alg in [
        ("kat-keypair-001-self-attestation.json", "kat-tct-002-self-attestation", "EdDSA"),
        ("kat-keypair-005-self-attestation.json", "kat-tct-003-p256-self-attestation", "ES256"),
    ]:
        f = load(SIGNED / "tct" / rel)
        if alg == "EdDSA":
            aid, jwk = k1["aid"], {"crv": "Ed25519", "kty": "OKP", "x": b64e(A1)}
        else:
            unc = vk.to_string("uncompressed")
            aid, jwk = aid5, {"crv": "P-256", "kty": "EC", "x": b64e(unc[1:33]), "y": b64e(unc[33:])}
        jti = derived_uuid(att_tag, vid)
        check(f"{vid}: jti = derived UUID over {att_tag!r} and the vector id",
              jti == f["decoded_claims"]["jti"] == f["_kat_input"]["jti"] == f["_kat_input"]["jti_derivation"]["jti"])
        claims = {"ver": AITP_VERSION, "jti": jti, "iss": aid, "sub": aid, "aud": aid,
                  "iat": 1711900000, "exp": 4867660000, "grants": ["aitp.attestation"],
                  "cnf": {"jkt": jwk_thumbprint(jwk)},
                  "ext": {"io.agentidentitytrustprotocol.kat": {"statement": f"{vid} archival attestation"}}}
        check(f"{vid}: decoded_claims equal the independently built claims", f["decoded_claims"] == claims)
        h64 = b64e(json.dumps({"alg": alg, "typ": "aitp-tct+jwt"}, separators=(",", ":")).encode())
        p64 = b64e(jcs(claims))
        si = f"{h64}.{p64}".encode()
        if alg == "EdDSA":
            token = f"{h64}.{p64}.{b64e(ed_sign(seed1, si))}"
            check(f"{vid}: EdDSA token re-mints byte for byte", token == f["tct_token"])
            check(f"{vid}: EdDSA signature verifies strictly", ed_verify_strict(A1, si, b64d(f["tct_token"].split(".")[2])))
        else:
            check(f"{vid}: ES256 header.payload re-mints byte for byte", f["tct_token"].rsplit(".", 1)[0] == f"{h64}.{p64}")
            dbl = f["_must_not_verify"]["double_hash_jws"].split(".")
            check(f"{vid}: double-hash token reuses header.payload", dbl[:2] == [h64, p64])
            p256_signature(vid, sk, vk, si, "p256." + f["tct_token"].split(".")[2], "p256." + dbl[2])

    section("── pinned-admission fixtures (RFC-AITP-0002 §3.4): proofs re-signed ──")
    def presentation(fx, env, n_len):
        idn = env["payload"]["identity"]
        snd = env["sender"]["agent_id"]
        nonce = b64d(env["payload"]["pop_nonce"])
        pre = proof_input(snd, fx["input"]["self_aid"], env["message_id"], env["timestamp"], env["payload"]["pop_nonce"])
        return (snd == k3["aid"] and idn["public_key"] == b64e(A3) and len(nonce) == n_len
                and snd in fx["input"]["trust_store"] and set(env["payload"]) == {"identity", "pop_nonce"}
                and b64e(ed_sign(seed3, H(pre))) == idn["proof"] and ed_verify_strict(A3, H(pre), b64d(idn["proof"]))), len(pre)
    f19 = load(CONF / "id-019-pinned-admission-success.json")
    ok, n = presentation(f19, f19["input"]["envelope"], 16)
    check("id-019: proof re-signs byte for byte over the 193-byte tuple", ok and n == 193)
    check("id-019: nonce is the outstanding challenge, issued under self_aid",
          f19["input"]["envelope"]["payload"]["pop_nonce"] == f19["input"]["outstanding_challenges"][0]["pop_nonce"]
          and f19["input"]["outstanding_challenges"][0]["verifier_aid"] == f19["input"]["self_aid"] == k1["aid"])
    f15 = load(CONF / "id-015-pinned-admission-wrong-message-type-rejected.json")
    e15 = dict(f15["input"]["envelope"], message_type="identity_presentation")
    ok, _ = presentation(f15, f15["input"]["envelope"], 16)
    check("id-015: id-019's envelope with only message_type changed; proof still verifies",
          ok and e15 == f19["input"]["envelope"] and f15["input"]["envelope"]["message_type"] != "identity_presentation"
          and f15["expected"]["error_code"] == "INVALID_ENVELOPE")
    f13 = load(CONF / "id-013-pinned-admission-nonce-reuse-rejected.json")
    s1, s2 = f13["input"]["sequence"]
    ok1, _ = presentation(f13, s1["envelope"], 16)
    ok2, n2 = presentation(f13, s2["envelope"], 16)
    check("id-013: both step proofs re-sign; same nonce, fresh message_id; step 2 IDENTITY_FAILED",
          ok1 and ok2 and n2 == 193 and s1["envelope"]["payload"]["pop_nonce"] == s2["envelope"]["payload"]["pop_nonce"]
          and s1["envelope"]["message_id"] != s2["envelope"]["message_id"]
          and s2["expected"]["error_code"] == "IDENTITY_FAILED")
    f14 = load(CONF / "id-014-pinned-admission-nonce-wrong-length-rejected.json")
    ok, n = presentation(f14, f14["input"]["envelope"], 15)
    check("id-014: 15-byte nonce is the challenge truncated; proof re-signs over the 192-byte tuple",
          ok and n == 192 and b64d(f14["input"]["envelope"]["payload"]["pop_nonce"])
          == b64d(f14["input"]["outstanding_challenges"][0]["pop_nonce"])[:15]
          and f14["expected"]["error_code"] == "IDENTITY_FAILED")

    f20 = load(CONF / "id-020-pinned-admission-nonce-expired-rejected.json")
    ok, n = presentation(f20, f20["input"]["envelope"], 16)
    ch = f20["input"]["outstanding_challenges"][0]
    check("id-020: proof re-signs over the 193-byte tuple; nonce issued under self_aid but expired at now",
          ok and n == 193 and ch["pop_nonce"] == f20["input"]["envelope"]["payload"]["pop_nonce"]
          and ch["verifier_aid"] == f20["input"]["self_aid"] and ch["expires_at"] < f20["input"]["now"]
          == f20["input"]["envelope"]["timestamp"] and f20["expected"]["error_code"] == "IDENTITY_FAILED")
    f21 = load(CONF / "id-021-pinned-admission-nonce-other-verifier-rejected.json")
    ok, n = presentation(f21, f21["input"]["envelope"], 16)
    ch = f21["input"]["outstanding_challenges"][0]
    check("id-021: proof re-signs with receiver self_aid; the challenge names kat-keypair-002 as verifier_aid",
          ok and n == 193 and ch["pop_nonce"] == f21["input"]["envelope"]["payload"]["pop_nonce"]
          and ch["verifier_aid"] == keypairs["kat-keypair-002"]["aid"] != f21["input"]["self_aid"]
          and f21["expected"]["error_code"] == "IDENTITY_FAILED")
    f22 = load(CONF / "id-022-pinned-admission-replay-before-rate-limit.json")
    q = f22["input"]["sequence"]
    oks = [presentation(f22, st["envelope"], 16)[0] for st in q]
    check("id-022: steps reuse id-019 / id-013 step 2 envelopes with re-signed proofs; deny list answers before the rate limit",
          all(oks) and q[0]["envelope"] == q[1]["envelope"] == f19["input"]["envelope"]
          and q[2]["envelope"] == q[3]["envelope"] == s2["envelope"]
          and q[0]["source"] == q[1]["source"] == q[2]["source"] != q[3]["source"]
          and f22["input"]["presentation_rate_limit"]["per_source"] == 1
          and [st["expected"].get("error_code") for st in q] == [None, "REPLAY_DETECTED", None, "IDENTITY_FAILED"]
          and q[2]["expected"].get("http_status") == 429)
    gated = [load(x) for x in sorted(CONF.glob("id-*.json"))]
    gated = [x for x in gated if x["input"].get("operation") == "verify_identity_presentation"
             or any("presentation" in st.get("operation", "") for st in x["input"].get("sequence", []))]
    check("pinned-admission fixtures: exactly eight, all status extension under feature aitp-pinned-admission",
          sorted(x["id"] for x in gated) == ["id-013", "id-014", "id-015", "id-016", "id-019", "id-020", "id-021", "id-022"]
          and all(x["status"] == "extension" and x["feature"] == "aitp-pinned-admission"
                  and x["required_for_v0_1"] is False and x["required_for_core"] is False for x in gated))

    section("── self-attestation fixtures (RFC-AITP-0005 §5.3) ──")
    f20t = load(CONF / "tct-020-self-attestation-verifies-as-attestation.json")
    kat2 = load(SIGNED / "tct" / "kat-keypair-001-self-attestation.json")
    h64, p64, s64 = f20t["input"]["tct_token"].split(".")
    check("tct-020: carries kat-tct-002 verbatim; EdDSA signature verifies strictly under the iss key",
          f20t["input"]["tct_token"] == kat2["tct_token"]
          and ed_verify_strict(A1, f"{h64}.{p64}".encode(), b64d(s64))
          and json.loads(b64d(p64)) == f20t["input"]["tct_token_claims"] == kat2["decoded_claims"])
    c20 = f20t["input"]["tct_token_claims"]
    check("tct-020: third-party relying party (self_aid != aud), verify_attestation, expected ext key present, success",
          f20t["input"]["operation"] == "verify_attestation" and f20t["input"]["self_aid"] != c20["aud"]
          and c20["iss"] == c20["sub"] == c20["aud"] and f20t["input"]["expected_ext_key"] in c20["ext"]
          and f20t["expected"]["outcome"] == "success" and f20t["feature"] == "aitp-self-attestation")
    f19t = load(CONF / "tct-019-attestation-missing-ext-key-rejected.json")
    c19 = f19t["input"]["tct_token_claims"]
    check("tct-019: attestation shape valid, ext lacks the expected key; TCT_SIGNATURE_INVALID",
          c19["iss"] == c19["sub"] == c19["aud"] == k1["aid"] and c19["grants"] == ["aitp.attestation"]
          and c19["cnf"]["jkt"] == c20["cnf"]["jkt"] and c19["ext"] and f19t["input"]["expected_ext_key"] not in c19["ext"]
          and f19t["expected"]["error_code"] == "TCT_SIGNATURE_INVALID" and f19t["status"] == "extension")
    f21t = load(CONF / "tct-021-attestation-issuer-not-trusted-at-iat-rejected.json")
    c21 = f21t["input"]["tct_token_claims"]
    h64, p64, s64 = f21t["input"]["tct_token"].split(".")
    rest = lambda f: {k: v for k, v in f["input"].items() if k != "trust_store"}
    check("tct-021: carries kat-tct-002 verbatim; signature verifies; only trust_store differs from tct-020, and it lacks the issuer; TCT_SIGNATURE_INVALID",
          f21t["input"]["tct_token"] == kat2["tct_token"]
          and ed_verify_strict(A1, f"{h64}.{p64}".encode(), b64d(s64))
          and json.loads(b64d(p64)) == c21 == kat2["decoded_claims"]
          and rest(f21t) == rest(f20t) and f21t["input"]["trust_store"]
          and c21["iss"] not in f21t["input"]["trust_store"] and c21["iss"] in f20t["input"]["trust_store"]
          and f21t["expected"]["outcome"] == "failure" and f21t["expected"]["error_code"] == "TCT_SIGNATURE_INVALID"
          and f21t["status"] == "extension" and f21t["feature"] == "aitp-self-attestation")
    f18t = load(CONF / "tct-018-attestation-marker-beside-grant-rejected.json")
    c18 = f18t["input"]["tct_token_claims"]
    check("tct-018: marker beside and after an ordinary grant, iss != sub, verify_tct, core; TCT_SIGNATURE_INVALID",
          "aitp.attestation" in c18["grants"][1:] and c18["iss"] != c18["sub"] and c18["aud"] == f18t["input"]["expected_audience"]
          and f18t["input"]["operation"] == "verify_tct" and f18t["status"] == "core"
          and f18t["expected"]["error_code"] == "TCT_SIGNATURE_INVALID")

    section("── tct-017 ──")
    f = load(CONF / "tct-017-es256-high-s-rejected.json")
    h64, p64, s64 = f["input"]["tct_token"].split(".")
    si = f"{h64}.{p64}".encode()
    raw = b64d(s64)
    r, s = sigdecode_string(raw, N)
    check("tct-017 payload == tct_token_claims", json.loads(b64d(p64)) == f["input"]["tct_token_claims"])
    check("tct-017 issuer is kat-keypair-005-p256", json.loads(b64d(p64))["iss"] == aid5)
    check("tct-017 token is high-S", s > N // 2)
    check("tct-017 lax ES256 accepts", p256_verify_lax(vk, H(si), raw))
    check("tct-017 strict rejects", not p256_verify_strict(vk, H(si), raw))
    check("tct-017 low-S twin is the RFC 6979 signature", p256_sign(sk, H(si)) == r.to_bytes(32, "big") + (N - s).to_bytes(32, "big"))

    section("── id-023: OIDC cnf.jkt for a P-256 AID (issue #68) ──")
    f23 = load(CONF / "id-023-oidc-p256-cnf-jkt-success.json")
    env23 = f23["input"]["envelope"]
    s23 = env23["sender"]["agent_id"]
    pt23 = p256_vk_from_aid(s23).pubkey.point
    jwk23 = {"crv": "P-256", "kty": "EC",
             "x": b64e(int(pt23.x()).to_bytes(32, "big")), "y": b64e(int(pt23.y()).to_bytes(32, "big"))}
    t5 = next(v for v in load(KAT / "jwk-thumbprints.json")["vectors"] if v["id"] == "kat-jwk-thumb-005-p256")
    check("id-023: sender == manifest.aid == kat-keypair-005-p256, oidc __VALID_JWT__, success",
          s23 == env23["payload"]["manifest"]["aid"] == aid5
          and env23["payload"]["identity"]["type"] == "oidc"
          and env23["payload"]["identity"]["proof"] == "__VALID_JWT__"
          and f23["expected"]["outcome"] == "success")
    check("id-023: EC JWK from the decompressed AID point is kat-jwk-thumb-005-p256",
          jcs(jwk23).decode() == t5["jwk_canonical"] and jwk_thumbprint(jwk23) == t5["jkt"])
    check("id-023: the OKP-shaped JWK of the same identifier gives a different jkt",
          jwk_thumbprint({"crv": "Ed25519", "kty": "OKP", "x": s23.removeprefix("aid:pubkey:p256:")}) != t5["jkt"])

    section("── Ed25519 vectors and signed examples (re-minted for the aitp/0.3 revision) ──")
    # Every Ed25519 value scripts/regen-known-answer.py or the aitp/0.3 re-mint
    # produced is re-derived here with the RFC 8032 arithmetic above, so each
    # pinned value is checked by a second stack and not only by its generator.
    seeds = {}
    for k in keypairs.values():
        if "seed_hex" in k:
            seeds[k["aid"]] = bytes.fromhex(k["seed_hex"])

    def ed_resign(name: str, signer: str, msg: bytes, sig_b64: str) -> None:
        sig = b64d(sig_b64)
        check(f"{name}: Ed25519 signature re-signs byte for byte", signer in seeds and ed_sign(seeds[signer], msg) == sig)
        check(f"{name}: Ed25519 signature verifies strictly", signer in seeds and ed_verify_strict(ed_public(seeds[signer]), msg, sig))

    for vid in ("kat-manifest-001", "kat-revocation-001", "kat-session-bundle-001"):
        v = jcsv[vid]
        c = jcs(v["object"])
        check(f"{vid}: version is {AITP_VERSION}", v["object"]["version"] == AITP_VERSION)
        check(f"{vid}: canonical bytes, length and sha256 recompute",
              c.hex() == v["jcs_canonical_hex"] and len(c) == v["jcs_canonical_len_bytes"]
              and H(c).hex() == v["sha256_hex"] and b64e(H(c)) == v["sha256_b64url"])
        if "coordinator_signature_b64url" in v:
            ed_resign(f"{vid} coordinator signature", v["object"]["coordinator"], H(c), v["coordinator_signature_b64url"])

    f = load(SIGNED / "manifest" / "kat-keypair-001-manifest.json")
    check(f"kat-keypair-001 manifest: version is {AITP_VERSION}", f["manifest"]["version"] == AITP_VERSION)
    ed_resign("kat-keypair-001 manifest", f["manifest"]["aid"], H(jcs(strip(f["manifest"]))), f["manifest"]["signature"])
    f = load(SIGNED / "revocation" / "kat-keypair-001-snapshot.json")
    check(f"kat-keypair-001 snapshot: version is {AITP_VERSION}", f["revocation_list"]["version"] == AITP_VERSION)
    ed_resign("kat-keypair-001 snapshot", f["revocation_list"]["issuer"], H(jcs(f["revocation_list"])), f["signature"])
    f = load(SIGNED / "session-bundle" / "kat-keypair-001-bundle.json")
    check("kat-keypair-001 bundle body is kat-session-bundle-001's object, same signature",
          strip(f["session_bundle"]) == jcsv["kat-session-bundle-001"]["object"]
          and f["session_bundle"]["signature"] == jcsv["kat-session-bundle-001"]["coordinator_signature_b64url"])

    def ed_jws(name: str, token: str, typ: str, decoded=None) -> dict:
        h64, p64, s64 = token.split(".")
        claims = json.loads(b64d(p64))
        check(f"{name}: header is exactly {{alg: EdDSA, typ: {typ}}}", b64d(h64) == jcs({"alg": "EdDSA", "typ": typ}))
        check(f"{name}: payload is the JCS form of its claims", b64d(p64) == jcs(claims))
        check(f"{name}: ver is {AITP_VERSION}", claims.get("ver") == AITP_VERSION)
        if decoded is not None:
            check(f"{name}: decoded_claims equal the payload", decoded == claims)
        ed_resign(name, claims["iss"], f"{h64}.{p64}".encode(), s64)
        return claims

    f = load(SIGNED / "tct" / "kat-keypair-001-issues-002.json")
    ed_jws("kat-keypair-001-issues-002 TCT", f["tct_token"], "aitp-tct+jwt", f["decoded_claims"])
    f = load(SIGNED / "grant-voucher" / "kat-voucher-001.json")
    voucher = f["voucher_token"]
    ed_jws("kat-voucher-001", voucher, "aitp-grant+jwt", f["decoded_claims"])
    f = load(SIGNED / "delegation" / "single-hop-001-002-003.json")
    single = ed_jws("single-hop delegation", f["delegation_token"], "aitp-delegation+jwt", f["decoded_claims"])
    check("single-hop delegation embeds kat-voucher-001 verbatim", single["voucher"] == voucher)
    for tok in jcsv["kat-session-bundle-001"]["object"]["participants"]:
        if "tct" in tok:
            ed_jws(f"kat-session-bundle-001 participant {tok.get('aid', '?')[:24]} TCT", tok["tct"], "aitp-tct+jwt")

    v = jcsv["kat-multihop-chain-001"]
    ed_jws("kat-multihop-chain-001 voucher_jws", v["voucher_jws"], "aitp-grant+jwt")
    for i, entry in enumerate(v["chain"]):
        ed_jws(f"kat-multihop-chain-001 chain[{i}]", entry, "aitp-delegation+jwt")
    digests = [b64e(H(e.encode())) for e in v["chain"]]
    check("kat-multihop-chain-001: per-entry digests, digest array JCS and chain_hash recompute",
          digests == v["chain_entry_sha256_b64url"] and jcs(digests).decode() == v["digest_array_jcs"]
          and b64e(H(jcs(digests))) == v["chain_hash"])
    outer = ed_jws("kat-multihop-chain-001 outer_delegation_jws", v["outer_delegation_jws"], "aitp-delegation+jwt")
    check("kat-multihop-chain-001: outer token carries the chain and chain_hash",
          outer.get("chain") == v["chain"] and outer.get("chain_hash") == v["chain_hash"])
    t = jcsv["kat-multihop-truncation-001"]
    check("kat-multihop-truncation-001: chain_hash_full is chain-001's chain_hash; truncated hash recomputes",
          t["chain_hash_full"] == v["chain_hash"] and b64e(H(jcs([]))) == t["chain_hash_truncated"])

    section("── env-011: previous revision rejected (strict cutover) ──")
    f11 = load(CONF / "env-011-previous-revision-rejected.json")
    e11 = f11["input"]["envelope"]
    check("env-011: version is the previous revision aitp/0.2, not the current one",
          e11["version"] == "aitp/0.2" != AITP_VERSION)
    ed_resign("env-011 envelope (pure sig_input_v2 over the aitp/0.2 envelope)", e11["sender"]["agent_id"],
              H(env_v2(e11)), e11["signature"])
    check("env-011: the expected result is UNKNOWN_VERSION",
          f11["expected"]["outcome"] == "failure" and f11["expected"]["error_code"] == "UNKNOWN_VERSION")

    section("── rev-010, bundle-008: committed signature over a version-altered body ──")
    snap = load(SIGNED / "revocation" / "kat-keypair-001-snapshot.json")
    bun = load(SIGNED / "session-bundle" / "kat-keypair-001-bundle.json")
    f10 = load(CONF / "rev-010-version-unknown.json")
    f08 = load(CONF / "bundle-008-version-unknown.json")
    for fx, ex_body, ex_sig, body, sig, signer, code in [
        (f10, snap["revocation_list"], snap["signature"],
         f10["input"]["snapshot"]["revocation_list"], f10["input"]["snapshot"]["signature"],
         snap["revocation_list"]["issuer"], "REVOCATION_SNAPSHOT_INVALID"),
        (f08, strip(bun["session_bundle"]), bun["session_bundle"]["signature"],
         strip(f08["input"]["session_bundle"]["session_bundle"]), f08["input"]["session_bundle"]["session_bundle"]["signature"],
         bun["session_bundle"]["coordinator"], "BUNDLE_VERSION_MISMATCH"),
    ]:
        changed = sorted(k for k in set(body) | set(ex_body) if body.get(k) != ex_body.get(k))
        A = ed_public(seeds[signer])
        sg = b64d(sig)
        check(f"{fx['id']}: only version differs from the signed example (aitp/9.9); same signature; expects {code}",
              changed == ["version"] and body["version"] == "aitp/9.9" and sig == ex_sig
              and fx["expected"]["outcome"] == "failure" and fx["expected"]["error_code"] == code)
        check(f"{fx['id']}: signature verifies over the signed example body",
              ed_verify_strict(A, H(jcs(ex_body)), sg))
        check(f"{fx['id']}: signature does NOT verify over the fixture body (strict or lax)",
              not ed_verify_strict(A, H(jcs(body)), sg) and not ed_verify_lax(A, H(jcs(body)), sg))
    check("bundle-008: coordinator_manifest is the committed kat-keypair-001 Manifest",
          f08["input"]["coordinator_manifest"] == load(SIGNED / "manifest" / "kat-keypair-001-manifest.json")["manifest"])

    section("── tct-022, tct-023: committed TCT, committed snapshot with a flipped signature bit (RFC-AITP-0008 §1.5) ──")
    tct_ex = load(SIGNED / "tct" / "kat-keypair-001-issues-002.json")
    snap = load(SIGNED / "revocation" / "kat-keypair-001-snapshot.json")
    flipped = bytearray(b64d(snap["signature"]))
    flipped[-1] ^= 1
    h64, p64, s64 = tct_ex["tct_token"].split(".")
    claims = json.loads(b64d(p64))
    issuer_pub = ed_public(seeds[claims["iss"]])
    check("kat-keypair-001-issues-002 TCT verifies strictly under its iss",
          ed_verify_strict(issuer_pub, f"{h64}.{p64}".encode(), b64d(s64)))
    check("kat-keypair-001 snapshot: committed signature verifies strictly",
          ed_verify_strict(issuer_pub, H(jcs(snap["revocation_list"])), b64d(snap["signature"])))
    pair = {}
    for fid, name, mode, outcome, code in [
        ("tct-022", "tct-022-invalid-snapshot-fail-closed.json", "fail_closed", "failure", "TCT_REVOKED"),
        ("tct-023", "tct-023-invalid-snapshot-fail-open.json", "fail_open", "success", None),
    ]:
        fx = load(CONF / name)
        pair[fid] = fx
        inp = fx["input"]
        irl = inp["issuer_revocation_list"]
        body, sig = irl["snapshot"]["revocation_list"], irl["snapshot"]["signature"]
        check(f"{fid}: token and claims are the committed signed example; audience is its aud",
              inp["operation"] == "verify_tct" and inp["tct_token"] == tct_ex["tct_token"]
              and inp["tct_token_claims"] == claims and inp["expected_audience"] == claims["aud"])
        check(f"{fid}: snapshot body is the committed one, issued by the TCT issuer; jti not listed",
              body == snap["revocation_list"] and irl["issuer"] == claims["iss"] == body["issuer"]
              and all(e["jti"] != claims["jti"] for e in body["entries"])
              and sorted(irl["snapshot"]) == ["revocation_list", "signature"])
        check(f"{fid}: signature is the committed one with the LSB of the last raw byte flipped",
              b64d(sig) == bytes(flipped) and b64e(bytes(flipped)) == sig)
        check(f"{fid}: signature does NOT verify over the body (strict or lax)",
              not ed_verify_strict(issuer_pub, H(jcs(body)), b64d(sig)) and not ed_verify_lax(issuer_pub, H(jcs(body)), b64d(sig)))
        check(f"{fid}: fail_mode {mode} expects {code or outcome}",
              irl["fail_mode"] == mode and fx["expected"]["outcome"] == outcome and fx["expected"].get("error_code") == code)

    def without_mode(fx):
        d = json.loads(json.dumps(fx["input"]))
        del d["issuer_revocation_list"]["fail_mode"]
        return d
    check("tct-022 and tct-023 inputs differ only in fail_mode",
          without_mode(pair["tct-022"]) == without_mode(pair["tct-023"]))

    section("── tct-024, tct-025: committed TCT, no revocation source for its issuer (RFC-AITP-0008 §1.4, §3.1) ──")
    for fid, name, mode, outcome, code in [
        ("tct-024", "tct-024-no-revocation-source-default-fail-closed.json", None, "failure", "TCT_REVOKED"),
        ("tct-025", "tct-025-no-revocation-source-explicit-fail-open.json", "fail_open", "success", None),
    ]:
        fx = load(CONF / name)
        pair[fid] = fx
        inp = fx["input"]
        irl = inp["issuer_revocation_list"]
        check(f"{fid}: core fixture; token and claims are the committed signed example; audience is its aud",
              fx["status"] == "core" and fx["required_for_core"] is True
              and inp["operation"] == "verify_tct" and inp["tct_token"] == tct_ex["tct_token"]
              and inp["tct_token_claims"] == claims and inp["expected_audience"] == claims["aud"])
        check(f"{fid}: issuer_revocation_list names the TCT issuer, is unavailable and carries no snapshot",
              irl["issuer"] == claims["iss"] and irl["available"] is False
              and sorted(irl) == sorted(["issuer", "available"] + (["fail_mode"] if mode else [])))
        check(f"{fid}: fail_mode {mode or '(absent: schema default fail_closed)'} expects {code or outcome}",
              irl.get("fail_mode") == mode and fx["expected"]["outcome"] == outcome and fx["expected"].get("error_code") == code)
    check("tct-024 and tct-025 inputs differ only in fail_mode",
          without_mode(pair["tct-025"]) == pair["tct-024"]["input"])

    section("── rev-011: committed TCT, committed snapshot signed by a different issuer (RFC-AITP-0008 §1.5) ──")
    fx = load(CONF / "rev-011-third-party-signed-list-discarded.json")
    snap5 = load(SIGNED / "revocation" / "kat-keypair-005-snapshot.json")
    inp = fx["input"]
    irl = inp["issuer_revocation_list"]
    body, sig = irl["snapshot"]["revocation_list"], irl["snapshot"]["signature"]
    check("rev-011: core fixture; token and claims are the committed signed example; audience is its aud",
          fx["status"] == "core" and fx["required_for_core"] is True
          and inp["operation"] == "verify_tct" and inp["tct_token"] == tct_ex["tct_token"]
          and inp["tct_token_claims"] == claims and inp["expected_audience"] == claims["aud"])
    check("rev-011: snapshot is the committed kat-keypair-005-p256 one, unmodified",
          body == snap5["revocation_list"] and sig == snap5["signature"]
          and sorted(irl["snapshot"]) == ["revocation_list", "signature"])
    check("rev-011: snapshot signature verifies under its own issuer kat-keypair-005-p256",
          body["issuer"] == aid5
          and p256_verify_strict(p256_vk_from_aid(body["issuer"]), H(jcs(body)), untag(sig, "p256")))
    check("rev-011: the list was obtained for the TCT issuer, but its signer is not the TCT issuer",
          irl["issuer"] == claims["iss"] and body["issuer"] != claims["iss"])
    check("rev-011: the TCT jti is not listed",
          all(e["jti"] != claims["jti"] for e in body["entries"]))
    check("rev-011: fail_closed expects TCT_REVOKED",
          sorted(irl) == ["fail_mode", "issuer", "snapshot"] and irl["fail_mode"] == "fail_closed"
          and fx["expected"]["outcome"] == "failure" and fx["expected"].get("error_code") == "TCT_REVOKED")

    if checks < EXPECTED_MIN_CHECKS:
        failures += 1
        print(f"  FAIL coverage: ran {checks} checks, expected at least {EXPECTED_MIN_CHECKS}")
    if not QUIET:
        print()
    if failures:
        print(f"✗ {failures} of {checks} independent checks FAILED")
        return 1
    print(f"✓ All {checks} independent checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
