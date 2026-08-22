# Search-lattice derivation matrix seed

This directory is a deliberately small, executable seed for the eventual
three-axis family `T[i,rho]`:

- `i` selects a feature-hierarchy node; scheduler choices are fibers over
  selected nodes;
- `rho` selects a representation;
- `T` selects a derivation stage.

The seed fixes `i = core` and now contains two complete row-local generated
stage chains:

```text
core/S descriptor -> Dg[S] -> Zg[S] ≅ Mg[S] -> Bg[S] -> Bigg[S]
                       ║       ║        ║         ║
                       ║ exact generated/reference correspondence
                       ║       ║        ║         ║
R[S] -> Dref[S] -> Zref[S] ≅ Mref[S] -> Bref[S] -> Bigref[S]

core/E descriptor -> Dg[E] -> Zg[E] ≅ Mg[E] -> Bg[E] -> Bigg[E]
                       ║
                       ║ exact generated/reference correspondence
                       ║
                 R[E] -> Dref[E]
```

This is a truthful prototype checkpoint, not a selection of the eventual
representation architecture. `R[S]` is the authoritative production core
relation; the derivation never edits or redefines it. The current S prototype
retains tagged `Owners` provenance and uses its presently implemented
structural allocation-support policy. That implementation is not evidence
that world-local allocation has been selected for the production lattice.

The selected post-prototype decisions are normative in
[`ARCHITECTURE-CONTRACT.md`](ARCHITECTURE-CONTRACT.md). This README describes
the executable prototype retained as an oracle and recovery point.

Checkpoint 2 separately states the selected world-local S, phase-sensitive E,
and numeric N source oracles under
[`oracles/core/`](oracles/core/README.md), with direct vertical maps at R.
Live/successful E and N supply resides in logical state; failure retains only
the narrow Support/next summary in `Dead` and `Done`. Those sources do not
replace or derive from the prototype columns described below.

Checkpoint 3 extracts those selected representations as compile-time
strategies and applies one representation-neutral core-source schema:

```text
S strategy ─┐
E strategy ─┼─> shared 13-rule core schema ─> Rg[S], Rg[E], Rg[N]
N strategy ─┘                                  │
                                               ├─ Qg_SE
                                               ├─ Qg_EN
                                               └─ direct Qg_SN
```

The three generated source relations are ordinary, statically named Redex
artifacts. Each is checked against its independently written Checkpoint 2
oracle with exact named raw-proof multisets, WF judgments, and successful and
failing traces. Generated S is also compared with production R[S] on the
explicitly shared well-formed core corpus. The generated Q maps are separately
compared with the direct oracle maps and their one-step squares; direct
`Qg_SN` does not call either adjacent map. These are executable finite-corpus
checks, not universal simulation or naturality theorems.

This new selected source path stops at R. It deliberately does not feed the
selected carriers through the prototype `#:environment` stage API or generate
D, Z, M, B, or Big yet; adapting the horizontal transformations to the full
phase views is the next checkpoint.

The generated artifact currently named E is a support-decorated-node
prototype. It erases S-side Owner groupings and tags and replaces their carrier
positions with cumulative `Support` positions on `Work`, `Conj`, `Returned`,
`Dead`, `Answer`, `Last`, and `Done`. It is not the selected E, in which
allocated-name support appears in live/successful logical state and only the
narrow failure summary appears in `Dead` and `Done`.

Here `g` means generated and `ref` means handwritten reference. The generated
and reference artifacts are separate modules. Each generated row's descriptor
declares its 13 semantic equations once; five visible stage invocations
generate ordinary, statically named Redex languages, metafunctions, and
judgments. S's production/reference column and prototype E's direct R/D oracles
are independently written, so the correspondence checks are not tautological.

`Z -> M` is intentionally displayed as an isomorphism. The two carriers have
the same four control cases; the M macro emits the constructor codec and
specializes the same retained-context transition program under the M names. It
does not maintain a second handwritten refocuser or perform an additional
semantic transformation.

The current direct S allocator computes support from the separated redex and
`WorkFocus`; plugging and scanning the whole frontier remains only its
executable specification. The prototype E allocator instead reads the
cumulative `Support` on the focused `Work`. On the currently tested,
well-formed translated S core frontiers those supports agree. This executable
core correspondence does not select either policy for the eventual world-local
representations and is not yet feature-generic.

## Status and terminology

The following terms are fixed for this project:

- **lexical-variable syntax** means bound `x` occurrences;
- **runtime logic-variable domain** means allocated `u` identities or numeric
  levels;
- **configuration carrier** means W/F states, frames, branches, and answers;
- **allocation provenance** means S-side Owner grouping and tags;
- **allocated-name support** means the cumulative names allocated in one
  possible world;
- **next allocation level** means N's counter;
- **transition observation** means evidence attached to a derivation or trace,
  not a runtime configuration constructor;
