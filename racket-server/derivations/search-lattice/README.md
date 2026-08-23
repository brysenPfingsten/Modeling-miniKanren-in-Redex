# Search-lattice derivation matrix seed

This directory is a deliberately small, executable seed for the eventual
three-axis family `T[i,rho]`:

- `i` selects a feature-hierarchy node; scheduler choices are fibers over
  selected nodes;
- `rho` selects a representation;
- `T` selects a derivation stage.

The seed fixes `i = core`. It retains the original two-row stage-generator
prototype as a recovery point and now also contains the selected complete core
representation matrix:

```text
                     R      D      Z ≅ M      B      Big
selected S           ◆      ◆        ◆        ◆       ◆
selected E           ◆      ◆        ◆        ◆       ◆
selected N           ◆      ◆        ◆        ◆       ◆
                     │      │        │        │       │
                     Q_R    Q_D      Q_Z/M      Q_B     Q_Big
```

Here a diamond means a static Redex artifact plus bounded executable
correspondence evidence on the stated well-formed core corpus. It does not mean
a universal simulation, a full feature cube, or a general naturality theorem.
The direct `Q_SN` map at every stage is checked against `Q_EN ∘ Q_SE`.
The primary vertical evidence is the five stage-transformation squares for
each of `Q_SE`, `Q_EN`, and direct `Q_SN`. Codec and readback comparisons live
in a separate test-only diagnostics suite. They neither construct a matrix
coordinate nor serve as the sole oracle for a representation map.

The retained prototype remains:

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

The prototype is not a selection of the eventual representation architecture.
`R[S]` is the authoritative production core relation; the derivation never
edits or redefines it. The prototype S retains tagged `Owners` provenance and
uses its presently implemented structural allocation-support policy. That
implementation is not evidence that world-local allocation has been selected
for the production lattice.

The selected post-prototype decisions are normative in
[`ARCHITECTURE-CONTRACT.md`](ARCHITECTURE-CONTRACT.md). This README describes
both the executable prototype retained as an oracle/recovery point and the
selected core matrix built beside it.

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

Checkpoint 4 carries those same selected sources through D, Z ≅ M, B, and
Big. The source schema publishes an expansion-time interface containing its
13-rule IR and complete variable, live-state, returned, failure-summary,
terminal, and payload/context views. The selected renderer consumes those
views directly to emit every horizontal coordinate and its phase-specific
representation maps. It does not lower through the retained
`#:environment` interface, construct a synthetic `Env`, or adapt the selected
views back into the prototype renderer. No source equation is restated in an
S/E/N stage module.

Each selected row checks the 13 independent source witnesses, source and stage
grammar/WF, unique raw decomposition, direct/spec raw proof counts, exact rule
labels, conservative B replay/spans, and finite Big closure/unfold. The primary
vertical harness checks the direct structural Q maps, all five
stage-transformation squares, direct operational squares, raw multiplicity,
exact labels and spans, sparse ordered support, failure summaries, and direct
S-to-N composition. A separate secondary harness owns plug, codec, and
readback diagnostics. The observation of allocation is the existing
`allocate-fresh` label (a singleton B span and an entry in flattened `BTrace`),
not a runtime `AllocateEvent`. Big claims are restricted to finite derivations:
there is no fuel, truncation, totalization, or claim that divergence produces a
result.

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
the same four control cases, and the structural codec remains useful as a
diagnostic. Nevertheless, the M transformer visibly emits an M-local direct
refocuser and transition system from the shared rule/control IR. Direct M does
not decode to Z or D, even though M adds no new semantic transformation.

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

### Selected complete core stage matrix

`framework/core-stage-schema.rkt` is the public selected-source bridge to
`framework/core-stage-renderers.rkt`. A generated source exports a static
source interface containing the concrete language, the single core rule IR
with its lexical dependencies, and complete views of runtime variables, live
states, returned values, failure summaries, terminals, focused payloads,
contexts, roots, frames, and redex partitions. The selected renderer consumes
those views directly. It does not import or invoke
`framework/stage-generators.rkt`, expose `#:environment`, or materialize a fake
environment to satisfy the prototype renderer. The source modules themselves
remain source-only and do not import either stage renderer.

`generated/core/stages/s.rkt`, `e.rkt`, and `n.rkt` each visibly instantiate
the bridge and the five transformations D, Z, M, B, and Big. They share one
representation-neutral compression policy. The emitted artifacts are ordinary
statically named Redex languages, metafunctions, judgments, and relations; no
runtime row selector or host semantic dispatcher is involved.

The selected public transformation forms are named
`define-selected-decomposition-stage`, `define-selected-refocused-stage`,
`define-selected-machine-isomorphism-stage`,
`define-selected-compressed-stage`, and `define-selected-fixed-point-stage`.
The distinct names allow the selected and retained prototype APIs to coexist
without aliases or accidental lowering between them.

