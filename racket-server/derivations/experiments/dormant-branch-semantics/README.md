# Earlier dormant-branch semantics

This directory owns the complete **earlier dormant-branch account**: its
native work-tree source, interpreter/machine derivation, correspondence maps,
counterexamples, and semantics-specific tests. The current GUI uses
[strict S matrix scheduler rows](../../matrix/scheduler-source.rkt):
DFS, Flip, and Railroad, with Railroad selected by default. Separate E/N
DFS/Railroad rows and downstream scheduler derivations remain open.
References below to the native lattice describe [source/](source/SEMILATTICE.md);
these derivations do not provide the application's current scheduler dispatch.

The investigation supports a systematic interpreter family, with an important
qualification: its base is a **demand variation** of the retained-scope strict
interpreter. Changing only the strict interpreter's Delay scheduling case
cannot explain the earlier dormant-branch semantics. The strict account matures
both operands and bind residuals before commitment; the earlier lattice can
expose an answer before its sibling runs. The [executable counterexamples](BARRIERS.md) establish this
difference, including a compiled recursive program with an exact self-loop.

Within the new demand account, DFS and Flip differ at one scheduling choice.
The Railroad extension retains left/right positions in the Search and
resumption language. Its orientation erasure yields Flip, both in the derived
source family and independently in the native lattice. The extra state retains
branch-position information; this is not evidence of a stronger answer
scheduler than Flip. Positions are retained **during scheduler switches**;
answer extraction still performs the explicit reassociations.

This is one of the [semantic experiments](../README.md), alongside
[early conjunction distribution](../early-conjunction-distribution/README.md).
It is not another allocation matrix row or a replacement GUI backend.

## Ownership and layout

```text
dormant-branch-semantics/
|-- source/
|   |-- languages/             Native Work/DisjL/DisjR grammars
|   |-- reduction-relations/   Feature, scheduler and relation-call equations
|   |   `-- private/           Source composition and substitution helpers
|   |-- wf/                   Native scope/store judgments
|   `-- inspection.rkt        Work-tree projection using shared drawing helpers
|-- derivation/               Direct, CPS, defunctionalized and generated machines
|                            Independent computation source and structural maps
|-- tests/
|   |-- nodes/ edges/ join/ grammar/ fibers/ overlays/ laws/
|   `-- *.rkt                 Derivation, allocation, strictness and picture checks
|-- BARRIERS.md               Exact limits and counterexamples
`-- all.rkt                  Complete account's validation gate
```

`source/` contains the original dormant work-tree calculus.
`derivation/source.rkt` independently states a computation presentation for
the functional derivation. Its map to the original calculus has a restricted
configuration domain; keeping both makes that claim and its counterexamples
inspectable. Neither is a forwarding wrapper around the strict source.

Tests whose subject is this account—including strict/dormant comparisons—live
in `tests/`. The application and current strict aggregate do not import its
execution providers. The comprehensive headless gate reaches it through the
[experiments aggregate](../all.rkt). Shared generators and runtime-test
observations live in [neutral test support](../../test-support/README.md).

## The common interpreter and its variations

[interpreter.rkt](derivation/interpreter.rkt) starts from the equations in
[retained-scope/interpreter.rkt](../../retained-scope/interpreter.rkt).
Owners, logical states, lexical substitution, eager atomic kernels, eager
relation expansion, answer-private support, and public commitment remain
explicit. The new control policy changes these three demand sites:

1. A disjunction retains a computation for its right operand. It demands its
   left operand first; it does not mature both before merging.
2. A Yield retains a computation for its tail. Merging a Yield retains the
   remaining merge instead of evaluating it before returning the head.
3. Binding a Yield evaluates the continuation of its head and retains the
   recursive bind of its residual. That residual is not matured alongside the
   head before merging.

These are semantic changes from strict to dormant-branch demand, **not CPS conversion,
registerization, or a proved fusion**. This is a small explicit variation of
the existing equations; no uniqueness or globally minimal construction is
claimed.