- **augmentation** means a feature delta;
- **embedding** means preservation of a base artifact inside an augmentation;
- **fiber** means scheduler choices available only over selected feature
  nodes;
- **functoriality** means staging preserves identities and composition of
  extensions; and
- **naturality** means representation translation commutes with a feature or
  stage map.

In particular, this checkpoint introduces no `AllocateEvent` configuration
constructor. Rule labels remain transition observations.

## The generator program

### Selected core-source strategies

`framework/core-source-schema.rkt` provides the source-level representation
program:

```racket
define-core-representation-strategy
define-generated-core-source
define-generated-core-representation-maps
```

A strategy declares the runtime-variable representation separately from its
supply/provenance representation. It supplies complete templates for state,
work, returned, dead, conjunction, answer, last, done, and root carriers,
rather than renaming a single environment slot. It also declares true empty
supply, conjunction focus, branch copy, return/failure joins, terminal answer
supply, allocation, addressing, variable operations, WF primitives, and
structural Q export/rebuild hooks. The framework consumes all of those fields
and emits a concrete branch-copy metafunction as part of each row.

This phase distinction is essential. Representation S keeps local Owner groups
on its path carriers and combines them while unwinding conjunction. E and N
store cumulative Support/next in live logical state, project only that narrow
summary into `Dead` and `Done`, and otherwise use ownerless carriers. No row
recovers supply from predecessor history, attaches it to a deferred right
goal, or merges sibling worlds.

The shared schema contains the 13 core reduction clauses exactly once. It
generates first-order variable operations, binder-local fresh substitution,
the source relation, raw named-successor access, and common WF traversal as
ordinary Redex definitions specialized by the strategy templates. The schema
does not contain `Owner`, `Support`, counter syntax, a runtime representation
dispatcher, grammar introspection, or `redex/parameter`. The latter remains a
tool for lifting dependencies across feature-language extensions, not for
selecting a representation.

The generated vertical-map consumer uses the three strategies' neutral
structural export/rebuild views to emit `Qg_SE`, `Qg_EN`, and an independently
direct `Qg_SN`. The public strategy descriptors are intended to be consumed by
their exported names; this checkpoint does not claim arbitrary prefixed or
renamed-import hygiene for the descriptor macro API.

### Retained horizontal-stage prototype

`framework/stage-generators.rkt` provides one compile-time form for the input
program and one for each arrow:

```racket
define-derivation-instance
define-derivation-delta
define-decomposition-stage
define-refocused-stage
define-machine-isomorphism-stage
define-compressed-stage
define-fixed-point-stage
```

A semantic instance names its source grammar, configuration-carrier
nonterminals, grammatical partitions, root and frame algebra, canonical dead
view, and semantic rules.
Each rule records a label, site, source control, target control, and ordered
Redex premises. A separate compression policy classifies settled/dead
producers, their legal followers, singleton rules, the retained transition
observation (currently exact rule labels), and the maximum span.

The existing `#:environment` field is provisional generator API vocabulary for
the prototype's repeated constructor slot. It is not the intended abstraction
for representation strategies, whose constructor positions may differ.

`define-derivation-delta` currently merges an augmentation into its base
descriptor before any stage is generated. The foreign fixture therefore shows
that one augmentation declaration propagates through the row. It does not yet
show separate staging and recombination of an extension, or establish
`Stage(Base + Delta) = Apply(StageExtension(Base, Delta), Stage(Base))`.

### Lifted Redex dependencies

Some rule premises depend on another Redex judgment whose language must widen
with the generated stage. The descriptor's `#:redex-parameters` field gives a
local premise name and its liftable default. A delta may introduce a fresh
dependency with `#:redex-parameters-add` or replace an inherited default with
`#:redex-parameter-overrides`. The framework emits seven rule-bearing sites as
liftable judgments: D's contraction, B's four producer/follower helpers and
direct step, and Big's direct dispatcher.

This uses `redex/parameter` for compile-time, lexically scoped lifting. It does
not use ordinary Racket `parameterize`, dynamically select a semantics, or add
a host dispatcher. Each generated artifact is still an ordinary statically
named Redex judgment, and the existing direct-stage and no-host-dispatch
boundaries remain in force.

The foreign fixture makes the dependency nonvacuous. Its base evidence
judgment has two natural-number proofs. The extended language adds strings and
an extended evidence judgment with two proofs that map `"lifted"` to `7`; the
delta overrides the inherited dependency. The generated D, direct/spec B, and
direct/spec Big artifacts all select that widened judgment lexically, produce
the extended result, and preserve both raw proofs.

