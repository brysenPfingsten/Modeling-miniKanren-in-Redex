# Earlier dormant-branch semantics: decorated search lattice

This directory retains the **earlier dormant-branch semantics** for comparison.
Disjunction leaves the right goal unevaluated while the active left path runs.
The source family provides No Interleave, Flip-Flop, and Railroad schedulers.
The current GUI uses [strict matrix scheduler rows](../../../matrix/scheduler-source.rkt)
for all three choices, with eager operands and bind, explicit commitment,
and active-scope allocation. The earlier dormant-branch sources documented below
are no longer its runtime provider. The strict derivation and the separate
fusion question are recorded in the
[semantic-policy matrix](../../../../../docs/semantic-policy-matrix.md).

The historical phrase “Search/rail” in
strict derivation documents names that derivation's Search feature; it does
not make the strict `mplus-delay` equations an implementation of this oriented
Railroad grammar. The [interpreter derivations of the earlier dormant-branch
semantics](../README.md) have partial correspondence
with these sources; they do not describe the current strict GUI integration.

Within this dormant-branch policy, one factored source is assembled from core and two
additive feature extensions.
Search is the literal union of delay and disjunction. DFS, flip, and rail are
scheduler fibers rather than additional feature nodes; rail alone extends the
carrier with its right-active execution state.

## Additive feature diamond

```mermaid
flowchart TD
  CORE["core"]
  DELAY["core + delay"]
  DISJ["core + disjunction"]
  SEARCH["search = delay union disjunction"]
  RELCALL["delay + relcall overlay"]
  SEARCHCALL["search union relcall"]
  DFSFLIP["DFS / flip fibers"]
  RAIL["rail fiber + DisjR closure"]
  DFSFLIPCALL["DFS / flip with relcall"]
  RAILCALL["rail + relcall"]
  DISTRIBUTED["alternative distributed source (common DisjR carrier)"]

  CORE --> DELAY
  CORE --> DISJ
  DELAY --> SEARCH
  DISJ --> SEARCH
  DELAY -. "relcall overlay" .-> RELCALL
  SEARCH --> SEARCHCALL
  RELCALL --> SEARCHCALL
  SEARCH --> DFSFLIP
  SEARCH --> RAIL
  SEARCHCALL --> DFSFLIPCALL
  SEARCHCALL --> RAILCALL
  RAIL --> RAILCALL
  RELCALL --> RAILCALL
  SEARCH -. "conjunction distribution experiment" .-> DISTRIBUTED
```

Delay and disjunction are additive feature extensions of core. Search is their
literal language and reduction-relation union, so it contributes no new
constructor or rule. Named-rule inventory tests verify exactly one inherited
copy of core behavior plus the delay and disjunction deltas.

Relcall is an overlay rooted in the delayed language. It adds relation goals,
`Γ`, configurations `(Γ F)`, and call expansion. `search-relcall` is the union
of that independently delayed-rooted overlay with search. `rail-relcall` is the
union of relcall and the rail fiber.

These historical source modules follow the same immediate-predecessor structure.
`search-red` combines assembled `disj-red` with the delay deltas, thereby
inheriting core exactly once. `rail-red` lifts that assembled `search-red` and
adds only `rail-delta-red` (the right-active closure and scheduler transitions).
`rail-relcall-red` likewise lifts assembled `search-relcall-red` and adds the
same rail delta under `Γ`; it does not reconstruct lower feature relations.

## Stratified carrier

`W` is unfinished work. `F` is the complete frontier and the root category.
Core contributes:

```text
A ::= Answer(owners, σ)

S ::= Returned(owners, σ)

W ::= Work(owners, g, σ)
    | Returned(owners, σ)
    | Dead(owners)
    | Conj(owners, W, g)

F ::= More(W)
    | Done(owners)
    | Last(owners, A)
```

The established goal language includes fresh, conjunction, equality,
disequality, success, and failure. An `owners` term has the explicit form
`Owners(owner ...)`; the records are ordered outermost-to-innermost. Each
`Owner(intro, tag)` stores one binder's ordered, duplicate-free introductions.
The stack is structural provenance, not cumulative allocated-name support, a
cache, a counter, or a second source of truth.

Each additive feature extension owns only its constructors:

| Additive feature extension | Additions |
| --- | --- |
| delay | `suspend`, `PendingDelay(owners,W)`, `Forced(owners,F)` |
| disjunction | `∨`, `DisjL(owners,W,W)`, `Emit(owners,A,F)` |

