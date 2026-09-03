# Search-lattice derivation matrix seed

This directory is a deliberately small, executable seed for the eventual
three-axis family `T[i,rho]`:

- `i` selects a feature-hierarchy node; scheduler choices are fibers over
  selected nodes;
- `rho` selects a representation;
- `T` selects a derivation stage.

The seed contains the selected complete core representation matrix, its two
separately staged real feature children (`delay` from Checkpoint 6A and
`disjunction` from Checkpoint 6B), and their policy-neutral zero-rule Search
join from Checkpoint 6C:

```text
                     R      D      Z ≅ M      B      Big
selected S           ◆      ◆        ◆        ◆       ◆
selected E           ◆      ◆        ◆        ◆       ◆
selected N           ◆      ◆        ◆        ◆       ◆
                     │      │        │        │       │
                     Q_R    Q_D      Q_Z/M      Q_B     Q_Big

delay S              ◆      ◆        ◆        ◆       ◆
delay E              ◆      ◆        ◆        ◆       ◆
delay N              ◆      ◆        ◆        ◆       ◆

disjunction S        ◆      ◆        ◆        ◆       ◆
disjunction E        ◆      ◆        ◆        ◆       ◆
disjunction N        ◆      ◆        ◆        ◆       ◆

search S             ◆      ◆        ◆        ◆       ◆
search E             ◆      ◆        ◆        ◆       ◆
search N             ◆      ◆        ◆        ◆       ◆
```

Here a diamond means a static Redex artifact plus bounded executable
correspondence evidence on the stated well-formed finite corpora. It does not mean
a universal simulation, a full feature cube, or a general naturality theorem.
The direct `Q_SN` map at every stage is checked against `Q_EN ∘ Q_SE`.
The primary vertical evidence is the five stage-transformation squares for
each of `Q_SE`, `Q_EN`, and direct `Q_SN`. Codec and readback comparisons live
in a separate test-only diagnostics suite. They neither construct a matrix
coordinate nor serve as the sole oracle for a representation map.

The concrete prototype columns formerly under `generated/core/s/` and
`generated/core/e/` were retired after Checkpoint 5. Their last published,
runnable state is commit
`969d2f57346d40da6bc3581c877ce67abd27a171` (`Implement separately staged
feature extensions`), where their focused suites pass 15/15 S tests and 17/17
E tests. They remain historical evidence, not active matrix coordinates or
canonical test suites. The retired S column retained tagged `Owners`
provenance; the retired support-decorated-node E column repeated cumulative
`Support` at carrier positions. Neither was the selected representation
architecture.

The whole-instance `framework/stage-generators.rkt` implementation remains
frozen solely for the bounded test-only oracle used by the StageExtension
fixtures. No selected public module imports that oracle, invokes
`#:environment`, or lowers a representation view into the prototype interface.

The selected post-prototype decisions are normative in
[`ARCHITECTURE-CONTRACT.md`](ARCHITECTURE-CONTRACT.md). This README describes
the selected core matrix and distinguishes it from the retained frozen
generator and historical concrete columns.

Checkpoint 2 separately states the selected world-local S, phase-sensitive E,
and numeric N source oracles under
[`oracles/core/`](oracles/core/README.md), with direct vertical maps at R.
Live/successful E and N supply resides in logical state; failure retains only
the narrow Support/next summary in `Dead` and `Done`. Those sources were stated
independently of the historical prototype columns.

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

Here `g` means generated and `oracle` means independently written. The selected
generated source and stage artifacts live in modules separate from their
Checkpoint 2 oracles, so the bounded comparisons are not tautological.

`Z -> M` is intentionally displayed as an isomorphism. The two carriers have
the same four control cases, and the structural codec remains useful as a
diagnostic. Nevertheless, the M transformer visibly emits an M-local direct
refocuser and transition system from the shared rule/control IR. Direct M does
not decode to Z or D, even though M adds no new semantic transformation.

The retained handwritten S reference allocator computes support from the
separated redex and `WorkFocus`; plugging and scanning the whole frontier
remains only its executable specification. The retained handwritten
support-decorated E reference instead reads cumulative `Support` from the
focused `Work`. On the tested, well-formed translated S core frontiers those
supports agree. This bounded historical correspondence does not select either
policy for the world-local representations and is not feature-generic.

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
dispatcher, or grammar introspection. Its feature-open source dependencies use
`redex/parameter` for lexical dependency lifting, not to select a
representation at runtime.

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
The distinct names allow the selected and frozen whole-instance generator APIs
to coexist without aliases or accidental lowering between them.

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

