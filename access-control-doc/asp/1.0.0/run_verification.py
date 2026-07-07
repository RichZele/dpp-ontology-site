#!/usr/bin/env python3
"""Run the dpp-ac ASP verification layer and report results.

Drives clingo (Potassco) over dpp-ac-verification.lp, which is a faithful
bounded abstraction of the SPARQL R01-R10 decision pipeline. Reports the
four verification properties and the six-scenario faithfulness cross-check.

Usage:  python run_verification.py
Requires:  pip install clingo
"""
import sys
from pathlib import Path
from collections import defaultdict

import clingo

HERE = Path(__file__).resolve().parent
PROGRAM = HERE / "dpp-ac-verification.lp"

EXPECTED_SCENARIOS = {
    "s1": "grant", "s2": "grant", "s3": "deny",
    "s4": "grant", "s5": "deny", "s6": "grant",
}


def solve():
    ctl = clingo.Control(["--models=0"])
    ctl.load(str(PROGRAM))
    ctl.ground([("base", [])])
    atoms = {}
    with ctl.solve(yield_=True) as handle:
        models = list(handle)
        if not models:
            print("UNSATISFIABLE — no stable model. Check the program.", file=sys.stderr)
            sys.exit(2)
        # deterministic program: exactly one stable model
        model = models[-1]
        buckets = defaultdict(list)
        for sym in model.symbols(shown=True):
            buckets[sym.name].append(sym)
        return buckets


def s(sym, i):
    return str(sym.arguments[i]).strip('"')


def main():
    b = solve()

    surface = defaultdict(dict)          # (role, action) -> {cat: outcome}
    for a in b.get("surface", []):
        role, act, cat, out = (s(a, 0), s(a, 1), s(a, 2), s(a, 3))
        surface[(role, act)][cat] = out

    conflicts = [(s(a, 0), s(a, 1), s(a, 2)) for a in b.get("conflict", [])]
    uncovered = sorted(s(a, 0) for a in b.get("role_uncovered", []))
    multi = list(b.get("multi_outcome", []))
    undecided = list(b.get("undecided", []))
    decisions = {s(a, 0): s(a, 1) for a in b.get("decision", [])}
    mismatches = [s(a, 0) for a in b.get("scenario_mismatch", [])]
    gcount = int(str(b["grant_count"][0].arguments[0])) if b.get("grant_count") else 0
    dcount = int(str(b["deny_count"][0].arguments[0])) if b.get("deny_count") else 0

    line = "=" * 66
    print(line)
    print("dpp-ac ASP VERIFICATION REPORT")
    print(line)

    # Property 1 — conflict-freeness
    print("\n[P1] CONFLICT-FREENESS (permission vs prohibition overlap)")
    if not conflicts:
        print("     PASS -- 0 conflicts; deny-overrides (R08) is never triggered.")
    else:
        print(f"     {len(conflicts)} conflict(s) found:")
        for r, a, c in conflicts:
            print(f"       - role={r} action={a} category={c}")

    # Property 2 — determinism / totality
    print("\n[P2] DECISION DETERMINISM & TOTALITY")
    det = "PASS" if not multi else "FAIL"
    tot = "PASS" if not undecided else "FAIL"
    print(f"     Determinism: {det} ({len(multi)} multi-outcome cells)")
    print(f"     Totality:    {tot} ({len(undecided)} undecided cells)")

    # Property 3 — coverage
    print("\n[P3] ROLE / POLICY COVERAGE")
    print(f"     Uncovered role classes ({len(uncovered)}): {', '.join(uncovered)}")
    print("     (expected: the 4 abstract classes economic_operator,")
    print("      regulatory_authority, service_provider, auth_rep)")

    # Property 4 — exhaustive grant enumeration (decision surface)
    print("\n[P4] EXHAUSTIVE DECISION SURFACE (role x action x Tier-1 category)")
    cats = ["product_id", "env_perf", "material", "supply_chain",
            "certification", "use_maint", "end_of_life"]
    sym = {"grant": "G", "conditional": "C", "deny": "."}
    roles = ["manufacturer", "importer", "distributor", "msa", "customs",
             "maintenance_tech", "recycler", "consumer"]
    header = "     " + f"{'role/action':22}" + " ".join(f"{c[:5]:>5}" for c in cats)
    print(header)
    total = grants = conds = denies = 0
    for role in roles:
        for act in ["read", "update", "delete"]:
            row = surface.get((role, act))
            if not row:
                continue
            cells = []
            for c in cats:
                o = row.get(c, "deny")
                cells.append(f"{sym[o]:>5}")
                total += 1
                grants += o == "grant"
                conds += o == "conditional"
                denies += o == "deny"
            print(f"     {role + '/' + act:22}" + " ".join(cells))
    print(f"\n     legend: G=grant  C=conditional(ABAC/PBAC-gated)  .=deny")
    print(f"     {total} decisions enumerated: "
          f"{grants} grant, {conds} conditional, {denies} deny")

    # Faithfulness gate — six scenarios
    print("\n" + line)
    print("FAITHFULNESS GATE -- six built-environment scenarios vs runtime pipeline")
    print(line)
    for q in ["s1", "s2", "s3", "s4", "s5", "s6"]:
        got = decisions.get(q, "?")
        exp = EXPECTED_SCENARIOS[q]
        ok = "OK " if got == exp else "XXX"
        print(f"     {q.upper()}  expected={exp:6} got={got:6} [{ok}]")
    print(f"\n     aggregate: {gcount} GRANT / {dcount} DENY "
          f"(runtime pipeline: 4 GRANT / 2 DENY)")

    if mismatches:
        print(f"\n     RESULT: FAITHFULNESS FAILED — mismatches: {mismatches}")
        sys.exit(1)
    print("\n     RESULT: PASS -- ASP layer reproduces all six runtime outcomes.")
    print(line)


if __name__ == "__main__":
    main()