Search contributes no new constructor. The rail fiber owns
`DisjR(owners,W,W)` and its right-active frame. The delayed-rooted relcall
overlay owns relation goals, `Γ`, and `(Γ F)`. Committed answers remain in
`Emit`/`Last`; they are not treated as disposable history.

## Compositional focus grammar

The primary language derives focus from recursive context categories:

| Grammar | Role |
| --- | --- |
| `WorkOwnerSlot` | the leading owner field of one work constructor |
| `WorkPath` | zero or more active work-path constructors |
| `SpineContext` | zero or more frontier-spine wrappers |
| `WorkFocus` | a work path below `More`, under spine wrappers |

Core contributes owner slots for `Work`, `Returned`, `Dead`, and `Conj`, and
defines `WorkPath` recursively through `Conj`. Delay adds the `PendingDelay`
owner slot and extends `SpineContext` directly through `Forced`. Disjunction
adds the `DisjL` owner slot, extends `WorkPath` directly through the active
`DisjL` child, and extends `SpineContext` directly through `Emit`. Rail adds the
`DisjR` owner slot and extends `WorkPath` directly through the active right
child. The fixed `Owners` wrapper lets empty and nonempty stacks use one
production with one hole classification, so Redex gives each generated context
one raw derivation.

These grammars are indexed inductive structures: hole and result categories
are implicit in their productions. No explicit W/F state tag, scheduler tag,
or dynamic sort-compatibility check is used. If a rule overlap reappears when
host ordering is removed, the grammatical factorization is unfinished.

## Owner transfer

Every rule states where its input owner records go. Expanding conjunction keeps
the source owners on `Conj` and starts the active child with an empty stack.
When the child returns or fails, its owners append after the conjunction's
owners. The empty stack is `(Owners)`. Finishing a returned or dead work item
transfers that stack to `Last` or `Done`.

Choice introduction keeps the source owners on the choice root and gives each
new branch an empty stack. Pruning discards only the failed branch's owners and
attaches the choice owners to the survivor. Commitment partitions choice-root
owners, answer owners, and residual owners among `Emit`, `Answer`, and the
residual frontier. Reassociation attaches an inner choice's owners separately
to the settled and residual leaves; the factored conjunction-resumption rules
put the outer conjunction and choice owners on the result choice and use
empty-owner child `Conj` nodes.

Delay promotion likewise keeps the original delay owners restricted to its
payload while placing the enclosing conjunction owners on the replacement
`PendingDelay`. Scheduler extraction attaches delayed owners to the extracted
payload without manufacturing or duplicating scope. Relcall expansion preserves
the owners already on its `Work` node.

## Factored source

Every primary step is a literal named Redex clause closed under the relevant
focus grammar. Host code performs atomic kernel work such as unification and
fresh-symbol choice; it does not dispatch among control rules.

The factored source continues down active work. Ordinary search attaches a
settled left-active continuation through:

```text
resume-left-choice-success
```

Core owns kernel, conjunction, fresh, and frontier-phase rules. Delay owns
suspension and force behavior. Disjunction owns left-active choice rules. Rail
owns `DisjR`, six rules that close the right-active carrier under stepping, and
the two scheduling transitions `rail-enter-right` and `rail-return-left`.

## Alternative distributed source

[early-conjunction-distribution/](../../early-conjunction-distribution/README.md)
keeps an executable alternative that distributes conjunction over choice in
the earlier dormant-branch semantics before machine derivation. It reuses their
feature carriers, retains a common `DisjR` carrier locally, and adds the
`Early*` focus-indexed normalization grammar. Nested rails exhibit an
observable answer-order difference from the factored source. Distribution
therefore needs a semantic assessment; it is not established as a merely
administrative or representation-preserving change.

The experiment regroups raw rules under its `Early*` grammar. Both its
`search-join-base-red.rkt` and the formerly shared raw seam now live together
in its `reduction-relations/` directory; the latter is
[`factored-search-base.rkt`](../../early-conjunction-distribution/reduction-relations/factored-search-base.rkt).
Ordinary `search-red` does not import this seam.

The distributed presentation also deliberately retains its historical common
right-active carrier. Its distributed search relation owns `DisjR`, the five
right-active closure clauses, and `distribute-right-choice`; distributed DFS
and flip inherit that carrier, and distributed rail adds only the two scheduler
transitions. This exception is contained inside the experiment and does not
alter the historical search, DFS, flip, or WF domains described above.
The distributed rail relation mechanically re-closes inherited rules on the
common distributed-search carrier; its rule-inventory delta over distributed
search is only those two scheduling transitions.

