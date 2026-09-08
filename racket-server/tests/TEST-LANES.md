# Test lanes

Run commands from the repository root, using the installed Racket dependencies.
An isolated compiled root avoids mixing cached artifacts from concurrent edits:

```sh
export PLTCOMPILEDROOTS=/private/tmp/full-strict-checks:
```

The trailing colon retains the normal compiled-root fallback. The aggregate
status below records the integration run on 2026-09-07; rerun the affected
gates after subsequent changes.

## Strict source, derivations and representation matrix

```sh
racket -y -l raco -- test racket-server/derivations/strict-search/all.rkt
```

This aggregate includes the selected retained-scope S derivation, the native
S/E/N matrix, full relation-program checks, generated-artifact freshness, and
constructor/dependency contracts. It also retains a work-order witness
comparing strict evaluation with the earlier dormant-branch semantics.
That witness is not an application runtime adequacy check.

Focused gates:

```sh
racket -y -l raco -- test racket-server/derivations/strict-search/retained-scope/all.rkt
racket -y -l raco -- test racket-server/derivations/strict-search/matrix/all.rkt
racket -y -l raco -- test racket-server/derivations/strict-search/matrix/retained-scope-tests.rkt
racket -y -l raco -- test racket-server/derivations/strict-search/matrix/full-tests.rkt
racket -y -l raco -- test racket-server/derivations/strict-search/retained-scope/relation-tests.rkt
racket -y -l raco -- test racket-server/derivations/strict-search/matrix/big/full-tests.rkt
```

| Gate | What it checks |
| --- | --- |
| Retained scope | Direct/CPS/data machines, functional-to-syntactic configuration maps, register decoders, and prescribed compression spans |
| Matrix aggregate | Twelve call-free S/E/N feature cells through R/D/Z/M/B/Big, direct representation maps, generated goals, exact work and allocation scope |
| Retained-scope checkpoint | Independently stated selected/matrix S sources and stages, and the selected functional machine mapped to actual native S/E/N transitions |
| Full source | Three additional relation cells, explicit `(program Γ q)`, native stage/configuration maps, calls, recursion and public boundaries |
| Functional relation extension | Explicit Γ captures and program frames through direct/CPS/data/register/compressed stages; exact connection to native full-language machines |
| Full Big | Independent finite judgments, fixed-point results, source-label traces and direct certificate maps with Γ in recursive premises |
| Strict GUI schedulers | Existing Flip source reused directly; DFS Delay variation; native Railroad orientation with exact single-step maps, full scope witnesses, strict bind and calls |

These checks compare configurations and intermediate Frontiers, not just final
answers. Witnesses cover strict sibling work, eager bind, nested rails,
internal versus public forcing, fresh across Delay, unused introductions,
sparse ancestry and lexical shadowing. Productive recursion is checked only
for bounded prefixes; deliberately unguarded calls must not invent a Delay
or commit a pending candidate.

The [research inventory](../derivations/strict-search/README.md) gives generator
commands and proof obligations. Universal correspondence, domain preservation,
productive streams and further `κ / Q / π` compression remain open. No separate
E/N functional interpreter or register derivation is implied by the matrix.

## Earlier dormant-branch semantics: interpreter derivations and comparison

```sh
raco test racket-server/derivations/scheduler-family/all.rkt
racket racket-server/derivations/scheduler-family/derive.rkt --check
racket racket-server/derivations/scheduler-family/show.rkt
```

The [family guide](../derivations/scheduler-family/README.md) states the exact
domains for these derivations of the earlier dormant-branch semantics.
Direct/CPS/defunctionalized/generated machines agree with their demand source
through structural readback and prescribed 0/1 spans. The
source/native map checks exact configuration transitions on the allocation-free
empty-Owners fragment, and records an ownership-transport counterexample
outside it. Local one-step allocation/kernel fixtures exercise additional
labels without enlarging that full-trace claim. Native Railroad/Flip tests
cover the full grammar, all native rules, active work, fresh and relation calls
under the explicit orientation map. Strict work/commit differences, compiled
divergent loops, and scoped provenance observations remain separate gates.

This research aggregate is included in the headless gate. Its diagnostics
name the earlier dormant-branch semantics explicitly; the current GUI uses the strict
matrix scheduler rows instead.

## Compiler, manual session and application payloads

```sh
racket -y -l raco -- test racket-server/tests/test-transpiler.rkt racket-server/tests/example-compat-tests.rkt
racket -y -l raco -- test racket-server/tests/search-runtime-tests.rkt racket-server/tests/model-example-matrix-tests.rkt
racket -y -l raco -- test racket-server/tests/scheduler-integration-tests.rkt racket-server/tests/search-lattice/all.rkt
racket -y -l raco -- test racket-server/tests/test-app.rkt racket-server/tests/visible-contract-tests.rkt racket-server/tests/search-picture-tests.rkt
racket -y -l raco -- test racket-server/tests/frontier-example-tests.rkt racket-server/tests/confidence-gates-tests.rkt racket-server/tests/runtime-test-support.rkt
racket -y racket-server/tests/ui-payload-smoke.rkt
```

`example-compat-tests` consumes every frontend example and checks both mini and
rendered micro against the full strict grammar, WF and explicit query metadata.
`model-example-matrix-tests` checks all twelve **compiler profiles** on a finite
relation program: 2 conjunction associations × 2 disjunction associations ×
3 delay placements. These are not the matrix's twelve representation/feature
cells. The strict-view sessions must follow the exact named S source edges,
including explicit public advancement, and agree with rendered micro.

