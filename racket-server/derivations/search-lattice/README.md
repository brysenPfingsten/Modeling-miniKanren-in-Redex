# Search-lattice derivation matrix seed

This directory is a deliberately small, executable seed for the eventual
three-axis family `T[i,rho]`:

- `i` selects a source feature or scheduler cell;
- `rho` selects a representation;
- `T` selects a derivation stage.

The seed fixes `i = core` and implements exactly this fragment:

```text
R[S] --decompose--> D[S] --refocus--> Z[S] --specialize--> M[S] --compress--> B[S] --fuse--> Big[S]
 |                    |
 | Q_R                | Q_D
 v                    v
R[E] --decompose--> D[E]
```

`R[S]` is the authoritative production core relation. The derivation never
edits or redefines that source semantics. `S` retains tagged `Owners` provenance
and derives allocation support structurally. `E` erases owner boundaries and
tags and stores the cumulative finite support visible at every carrier
position.

The eight implemented cells are ordinary, statically named Redex artifacts:

- `R[S]`: the existing production `core-lang`/`core-red` source;
- `D[S]`: a grammatical decomposition plus 13 independently stated
  contractions;
- `Z[S]`: an exact D-shaped refocused carrier, codecs/readback, and both slow
  and direct refocusing;
- `M[S]`: an exact-step machine with its own retained-context refocuser, a
  structural Z/M codec, and an independently transported Z specification;
- `B[S]`: a bounded transition-compressed carrier whose direct rules emit
  nonempty one- or two-label replay certificates;
- `Big[S]`: a fixed-point promotion with one observable outcome constructor,
  `BigFinal`, and direct clauses that do not import any prior derived stage;
- `R[E]`: an independently stated 13-rule cumulative-support calculus;
- `D[E]`: a second macro-instantiated decomposition with 13 independently
  stated E contractions.

The direct S allocator computes support from the separated redex and
`WorkFocus`; plugging and scanning the whole frontier remains only its
executable specification. The E allocator instead reads the cumulative
`Support` on the focused `Work`. On a well-formed translated S frontier those
two supports are equal. This equality is a core-cell theorem, not yet a
feature-generic one: a disjunction sibling or an emitted answer can retain a
live name outside the active work path. Extending E across those cells will
need an explicit global/live-support component or a stronger representation
invariant; the current local allocator must not simply be macro-instantiated
there.

## Generated shell, explicit semantics

The framework macro generates only representation-independent administrative
syntax and plumbing: decomposition results, labelled contracta, plugs, label
projection, and grammatical decomposition. Source rules, contraction rules,
well-formedness, representation maps, direct refocusing clauses, inventories,
and witnesses remain explicit.

In particular, no clause table generates both a source relation and its
derived counterpart. The correspondence checks compare complete raw labelled
proof multisets before any deduplication.

The horizontal S pipeline keeps its validation relations separate from the
direct artifacts. `M[S]` has a direct machine stepper and a Z-transported
specification; the tests establish an exact labelled commuting square for all
13 source rules. `B[S]` directly restates the core producer and structural
cases without calling the M stepper. Its separate specification replays each
certificate through exact M transitions and then checks the M/B square.

Compression is deliberately small and inspectable. Allocation, conjunction
expansion, and already-settled structural transitions occupy singleton spans.
A result-producing transition (`succeed`, `fail`, unification, or
disequality) may fuse with exactly one following conjunction or frontier
transition. There are no empty spans and no spans longer than two labels. The
golden finite trace demonstrates the complete partition:

```text
9 exact M labels
  allocate-fresh
  expand-conjunction
  expand-conjunction
  unify-success, conj-return
  disequality-success, conj-return
  succeed, finish-success

= 6 B spans whose flattened labels reproduce the exact M trace
```

`B[S]` is this bounded compression stage, not a big-step evaluator.
`Big[S]` is the following fixed point: its direct evaluator distributes the
driver through the core semantic clauses and erases the intermediate trace.
An independent specification initializes B compositionally, closes its
certified spans, and retains that `BTrace` as evidence. Singleton root,
closure, and one-step-unfold squares check that every reachable B suffix
promotes to the same exact `BigFinal` result. The six-span/nine-label theorem
therefore remains visible instead of disappearing inside the fused evaluator.

