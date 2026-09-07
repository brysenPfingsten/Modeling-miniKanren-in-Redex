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
constructor/dependency contracts. It also retains a strict/online work-order
witness. That witness is not an application
runtime adequacy check.

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
Search candidates from committed answers, and strict internal force from public
advance. Native lattice sessions retain `(Γ F)` configurations and mark the
source's exposed `force-delay` reduction as a public operation. The current
picture projection reads either carrier directly. The gates check source/state highlighting, exact common/private scope,
back/replay/reset, bounded responsiveness, and the absence of extra kernel work
during status inspection or rendering. The visible-contract entry point remains
part of `scripts/run_ui_smoke.sh`. The payload smoke prints actual full program
configurations, operation labels, statuses and committed counts.

Manual sessions in `src/program-runner.rkt` and the GUI do not enforce a source
`run n` limit. Their status describes the computation. Automatic consumption
is tested separately below. The GUI defaults to Lattice search/Railroad and
retains No Interleave and Flip-Flop; its separate Strict Search view sends
`{ "model": "strict" }`. API/library calls default to `(strict-search)`.
An explicit `search-strategy` with scheduler `"dfs"`, `"flip"`, or `"rail"`
instead selects native lattice execution. Compiler profiles and source occurrence IDs are
shared; initial wrappers and subsequent configurations remain source-specific.
Neither application routing nor common rendering establishes correspondence
between those sources.
The native lattice aggregate passed **111 cases**. The scheduler integration
suite passed **4 cases**, covering 36 profile/scheduler traces, 15 scope
witnesses, 4 policy witnesses, and 3 pending-bind witnesses.

## Automatic consumer and miniKanren library

```sh
racket -y -l raco -- test racket-server/tests/program-runner-tests.rkt racket-server/tests/minikanren-library-tests.rkt
```

The automatic `run-source`/`run-forms` driver belongs to `src/minikanren.rkt`,
alongside run/run* and evaluator/module APIs. Limit handling stops at the first
exposed Delay with enough answers, or at completion. For Strict Search this
must finish the current eager round and commitment. All three lattice schedulers
also check that an unguarded residual after a committed answer still exhausts
the step cap if it cannot reach the next Delay.
Returned answers can be a requested prefix while the saved configuration and
picture retain surplus committed answers. Tests also cover zero limits, finite
completion, step caps, source modes and host-value reification.

## Alternative distributed-source experiment

```sh
racket -y -l raco -- test racket-server/derivations/distributed-search/tests.rkt
```

[distributed-search/](../derivations/distributed-search/README.md) sits beside
`strict-search/` and keeps an older online source that distributes conjunction
over choice before machine derivation. Nested rails expose an observable
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
frontend run after fixing initialization-time control freezing passed **56 tests**;
the build passed and lint reported zero errors with three unchanged hook warnings.
Selector behavior does not establish an interpreter correspondence.

`tests/test-all-headless.rkt` now aggregates the maintained compiler, library,
session, API, rendering and payload suites, together with the strict research
aggregate, all 111 native lattice source cases, scheduler integration, and
runtime/dependency checks. Native source tests do not count as an interpreter
correspondence proof. The current headless entry point is:

```sh
racket -y -l raco -- test racket-server/tests/test-all-headless.rkt
```

The final headless run passed **3,502 tests**. Its HEADLESS suite passed all
**205 cases**, with zero failures or errors, including the unchanged Flip
wrapper expectation. The 3,262 strict derivation checks are included in that
total, not additive. HEADLESS raises on nonzero failures rather than silently
succeeding. The final live GUI checks also verified all four runtime selections,
exact Back/Step replay, and frozen controls during a delayed initialization
response; see the [application trace](../../docs/semantics-ladder.md#evidence-and-remaining-work).

`tests/test-all.rkt` is the GUI RackUnit runner, not the headless CI entry point.
Lattice operational suites are not substitutes for the strict source
and relation-stage checks. See the [policy boundary](../../docs/semantic-policy-matrix.md)
and [correction log](../derivations/strict-search/CORRECTIONS.md).
