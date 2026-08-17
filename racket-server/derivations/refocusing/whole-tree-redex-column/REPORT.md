# Whole-tree marked-column pilot report

## Outcome

The selected full-search cell now exists as an inspectable vertical Redex
derivation:

```text
R_m -> D_m -> Z_m <-> M_marked -> B_marked -> B_downarrow
```

The result is positive but deliberately narrower than a production-lattice
adoption decision.  For this marked, no-`relcall` cell, the stratified source
architecture survives decomposition, direct refocusing, explicit machine
specialization, certified transition compression, and fixed-point promotion.
Each arrow has a compositional specification, a separately stated direct
artifact, and executable correspondence checks.  The same shared control
schemas instantiate both the toy kernel and a c-free miniKanren kernel.

The pilot also found and repaired a real presentation defect.  The first
internal continuation grammar admitted many terms that were not meaningful
decomposition or refocusing images.  Continuing to polish that formulation
would have made the later arrows partial by construction.  The replacement is
the complete-context BF/LF architecture described below.  That revised
presentation, rather than the earlier split continuation, is the part worth
carrying into the next experiment.

This is evidence to continue with the architecture, not yet evidence to
replace the full production lattice.  The next discriminating work is the Q
column and feature-naturality layer.

## The source decision that survived

The source keeps unfinished work `W` internal and whole/frontier terms `F` at
the root.  Its categories and contexts are indexed inductively by their input
and output grammatical categories: the sorts are implicit in the grammar,
with no reified sort tags.

The fresh rules distinguish two operational situations:

```text
More(WorkFresh(u,W,tag))
  -> FrontierFresh(u,More(W),tag)

LF[WorkFresh(u,DisjL(S,W),tag)]
  -> LF[DisjL(WorkFresh(u,S,tag),
              WorkFresh(u,W,tag))]
```

The first rule is a boundary move.  Its marker owns everything left in the
whole frontier, so one `FrontierFresh` may cover both the next answer and the
residual computation.  The second is local.  Reassociation would otherwise
make it impossible for one unary wrapper to own exactly the settled branch
and its sibling while excluding outer work.  The rule therefore keeps the
explicit intermediate and attaches the same introduction marker to the two
choice descendants.  The symmetric `DisjR` rule is owned by `search-join`.
Both are named `expose-choice-through-work-fresh`, emphasizing their control
purpose rather than asserting a general scope equation.

Generic reassociation, commitment, hoisting, and rail rules proceed only after
that exposure.  Transition compression may fuse the exposure with a preceding
producer, but the exact marked relation retains the step and label.

## Why BF/LF is the cleaner context grammar

The derivation needs complete actual-hole contexts, not an arbitrary product
of a work zipper and a frontier zipper:

```text
BF ::= More(hole) | frontier-wrapper(BF)
LF ::= More(NFWW) | frontier-wrapper(LF)
WF ::= BF | LF
```

`BF` is a complete W-to-F context whose hole is immediately below `More`.
`LF` is a complete W-to-F context with a first ordinary `Conj` or `Disj`
frame below `More`; any deeper W-to-W context is already part of that one
actual-hole value.  `FF` remains an F-to-F context, and `WFrame` identifies
one adjacent work frame.

This grammar gives the control distinction directly:

| Property | `BF` | `LF` |
| --- | --- | --- |
| Hole position | whole-frontier boundary | branch-local work |
| Innermost work-frame pop | none | exactly one |
| `WorkFresh` action | lift to `FrontierFresh` | traverse or expose local choice |
| Runtime sort/compatibility field | none | none |

The decomposition/result constructors retain genuinely different shapes, but
later stages retain constructors only for operationally distinct control
modes.  No state carries a W/F field, a split continuation compatibility
predicate, a scheduler register, or a hidden ambient-scope cache.

## Constructor flow

The constructor changes remain visible rather than being hidden behind shared
Racket evaluators:

