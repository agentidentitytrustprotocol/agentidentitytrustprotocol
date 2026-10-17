#!/usr/bin/env python3
"""Independently recompute the P-256 and signature-strictness known answers.

Maintainer tool, not part of `make validate`. It needs `python-ecdsa`
(`pip install ecdsa`), which CI does not install; `scripts/verify-known-answer.mjs`
is what CI runs, and it depends on nothing beyond Node's standard library.

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

Usage:
    python3 scripts/recompute-known-answer-independent.py

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
    sys.exit("python-ecdsa is required: pip install ecdsa")

REPO = Path(__file__).resolve().parent.parent
CONF = REPO / "schemas" / "conformance"
KAT = CONF / "known-answer"
SIGNED = KAT / "signed-examples"

failures = 0
checks = 0


def check(name: str, cond: bool) -> None:
    global failures, checks
    checks += 1
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
    keypairs = {k["id"]: k for k in load(KAT / "keypairs.json")["vectors"]}
    jcsv = {v["id"]: v for v in load(KAT / "jcs-sha256.json")["vectors"]}
    strict = {v["id"]: v for v in load(KAT / "signature-strictness.json")["vectors"]}

    print("── keypairs ──")
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

    print("── jcs-sha256.json P-256 vectors ──")
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

    print("── jcs-sha256.json pinned-key proofs (RFC-AITP-0002 §3.1) ──")
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

    print("── pinned-key fixtures: each proof against its own tuple ──")
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

    print("── signature-strictness.json ──")
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

    print("── signed examples (P-256) ──")
    f = load(SIGNED / "envelope" / "kat-keypair-005-envelope.json")
    env = f["envelope"]
    sig_input = f"{env['message_id']}|{env['timestamp']}|{env['sender']['agent_id']}|{H(jcs(env['payload'])).hex()}"
    check("envelope sig_input", sig_input == f["sig_input"] and H(sig_input.encode()).hex() == f["sig_input_sha256_hex"])
    check("envelope signer", env["sender"]["agent_id"] == aid5)
    p256_signature("envelope", sk, vk, sig_input.encode(), env["signature"], f["_must_not_verify"]["double_hash_signature"])
    fixture = load(CONF / "env-005-p256-envelope-success.json")["input"]["envelope"]
    strip = lambda o: {k: x for k, x in o.items() if k != "signature"}
    check("envelope equals env-005 input apart from signature", jcs(strip(env)) == jcs(strip(fixture)))

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

    print("── self-attestation TCTs (RFC-AITP-0005 §5.3), re-minted from their inputs ──")
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
        claims = {"ver": "aitp/0.2", "jti": jti, "iss": aid, "sub": aid, "aud": aid,
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

    print("── pinned-admission fixtures (RFC-AITP-0002 §3.4): proofs re-signed ──")
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
                  and x["required_for_v0_1"] is False and x["required_for_v0_2"] is False for x in gated))

    print("── self-attestation fixtures (RFC-AITP-0005 §5.3) ──")
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
    f18t = load(CONF / "tct-018-attestation-marker-beside-grant-rejected.json")
    c18 = f18t["input"]["tct_token_claims"]
    check("tct-018: marker beside and after an ordinary grant, iss != sub, verify_tct, core; TCT_SIGNATURE_INVALID",
          "aitp.attestation" in c18["grants"][1:] and c18["iss"] != c18["sub"] and c18["aud"] == f18t["input"]["expected_audience"]
          and f18t["input"]["operation"] == "verify_tct" and f18t["status"] == "core"
          and f18t["expected"]["error_code"] == "TCT_SIGNATURE_INVALID")

    print("── tct-017 ──")
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

    print()
    if failures:
        print(f"✗ {failures} of {checks} independent checks FAILED")
        return 1
    print(f"✓ All {checks} independent checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