The selected source and stage frameworks use `redex/parameter` where a
generated Redex declaration depends on another source- or stage-local
judgment, metafunction, or relation that must later widen with a language
extension. The required package behavior reconstructs every inherited
extension at the exact descendant language, registers extensions through
ancestor bases, and invalidates automatic lifts after explicit extensions. A
second staged delta therefore does not freeze the first delta's dependency at
the first language or reuse a lift from an older extension environment. This
is lexical dependency lifting for ordinary statically named artifacts; it is
not dynamic `parameterize`, a representation selector, or a host semantic
dispatcher.

### Frozen whole-instance oracle generator

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

This generator, including its `#:environment` field, is retained solely for
the frozen test-only whole-instance oracle. No selected public module exposes
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
the frozen whole-instance generator's settled/dead producer classes
grammatical and are checked to have no proofs. The identity StageExtension
copies the complete row metadata exactly. Delta1 is the existing Query/Box
StageExtension, and Delta2 adds `Probe Input -> Query Input` against Delta1's
actual result row. The selected route applies those extensions in sequence
through D/Z/M/B/Big; the test-only oracle premerges Base+Query+Probe and sends
the whole instance through the unchanged `stage-generators.rkt`.

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

### Checkpoint 6A: the real Delay feature

Checkpoint 6A instantiates the first representation-neutral, separately staged
miniKanren feature. One abstract Delay source schema is applied to the selected
S, E, and N core sources and owns exactly these three equations:

```text
suspend-goal
bubble-delay-through-conj
force-delay
```

The schema owns `suspend`, `PendingDelay`, and `Forced`, but no Owner, Support,
counter, scheduler, disjunction, or relation-call case. `PendingDelay` carries
work and `Forced` remains a real frontier/spine constructor: WF traverses it,
the direct Q maps preserve it structurally, and all six stage representations
retain its observable nesting. Core allocation and its lifted substitution and
focused-world prefix dependencies remain inherited. A second test-only feature
extends Delay without copying any Delay equation, exercising that open
dependency boundary.

`define-generated-delay-stage-extension` synthesizes the specialized Delay
StageExtension from that Delay source descriptor and applies it independently
to the already generated S, E, and N core rows. The selected stage-control IR
now admits general frontier-to-frontier transitions. Z and M refocus such
transitions directly, B has an explicit frontier control, and Big separates
work dispatch from frontier control. All three Delay labels are singleton B
spans; the existing inherited core fusion policy is unchanged and no
cross-feature fusion is introduced.

The generated rows expose direct core-to-Delay embeddings at R, D, Z, M, B,
and Big; direct S-to-E, E-to-N, and independently direct S-to-N maps at every
coordinate; and the selected feature, representation, and stage faces. The
tests compare complete raw `build-derivations` proof multisets without
deduplication, exact labels and singleton spans, WF, finite traces, Q
composition, embeddings, and the bounded commuting faces. Independently
written S/E/N Delay source oracles and direct oracle Q maps provide a separate
semantic reference for the finite corpus.

This is specialized Delay StageExtension synthesis and bounded cube evidence
for the checked corpus. It is not arbitrary `Delta -> StageExtension`
synthesis, a universal functoriality or naturality theorem, or evidence about a
branch scheduler.

### Checkpoint 6B: the real Disjunction feature

Checkpoint 6B adds Disjunction as a second child of core, independently of
Delay and without introducing the Search join. One representation-neutral
source schema owns exactly these five equations:

```text
expand-disjunction
skip-left-failure
reassociate-left-result
commit-choice-answer
resume-left-choice-success
```

They account respectively for branch creation, failed-left elimination,
nested-choice reassociation, answer emission, and successful-left commitment
to a following conjunction goal. The schema sees only abstract `Choice`,
`Emit`, prefix-transfer, branch-copy, and source-carrier views. It does not
inspect Owner groups, Support lists, or numeric counters. Expansion constructs
two copies of the complete incoming possible-world state, preserving its
substitution, disequalities, trail, and state tag while applying the strategy's
branch-copy operation to its allocation supply. Consequently, an outer
allocation remains visible in each descendant while incomparable siblings
retain separate allocation histories and may reuse the same S/E atom or N
level.