A separate two-module fixture checks the corresponding identifier-hygiene
boundary. `stage-generators-parameter-base-fixture.rkt` exports a base grammar,
liftable evidence judgment, and descriptor. The derived feature module imports
those bindings, widens the input grammar with strings, overrides the evidence
slot, adds a `query` rule, and generates D through Big. The test harness then
observes the extended result and both raw proofs through D, direct/spec B, and
direct/spec Big. The guarantee is deliberately this concrete base-module to
feature-module descriptor/delta split; it is not runtime semantic selection.

Each arrow consumes the preceding compile-time descriptor and expands to
ordinary Redex declarations:

- D emits the D/C grammar, plugs, label projection, grammatical decomposition,
  the descriptor's contractions, and the direct D step.
- Z emits D/Z codecs, readback, the slow plug/decompose specification, and a
  direct refocuser specialized from the declared root/frame algebra.
- M emits the exact Z/M isomorphism and the same specialized refocusing program
  under the M constructors.
- B emits B-local producer, follower, and singleton clauses plus exact one- or
  two-label certificates. Its independent specification replays M; direct B
  never calls M.
- Big distributes a strict recursive driver through the semantic/control
  equations. Its direct language extends the source language and does not call
  D, Z, M, or B. A separate specification closes B while retaining `BTrace`.

The two column modules visibly contain one instance, one policy, and five stage
invocations, including the structural Z/M reification. They contain no
handwritten Redex judgment bodies outside the instance declaration.

Their source-level spines are deliberately unsurprising:

```racket
(define-derivation-instance core/S ...)
(define-decomposition-stage core/D/S #:from core/S ...)
(define-refocused-stage core/Z/S #:from core/D/S ...)
(define-machine-isomorphism-stage core/M/S #:from core/Z/S ...)
(define-compression-policy core/compression/S ...)
(define-compressed-stage
  core/B/S #:from core/M/S #:policy core/compression/S ...)
(define-fixed-point-stage core/Big/S #:from core/B/S ...)

(define-derivation-instance generated-core/e ...)
(define-decomposition-stage generated-core/D/e #:from generated-core/e ...)
(define-refocused-stage generated-core/Z/e #:from generated-core/D/e ...)
(define-machine-isomorphism-stage generated-core/M/e
  #:from generated-core/Z/e ...)
(define-compression-policy generated-core/compression/e ...)
(define-compressed-stage generated-core/B/e
  #:from generated-core/M/e #:policy generated-core/compression/e ...)
(define-fixed-point-stage generated-core/Big/e
  #:from generated-core/B/e ...)
```

### One rule through the stages

The core/S input program states `succeed` once:

```racket
[succeed
 #:site work
 #:from (run (Work owners (succeed tag) σ) WorkFocus)
 #:to (settled (Returned owners σ) WorkFocus)
 #:premises ()]
```

From that one equation, D emits a `DecWork` to labelled `ContractWork`
contraction. Z contracts in D and directly refocuses the returned value. M is
the codec-renamed Z transition. The compression policy marks `succeed` as a
settled producer, so B fuses it with the context-selected `conj-return` or
`finish-success` and retains both labels in `transition-span`. Big turns the
same target control into the recursive premise of its direct `big-dispatch`
equation. The corresponding tests compare each emitted artifact with the
handwritten reference and production relation using raw Redex derivations.

Compression remains deliberately bounded: allocation, conjunction expansion,
and already-settled structural transitions occupy singleton spans; a result
producer may fuse with exactly one legal follower. Empty and three-label spans
are outside the B grammar. A golden finite trace checks that flattening the B
certificates reproduces the exact M label trace.

The framework-only fixture uses unrelated `Pulse`, `Crash`, `Echo`, `Box`,
`Top`, and `Shell` syntax, and deliberately renames the carrier categories to
`Task`, `World`, `Result`, `TaskFocus`, and `WorldSpine`. Its base descriptor
premerged with one Box augmentation generates the entire D/Z/M/B/Big column.
This tests declaration propagation, not a separately compiled stage extension.
A deliberately duplicated evidence judgment also proves that two raw proofs
with the same result remain two proofs through D, direct/spec B, and
direct/spec Big.

The S-to-E prototype bridge is independent and context-threaded. Its executable
vertical correspondence currently stops at R and D: it checks source,
decomposition, contraction, and D-step squares only on its stated well-formed
domain. There are no Q maps or cross-row naturality results yet for Z, M, B, or
Big. Those later generated E artifacts have row-local direct/spec and codec
checks only. The generated E column does not import S, the bridge, or `Owners`.

## What to look at

- `framework/core-source-schema.rkt` is the selected representation-strategy
  and shared 13-rule source transformation.
- `framework/core-source-schema-tests.rkt` is a foreign-carrier expansion
  fixture covering carrier templates, distinct supply operations, all variable
  outcomes, WF, allocation, and generated vertical maps.
- `generated/core/source/s.rkt`, `e.rkt`, and `n.rkt` are the three selected
  strategy declarations and visible source-generation invocations.