Suppressing ownership parameters just to show control, the base language is:

```text
Search ::= Empty | One(state) | Yield(answer, computation) | Delay(computation)
computation ::= () → Search

eval(g ∨ h, state) = plus(eval(g,state), λ().eval(h,state))
plus(Empty,r)      = r()
plus(One(s),r)     = Yield(s,r)
plus(Yield(s,t),r) = Yield(s, λ().plus(t(),r))
bind(Yield(s,t),f) = plus(f(s), λ().bind(t(),f))
```

The implementation makes both merge operands computations and then explicitly
demands the selected one. This exposes the operand order in ordinary strict
Racket. The dormant operand and Yield tail are computations; neither is an
object-language Delay. A host transfer to a generated PC is also not a Delay.

Only one delayed-merge equation differs between the base policies:

```text
DFS:  plus(Delay(d),r) = Delay(λ().plus(d(),r))
Flip: plus(Delay(d),r) = Delay(λ().plus(r(),d))
```

Success, failure, candidate extraction, bind, fresh, and calls share their
equations. The native DFS/Flip sources independently share these operations
and differ only in `dfs-delay-left` versus `flip-delay-left`.

Search candidates still have pending obligations. Bind can reject a candidate
without committing anything. Commitment now demands a Yield's computational
tail **under the already emitted prefix**. It creates no Forced node for this
demand. A real Delay ends that round; public advancement crosses it. Direct
`run` still returns a Frontier at a Delay/terminal boundary, while its derived
machine exposes intermediate commitment and work. Thus a direct whole-round
call can diverge after an intermediate machine answer has been committed.

## What Railroad adds

The extension adds a right-active merge computation and a right-positioned
candidate, rather than exchanging saved computations:

```text
base computation:      mplus(O, left, right)       ; demands left
extended computation:  mplusR(O, left, right)      ; demands right
base candidate:        Yield(O, Answer, residual)
extended candidate:    YieldR(O, residual, Answer)
```

The procedure counterpart is `merge/s` with a left/right side. Right-active
merge is rejected for DFS and Flip. The grammars in [source.rkt](derivation/source.rkt)
make the same distinction: `OnlineRail` extends `OnlineBase`, and the base
grammar rejects `mplusR` and `YieldR`, including inside delayed computations.
`RMerge` retains the side and the two saved computations after
defunctionalization. `YieldR` retains which side supplied a mature candidate
until bind/commit consumes it.

For empty Owners, one representative switch is:

```text
                      mplus(Delay(cA), cB)
                          /          \
             Flip:       /            \       Railroad:
       Delay(mplus(cB,cA))        Delay(mplusR(cA,cB))

native: Delay(DisjL(B,A))          Delay(DisjR(A,B))
```

Here the computations A/B remain unevaluated. This diagram omits native
`PendingDelay`/`More` wrappers for readability. Run the exact constructor
example with `racket racket-server/derivations/experiments/dormant-branch-semantics/derivation/show.rkt`.

The current strict Railroad is a separate extension. Its eager Yield tail and
saved mature right Search express different pending work; its resumed merge
also forces the previous left before commitment can expose the saved right.
Similarity between strict `RMerge` and these resumption records does not
establish correspondence with the earlier dormant-branch semantics.

## Derivation and executable relationships

```text
Retained-scope strict interpreter
                |
                | change demand policy; not an equivalence
                v
Earlier dormant-branch semantics
  DFS / Flip interpreters -- retain orientation --> Railroad interpreter
             |                                               |
             +---------------------+-------------------------+
                                   |
                          CPS + defunctionalization
                                   |
                                   v
                          Generated data machine
                                   ^
                                   | structural readback; 0/1 source steps
                                   v
                   Independent source equations and contexts
                                   |
                                   | prescribed spans; allocation-free fragment
                                   v
                   Earlier native DFS / Flip / Railroad lattice
```