The direct structural Q maps preserve the common inherited prefix and rebuild
the two Choice branches from their own exported supports. They do not merge a
sibling's branch-local allocation into the other branch. The finite corpus
includes sibling reuse, a shared outer variable, left failure, multiple answer
emission, nested reassociation, and conjunction resumption. Independently
written S/E/N Disjunction source and WF oracles, with independent direct Q
maps, are kept separate from the generated artifacts and preserve complete raw
proof multiplicities.

`define-generated-disjunction-stage-extension` specializes the five source
rules through D, Z, M, B, and Big for each already generated core row. Its
controls distinguish work expansion, failed and settled choice popping,
frontier answer emission, and resumption into work. All five Disjunction
labels are singleton B spans. When a core settled/dead producer is immediately
followed by a Disjunction rule, the core producer uses its guarded singleton
fallback and the feature step remains a separate singleton; established core
fusion elsewhere is unchanged and no core-plus-feature or cross-feature span
is introduced.

The generated rows expose direct core-to-Disjunction embeddings at R, D, Z,
M, B, and Big, direct S-to-E, E-to-N, and independently direct S-to-N maps at
every coordinate, and the bounded feature, representation, and stage faces.
The checked claims are restricted to the finite corpus, exact labels and
spans, WF, raw proof multisets, finite traces, Q composition, embeddings, and
commuting faces exercised by the focused suites. They are not universal
functoriality or naturality theorems, arbitrary feature synthesis, or evidence
for the later Search join or any scheduler-owned interaction.

The retained handwritten `core/s-to-e.rkt` bridge is a historical R/D
reference only. Its bounded correspondence stops at R and D. The selected
generated matrix supplies phase-local representation maps through Big
independently and does not import this bridge.

### Checkpoint 6C: the zero-rule Search join

Checkpoint 6C composes the two selected features without choosing a scheduler.
The Search language is the Delay/Disjunction grammar union and its source
relation has exactly the inherited 21 labels: 13 core, three Delay, and five
Disjunction. `SearchJoinDelta` owns no labels, syntax, WF cases, Q cases, or
stage transitions. This matches the production join boundary; DFS, flip, and
rail each own different Delay-through-choice behavior and remain absent here.

The canonical generated route is core to Disjunction to Delay to an identity
Search join. A separately generated core-to-Delay-to-Disjunction route checks
the feature-order diamond on the bounded mixed corpus. Stage emitters retain
their owned source/template identity while accepting
`#:dependencies-from` the completed Search source for exact-language
substitution, prefix, and transfer dependencies. This lets Delay bubble into a
later Choice and lets Disjunction skip into a later PendingDelay without
adding a Search-owned semantic rule. The keyword defaults to the owned source,
so the Checkpoint 6A and 6B rows keep their existing behavior.

The mixed corpus exercises Delay inside Emit, Disjunction inside Forced,
cross-carrier prefix transfer in both feature orders, joint allocation state,
and bounded finite traces. It also records a deliberate scheduler barrier: an
active PendingDelay inside DisjL is grammatical and WF but has no
policy-neutral Search successor. The barrier is outside the finite Big
WF/progress claim. It is not classified as terminal and no scheduler rule is
invented to force progress.

The focused evidence compares independent S/E/N Search source and WF oracles,
complete raw proof multisets, exact B spans, child-to-Search embeddings, direct
S-to-E/E-to-N/S-to-N maps, both feature orders, diagnostic transports, and
finite Big results. Production Search provides a secondary 21-label inventory
check, but its whole-frontier S allocation is not used as the oracle for the
selected sibling-local policy.

This is bounded additive-composition evidence, not a universal commutation or
progress theorem. Checkpoint 6C stops before DFS, flip, rail/DisjR,
relation-call overlays, fairness or interleaving claims, and scheduler-specific
allocation cadence.

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
- The selected schemas and renderers import `redex/parameter` directly;
  transitive feature-order regressions enforce the package behavior they
  require.
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
- `framework/delay-schema.rkt` owns the one neutral three-rule Delay schema,
  the representation-view protocol, the open source extension, and the
  specialized Delay StageExtension synthesis. `delay-schema-tests.rkt`,
  `delay-stage-extension-tests.rkt`, and `delay-stage-asymmetric-tests.rkt`
  check open feature inheritance, lifted dependencies, representation-view
  separation, generic frontier controls, singleton B spans, and finite Big
  behavior.
