# Representation and compositional-staging architecture

This document is the authoritative design contract for work after the
stage-generator prototype checkpoint. It fixes the intended architecture and
records bounded implementation evidence only where stated below; it does not
promote executable fixtures into universal representation, staging, or
commuting theorems.

In this contract, "frozen prototype" denotes the retained
`framework/stage-generators.rkt` implementation and its bounded test-only
whole-instance oracle. The concrete legacy S/E column modules are historical;
the README records their final runnable commit.

The implementation order is part of the contract:

```text
truthful prototype checkpoint
-> architecture contract
-> independent core S/E/N sources
-> representation-strategy extraction
-> complete core matrix
-> separately staged augmentations
-> real feature hierarchy
```

Production remains unchanged until the parallel core sources and their stated
vertical maps are green. Generated artifacts never serve as their own sole
oracle.

## Axes and vocabulary

The intended family has three non-Cartesian axes:

- `i`: a node in the decorated feature/inheritance hierarchy;
- `rho`: a representation strategy, initially S, E, or N; and
- `T`: a derivation stage in `R -> D -> Z ~= M -> B -> Big`.

Scheduler choices are fibers over selected feature nodes, not feature nodes
invented merely to fill a grid. Relation calls are overlays on supported
descendants of delay. Consequently, some coordinates are deliberately absent.

Terms have the following fixed meanings:

- **lexical-variable syntax**: bound `x` occurrences;
- **runtime logic-variable domain**: allocated `u` identities or numeric
  levels;
- **configuration carrier**: runtime W/F states, frames, branches, and
  answers;
- **allocation provenance**: S-side Owner grouping and tags;
- **allocated-name support**: the ordered, cumulative names allocated in one
  possible world;
- **next allocation level**: N's counter;
- **transition observation**: evidence on a derivation or trace, not a runtime
  configuration constructor;
- **augmentation**: a feature delta;
- **embedding**: preservation of a base artifact inside an augmentation;
- **fiber**: a policy choice available only over selected feature nodes;
- **functoriality**: staging preserves identity and composition of extensions;
  and
- **naturality**: representation translation commutes with a feature or stage
  map.

`Z ~= M` is structural reification through an explicit isomorphism. It is not
an additional semantic transformation.

Here **representation-S** means the Owner-decorated representation. It is
distinct from the existing Redex nonterminal named `S` for settled/`Returned`
forms. In this document, unqualified **allocated-name support** always means
the intended ordered per-world allocation history. Whole-frontier occurrence
sets and the repeated `Support` fields of the checkpointed prototype are
different, explicitly qualified calculations.

## Representation strategies

### S: world-local, proof-relevant introductions

S retains `(Owner intro tag)` decorations at syntax positions that carry
allocation provenance. It does not restore `Fresh`, `WorkFresh`, or related
wrapper nodes.

For each possible world, cumulative allocated-name support is reconstructed by
following that world's path and concatenating visible Owner introductions in
order. The following invariants are per-world:

- introductions are ordered and duplicate-free along a path;
- every runtime variable visible in that world occurs in its path support;
- support is cumulative along the history of that world;
- an outer/shared introduction remains visible in every descendant world; and
- introductions belonging exclusively to incomparable siblings are ignored.

Different alternative worlds may allocate the same runtime atom. Uniqueness is
not global across the frontier. S preserves binder grouping, provenance tags,
empty binders, and introduction order even when an introduced variable is
unused. Owner sequences are stored grouped provenance, not a cached support
field; cumulative support is derived from their introduction order along a
world path and is never recovered by sorting or deduplicating variable names.

Named S allocation chooses the first `k` canonical `u` atoms absent from the
current world-path support, in binder order. It does not inspect incomparable
siblings.

World ancestry disambiguates reused syntax: equal atoms introduced after two
worlds split denote distinct allocations, while equal atoms in their copied
support prefix denote the same inherited variable. No operational step unifies
values across incomparable worlds.

This is a world-local design decision. It supersedes, rather than endorses, the
prototype's whole-live-frontier allocation policy.

### E: world-local support with a failure summary

E uses allocated `u` identities as its runtime logic-variable domain. Each
logical state contains ordered, duplicate-free, cumulative allocated-name
support alongside the substitution, disequalities, trail, and state tag.
The normative schematic state shape is:

```text
(state Support substitution disequalities trail state-tag)
```

