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

## Notes

- Legacy/manual test files still exist in-tree for reference, but they are not part of supported test lanes.