- `oracles/delay/` contains the independently written S, E, and N source/WF
  oracles and their direct vertical maps. Its tests do not import generated
  Delay artifacts.
- `generated/delay/source/` contains the three real Delay sources, their direct
  R maps, and their direct core-to-Delay embeddings.
  `generated/delay/stages/` applies the specialized extension to the three
  already generated core rows and owns the D/Z/M/B/Big maps, embeddings, and
  stage faces. `source-tests.rkt`, `horizontal-tests.rkt`,
  `embedding-tests.rkt`, `cube-tests.rkt`,
  `transport-diagnostics-tests.rkt`, and `dependency-tests.rkt` are the six
  registered leaf suites; `tests.rkt` is their focused aggregate. They check
  the independent corpus, horizontal rows, embeddings, primary cube,
  secondary transport diagnostics, and dependency boundary. `all.rkt` exports
  the generated Delay artifacts without re-registering the leaf tests.
- `framework/disjunction-schema.rkt` owns the neutral five-rule Disjunction
  schema, the complete-state-copy and structural Choice/Emit view, and the
  specialized Disjunction StageExtension synthesis.
  `disjunction-schema-tests.rkt` checks the exact equations, source WF/raw
  multiplicity, state copying, sibling separation, and direct Q behavior;
  `disjunction-stage-extension-tests.rkt` checks the separately applied stage
  controls, singleton boundary spans, and finite Big behavior.
- `oracles/disjunction/` contains the independently written S, E, and N
  Disjunction source/WF oracles and their direct vertical maps. Its tests do
  not import generated Disjunction artifacts.
- `generated/disjunction/source/` contains the three generated Disjunction
  sources, their direct R maps, and direct core-to-Disjunction embeddings.
  `generated/disjunction/stages/` applies the specialized extension to the
  three core rows. `source-tests.rkt`, `horizontal-tests.rkt`,
  `embedding-tests.rkt`, `cube-tests.rkt`,
  `transport-diagnostics-tests.rkt`, and `dependency-tests.rkt` are the six
  registered leaf suites; `tests.rkt` is their focused aggregate. They own
  source/oracle correspondence, horizontal staging, embeddings, cube faces,
  transport diagnostics, and dependency separation without turning those
  bounded checks into a universal theorem.
- `framework/search-join-schema.rkt` names the explicit zero-rule source join
  and identity StageExtension. `stage-extension-dependencies-tests.rkt` uses
  two sibling fixtures to check late-bound dependency traversal in both
  feature orders without changing either feature's owned source language.
- `oracles/search/` independently composes the core, Delay, and Disjunction
  source deltas in S, E, and N, supplies direct Q maps, and records the
  policy-neutral scheduler barrier. It imports no generated Search artifact.
- `generated/search/source/` constructs the canonical zero-rule Search rows;
  `generated/search/stages/` applies both child extensions and the identity
  join through D/Z/M/B/Big. Their `feature-order/` subdirectories contain the
  reverse construction used only for the order diamond. The eight registered
  leaves cover source/oracle correspondence, horizontal rows, child
  embeddings, source and stage feature order, primary cube faces, secondary
  diagnostics, and dependency separation; `tests.rkt` is their focused
  aggregate and `all.rkt` exports only generated artifacts.
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
- `framework/stage-generators.rkt` is the frozen whole-instance oracle
  generator.
- `framework/stage-generators-tests.rkt` is the foreign base-plus-delta
  instantiation and test harness, including the same-module lifting and
  cross-module hygiene regressions.
- `framework/stage-generators-parameter-base-fixture.rkt` and
  `framework/stage-generators-parameter-derived-fixture.rkt` are the real
  two-module base/feature split used by the hygiene regression.
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
- `core/e/` contains the retained handwritten support-decorated E reference
  language, WF, source, and decomposition.
- `core/s-to-e.rkt` contains the retained handwritten `Q_R`, `Q_D`, context
  maps, and executable R/D square checks.