- `generated/core/source/vertical.rkt` instantiates generated `Q_SE`, `Q_EN`,
  and direct `Q_SN`; `comparison-tests.rkt` compares all generated sources and
  maps with the independent oracles and bounded production-S corpus.
- `generated/core/source/dependency-tests.rkt` enforces the one-schema,
  representation-neutral, source-only dependency boundary.
- `framework/stage-generators.rkt` is the parametric transformation program.
- `framework/stage-generators-tests.rkt` is the foreign base-plus-delta
  instantiation and test harness, including the same-module lifting and
  cross-module hygiene regressions.
- `framework/stage-generators-parameter-base-fixture.rkt` and
  `framework/stage-generators-parameter-derived-fixture.rkt` are the real
  two-module base/feature split used by the hygiene regression.
- `generated/core/s/column.rkt` is the one-time S semantic declaration followed
  by the five visible stage invocations.
- `generated/core/s/column-tests.rkt` compares generated S with both
  production and every handwritten horizontal reference stage.
- `generated/core/e/column.rkt` is the independent support-decorated-node
  prototype instance followed by the same five stage invocations.
- `generated/core/e/column-tests.rkt` compares generated E with independent
  R[E] and handwritten D[E], then checks its generated horizontal stages.
- `framework/decomposition-instance.rkt` is the earlier structural-shell macro
  retained for the handwritten reference column.
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
- `core/s/private/support-kernel.rkt` is the stage-independent runtime
  logic-variable occurrence and fresh-introduction kernel used by the current
  S allocation policy in D, B, and Big.
- `core/e/` contains the independent prototype E language, WF, source, and
  decomposition.
- `core/s-to-e.rkt` contains the prototype `Q_R`, `Q_D`, context maps, and
  executable R/D square checks.
- `demo.rkt` prints one sparse-support witness through both handwritten and
  generated S/E coordinates. It makes the common `u:1` allocation visible,
  retains the handwritten B-to-Big trace certificate, and ends with a separate
  two-label compression witness.
- `tests/core-matrix-tests.rkt` owns the currently implemented R/D cross-cell
  proof-count and commuting obligations.
- `tests/core-s-horizontal-tests.rkt` owns the 13-rule M/B/Big corpus, exact raw
  proof counts, codecs/readback, complete finite traces, replay checks, the
  nine-label/six-span golden partition, every reachable B suffix, all four Big
  entries, and duplicate-binder rejection.

From the repository root:

```sh
raco pkg install redex-parameter
```

Then run the demo and focused gates:

```sh
racket racket-server/derivations/search-lattice/demo.rkt
raco test racket-server/derivations/search-lattice/framework/core-source-schema-tests.rkt
raco test racket-server/derivations/search-lattice/framework/stage-generators-tests.rkt
raco test racket-server/derivations/search-lattice/generated/core/source/tests.rkt
raco test racket-server/derivations/search-lattice/generated/core/s/column-tests.rkt
raco test racket-server/derivations/search-lattice/generated/core/e/column-tests.rkt
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
  racket-server/derivations/search-lattice/framework/core-source-schema-tests.rkt \
  racket-server/derivations/search-lattice/framework/stage-generators-tests.rkt \
  racket-server/derivations/search-lattice/generated/core/source/tests.rkt \
  racket-server/derivations/search-lattice/generated/core/s/column-tests.rkt \
  racket-server/derivations/search-lattice/generated/core/e/column-tests.rkt \
  racket-server/derivations/search-lattice/tests/all.rkt
```

The dependency direction is one-way: derived modules may import the production
core, but no production module imports this directory.

## Deliberate stopping boundary

This seed does not yet instantiate separately staged real feature
augmentations, scheduler fibers, relation calls, or the distributed
presentation. The foreign Box delta demonstrates that a premerged augmentation
declaration propagates mechanically; it is not a separate stage extension or a
delay/disjunction result.
The retained full horizontal prototype coordinates stop at core/S and core/E.
The selected source generator now includes core/S, core/E, and core/N, but
stops at R for all three representations.

In the current support-decorated-node prototype, local `Support` agrees with the
current S policy on the stated well-formed core domain. Branching features such
as disjunction and search expose names retained outside the active path. This is
a limitation of the prototype, not a reason to treat it as the selected
phase-sensitive E.

The retained stage prototype does not implement `N`. The selected source path
does: E's ordered support is positionally mapped to N levels and N allocation
uses its state-local next counter. Sparse E names and allocation observations
are covered at R, while lifting those strategies through later stages remains
open. The legacy prototype allocation behavior remains recovery evidence, not
an administrative form for the selected generator to guess.

This checkpoint claims neither a full cube nor functoriality or a universal
naturality theorem. It distinguishes instantiated row-local artifacts from
validated representation edges and commuting faces.

Production modules never import this directory.