Its dedicated [tests](../../early-conjunction-distribution/tests.rkt) run
alongside this account under the experiments aggregate. That retains
comparison evidence; it adds no GUI policy, strict matrix coordinate,
or A7/A9 integration. No correspondence with the S reference
interpreter or a derived distributed machine is claimed by this relocation.

## Scheduler fibers

The lattice scheduler surface contains exactly:

```text
dfs | flip | rail
```

DFS preserves left-active order; flip changes the delayed turn discipline;
rail uses `DisjL`/`DisjR` plus its right-active closure and two scheduling
rules. DFS and flip use `search-lang`, `search-relcall-lang`, `search-wf`, and
`search-relcall-wf`, all of which exclude `DisjR`. Rail uses the corresponding
`rail-lang`, `rail-relcall-lang`, `rail-wf`, and `rail-relcall-wf` extensions.
The current GUI has the same three scheduler names, but executes strict S
matrix sources. Its Strict reference view selects the matrix's Flip relation.
Associativity and delay-placement compilation controls remain independent.

## WF metatheory and observations

Each feature module instantiates a shared WF schema whose direct Redex
judgments validate states, goals, substitutions, disequalities, trails,
continuations, and owner stacks. WF threads visible introductions as an
inherited metatheoretic parameter. Reading an owner stack extends visibility
outermost to innermost, rejects duplicate or reused names, and checks the owned
payload under the extended visibility. The carrier stores no complete scope
set, cache, counter, or WF summary.

Owner records and introduced names, answers, force evidence, and frontier
shape are independent structural observations; the enclosing `Owners`
constructor contributes no occurrence of its own. Allocation-event traces are
observed from named steps, rather than reconstructed from a cached state field.
These observations are tested alongside WF preservation rather than used to
define it.

Edge tests compare source and target grammar, WF judgments, and complete raw
named-successor/proof multisets, with positive source coverage. Trace,
terminal, and observation checks remain in the semantic owner that states each
additional claim. Identity syntax alone is not treated as a
conservative-extension proof. These source-level edge laws establish
embedding, conservativity, and provenance; they are not naturality tests.
Naturality requires a derivation transformation at multiple stages and a
commuting square.

## Mirrored semantic test topology

`racket-server/derivations/experiments/dormant-branch-semantics/tests/` mirrors the architecture through node,
edge, join, grammar, scheduler-fiber, overlay and law suites. Additional files
check the derived machines and strict/dormant differences. The account's
root aggregate joins its native source and derivation evidence; the separate
experiments aggregate also invokes early conjunction distribution. See
[the test inventory](../tests/README.md)
for the exact responsibilities and theorem boundaries.

## Compiler and observations

The comparison tests initialize `(Γ F)` terms rooted at `More(Work(...))`
and invoke these native relations directly. The current compiler/application
instead initializes strict `(program Γ (commit (eval ...)))` terms; selecting
a GUI scheduler does not launch this older source. Compiler-driven comparisons
hold lowered goals and definitions fixed without converting running states.

At the outer Frontier tip, `More(PendingDelay(...))` has the native
`force-delay` reduction. Nested delay promotion and scheduling have their own
named reductions. This is different granularity from strict public `advance`.

The local [inspection.rkt](inspection.rkt) projection preserves ownership,
candidates versus committed answers, Done/Last completion, choice activity,
and force evidence. It reuses the application's shared logical-state/Owner/goal
drawing helpers, while all dormant control cases remain here. The earlier
`picture.rkt` is retained for its source-specific picture properties. See
[PICTURE-DESIGN-NOTES.md](PICTURE-DESIGN-NOTES.md).

Fresh allocation is a whole-frontier step. The rule names that frontier
`F_support`; logical-variable occurrences throughout it derive the
allocated-name support. Redex chooses binder names sequentially against that
frontier, records one `Owner` per binder, and therefore remains single-valued
while seeing completed answers, sibling branches, and allocated-but-unused live
variables.

This document records the earlier dormant-branch semantics. The separate
[interpreter and machine derivation](../README.md)
provide interpreters, a generated machine, and partial source correspondence.
Universal correspondence, full allocation transport, and recursive or infinite
observation theorems remain open.