| Artifact | Responsibility |
|---|---|
| [source/](source/SEMILATTICE.md) | Native feature/scheduler/relcall languages, reduction relations, WF, structural observations and work-tree inspection |
| [tests/](tests/README.md) | Native source laws, derived-machine checks, strict/dormant counterexamples, allocation evidence and rendering checks |
| [interpreter.rkt](derivation/interpreter.rkt) | Direct equations, real computation closures, and separate public consumer |
| [cps.rkt](derivation/cps.rkt) | Explicit continuations for demand, bind, commitment and resumption |
| [data.rkt](derivation/data.rkt), [defunc.rkt](derivation/defunc.rkt) | Actual closure/continuation families as data; functional kernel Outcomes become native data Outcomes here |
| [derive.rkt](derivation/derive.rkt), [machine.rkt](derivation/machine.rkt) | Shared checked tail-position transformation generates 13 PC clauses and a data dispatch loop; no hand-copied lattice transitions |
| [source.rkt](derivation/source.rkt) | Independently stated grammars, contexts, named contractions, decomposition, plugging, retained scope, public advance and source orientation erasure |
| [functional-source.rkt](derivation/functional-source.rkt) | Structural machine readback, policy/Γ/scope validation, exact prescribed spans and administrative rank |
| [lattice-map.rkt](derivation/lattice-map.rkt) | Structural source/native map, label refinement, public span and administrative weight; explicit domain restriction |
| [orientation.rkt](derivation/orientation.rkt) | Independent full native Railroad→Flip map and exhaustive native label map |
| [BARRIERS.md](BARRIERS.md) | Strictness/divergence counterexamples, allocation and provenance discrepancies |
| [all.rkt](all.rkt) | Native source, derivation, and comparison gates for this complete account, with no runtime import from the GUI |

There is no Outcome conversion adapter. Configurations contain data, including
pending goals, relation environments, continuation frames and resumptions.
Direct/CPS closure description tables exist only in tests to inspect actual
captures. Reachable generated-machine configurations contain data; the decoder
rejects procedures. Neither consults those tables. Reusing the existing tail
transformer and kernel equations does not import an older scheduler
implementation.

The generated machine comes from the functional derivation. The source side
currently supplies its own decomposition and plugging, plus the checked
structural readback; this directory does not claim a second independently
generated refocused machine.

The current correspondence statements are deliberately different in strength:

| Relationship | Strongest current result and its domain |
|---|---|
| Direct ↔ CPS ↔ defunctionalized ↔ generated machine | Exact tested public Frontiers, residual captures and actual work order for each policy; all PCs and record families exercised. General transformation correctness remains a proof obligation. |
| Generated machine → new source | Structural readback on reachable configurations, exact zero-or-one source contraction per machine step, and a strictly decreasing rank on empty spans. Every source label and every in-scope PC is covered. |
| Extended source → Flip source | Explicit orientation erasure; tested one-step equality including all retained-scope ownership witnesses. Owners, Γ, states and tags remain literal. |
| Derived DFS → native DFS | Configuration-level weak correspondence on the closed allocation-free fragment with empty Owners; prescribed administrative and public spans. Full allocation/ownership correspondence is not claimed. |
| Derived Flip → native Flip | Same fragment and strength, with swapping in the delayed merge. |
| Derived Railroad → native Railroad | Same fragment and strength, with both active-side constructors and right-candidate bind/commit. |
| Native Railroad → native Flip | Complete one-step successor lists agree under orientation/label erasure in checked configurations, including all 30 Railroad / 23 Flip rules, full relations and fresh allocation. A strong-bisimulation proof sketch is below. |
| New family → matching native scheduler, with allocation | All 20 retained-scope witnesses × 3 policies preserve ordered atomic attempts and completed world-Frontier observations under explicit scoped alpha and ownership transport. This is full-owner observational evidence, not a pending-configuration bisimulation. |
| Existing Strict ↔ native Railroad | Finite completed-result evidence at specified observations; unrestricted exposed-answer equivalence fails by an exact recursive counterexample. Full work/commit traces already differ on finite goals. |