| Focus shape | Decomposition `D` | Refocused `Z` | Exact machine `M` | Compressed `B` |
| --- | --- | --- | --- | --- |
| Boundary work redex | `DecWork(BR,BF)` | `ZWork(BR,BF)` | `MWork(BR,BF)` | phase-specific mode with `BF` |
| Branch-local fresh redex | `DecWork(LFR,LF)` | `ZWork(LFR,LF)` | `MWork(LFR,LF)` | phase-specific mode with `LF` |
| Other local work redex | `DecWork(LR,WF)` | `ZWork(LR,WF)` | `MWork(LR,WF)` | phase-specific mode with `WF` |
| Frontier terminal | `DecFrontier(T,FF)` | `ZFrontier(T,FF)` | `MFrontier(T,FF)` | `BFinal(T,FF)` |

The compressed phase-specific modes are
`BRun(NW,WF)`, `BSettled(SR,WF)`, `BDead(WF)`, `BDelay(W,WF)`, and
`BFinal(T,FF)`.  Those constructors are grammatical control refinements, not
reified source sorts.

## Executable arrow contracts

| Arrow | Translation or correspondence | Compositional specification | Direct Redex artifact | Executable contract |
| --- | --- | --- | --- | --- |
| `R -> D` | `decompose`, `plug-D`; `contract`, `plug-C` | decompose, contract, plug, then decompose | independently repeated decomposed clauses | the four raw `in-hole` factorizations form a unique cover; complete named source successors equal contraction successors; direct D successors equal specification successors |
| `D -> Z` | `D->Z`, `Z->D`, `readback-Z` | `decompose(plug-C(C))` | retained-context `refocus-direct(C,Z)` | codecs/readback agree; direct refocus equals slow plug-and-redecompose; labeled direct/spec Z successors agree |
| `Z <-> M` | `encode-ZM`, `decode-MZ` | transport a Z step across the codecs | independently repeated M refocus/step clauses | codecs are inverse on the exact grammars; labeled Z/M commuting square and reachable prefix images agree |
| `M -> B` | `decode-BM`; reachable correspondence judgment | canonical one-, two-, or three-edge exact-M corridor | symbolic residual dispatch over `BQ` | complete direct/spec successor sets agree; every nonempty span replays exactly to the decoded target; concatenated spans partition exact traces |
| `B -> B_downarrow` | `promote/direct`; `FinalResult(T,FF)` readback | strict finite closure carrying the ordered span list | independent syntax-directed fixed point over `EQ` | closure/direct results agree; one-step unfold removes exactly the first span; root-entry square and terminal readbacks agree |

The source semantics consists of genuine individually named Redex rules under
the grammar-defined `FF`, `WF`, and `LF` contexts.  The presentations do not
share a host-language rule-selection dispatcher.  Host Racket supplies kernel
operations and syntax-building infrastructure; the redex and context grammars
determine which control clause applies, while Redex judgments reify those
grammatical facts and derived transitions.  Removing a judgment or query
projection therefore does not introduce a new choice of focus.

## Labels and compression certificates

Labels are first-class semantic data throughout the exact column:

| Stage | Edge annotation | Meaning |
| --- | --- | --- |
| `R`, `D`, `Z`, `M` | `ell` | one exact control or kernel transition |
| Shared control edge | `(rule owner)` | one of the explicit cell rule/owner pairs |
| Kernel edge | `(kernel kname core)` | exact atomic outcome supplied by the selected kernel |
| `B` | `transition-span(ell_1,...,ell_n)`, `n >= 1` | canonical exact-machine path certificate |
| finite big step | ordered list of `transition-span` values | complete compressed-path certificate |

The executable alphabets and translations live in
[`control-language.rkt`](../whole-tree/reference/marked/control-language.rkt),
[`toy/labels.rkt`](../whole-tree/reference/marked/toy/labels.rkt), and
[`mk/labels.rkt`](../whole-tree/reference/marked/mk/labels.rkt).  `Ktoy`
translates explicitly to the
committed 28-label oracle family.  `Kmk` retains seven distinct atomic labels:
success, failure, unification success, unification blocked by disequality,
unification failure, disequality success, and disequality failure.

Because every compressed edge contains at least one exact edge, compression
introduces no empty administrative loop.  That fact does not by itself prove
termination or characterize divergence.

## P[K] scope