The state tag remains semantic metadata; it is not Owner allocation
provenance.

While a world is live or successfully returned, its `Support` is carried by
its logical state. When that world fails, only the ordered Support summary
survives. The complete failed state is not retained.

The ownerless core configuration templates are exactly:

```text
Answer   ::= (Answer state)
Settled  ::= (Returned state)
Work     ::= (Work goal state)
           | (Returned state)
           | (Dead Support)
           | (Conj Work goal)
Frontier ::= (Last Answer) | (Done Support) | (More Work)
```

`Support` is not repeated on `Work`, `Conj`, `Returned`, `Answer`, `Last`,
feature wrappers, or the suspended second goal of a conjunction. `Dead` and
`Done` narrowly own the failed world's Support summary so structural
representation maps do not need external history. They retain no
substitution, disequalities, trail, state tag, or complete logical state.

The state discipline is:

- fresh chooses the first `k` canonical `u` atoms absent from that state's
  support and extends the support in binder order;
- disjunction copies the complete incoming state into each alternative world;
- a returned state is threaded directly into the second conjunct;
- conjunction return does not combine two supports; and
- support is cumulative within one world but may diverge across alternatives.

An allocation in one alternative therefore does not reserve that atom in an
incomparable sibling.

### N: numeric variables with a phase-sensitive next level

N uses natural numbers as runtime logic-variable identities. Each logical
state carries a natural `next` allocation level alongside the substitution,
disequalities, trail, and state tag. Object-language numeric data remains
syntactically distinct from these runtime variable identities.

```text
(state next substitution disequalities trail state-tag)
```

N uses the same ownerless live and successful configuration templates as E,
with this N state in each state-bearing position. A failed world instead has
`(Dead next)`, and terminal failure has `(Done next)`. These forms retain no
substitution, disequalities, trail, state tag, or complete logical state.
`Conj`, its suspended second goal, and feature wrappers carry no counter field
of their own.

A `k`-variable fresh at level `n` allocates, in binder order,
`n, ..., n + k - 1` and produces level `n + k`. In particular, `fresh ()`
performs an allocation transition but leaves `next` unchanged.

The state discipline is:

- disjunction copies the complete state and its `next` into each alternative;
- a returned `next` is threaded into the second conjunct; and
- counters are never added or joined when alternatives or conjunctions
  finish.

Independent sibling worlds may therefore allocate the same numeric levels.

Across all three representations, allocation supply is phase-sensitive:

- live and successfully returned worlds expose supply through Owner
  provenance in S or through the logical state in E and N;
- failed worlds retain only `(Dead owners)`, `(Dead Support)`, or
  `(Dead next)`;
- terminal failure retains the same summary in `Done`;
- a dead branch's summary remains branch-local and is discarded with that
  branch; it is never unioned, appended, maximized, or otherwise combined
  with a sibling supply; and
- standard answer/search observations ignore failure summaries unless a
  theorem explicitly observes allocation history, while exact structural
  representation correspondences preserve them.

This is not a restored Fresh wrapper, an `AllocateEvent`, a full failed state,
or a cache repeated throughout the configuration carrier. It is the narrow
summary owned by the failed phase.

## Fresh contraction boundary

A fresh contraction replaces only free occurrences of the lexical variables
bound by that fresh form. Allocation assigns runtime variables in binder order;
the resulting substitution is simultaneous and capture-avoiding. It respects
lexical shadowing: descent stops for a name beneath a nested fresh form that
binds that same name.

Intermediate goals may contain all of the following at once:

- runtime variables allocated by earlier steps;
- runtime variables allocated by the current step; and
- lexical variables governed by enclosing or nested binders.

A fresh step does not globally translate lexical syntax into runtime syntax.
It leaves runtime variables and unrelated lexical variables untouched.

Empty, singleton, multi-variable, unused, nested, and shadowing binders are all
semantic witnesses, not parser edge cases.

## Transition observations

No representation adds an `AllocateEvent` runtime constructor. Every row
retains the `allocate-fresh` rule label, so labeled traces preserve the fact and
order of allocation steps.

If a theorem later requires allocation arity, tag, or exact introduction, it
may use a trace-side observation such as `(allocate tag arity)` or
`(allocate tag intro)`. Such evidence belongs to derivations or traces. It is
not persistent configuration syntax.

