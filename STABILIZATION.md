# Stabilization Ledger

This is the live source of truth for search-lattice stabilization.

`JBH-refactor-notes.txt` is historical scratch and rationale only. If this file
and that file disagree, this file wins.

During stabilization:
- no semantic edits above the current stabilization frontier unless needed to
  keep the repo compiling
- no new alpha renames unless a name itself causes a correctness bug or import
  failure
- if a higher layer compensates for a lower-layer defect, remove that
  compensation later rather than preserving it
- focused layer suites are the primary signal; umbrella/headless runs are
  secondary confirmation only
- legacy tests are evidence, not authority
- a failing legacy test must be triaged as one of:
  - intended semantic drift: rewrite or remove the test
  - stale harness assumption: narrow the test to the layer that still owns the
    claim
  - real regression: fix the implementation
- no pre-stabilization test is protected from deletion if it encodes an
  obsolete semantic story

## Locked

- Trivial core utilities: `walk`, `unify`, `extend`, `occurs?`,
  `fresh-substitution`, `c-append`.

- L0/core runtime layer:
  `core-lang`, `core-red`, `core-wf`, and the focused L0 gate corpus in
  `racket-server/tests/stabilization-gates-tests.rkt`.
  Current touched-file inventory:
  `racket-server/src/search-lattice/languages/core-lang.rkt`,
  `racket-server/src/search-lattice/reduction-relations/core-red.rkt`,
  `racket-server/src/search-lattice/wf/core-wf.rkt`,
  `racket-server/tests/property-core.rkt`,
  `racket-server/tests/search-lattice-tests.rkt`,
  `racket-server/tests/stabilization-gates-tests.rkt`.

## Provisional

- L1/delay runtime and wf layer:
  `delay-lang`, `delay-red`, `delay-wf`, and the focused L1 witness corpus in
  `racket-server/tests/stabilization-gates-tests.rkt`.
  Current touched-file inventory:
  `racket-server/src/search-lattice/languages/delay-lang.rkt`,
  `racket-server/src/search-lattice/reduction-relations/delay-red.rkt`,
  `racket-server/src/search-lattice/wf/delay-wf.rkt`.
  Reason still provisional:
  ordinary `Freshened(...)` configs created by `core/fresh-substitute` step and
  preserve exact scope, but are still rejected by `wf-cfg/delay?`.

- L2/shared disjunction runtime and wf layer:
  `disj-lang`, `disj-branch-lang`, `disj-seq-red`, `disj-fused-red`,
  `disj-wf`, and the focused L2 witness corpus in
  `racket-server/tests/stabilization-gates-tests.rkt`.
  Current touched-file inventory:
  `racket-server/src/search-lattice/languages/disj-lang.rkt`,
  `racket-server/src/search-lattice/languages/disj-branch-lang.rkt`,
  `racket-server/src/search-lattice/reduction-relations/disj-seq-red.rkt`,
  `racket-server/src/search-lattice/reduction-relations/disj-fused-red.rkt`,
  `racket-server/src/search-lattice/wf/disj-wf.rkt`.
  Reason still provisional:
  shared-fresh and branch-local traces show the intended first-step split, but
  the focused witness traces are not yet lockable end-to-end.

- L3/search-base runtime and wf layers:
  `search-base-seq-lang`, `search-base-fused-lang`,
  `search-base-seq-red`, `search-base-fused-red`,
  `search-base-wf`, `search-base-calls-wf`.

- Rail runtime and wf layers:
  `rail-seq-lang`, `rail-fused-lang`,
  `rail-seq-red`, `rail-fused-red`,
  `rail-wf`, `rail-calls-wf`.

- Calls overlays and search-strategy overlays:
  `calls-lang`, `calls-red`,
  `search-base-*-calls-*`,
  `rail-*-calls-*`,
  `search-dfs-*`,
  `search-flip-*`.

- Downstream consumers:
  `canonical-json.rkt`,
  `contracts/visible-node-contract.json`,
  app/runtime-facing tests and visible/rendering expectations.

## Deficient

- `JBH-refactor-notes.txt` as an active spec. It is no longer authoritative.

- Delay/disjunction wf under-acceptance immediately after
  `core/fresh-substitute`.
  Current witnesses live in
  `racket-server/tests/stabilization-gates-tests.rkt`.

- Host-side bubble/hoist helper logic in
  `racket-server/src/search-lattice/reduction-relations/private/common.rkt`.

- Host-side scope/accounting helpers in
  `racket-server/tests/frontier-observable-support.rkt` where they exceed their
  role as test support and start acting as semantic authorities.

## Frozen Renames

- `KWork`
- `QSpine`
- `KBranch`
- `wf-answer/core?`
- language-provenance rule-name prefixes such as `core/...` and `delay/...`

No rename rollback is allowed during stabilization unless the name itself
causes a correctness bug or import failure.
