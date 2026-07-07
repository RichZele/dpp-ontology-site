# dpp-ac — Answer Set Programming verification layer

Design-time formal verification of the `dpp-ac` access-control policy set. The
encoding is a **faithful bounded abstraction** of the runtime SPARQL decision
pipeline (rules R01 to R10 over the OWL 2 DL and SHACL model), used to check
properties that per-request evaluation cannot establish exhaustively.

## Files

| File | Purpose |
|------|---------|
| `dpp-ac-verification.lp` | The Answer Set Program (facts + decision rules + verification checks) |
| `run_verification.py` | Driver that runs clingo and prints the report |
| `verification-report.txt` | Saved solver output (the reproducible report) |

## Run it

```bash
pip install clingo
python run_verification.py
```

Requires the Python `clingo` module (Potassco). The program is deterministic, so
it yields a single stable model and the same report on every run.

## What is verified

The encoding mirrors only the decision-relevant rules — the RBAC grant with its
attribute gate (R01), the RBAC prohibition (R02), the ownership and delegation
grants (R06 and R07), and the deny-overrides and closed-world aggregation
(R08 and R09). The temporal and purpose rules (R03 and R04) are provenance
markers that do not gate the decision, and R05 duplicates the gate already in
R01, so all three lie outside the abstraction.

**Faithfulness gate.** The six built-environment scenarios are reproduced
exactly (four grants, two denials), confirming the abstraction matches the
runtime pipeline before any property is asserted.

**Properties** verified over the bounded policy model:

- **P1 Conflict-freeness** — no combination is both permitted and prohibited.
- **P2 Decision determinism and totality** — every combination receives exactly one outcome.
- **P3 Role and policy coverage** — reproduces the SPARQL role-coverage result (four abstract role classes unbound).
- **P4 Exhaustive decision enumeration** — the full role by action by category decision surface.

## Provenance

Facts are transcribed from the canonical artifacts in this repository:
`ontologies/domain/dpp-roles.ttl`, `ontologies/domain/dpp-data-categories.ttl`,
`examples/scenarios/example-policies.ttl`, and
`examples/knowledge-graphs/built-environment-scenario.ttl`. The guarantees hold
over this bounded policy model rather than over arbitrary external data.
