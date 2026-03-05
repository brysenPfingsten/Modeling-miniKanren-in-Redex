# Test Lanes

This directory has multiple intentional lanes. Keep them separate so failures are easier to triage.

## Lane A: Headless (default)

Runs deterministic/unit/property checks that do not require GUI interaction.

```sh
raco test racket-server/tests/test-all-headless.rkt
```

Includes:
- Core property/judgment checks
- Variant lattice + randomized variant checks
- Frontend example compatibility gate (surface programs must parse/lift into `L4` syntax)

## Lane B: App/API Regression

Runs the app-level test suite used for server behavior regression checks.

```sh
raco test racket-server/tests/test-all.rkt
```

## Lane C: Frontend Compatibility-Gating Logic

Runs pure frontend logic tests for compatibility analysis status + Start-button gating behavior.

```sh
npm --prefix frontend test
```

## Notes

- Deprecated legacy suites are archived under `racket-server/tests/archive/legacy-deprecated/`.
- Supported lanes are only the three listed above.
