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

## Lane C: Frontend Unit Tests

Runs pure frontend unit tests.

```sh
npm --prefix frontend test
```

## Lane D: Model×Example API-Flow Matrix (automated GUI-proxy)

Runs full surfaced-model/example stepping audit without manual clicking:
- init with selected model (`POST /api/post/init`, payload includes `model`)
- step up to 25 or termination (`GET /api/get/next`)
- assert payload shape each step (`step`, `stepName`, JSON `program`)

Coverage policy:
- Surfaced models only (`L3/L4`): full example matrix.

```sh
raco test racket-server/tests/model-example-matrix-tests.rkt
```

## Notes

- Deprecated legacy suites are archived under `racket-server/tests/archive/legacy-deprecated/`.
- Supported lanes are `A`/`B`/`C`/`D` above.