S retains Owner grouping and tags persistently as proof-relevant provenance. E
and N intentionally forget only that Owner-specific information. Goal tags,
state tags, rule labels, and other semantic labels are preserved. Feature
structure such as `Forced` remains part of the configuration carrier and is not
conflated with allocation evidence. A renderer label such as `Freshened` is
presentation vocabulary, not a restored runtime Fresh wrapper.

## Vertical representation maps

Every Q map has an explicit grammatical and well-formedness domain. A map may
be partial outside that domain. Comparisons retain complete raw proof
multiplicity and exact rule-label order.

### `Q_SE`

`Q_SE` traverses S with a world-path accumulator. At each S provenance site it
appends the visible Owner introductions in order. At each logical state it
stores the accumulated support in the E state, then erases persistent Owner
decorations from the surrounding configuration carrier.

For `(Dead owners)` and `(Done owners)`, it appends every Owner introduction
visible on that world path and stores the resulting ordered Support directly
in the corresponding E failure form.

At a branch, the incoming accumulator is copied and each possible world is
translated independently. Introductions exclusive to one sibling never enter
another sibling's support. A shared prefix is translated consistently in every
descendant.

`Q_SE` itself preserves every runtime name in its input. On mapped inputs, the
same least-unused world-local allocator makes the S/E operational square exact.
Only a theorem comparing independently chosen but equivalent executions may
use per-world alpha-renaming, with the common outer prefix held fixed.

### `Q_EN`

`Q_EN` treats the order of a well-formed E support as authoritative. For
support `(u_0, ..., u_(n-1))`, it maps `u_i` to numeric runtime variable `i`,
renames the goal, substitution keys and values, disequalities, trail, and
answers coherently, and sets `next` to `n`.

The Support stored in `Dead` or `Done` is addressed in the same way and maps
directly to the corresponding N form carrying `next = n`. In particular,
`Q_EN` remains an ordinary structural function on failed conjunctions; it does
not receive predecessor history or a ghost support argument.

Sparse or noncanonical E atoms are admitted when the support is ordered,
duplicate-free, and covers every runtime variable visible in that world. They
are canonicalized by position, not sorted by spelling. Extra allocated but
unused support entries are retained in the addressing and therefore count
toward `next`. A duplicate support or a runtime variable absent from support is
outside the map's domain.

Each alternative world is addressed independently, while a copied outer
support prefix receives the same addresses in every descendant.

The map's domain is also **prefix-coherent**: alpha/address maps agree on common
ancestry and may diverge only after a branch. Any syntactically shared future
goal or continuation may mention only variables from the support prefix common
to every world that can reach it. Reachable configurations from canonical roots
must establish this property; arbitrary grammatical configurations that do not
satisfy it are outside `Q_EN`.

### `Q_SN`

The direct `Q_SN` traversal accumulates ordered S introductions and assigns
their canonical numeric addresses, including the Owner summaries stored in
`Dead` and `Done`. On its stated domain it must agree exactly with composition:

```text
Q_SN = Q_EN o Q_SE
```

Alpha-aware comparison is used only where explicitly stated; it is not a
license to ignore inconsistent substitution, trail, answer, or trace
renaming.

### Stage-local representation maps

The selected stage renderer consumes the representation strategies' complete
variable, live-state, returned, failure-summary, terminal, and payload/context
views directly. It does not lower those views through the retained
`#:environment` generator, expose that interface from a selected public
module, or materialize a synthetic environment for the prototype renderer.

Each stage transformer owns and directly emits the representation map for the
phase it creates. For a representative S-to-E edge, the primary obligations
are:

```text
Q_D   o decompose_S  = decompose_E  o Q_R
Q_Z   o refocus_S    = refocus_E    o Q_D
Q_M   o machineize_S = machineize_E o Q_Z
Q_B   o compress_S   = compress_E   o Q_M
Q_Big o big_S        = big_E        o Q_B
```

The corresponding laws apply to every selected representation edge, including
an independently direct S-to-N map. No later Q map is implemented by decoding
to an earlier stage, applying an earlier Q, and re-encoding. Codecs and
readback may remain as test-only secondary diagnostics after the direct map
exists; they neither construct coordinates nor serve as the sole oracle.
`Z ~= M` remains the intentional carrier isomorphism, but M still has a
visibly generated native direct transition system.

## Feature and stage composition

The source hierarchy is built from separately owned augmentations:

