#!/usr/bin/env python3
"""Goal-ranking oracle for the AITP Tamarin theories.

Tamarin calls this once per proof step with the lemma name as argv[1] and
the open goals on stdin, one per line as "N: goal". It prints the goal
indices, best first.

Executability lemmas (exec_*) use rank_exec. All other lemmas:
  0  the lemma's own actions, and the !IdP / !Ltk / !Enrolled facts that
     bind the IdP key and honest keys (an unbound IdP key leaves "the
     adversary forged the ID token" open for a long time)
  1  knowledge of a long-term or IdP key (a no-Reveal premise refutes it)
  2  envelope signatures (they pin the sender's rule instance)
  3  other signatures (ID tokens, TCTs, vouchers, delegation tokens, PoP)
  5  anything else
  7  St_ state facts of earlier protocol steps
  8  knowledge of fresh values (nonces, jtis)
  9  knowledge of public keys and thumbprints, which are public anyway:
     solving them early branches over every message that carries a key
"""
import re
import sys

# Knowledge of a bare message variable: any message the adversary knows is a
# source, so it is solved last, once other goals have instantiated it.
VAR = re.compile(r"^!KU\( [a-zA-Z][\w.]* \)")

ACTIONS = re.compile(
    r"^(Accept|Seen|PoPAccept|HSPoPAccept|DSPoPAccept|RenPoPAccept|R_Hello|"
    r"R_Commit|I_Commit|I_Start|RS_Accept|RS_Challenge|RenewAccept|"
    r"DelegAccept|DelegChallenge)\(")


def rank_exec(goal):
    """Executability lemmas: walk the honest run back from its last step,
    state facts first, and leave adversary knowledge for last."""
    if VAR.match(goal):
        return 10
    if ACTIONS.match(goal) or re.match(r"!?(St_\w+|Ltk|Enrolled|IdP|Manifest|Held|Voucher|Sub)\(", goal):
        return 0
    if re.match(r"!KU\( ~(ltk|skI)", goal):
        return 0
    if goal.startswith("!KU( sign(<'aitp-envelope-v2'"):
        return 1
    if goal.startswith("!KU( sign("):
        return 2
    if re.match(r"!KU\( (pk|jkt)\(", goal):
        return 9
    return 5


def rank(goal, lemma=""):
    if VAR.match(goal):
        return 10
    if ACTIONS.match(goal) or re.match(r"!?(IdP|Ltk|Enrolled|St_)", goal):
        return 0
    if lemma.startswith("P2") and goal.startswith("!KU( sign(h("):
        return 1
    if lemma.startswith("P3_tct") and goal.startswith("!KU( sign(<'aitp-tct+jwt'"):
        return 1
    if lemma.startswith("P5_scope") and goal.startswith("!KU( sign(<'aitp-grant+jwt'"):
        return 1
    if lemma.startswith("P5_delegator") and goal.startswith("!KU( sign(<'aitp-delegation+jwt'"):
        return 1
    if re.match(r"!KU\( ~(ltk|skI)", goal):
        return 1
    if goal.startswith("!KU( sign(<'aitp-envelope-v2'"):
        return 2
    if goal.startswith("!KU( sign("):
        return 3
    if re.match(r"!KU\( (pk|jkt)\(", goal):
        return 9
    if goal.startswith("!KU( ~"):
        return 8
    return 5


def main():
    goals = []
    for line in sys.stdin.read().splitlines():
        m = re.match(r"^(\d+):\s*(.*)$", line)
        if m:
            goals.append((m.group(1), m.group(2)))
    lemma = sys.argv[1] if len(sys.argv) > 1 else ""
    if lemma.startswith("exec"):
        key = lambda i: (rank_exec(goals[i][1]), i)
    else:
        key = lambda i: (rank(goals[i][1], lemma), i)
    ranked = sorted(range(len(goals)), key=key)
    print("\n".join(goals[i][0] for i in ranked))


if __name__ == "__main__":
    main()