The machine/source relation covers initial evaluation, internal computation
demand, commitment, halted Frontiers and explicit public advancement. Its
policy is a static index: a completed Frontier need not retain an unused
scheduler value. Stored policy, Γ and inherited scope are checked against
that index and the structural context. The repeated `collect` library driver
is explicitly rejected by this decoder: the source grammar has single
advance, not a collect constructor. Direct/CPS/data/dispatch tests separately
compare finite collection. No pending collect obligation is erased by a map.

## Why the administrative spans are justified

For the functional machine, define `R(M,c)` by `machine->source(policy,M)=c`
and the decoder's policy/environment/scope invariant. Each of the explicit PC
cases supplies either `[]` or `[source-label]`; tests execute that exact span
and compare the next configuration. There is no forward search for matching
answers. The rank counts the remaining demanded-resumption constructors,
outcome dispatch, and return reconstruction. Each empty span strictly lowers
it. Recursive relation expansion is a semantic step, never hidden in this
rank or the host trampoline.

For the source/native fragment, `mplus-one` packages the same candidate already
present in native `DisjL`/`DisjR`; `commit-delay` wraps the same exposed pending
Delay. These have identical native images. The other contractions map to one
named native contraction. Atomic `eval-atom` is refined to its actual shared
kernel branch, including failure and disequality outcomes.

An inspectable example is:

```text
commit(mplus(One(A), cB)) → commit(Yield(A,cB))

both decode to: More(DisjL(Returned(A), Work(B)))
```

The global administrative weight counts mplus and commit nodes, and weights
advance by its remaining Frontier spine plus one. It decreases on candidate
packaging, Delay wrapping, and each administrative prefix traversal. No
normalizer descends below Delay or demands a Yield tail on its own.
Public advance has a separately prescribed span: invocation, one traversal
per existing Emit/Forced node, and one `advance-delay` contraction. It matches
the native public `force-delay` edge, preserving the stopping boundary.

For native Railroad/Flip, define `Rrail(L,F)` iff
`F=rail->flip/config(L)`. `DisjR(O,L,R)` maps to
`DisjL(O,ψ(R),ψ(L))`; the other constructors are homomorphic. A right-active
context becomes a left-active context with its sibling reflected. Owner-root
attachment commutes with this map. The map preserves the set of logical names
used by whole-Frontier freshness, and leaves goals, Γ and stores untouched.
Each oriented contraction maps to the listed Flip contraction. Conversely,
the same active path and constructor case determines the Railroad successor.
This gives a rule-by-rule strong-bisimulation proof plan after label mapping;
the tests check both complete successor lists rather than only one direction.
The relation intentionally forgets GUI branch-position observations.

## Discrepancy inventory

Numbers refer to: **1** representation/alpha; **2** administrative/phase;
**3** implementation of the same scheduler; **4** semantic/observable change;
**5** apparent bug.