```text
core
|-- delay
|   `-- relation-call overlay
|-- disjunction
`-- search = delay + disjunction + search-owned interactions
    |-- DFS fiber
    |-- flip fiber
    `-- rail fiber with the additional DisjR carrier
```

Relation-call overlays also apply to selected delay descendants. A feature
schema may copy or carry a complete representation state, but it may not
inspect Owner, Support, or counter internals unless allocation is genuinely
owned by that feature.

Search grammar may be the union of delay and disjunction grammar, but genuine
interaction rules and their WF obligations are owned by the search-join
augmentation. No inherited core rule is duplicated there.

The frozen whole-instance generator, which premerges a delta before staging,
is retained as an oracle. The intended separately staged construction must
establish:

```text
T(Base + Delta)
  ~=
Apply(StageExtension(T, Base, Delta), T(Base))
```

A staged augmentation is parameterized by the staged base interface; it is not
a standalone language. `framework/core-redex-parameter.rkt`, the selected-only
transitive lifting module derived from `redex/parameter`, is used only to lift
dependent Redex judgments, metafunctions, and relations across descendant
languages. It recursively reconstructs inherited extensions at the exact
target language. The upstream package remains on the frozen generator and its
test-only oracle. Neither lifting implementation is the representation
mechanism.

### Checkpoint 5 bounded identity and composition evidence

Checkpoint 5 instantiates the identity and sequential-composition obligations
with a foreign, non-miniKanren fixture. The base row classifies every
executable compression label as a singleton. Two base-owned producer labels
have always-false premises: they inhabit the settled/dead producer categories
required by the unchanged frozen generator but have no derivations. Delta1 is
the separately compiled Query/Box StageExtension. Delta2 adds
`Probe Input -> Query Input` and is applied to Delta1's actual result row, not
to the original base. An explicit identity StageExtension copies the complete
base-row metadata.

The selected route stages Base, applies Delta1, then applies Delta2 through
D/Z/M/B/Big. A test-only route premerges Base+Query+Probe and invokes the
unchanged whole-instance `stage-generators.rkt`; no selected public module
imports that route or invokes `#:environment`. The comparison observes the
complete multiset of top-level `build-derivations` judgment terms without
deduplication, preserving full outputs, labels, targets, and B spans while
canonicalizing only the paired judgment heads. Renderer-specific derivation
names are reported as separate histograms because internal wrapper proof trees
are scaffolding, not the cross-renderer semantic observation.

The bounded corpus checks inherited Echo and Allocate, both lifted Query
proofs, Probe success/failure/rejection, exact singleton traces and impossible
sentinel rejection, direct/spec systems, Z/M and M/B squares, B replay and
promotion, and Big spec, unfold/closure/root squares, and finite closure.
Compile-time assertions separately check every identity/result-row primary and
diagnostic identifier, phase dependency default, feature label, and
compression boundary batch. This establishes
`Stage(identity) = identity` and the stated sequential/whole-instance
observation equality only for this explicit two-delta fixture and corpus.

Checkpoint 5 stopped at that fixture boundary. It established no automatic
`Delta -> StageExtension` synthesis, universal functoriality theorem, or claim
about scheduler fibers, relation-call overlays, or arbitrary feature
composition.

### Checkpoint 6A bounded Delay cube

Checkpoint 6A adds the first real child of core. A single neutral Delay schema
is rendered for S, E, and N and owns exactly `suspend-goal`,
`bubble-delay-through-conj`, and `force-delay`. Its representation view owns
only `PendingDelay` and `Forced` shapes and their neutral prefix transfer; it
does not branch on Owner, Support, or counter syntax. Core equations are
inherited, not copied. The source is transitively open to a later feature, and
the bounded second-feature fixture checks that Delay equations and lifted core
allocation dependencies remain available without restatement.

`Forced` is part of the configuration carrier, not trace-only allocation
evidence. It is traversed by WF, exported and rebuilt by the direct structural
Q views, retained by D/Z/M/B/Big, and remains visible around the frontier as
execution continues. The stage-control contract therefore admits a general
frontier-to-frontier source rule: Z and M use native whole-frontier refocusers,
B uses an explicit frontier control, and Big keeps work dispatch separate from
frontier control. This general control path is representation-neutral; it is
not a Delay-coordinate exception.

