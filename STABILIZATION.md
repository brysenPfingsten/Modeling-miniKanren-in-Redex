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
- the active aggregate entrypoints stop at the current locked surface:
  `languages/all.rkt`, `reduction-relations/all.rkt`, `wf/all.rkt`, and
  `tests/test-all-headless.rkt` are intentionally limited to the current
  L0/L1/L2/L3 surface
- quarantined L3+ code stays in-tree but is removed from active aggregate
  wiring until its lower-layer dependencies are locked

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

- L1/delay runtime and wf layer:
  `delay-lang`, `delay-red`, `delay-wf`, and the focused L1 gate corpus in
  `racket-server/tests/stabilization-gates-tests.rkt`.
  Current touched-file inventory:
  `racket-server/src/search-lattice/languages/delay-lang.rkt`,
  `racket-server/src/search-lattice/reduction-relations/delay-red.rkt`,
  `racket-server/src/search-lattice/wf/delay-wf.rkt`.
  Lock evidence:
  nested-delay traces lock end-to-end, `Bounced` is introduced only at the
  delay frontier, and ordinary `Freshened(...)` configs created by
  `core/fresh-substitute` are now accepted by `wf-cfg/delay?`.
  Grammar note:
  the real exclusion target for uninvoked `delay` is top-level already
  resolved search roots such as `(⊤ σ)`, `(empty-tree)`, and their
  `Freshened`-wrapped forms. `Bounced` and `(promoted + cfg)` are not the
  reason for the restriction; those are already `cfg`-only and not members of
  `search`.
  The active lower-lattice decomposition now reflects that directly:
  `search` is factored as a single outer `Freshened` wrapper over resolved roots
  and bare runnable roots, and `delay` is a `search` form that wraps only
  `runnable-search`.

- L2/shared disjunction runtime and wf layer:
  `disj-lang`, `disj-base-red`, `disj-seq-red`, `disj-fused-red`,
  `disj-wf`, and the focused L2 gate corpus in
  `racket-server/tests/stabilization-gates-tests.rkt`.
  Current touched-file inventory:
  `racket-server/src/search-lattice/languages/disj-lang.rkt`,
  `racket-server/src/search-lattice/reduction-relations/disj-base-red.rkt`,
  `racket-server/src/search-lattice/reduction-relations/disj-seq-red.rkt`,
  `racket-server/src/search-lattice/reduction-relations/disj-fused-red.rkt`,
  `racket-server/src/search-lattice/wf/disj-wf.rkt`.
  Lock evidence:
  seq/fused differ only in their policy steps, shared-fresh and branch-local
  traces both complete, promoted left answers bubble to the spine in two steps,
  failures erase locally, and branch-local stepping is now expressed directly by
  the L2 extension of `KWork` instead of a separate `KBranch` context.

- L3/search-base runtime and wf layer:
  `search-base-lang`, `search-base-pre-red`,
  `search-base-seq-red`, `search-base-fused-red`,
  `search-base-wf`, and the focused L3 gate corpus in
  `racket-server/tests/stabilization-gates-tests.rkt`.
  Current touched-file inventory:
  `racket-server/src/search-lattice/languages/search-base-lang.rkt`,
  `racket-server/src/search-lattice/reduction-relations/search-base-pre-red.rkt`,
  `racket-server/src/search-lattice/reduction-relations/search-base-seq-red.rkt`,
  `racket-server/src/search-lattice/reduction-relations/search-base-fused-red.rkt`,
  `racket-server/src/search-lattice/wf/search-base-wf.rkt`.
  Lock evidence:
  seq/fused share one L3 language, plain L2 reassociation/consumption lifts
  unchanged into L3, bounced reassociation/consumption is now structural in
  Redex under `QSpine`/`QFront`, and the search-base reducers no longer depend
  on the four host-side branch-frontier helpers.

## Provisional

- Rail runtime and wf layers:
  `rail-seq-lang`, `rail-fused-lang`,
  `rail-seq-red`, `rail-fused-red`,
  `rail-wf`, `rail-calls-wf`.
  Current status in the rebuild branch:
  quarantined from `all.rkt` and `test-all-headless.rkt`.

- Calls overlays and search-strategy overlays:
  `calls-lang`, `calls-red`,
  `search-base-*-calls-*`,
  `rail-*-calls-*`,
  `search-dfs-*`,
  `search-flip-*`.
  Current status in the rebuild branch:
  quarantined from `all.rkt` and `test-all-headless.rkt`.

- Downstream consumers:
  `canonical-json.rkt`,
  `contracts/visible-node-contract.json`,
  app/runtime-facing tests and visible/rendering expectations.
  Current status in the rebuild branch:
  quarantined from `test-all-headless.rkt`.

## Deficient

- `JBH-refactor-notes.txt` as an active spec. It is no longer authoritative.

- Delay/disjunction wf under-acceptance immediately after
  `core/fresh-substitute`.
  Current witnesses live in
  `racket-server/tests/stabilization-gates-tests.rkt`.

- Host-side bubble/hoist helper logic in
  `racket-server/src/search-lattice/reduction-relations/private/common.rkt`.
  Search-base no longer depends on these helpers, but the quarantined
  rail/calls layers still may.

- Host-side scope/accounting helpers in
  `racket-server/tests/frontier-observable-support.rkt` where they exceed their
  role as test support and start acting as semantic authorities.

- Remaining quarantined layers still need to be propagated through the final
  `search` / `runnable-search` / branch-aware `KWork` factoring all the way to
  their final UI-facing consumers.

## Frozen Renames

- `KWork`
- `QSpine`
- `wf-answer/core?`
- `calls-lang` should be renamed to `delay-calls-lang` when the calls overlay
  is reopened; the current name is historically inherited and semantically
  misleading because it already includes the delay layer
- language-provenance rule-name prefixes such as `core/...` and `delay/...`

No rename rollback is allowed during stabilization unless the name itself
causes a correctness bug or import failure.