| Discrepancy | Classification and evidence |
|---|---|
| Flip swaps children; Railroad changes active side | **3**, with extra position information erased by the two orientation maps. It is visible to a position-sensitive GUI observer. |
| Strict operands and bind tails are eager; lattice siblings/residuals are dormant | **4**. Finite work/commit counterexamples and compiled unguarded self-loop. |
| Search candidate versus committed answer | **2** within the new family/native fragment: Yield/Returned may still be under bind. Pending failure emits nothing. Moving strict commitment across sibling work would instead be **4**. |
| Yield packaging and unfinished Frontier wrappers | **1/2** under the explicit decoder. Unary More remains unfinished Frontier work; Done and Last remain distinct terminal forms. |
| Internal computational demand versus public Delay advancement | **2** for the new derived/native spans; no extra public round for a Yield tail. Strict's eager internal force has **4** work/commit consequences. |
| Bind and merge continuation records versus work-tree contexts | **1/2**, checked structurally in the new derivation. Right-active bind retains the oriented residual. |
| Relation environment/call representation | **1/2**: explicit Γ and eager expansion are retained. Calls introduce no implicit Delay; compilation supplies any suspension. |
| Active-path versus whole-retained-Frontier fresh names | **1** on tested scoped observations. A single global renaming is insufficient; failed branches can disappear and names can be reused. |
| Shared Owners on Forced versus a following Emit/merge | Requires an explicit scope-transport relation beyond alpha (**1/2** for world observations). Exact node-provenance observations distinguish them (**4** at that observation level). The simple native map has an asserted counterexample. |
| Apparent production bug | No production semantic repair was made. Negative correspondence checks record their discrepancy rather than changing either endpoint. |

## Validation and remaining obligations

Before the architectural relocation, the interpreter investigation passed
**191 cases** within a **3,693-test** headless checkpoint on 2026-09-07.
That count predates the current combined account gate. See the
[test lanes](../../../tests/TEST-LANES.md) for validation of the relocated
sources, derivation, and tests; the historical counts are not additive.

Run from the repository root:

```sh
raco test racket-server/derivations/experiments/dormant-branch-semantics/all.rkt
racket racket-server/derivations/experiments/dormant-branch-semantics/derivation/derive.rkt --check
racket racket-server/derivations/experiments/dormant-branch-semantics/derivation/show.rkt
```

The finite corpus includes simple/nested choices, both delay sides, repeated
resumption, failure, multiple answers, pending bind, relation and mutual
relation calls, fresh across Delay, empty/unused introductions, sparse
ancestry and answer-private allocation. Tests distinguish work, candidates,
committed prefixes, public pauses, terminal shapes and actual active work.
Guarded infinite tests state bounded observations and a specific DFS cycle;
unguarded negative tests close exact native self-loops. A fuel limit alone is
never used as proof of divergence or finite completion.

The focused source/native gate exercises all 32 distinct native labels across
the three policies and all five source administrative labels. Allocation and
constrained-unification cases outside the full-trace fragment are explicitly
local one-step checks. The functional/source gate exercises all 24 source
labels and 12 in-scope machine PCs, checking 1,575 singleton semantic spans
and 2,094 decreasing administrative spans in its finite corpus. The independent
functional gate also checks the thirteenth PC for library collection.

Remaining formal obligations are:

1. General CPS/defunctionalization correctness for all well-formed programs,
   including preservation of the direct closure scope interface.
2. A quantified source/machine adequacy and divergence-sensitive weak
   bisimulation proof using the explicit spans and ranking function.
3. Universal source/native fragment correspondence, including decomposition,
   progress/reflection and the shared atomic-kernel lemmas.
4. Universal source-family and native orientation bisimulations, with the
   freshness and context lemmas stated above.
5. A full pending-configuration relation combining scoped alpha and exact
   allocation-world/provenance transport. Completed world observations alone
   do not supply this relation; the current raw map fails beyond its fragment.
6. A separately hypothesized guarded strict-to-online observation theorem.
   It must specify answer order, Delay rounds, commitment and provenance
   observations; unrestricted correspondence is disproved.
7. General productivity/fairness and coinductive stream results. The guarded
   witnesses and finite Big results elsewhere do not establish these.

The GUI's association and delay-placement settings remain a separate
compilation coordinate. The new interpreters receive an already compiled
goal and explicit definitions; scheduler choice does not rewrite them.
[Compiler-driven barriers](tests/barriers-tests.rkt) hold compilation fixed, and the
[existing application gate](../../../tests/scheduler-integration-tests.rkt)
retains the full profile/scheduler combinations. No GUI runtime is redirected
through these experimental interpreters.