- `demo.rkt` presents selected generated S/E matrix coordinates alongside the
  retained handwritten S reference. It retains the handwritten B-to-Big trace
  certificate and a separate two-label compression witness.
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
raco test racket-server/derivations/search-lattice/framework/delay-schema-tests.rkt
raco test racket-server/derivations/search-lattice/framework/delay-stage-extension-tests.rkt
raco test racket-server/derivations/search-lattice/framework/delay-stage-asymmetric-tests.rkt
raco test racket-server/derivations/search-lattice/framework/disjunction-schema-tests.rkt
raco test racket-server/derivations/search-lattice/framework/disjunction-stage-extension-tests.rkt
raco test racket-server/derivations/search-lattice/framework/search-join-schema-tests.rkt
raco test racket-server/derivations/search-lattice/framework/stage-extension-dependencies-tests.rkt
raco test racket-server/derivations/search-lattice/framework/stage-generators-tests.rkt
raco test racket-server/derivations/search-lattice/generated/core/source/tests.rkt
raco test racket-server/derivations/search-lattice/generated/core/stages/tests.rkt
raco test racket-server/derivations/search-lattice/oracles/delay/tests.rkt
raco test racket-server/derivations/search-lattice/generated/delay/tests.rkt
raco test racket-server/derivations/search-lattice/oracles/disjunction/tests.rkt
raco test racket-server/derivations/search-lattice/generated/disjunction/tests.rkt
raco test racket-server/derivations/search-lattice/oracles/search/tests.rkt
raco test racket-server/derivations/search-lattice/generated/search/tests.rkt
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

Checkpoint 6A changed test registration and would ordinarily have triggered
this explicit `--recursive` mode.  After roughly twelve hours of bounded
implementation and diagnosis, its explicit acceptance stop prohibited the
default runner, canonical aggregate, and recursive audit.  Its handoff records
the focused results and the statically checked inventory separately; it does
not present a repeated or inferred canonical count as test evidence.

Checkpoint 6B follows the same acceptance freeze. Its handoff records only the
bounded focused Disjunction results and static inventory evidence obtained for
this checkpoint; it does not claim a default-runner, canonical-aggregate, or
recursive-audit pass.

Checkpoint 6C retains that acceptance boundary. Its handoff records the
bounded Search-join, feature-order, and compatibility results together with
static inventory evidence. The default runner, canonical aggregate, and
recursive registration audit are not restarted or inferred from those focused
counts.

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

This seed now instantiates two separately staged real augmentations over the
selected S/E/N core rows through R/D/Z/M/B/Big, Delay and Disjunction, plus
their policy-neutral zero-rule Search join. It stops at Checkpoint 6C.
Branch-scheduler interaction rules, DFS/flip/rail fibers, DisjR,
relation-call overlays, scheduler-specific allocation cadence, and the
distributed presentation have not begun. Neither child nor the common join
chooses a branch scheduler or supplies evidence about those later coordinates.

The retired historical prototype stopped at core/S and the
support-decorated-node core/E; its last runnable state is the commit recorded
above. The live selected path completes the core/S, core/E, and core/N rows
through R, D, Z ≅ M, B, and Big.

In the historical support-decorated-node prototype, local `Support` agreed with
the then-current S policy on the stated well-formed core domain. Branching
features such as disjunction and search expose names retained outside the
active path. This was a limitation of the prototype, not a reason to treat it
as the selected phase-sensitive E.

The historical prototype did not implement `N`. The selected matrix does: E's
ordered support is positionally mapped to N levels and N allocation uses its
state-local next counter. Sparse E names, failure summaries, and allocation
observations are checked through every core stage, including the five direct
stage-transformation laws, secondary transport diagnostics, and direct S-to-N
composition. The legacy prototype allocation behavior is preserved in the
historical commit; it is not an administrative form for the selected generator
to guess.

This checkpoint claims the finite-corpus raw-proof, embedding, direct-Q, and
commuting-face evidence stated above for core, Delay, Disjunction, and their
zero-rule Search join. It does not claim universal functoriality or naturality,
arbitrary feature synthesis, scheduler progress, or facts about the absent 6D
fibers. It distinguishes instantiated row-local artifacts from tested
representation edges and bounded commuting faces.

Production modules never import this directory.