The specialized Delay stage synthesizer consumes a generated Delay source and
produces one StageExtension that is applied to each already generated core row.
It is evidence for this schema, not a general compiler from arbitrary deltas.
Each Delay rule is a singleton B span. Inherited core producer/follower fusion
remains exactly the core policy, and the Delay feature introduces no
cross-feature fusion or branch scheduler.

For every representation, direct embeddings `J-core->delay` are instantiated
at R, D, Z, M, B, and Big. Direct S-to-E, E-to-N, and S-to-N maps are
instantiated at every Delay coordinate; S-to-N composition is checked
separately. The bounded cube harness checks the feature embeddings, the five
stage-transformation faces, the representation faces, exact labels and B
spans, WF and finite traces, and complete raw `build-derivations` proof
multisets without deduplication. Independent handwritten S/E/N Delay sources,
WF judgments, and direct Q maps provide the finite source oracle instead of
reusing generated artifacts.

These executable faces establish only the observations made on the checked
finite corpus. They are not a universal feature functor, a general naturality
proof, or arbitrary `Delta -> StageExtension` synthesis. Checkpoint 6A stops
before Checkpoint 6B: disjunction, search-owned interactions, search scheduler
fibers, relation-call overlays, and their additional WF/correspondence
obligations remain absent.

## Conservative compression and finite Big

B initially retains the established base compression. Every newly introduced
feature-owned rule forms a singleton span, every original rule label remains
visible in order, and no cross-feature fusion is permitted. A combined feature
node may later own a cross-feature compression only after a separate replay
certificate establishes it.

At a feature boundary, an inherited producer uses its established fused span
only when the next transition is a legal base follower. If the next transition
is feature-owned, the inherited producer has a singleton fallback and the
feature rule forms its own singleton span. The fallback is enabled only when no
legal base fusion applies, so it neither loses progress nor duplicates raw
proofs.

Big is a relation or evaluator for finite derivations. On its stated WF/progress
domain, a B configuration has a Big derivation exactly when its finite B closure
terminates, including the zero-step terminal case. A diverging program has no
finite Big derivation, and direct execution of the evaluator may diverge. An
ill-WF or stuck configuration is outside this equivalence. No fuel, truncation,
or default terminal result is added to make Big total.

## Evidence and claim boundary

The architecture separates four kinds of evidence:

1. independently written source/reference artifacts;
2. generated artifacts compared with those oracles;
3. executable raw-proof, trace, embedding, and commuting-face checks; and
4. universal theorems, when separately established.

Representative or generated Redex tests are evidence, not universal proofs.
Neither a populated coordinate nor row-local agreement establishes general
functoriality or naturality. The Checkpoint 5 fixture establishes only its
explicitly bounded identity and two-delta observation; Checkpoint 6A adds only
the finite-corpus Delay embeddings and commuting faces stated above.
Production modules must never import this derivation subtree.

## Non-negotiable construction boundaries

- The independent S, E, and N source oracles are stated directly; no shared
  semantic table generates both an artifact and its sole oracle.
- A representation strategy supplies complete variable, state, and constructor
  views. A feature schema does not mention concrete Owner, Support, or counter
  syntax unless it owns allocation.
- Selected stage renderers consume those views directly; no selected public
  module exposes or invokes `#:environment`, and no adapter creates a fake
  environment for the retained prototype renderer.
- Each phase-specific representation map is emitted directly by its owning
  stage transformer. Codec and readback paths are secondary diagnostics only.
- If a renderer needs a concrete Owner, Support, counter, or row-local next
  case, the representation-view contract must be extended instead of adding a
  coordinate-specific exception.
- A separately staged augmentation must operate on the staged base interface;
  premerging the source descriptor again does not satisfy the staging law.
- Delay must be generated from its one representation-neutral three-rule
  schema. `Forced` remains structural and Q/WF-visible, and frontier control is
  generalized in the shared stage contract rather than special-cased in one
  coordinate.
- Inherited Redex rules and dependencies are lifted over extended languages,
  not copied into each descendant.
- Correspondence compares complete raw derivation multisets. Successor
  deduplication cannot establish a proof-count theorem.
- E and N never regain persistent Fresh or Owner data that their Q maps
  intentionally forget.
- B does not introduce uncertified cross-feature fusion, and Big is not
  totalized with fuel.
- Production never imports the derivation subtree and is not changed before the
  independent core sources and vertical maps are green.