Stage carriers split focused work from its `WorkFocus`, so a payload-only Q
map would lose S's outer Owner prefix. The selected strategies therefore also
export joint focused-work/focus, root-focus, failure-summary/focus, and terminal
views. Each selected stage transformer owns the direct representation map for
the phase it creates: D emits `Q_D`, Z emits `Q_Z`, M emits `Q_M`, B emits
`Q_B`, and Big emits `Q_Big`. In particular, `BDead` is mapped together with
its focus, so S's local dead Owners and its enclosing frame Owners become the
one cumulative E Support/N level before rebuilding the target. No later map is
implemented by decoding to an earlier stage, applying an earlier Q, and
re-encoding.

For each representation edge, the primary obligations are the literal
stage-transformation laws:

```text
Q_D   o decompose_S  = decompose_E  o Q_R
Q_Z   o refocus_S    = refocus_E    o Q_D
Q_M   o machineize_S = machineize_E o Q_Z
Q_B   o compress_S   = compress_E   o Q_M
Q_Big o big_S        = big_E        o Q_B
```

The same generated forms instantiate these laws for S→E, E→N, and the
independently direct S→N edge. Direct S→N maps do not call the adjacent
maps; their agreement with `Q_EN ∘ Q_SE` is a separate composition check.
The primary suite compares complete raw proof-output multisets and retains
exact transition labels and B spans on the bounded corpus. Inverse codecs,
stage readbacks, and codec-derived spec/square helpers are retained only in
row-local `diagnostics` submodules and the secondary transport-diagnostics
suite. They are not public selected maps, implementation routes, or sole
oracles.

The selected renderer uses `framework/core-redex-parameter.rkt`, a
selected-only transitive lifting module derived from `redex/parameter`, where a
generated Redex declaration depends on another stage-local judgment,
metafunction, or relation that must later widen with a language extension. It
reconstructs every inherited extension at the exact descendant language, so a
second staged delta does not freeze the first delta's dependency at the first
language. The upstream package remains on the frozen prototype and its
test-only whole-instance oracle. This is lexical dependency lifting for
ordinary statically named artifacts; it is not dynamic `parameterize`, a
representation selector, or a host semantic dispatcher.

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

This generator, including its `#:environment` field, is retained solely as the
frozen prototype/oracle and recovery point. No selected public module exposes
or invokes that field, and no selected adapter feeds it a representation view.
Only genuinely representation-neutral ideas have been extracted into the
selected renderer: Redex declaration emission, stage-shell rendering,
dependency lifting, the rule inventory, compression policy, and fixed-point
scaffolding.

`define-derivation-delta` currently merges an augmentation into its base
descriptor before any stage is generated. The foreign fixture therefore shows
that one augmentation declaration propagates through the row. By itself, this
retained premerge route does not show separate staging and recombination of an
extension, or establish
`Stage(Base + Delta) = Apply(StageExtension(Base, Delta), Stage(Base))`; the
selected bounded StageExtension evidence is stated below.

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

The two retained prototype column modules visibly contain one instance, one
policy, and five stage invocations, including the structural Z/M reification.
They contain no
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
contraction. Z contracts in D and directly refocuses the returned value. M
emits the corresponding transition again in its own carrier and through its
own direct, phase-local refocuser; the Z/M codec is only a diagnostic. The
compression policy marks `succeed` as a settled producer, so B fuses it with
the context-selected `conj-return` or `finish-success` and retains both labels
in `transition-span`. Big turns the same target control into the recursive
premise of its direct `big-dispatch` equation. The corresponding tests compare
each emitted artifact with the handwritten reference and production relation
using raw Redex derivations.

Compression remains deliberately bounded: allocation, conjunction expansion,
and already-settled structural transitions occupy singleton spans; a result
producer may fuse with exactly one legal follower. Empty and three-label spans
are outside the B grammar. A golden finite trace checks that flattening the B
certificates reproduces the exact M label trace.

The basic framework-only fixture uses unrelated syntax and deliberately
renames the carrier categories to `Task`, `World`, `Result`, `TaskFocus`, and
`WorldSpine`. It checks full-view consumption, empty frame partitions, and the
complete selected stage shells without importing the prototype renderer.

A separate foreign StageExtension fixture generates the base R/D/Z/M/B/Big
artifacts first, then applies a Query/Box augmentation from another module.
The feature owns its syntax and rules; inherited `Echo` and its duplicated
evidence are not copied. Exact-language dependency extensions keep both raw
proofs through D, native Z and M, direct B, and Big. Its B checks distinguish
legal base fusion under `Wrap` from the feature boundary under `Box`: the base
producer and feature follower remain two singleton spans, while a fixture-only
inert `Seal` frame proves that the guarded fallback cannot invent progress.
Five bounded embedding squares compare the separately staged artifacts, and a
separate handwritten premerged observation oracle checks the chosen success
and failure witnesses. This is explicit foreign post-generation evidence, not
automatic `Delta -> StageExtension` generation, a real search feature, a
universal staging theorem, or functoriality.