The compiler's source-attribution cases check occurrence IDs and emitted spans
across all twelve profiles, including nested `conde`, reassociated conjunction,
repeated identical calls, shadowing, allocation, and explicit versus inserted
Delay. Runtime copies of a definition retain its source identity. The 2026-09-07
repair also compared 168 compiled configurations with their saved pre-change
targets, equal after erasing labels; seven compiler/display/JavaScript-parser
round trips checked literal escaping. These checks concern source attribution,
not a new semantic transformation.

The application gates distinguish paused More from completed Done/Last,
Search candidates from committed answers, and internal force from public
advance. All application sessions retain strict `(program Γ q)` configurations.
The historical source tests initialize their own `(Γ F)` fixtures and select
their native relations directly. The picture projection can also inspect those
earlier terms. The gates check source/state highlighting, exact common/private scope,
back/replay/reset, bounded responsiveness, and the absence of extra kernel work
during status inspection or rendering. The visible-contract entry point remains
part of `scripts/run_ui_smoke.sh`. The payload smoke prints actual full program
configurations, operation labels, statuses and committed counts.

Manual sessions in `src/program-runner.rkt` and the GUI do not enforce a source
`run n` limit. Their status describes the computation. Automatic consumption
is tested separately below. The GUI defaults to the strict scheduler lattice/Railroad and
retains No Interleave and Flip-Flop; its separate Strict Search view sends
`{ "model": "strict" }`. API/library calls default to `(strict-search)`.
An explicit `search-strategy` with scheduler `"dfs"`, `"flip"`, or `"rail"`
instead selects the corresponding strict S matrix scheduler. All selections
share the strict program wrapper. Public `advance` is explicit for each;
`force-delay` is always internal. Railroad retains its native orientation
through rendering and uses a checked erasure map for comparison to Flip.
The earlier dormant-branch semantics aggregate has **111 cases**. The corrected
scheduler integration suite has **7 cases**, covering 36 profile/scheduler
traces, retained scope, exact work/commit order, pending bind, and guarded
and unguarded recursion. Its earlier four-case checkpoint described the
former GUI's dormant-branch sources.

## Automatic consumer and miniKanren library

```sh
racket -y -l raco -- test racket-server/tests/program-runner-tests.rkt racket-server/tests/minikanren-library-tests.rkt
```

The automatic `run-source`/`run-forms` driver belongs to `src/minikanren.rkt`,
alongside run/run* and evaluator/module APIs. Limit handling stops at the first
exposed Delay with enough answers, or at completion. For Strict Search this
must finish the current eager round and commitment. All three strict schedulers
also check that an unguarded operand prevents premature answer commitment
and exhausts the step cap.
Returned answers can be a requested prefix while the saved configuration and
picture retain surplus committed answers. Tests also cover zero limits, finite
completion, step caps, source modes and host-value reification.

## Alternative distributed-source experiment

```sh
racket -y -l raco -- test racket-server/derivations/distributed-search/tests.rkt
```

[distributed-search/](../derivations/distributed-search/README.md) sits beside
`strict-search/` and varies the earlier dormant-branch semantics by distributing
conjunction over choice before machine derivation. Nested rails expose an observable
answer-order difference from the factored source. Its experiment-only raw
seam is local to `reduction-relations/factored-search-base.rkt`.

The older `tests/search-lattice/all.rkt` still references this dedicated suite
at its new path, preserving an existing gate. Relocation does not add a strict
correspondence, GUI selector, matrix cell, or A7/A9 machine integration.
The alternative and its semantic assessment remain separate from the strict
application gates above.

## Frontend and aggregate status

```sh
npm --prefix frontend test
npm --prefix frontend run lint
npm --prefix frontend run build
```

Frontend tests cover runtime-family requests, the three lattice schedulers,
remembered settings, frozen controls, profile requests, source mapping, state
inspection, and both families' visible-node contract. The latest completed
frontend run after the strict scheduler correction passed **56 tests**;
the build passed and lint reported zero errors with three unchanged hook warnings.
Selector behavior does not establish an interpreter correspondence.

`tests/test-all-headless.rkt` now aggregates the maintained compiler, library,
session, API, rendering and payload suites, together with the strict research
aggregate, the 191 scheduler-family cases, all 111 native lattice source cases,
scheduler integration, and runtime/dependency checks. Native source tests do
not count as an interpreter correspondence proof. The current headless entry point is:

```sh
racket -y -l raco -- test racket-server/tests/test-all-headless.rkt
```

The strict scheduler correction passed **3,721 tests** in the combined
headless gate, including all **208 HEADLESS cases**, with zero failures or
errors. Strict derivation and historical source checks are included in that
total, not additive. HEADLESS raises on nonzero failures rather than silently
succeeding. The preceding consolidation checkpoints recorded 3,502 and
3,693 tests before this correction.

Current API/payload and picture checks pass. Fresh native servers on loopback
ports 5101/5174 passed the browser check for all three strict schedulers and
the reference view: eager work before commitment, nested Delay boundaries,
Railroad orientation, answer inspection, Back/Step replay, reset and frozen
controls. The full `same` relation example also completed with a nondefault
compilation profile. Existing application servers were not replaced. See the
[application trace](../../docs/semantics-ladder.md#evidence-and-remaining-work).

The Dockerfile now preserves `src/` and includes the strict matrix/shared
providers at their imported paths. Both Compose configurations validate, and
an isolated copy without compiled caches loaded the application and rendered
all three schedulers to completion. Docker image build/container execution
remains unverified because the daemon returned HTTP 500.

`tests/test-all.rkt` is the GUI RackUnit runner, not the headless CI entry point.
Lattice operational suites are not substitutes for the strict source
and relation-stage checks. See the [policy boundary](../../docs/semantic-policy-matrix.md)
and [correction log](../derivations/strict-search/CORRECTIONS.md).