The S-to-E bridge is context-threaded: a child support includes the flattened
owners on every enclosing path. Its dynamic source, contraction, and D-step
squares are claimed only for well-formed S terms. The tests retain both a
well-formed allocation witness and an ill-formed counterexample where the S
whole-frontier scan and an E local environment necessarily choose different
names. The Redex quotient maps are likewise partial outside that WF domain:
ill-formed repeated owner introductions do not inhabit E's duplicate-free
`Support` codomain.

## What to look at

- `framework/decomposition-instance.rkt` is the compile-time generator.
- `core/s/decomposition.rkt` is the explicit S decomposition/contraction.
- `core/s/source-spec.rkt` is the isolated production-backed slow adapter.
- `core/s/refocused.rkt` is the first direct refocusing artifact.
- `core/s/machine.rkt` is the independently specialized exact-step machine;
  `core/s/machine-spec.rkt` contains its Z-transported specification and
  square.
- `core/s/compressed.rkt` is the direct bounded compressor;
  `core/s/compression-spec.rkt` contains exact M replay and the M/B square.
- `core/s/fixed-point.rkt` is the direct fused evaluator;
  `core/s/fixed-point-spec.rkt` contains B initialization/closure, retained
  trace evidence, and the B/Big unfold, closure, and root squares.
- `core/s/private/support-kernel.rkt` is the stage-independent logical-name
  support and fresh-introduction kernel shared by D, B, and Big.
- `core/e/` contains the independent E language, WF, source, and
  decomposition.
- `core/s-to-e.rkt` contains `Q_R`, `Q_D`, context maps, and executable square
  checks.
- `demo.rkt` prints one sparse-support witness at all eight coordinates. It
  makes the common `u:1` allocation visible in both rows, shows the direct M
  and B allocation steps, retains the complete B-to-Big trace certificate,
  and ends with a separate two-label B compression witness.
- `tests/core-matrix-tests.rkt` owns the cross-cell proof-count and commuting
  obligations.
- `tests/core-s-horizontal-tests.rkt` owns the 13-rule M/B/Big corpus, exact raw
  proof counts, codecs/readback, complete finite traces, replay checks, the
  nine-label/six-span golden partition, every reachable B suffix, all four Big
  entries, and duplicate-binder rejection.

From the repository root:

```sh
racket racket-server/derivations/search-lattice/demo.rkt
raco test racket-server/derivations/search-lattice/tests/all.rkt
```

For every local sanity check as well as the aggregate matrix gate:

```sh
raco test \
  racket-server/derivations/search-lattice/all.rkt \
  racket-server/derivations/search-lattice/demo.rkt \
  racket-server/derivations/search-lattice/core/s/refocused.rkt \
  racket-server/derivations/search-lattice/core/s/machine.rkt \
  racket-server/derivations/search-lattice/core/s/machine-spec.rkt \
  racket-server/derivations/search-lattice/core/s/compressed.rkt \
  racket-server/derivations/search-lattice/core/s/compression-spec.rkt \
  racket-server/derivations/search-lattice/core/s/private/support-kernel.rkt \
  racket-server/derivations/search-lattice/core/s/fixed-point.rkt \
  racket-server/derivations/search-lattice/core/s/fixed-point-spec.rkt \
  racket-server/derivations/search-lattice/core/e/language.rkt \
  racket-server/derivations/search-lattice/core/e/source.rkt \
  racket-server/derivations/search-lattice/core/s-to-e.rkt \
  racket-server/derivations/search-lattice/tests/all.rkt
```

The dependency direction is one-way: derived modules may import the production
core, but no production module imports this directory.

## Deliberate stopping boundary

This seed does not yet include `Z[E]`, `M[E]`, `B[E]`, `Big[E]`, feature
extensions, schedulers, relation calls, or the distributed presentation. The
current horizontal endpoint is core-only `Big[S]`. It makes no claim about
delay, disjunction, rail, or relation-call divergence; those remain future
feature-owned extensions.

It also does not implement `N`. Current source allocation is based on live
frontier support and may reuse a low logical name after pruning removes its
last occurrence. A monotone counter therefore cannot preserve literal name
traces. Before adding `N`, the project must choose and state a canonical
renaming or alpha-correspondence theorem, including sparse names and
allocation-event observations. That is a semantic decision, not another
administrative form for the generator to guess.

Production modules never import this directory.