Checkpoint 5 adds a second, still foreign and bounded fixture for the identity
and composition laws. Its base row makes every executable compression label a
singleton; two base-owned, always-false sentinel producer rules merely keep
the frozen prototype's settled/dead producer classes grammatical and are
checked to have no proofs. The identity StageExtension copies the complete row
metadata exactly. Delta1 is the existing Query/Box StageExtension, and Delta2
adds `Probe Input -> Query Input` against Delta1's actual result row. The
selected route applies those extensions in sequence through D/Z/M/B/Big; the
test-only oracle premerges Base+Query+Probe and sends the whole instance
through the unchanged `stage-generators.rkt`.

The comparison retains the complete multiset of normalized top-level
`build-derivations` judgment terms, including duplicates, full targets,
labels, and B spans; only the paired judgment heads are renamed to common
stage tags. Renderer-specific derivation-name histograms are asserted
separately rather than erased. The bounded corpus covers inherited Echo and
Allocate carriers, both lifted Query proofs, the Probe success/failure/
rejection paths, exact singleton traces, sentinel rejection, direct/spec
systems, Z/M and M/B squares, B replay and promotion, and Big spec,
unfold/closure/root squares, and finite traces. Expansion-time assertions also
compare every identity/result-row primary and diagnostic artifact, dependency
default, singleton label, and compression-boundary batch. This is concrete
evidence for `Stage(identity) = identity` and for identity/composition on this
two-delta corpus. It is not automatic `Delta -> StageExtension` synthesis, a
universal functoriality theorem, or a real feature hierarchy.

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
- `framework/core-stage-schema.rkt` connects an exported selected-source view
  to the view-native selected renderer; its two-module fixture checks that
  private semantic and Q-hook bindings survive the boundary.
- `framework/core-stage-renderers.rkt` emits the selected D/Z/M/B/Big shells,
  native direct transition systems, phase-owned representation maps, and their
  primary transformation squares without invoking the retained
  `#:environment` backend.
- `framework/core-redex-parameter.rkt` is the selected-only transitive
  dependency-lifting implementation. The frozen generator and test-only
  whole-instance oracle continue to use the upstream package.
- `framework/core-stage-extension-base-fixture.rkt`,
  `core-stage-extension-query-fixture.rkt`, and
  `core-stage-extension-applied-fixture.rkt` form the explicit foreign
  post-generation extension; `core-stage-extension-tests.rkt` checks its five
  bounded embedding laws, dependency lifting, conservative spans, and finite
  Big observations against the independent bounded oracle.
- `framework/core-stage-functor-base-fixture.rkt`,
  `core-stage-functor-identity-fixture.rkt`,
  `core-stage-functor-probe-fixture.rkt`, and
  `core-stage-functor-sequential-fixture.rkt` form the bounded identity and
  two-delta selected route. `core-stage-functor-oracle-fixture.rkt` is its
  test-only frozen whole-instance route, and `core-stage-functor-tests.rkt`
  owns the raw-multiset, metadata, trace, replay, square, and closure checks.
- `generated/core/stages/s.rkt`, `e.rkt`, and `n.rkt` are the three selected
  complete horizontal columns. `policy.rkt` is their one shared compression
  policy and `corpus.rkt` is their keyed independent witness corpus.
- `generated/core/stages/horizontal-tests.rkt` checks every selected row
  through Big, including raw derivation counts;
  `vertical-transformation-tests.rkt` checks the five primary laws and direct
  operational squares, while `vertical-transport-diagnostics-tests.rkt` owns
  the secondary codec/readback comparisons.
- `generated/core/stages/dependency-tests.rkt` enforces the one-interface,
  five-visible-stage, no-restated-equation boundary.
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
- `tests/test-inventory.rkt` is the explicit semantic-suite registry and checks
  that every intended test module is registered exactly once, every focused
  wrapper is deliberately allowlisted, and no registered suite silently
  disappears.
- `tests/all.rkt` is the sole canonical derivation semantic aggregate. It
  flattens the registered leaf suites so aggregate wrappers cannot cause a
  second invocation of the same suite.

From the repository root:

```sh
raco pkg install redex-parameter
```

Then run the demo and focused gates:

