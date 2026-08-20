# Test lanes

The lanes keep source semantics, compiler/runtime composition, app
serialization, and frontend behavior distinct. The Racket commands use an
isolated package home and compiled root.

## Lane A: comprehensive headless production tests

```sh
PLTUSERHOME=/tmp/decorated-lattice-plt \
PLTCOMPILEDROOTS=/tmp/decorated-lattice-compiled \
  raco test racket-server/tests/test-all-headless.rkt
```

Lane A imports one semantic aggregate from
`racket-server/tests/search-lattice/all.rkt`. That aggregate mirrors the
architecture:

- node suites for core, delay, disjunction, and search;
- edge suites for the four claimed conservative feature embeddings;
- a search-join suite proving that the semilattice join is exactly the inherited
  delay/disjunction union, with one shared core copy and no new carrier syntax
  or rules;
- compositional focus-grammar evidence;
- DFS, flip, and rail scheduler-fiber suites, including rail's right-active
  carrier closure and fiber-specific progress;
- the delayed-rooted relcall overlay;
- crosscutting determinism, raw-proof uniqueness, WF preservation, structural
  ownership, whole-frontier allocation, and frontier-observation laws; and
- the isolated distributed presentation.

The same headless lane separately imports compiler, runtime, program-runner,
HTTP-independent API, renderer-contract, example, and library integration
suites. `APP` and `ui-payload-smoke.rkt` are not part of Lane A.

Run the complete semantic subtree without the integration suites with:

```sh
PLTUSERHOME=/tmp/decorated-lattice-plt \
PLTCOMPILEDROOTS=/tmp/decorated-lattice-compiled \
  raco test racket-server/tests/search-lattice/all.rkt
```

Representative focused semantic gates are:

```sh
PLTUSERHOME=/tmp/decorated-lattice-plt \
  raco test racket-server/tests/search-lattice/nodes/core-tests.rkt
PLTUSERHOME=/tmp/decorated-lattice-plt \
  raco test racket-server/tests/search-lattice/edges/core-delay-tests.rkt
PLTUSERHOME=/tmp/decorated-lattice-plt \
  raco test racket-server/tests/search-lattice/join/search-join-tests.rkt
PLTUSERHOME=/tmp/decorated-lattice-plt \
  raco test racket-server/tests/search-lattice/grammar/frame-grammar-tests.rkt
PLTUSERHOME=/tmp/decorated-lattice-plt \
  raco test racket-server/tests/search-lattice/fibers/scheduler-progress-tests.rkt
PLTUSERHOME=/tmp/decorated-lattice-plt \
  raco test racket-server/tests/search-lattice/overlays/relcall-overlay-tests.rkt
PLTUSERHOME=/tmp/decorated-lattice-plt \
  raco test racket-server/tests/search-lattice/laws/determinism-tests.rkt
PLTUSERHOME=/tmp/decorated-lattice-plt \
  raco test racket-server/tests/search-lattice/laws/wf-preservation-tests.rkt
PLTUSERHOME=/tmp/decorated-lattice-plt \
  raco test racket-server/tests/search-lattice/experiments/distributed-tests.rkt
```

The manual fresh-scope trace witness remains a focused compiler-to-runtime
module:

```sh
PLTUSERHOME=/tmp/decorated-lattice-plt \
  raco test racket-server/tests/redex-fresh-scope-witness.rkt
```

## Lane B: app/API and serialized renderer

```sh
PLTUSERHOME=/tmp/decorated-lattice-plt \
  raco test racket-server/tests/test-app.rkt
PLTUSERHOME=/tmp/decorated-lattice-plt \
  racket racket-server/tests/ui-payload-smoke.rkt
```

`test-all.rkt` remains the GUI RackUnit runner and is not a headless CI entry
point.

## Lane C: frontend

```sh
npm --prefix frontend test
npm --prefix frontend run lint
npm --prefix frontend run build
```

The frontend contract sends `searchStrategy = { scheduler }` and exposes only
DFS, flip, and rail.

## Lane D: compiler/runtime configuration matrix

```sh
PLTUSERHOME=/tmp/decorated-lattice-plt \
  raco test racket-server/tests/model-example-matrix-tests.rkt
```

For one bounded representative miniKanren program, this lane crosses two
conjunction associations, two disjunction associations, three delay placements,
and three schedulers. Its 36 cells exercise compilation, scheduler-domain and
WF checks, model-backed initialization, named stepping, and terminal
observations. The same suite retains direct and API-flow coverage over the
frontend example corpus.

## Contract boundaries

- Delay and disjunction are additive feature extensions. Search is exactly
  their semilattice join: the literal language/relation union with one shared
  core copy and no join-owned syntax or rules.
- Production relation dependencies follow the same immediate-predecessor
  arrows: search combines assembled disjunction with the delay delta, rail
  lifts assembled search plus its local delta, and rail-relcall lifts assembled
  search-relcall plus that delta under `Γ`. The retained raw join seam is
  distributed-experiment support only.
- Source edge suites prove the stated embeddings and conservativity. They are
  not naturality tests.
- Relcall is an overlay rooted in the delayed language independently of search;
  search-relcall is their union, and rail-relcall is the union of relcall with
  rail. Relcall is not a core-rooted feature node.
- DFS, flip, and rail are scheduler fibers, not feature extensions. Rail alone
  extends its execution carrier with `DisjR`, six right-active closure rules,
  and two scheduling transitions.
- The production source is factored. The distributed presentation is an
  isolated executable experiment, not a runtime strategy.
- The distributed experiment deliberately retains `DisjR` and right-active
  normalization/closure on its common search carrier; distributed rail adds
  only scheduling. This does not widen production search, DFS, or flip.
- Each scheduler is checked against its matching grammar and WF judgment. DFS
  and flip use ordinary search/search-relcall, which exclude `DisjR`; rail uses
  rail/rail-relcall.
- `parse-prog/canonical` emits production `(Γ F)` directly; there is no
  mixed-work target or lowering module.
- WF is expressed by direct Redex judgments over inherited visibility and
  explicitly tagged `(Owners ...)` stacks. Allocated-name support is derived
  from the whole live frontier rather than stored. Owner, answer, and force
  counts are independent observations, not carrier fields.
- Only the phase-neutral labels documented in `PICTURE-DESIGN-NOTES.md` may
  leave the visible tree unchanged.

Current pass counts belong in the checkpoint handoff, where they can be tied to
an exact HEAD. This document intentionally does not preserve stale counts.