The canonical
[`whole-tree/reference/marked/README.md`](../whole-tree/reference/marked/README.md)
describes the completed parameterized column.
One non-operational control template owns the carrier, BF/LF/WF contexts,
phase grammars, marker traversal, freeze/resume, and search rules.  Handwritten
schema macros instantiate precise Redex languages because language bindings
must be known at expansion time.  No relation is defined over the abstract
template itself.

Each kernel supplies atomic stepping together with its named source-leaf
presentation, an initial state, fresh opening, and kernel-specific
well-formedness.  `toy/` and `mk/` replace every abstract
atomic/state/name leaf before any operational artifact is defined, so mixed
kernel values are rejected by grammar rather than a dynamic kernel tag.

The `Kmk` state is c-free and carries substitution, disequalities,
unification history, and provenance.  The intrinsic front-, middle-, and
back-half arrow suite runs for both `Ktoy` and `Kmk`.  A separate canonical
parity suite checks the seven `Kmk` atomic outcomes against the production core
relation after the test alone restores the production cached scope.

## Validation and inspectable traces

The aggregate parameterized suite is:

```sh
racket racket-server/derivations/refocusing/whole-tree/reference/marked/tests/run.rkt
```

The latest intrinsic run completed 44 RackUnit tests with no failures or
errors.  The canonical aggregate, including four temporary external-oracle
parity tests, completed 48 tests.
Its grammatical-focus litmus counts the four raw `in-hole` factorizations
without invoking `decompose`, counts raw proof trees rather than deduplicated
judgment results, checks `R`/`NW` as a disjoint exhaustive partition, and pins
the complete 28-rule `Ktoy` and 32-rule `Kmk` source inventories.  The broader
suite also runs bounded `redex-check` campaigns and walks complete
deterministic witness traces and every reachable suffix.

The concrete marked-oracle suite remains green as a separate baseline:

```sh
racket racket-server/derivations/refocusing/whole-tree-redex-column/tests/run.rkt
```

Its latest local run completed 70 tests with no failures or errors, including
the larger source, BF/LF, decomposition, refocusing, machine, compression,
fixed-point, and isolated-kernel enumeration campaigns.

The canonical
[`TRACES.md`](../whole-tree/reference/marked/TRACES.md) is generated by
[`export-traces.rkt`](../whole-tree/reference/marked/export-traces.rkt).  It
records the nested-fresh,
late-hoist, rail, right-active-fresh, and real-kernel miniKanren witnesses.  The
exporter aborts unless R/D/Z/M labels and codecs align, compressed spans
partition the exact trace, the finite closure certificate matches that span
list, direct promotion agrees, and all terminal readbacks coincide.  Regenerate
and compare it with:

```sh
racket racket-server/derivations/refocusing/whole-tree/reference/marked/export-traces.rkt \
  | diff - racket-server/derivations/refocusing/whole-tree/reference/marked/TRACES.md
```

The transcript includes the exact before/after trees for boundary fresh
lifting, local marker replication, right-active exposure, late distribution,
and rail turns, as well as compact initial/terminal D, Z, M, B, and big-step
artifacts.

## Claim boundary and next experiment

The present evidence is executable and bounded.  It is not a universal
mechanized proof.  In particular:

- the inductive big-step judgment establishes agreement only when a finite
  result derivation exists; it neither proves termination nor distinguishes
  divergence from stuck or ill-formed inputs;
- the selected cell has no relation-call overlay, so recursive search and its
  infinite observations have not been derived;
- the Q maps for caching `c`, erasing fresh markers, and erasing completed
  history have not been added, nor have their alpha-aware weak simulations or
  anti-stuttering ranks;
- the full feature lattice, conservative-extension checks, join provenance,
  and transformation-naturality squares remain deferred; and
- kernel parameterization demonstrates control independence for `Ktoy` and
  `Kmk`, but it is not a claim that the production lattice has already been
  replaced.

The clean next step is therefore to keep this marked column frozen as the
derived reference, add Q as separately inspectable maps, and then test feature
naturality one additive embedding at a time.  If those squares fail, the
failure should drive another source-grammar revision before any broad
production migration.