```sh
racket racket-server/derivations/search-lattice/demo.rkt
raco test racket-server/derivations/search-lattice/framework/core-source-schema-tests.rkt
raco test racket-server/derivations/search-lattice/framework/core-stage-schema-tests.rkt
raco test racket-server/derivations/search-lattice/framework/core-stage-extension-tests.rkt
raco test racket-server/derivations/search-lattice/framework/core-stage-functor-tests.rkt
raco test racket-server/derivations/search-lattice/framework/stage-generators-tests.rkt
raco test racket-server/derivations/search-lattice/generated/core/source/tests.rkt
raco test racket-server/derivations/search-lattice/generated/core/stages/tests.rkt
raco test racket-server/derivations/search-lattice/generated/core/s/column-tests.rkt
raco test racket-server/derivations/search-lattice/generated/core/e/column-tests.rkt
raco test racket-server/derivations/search-lattice/tests/all.rkt
```

## Checkpoint testing

The checked-in pre-commit gate is run from the repository root:

```sh
scripts/run_search_lattice_checkpoint.sh
```

The default runner creates a fresh derivation compiled root, executes the
canonical aggregate exactly once, and then compiles every nonignored derivation
`.rkt` module under that same root without rerunning its `module+ test` body. It
writes every compile target explicitly into the derivation root; dependency
loading may use configured fallback artifacts, including installed or
source-adjacent compiled caches, but the sweep never writes a fallback
artifact. The runner creates a second fresh compiled root for the unchanged
production aggregate,
runs `git diff --check`, and verifies that testing did not change tracked or
staged contents. It retains and reports both roots, the derivation and
production test counts, the compile-sweep module count, and each lane's status
and elapsed time. It does not override `PLTUSERHOME`.

The explicit slow mode adds a redundant recursive registration audit under a
third fresh compiled root:

```sh
scripts/run_search_lattice_checkpoint.sh --recursive
```

That mode runs `raco test -x racket-server/derivations/search-lattice` only
after the default lanes. Its repeated leaf/aggregate invocation count is
reported separately and must never be added to the canonical aggregate count.

This literal recursive gate is required for the prototype checkpoint because it
establishes the initial test-registration baseline. After Checkpoint 4T, use the
canonical checkpoint runner described there; do not repeat this recursive
discovery command at every semantic checkpoint.

At every semantic checkpoint:

- run the focused suites for the modules and transformations changed;
- preserve raw `build-derivations` proofs and compare complete proof
  multiplicities without deduplication;
- run WF, label, trace, codec, replay, and correspondence obligations relevant
  to the changed coordinate;
- run the checked-in checkpoint runner in its default mode;
- require one fresh-cache execution of the canonical derivation aggregate;
- require a compile-only sweep of every nonignored derivation `.rkt` module;
- require an independently fresh execution of the unchanged production
  search-lattice aggregate;
- run `git diff --check`;
- inspect the exact staged path list;
- document tested evidence separately from universal theorem claims;
- commit only after the semantic status is truthful;
- push and verify the exact remote hash.

Do not use the number of times a suite was re-executed as additional evidence.
Checkpoint handoffs report unique canonical test counts. Reserve the literal
recursive command for test-registration or test-infrastructure changes, final
release/coherence checkpoints, scheduled CI, or diagnosis of a suspected
aggregate/direct discrepancy.

The dependency direction is one-way: derived modules may import the production
core, but no production module imports this directory.

## Deliberate stopping boundary

This seed does not yet instantiate separately staged real feature
augmentations, scheduler fibers, relation calls, or the distributed
presentation. The foreign Query/Box fixture checks bounded embedding laws, and
the foreign Query/Box then Probe fixture checks exact StageExtension identity
metadata and bounded two-delta composition through D/Z/M/B/Big against the
test-only frozen whole-instance oracle. Neither fixture generates a
StageExtension automatically from a source delta, implements delay or
disjunction, establishes a real feature face or hierarchy, or proves a
universal functoriality theorem. Checkpoint 5 stops at this fixture boundary;
Checkpoint 6 work has not begun.
The retained prototype coordinates stop at core/S and the
support-decorated-node core/E. The selected path separately completes the
core/S, core/E, and core/N rows through R, D, Z ≅ M, B, and Big.

In the current support-decorated-node prototype, local `Support` agrees with the
current S policy on the stated well-formed core domain. Branching features such
as disjunction and search expose names retained outside the active path. This is
a limitation of the prototype, not a reason to treat it as the selected
phase-sensitive E.

The retained prototype does not implement `N`. The selected matrix does: E's
ordered support is positionally mapped to N levels and N allocation uses its
state-local next counter. Sparse E names, failure summaries, and allocation
observations are checked through every core stage, including the five direct
stage-transformation laws, secondary transport diagnostics, and direct S-to-N
composition. The legacy prototype allocation behavior remains recovery
evidence, not an administrative form for the selected generator to guess.

This checkpoint claims bounded fixture-level identity and composition evidence,
not a full feature cube, general functoriality, or a universal naturality
theorem. It distinguishes instantiated row-local artifacts from validated
representation edges and commuting faces.

Production modules never import this directory.
