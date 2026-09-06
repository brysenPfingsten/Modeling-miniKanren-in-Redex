# Strict S derivation: goals, search, and settled output

This is the earlier explicit-prefix S checkpoint. Start new work with the
[retained-scope account](../retained-scope/README.md), whose source and
interpreter keep introductions on the active computation itself. This
checkpoint remains executable for comparison; its shared kernels, control
transformation, and test fixtures now live outside this directory.

This route derives a strict interpreter through ANF, CPS, defunctionalization,
explicit transitions, and registers with a PC trampoline. Evaluation produces
active search. A separate executable commitment operation constructs the
settled prefix returned by `run`. Bind never consumes settled output.

The [independent S/E/N matrix](../matrix/README.md) remains a family of data
representations and transition systems. The functional stages are a source
for a Danvy derivation, not another allocation representation. The older
[N functional experiment](../a7-a9/README.md) remains a comparison; its host
binding/kernel interfaces are not part of this route's data-machine claim.

## Three grammars and the commitment boundary

With `O = Owners(Owner(intro,tag), ...)` and `A = Answer(O,state)`:

```text
g ::= atomic | fresh(xs,g) | conj(g,g) | disj(g,g) | suspend(g)

S ::= Empty(O) | One(O,state) | Yield(O,A,S) | Delay(O,R)

F ::= Done(O) | Last(Owners(),A) | Emit(O,A,F)
    | Forced(O,F) | More(Delay(O,R))
```

Goals are program syntax. A goal disjunction becomes strict evaluation of two
operands followed by merge; it does not become a dormant scheduler branch.
`S` is active search. `One` and the eager candidates in `Yield` can still
fail, expand, or delay when a pending bind applies its right goal.
`F` is settled output with at most one exposed unfinished tip. Its prefix
contains answers whose remaining goal obligations have been discharged.

`Yield` is an eager active-search constructor, not an emission event.
`More(Delay(O,R))` denotes unfinished Frontier work and occurs only in `F`.
This avoids using the same Emit/Last values with two contextual meanings.
The independent matrix uses the same `Yield(O,A,S)` constructor. The
correspondence maps preserve its name, ordering, ownership, and eager tail.

The executable boundary is:

```text
run(g) = commit(eval(g))
commit(Empty(O))       = Done(O)
commit(One(O,state))   = Last(Owners(),Answer(O,state))
commit(Yield(O,A,S))   = Emit(O,A,commit(S))
commit(Delay(O,R))     = More(Delay(O,R))
```

Strict host evaluation finishes the entire eager search chunk before
`commit` begins. Commitment performs no goal evaluation, merge, bind, or
forcing. It stops at the actual Delay and leaves its resumption as active
search. No pending bind surrounds a committed candidate: obligations for
delayed candidates remain inside the retained resumption.

In CPS this boundary is a continuation. Defunctionalization makes it
`KCommit(k)`; `KCommitEmit(O,A,k)` reconstructs the settled tail.
The generated machine has a real `commit/d` control point. Its initial
continuation is `KCommit(KDone())`. Role is therefore represented in
constructors and executable transitions, not supplied by readback polarity.

## Incremental interface and strictness

| Operation | Behavior |
| --- | --- |
| `run(goal, #:owners O, #:state state)` | Mature the whole required eager search chunk, commit it, return F without forcing its tip. |
| `resume-once(F)` | Preserve Emit/Forced prefix; at More(Delay(O,R)), run R, commit its mature result, and retain O on a new Forced. Terminal F is unchanged. |
| `collect-all(F)` | Explicitly repeat the exposed crossings to obtain a completed finite frontier. |

Both disjunction operands mature before merge. Yield tails are eager.
Bind evaluates its head continuation result and its recursive residual before
merging them. Only object-language Delay suspends search work.

Internal `force` runs a resumption and restores its local Owners on active
search; it records no observation event. Public resumption keeps those Owners
on Forced and commits the unprefixed body result. One exposed crossing may
perform several internal forces while completing nested strict merge/bind.
Forced counts exposed crossings, not every host procedure invocation.

Advance and collection traverse only F. They retain each settled answer and
its position while changing the unfinished suffix. Raw resumptions return S,
never an F to be fed back into bind. Collection can diverge; it is an explicit
consumer, not the basic interpreter interface.

## Inspectable stages

| Stage | Artifact | Representation change |
| --- | --- | --- |
| Direct | [00-direct.rkt](00-direct.rkt) | Functional continuations/resumptions; distinct S and F; explicit commitment |
| ANF | [01-anf.rkt](01-anf.rkt) | Name strict operand, resumption, commitment, and consumer results |
| CPS | [02-cps.rkt](02-cps.rkt) | Every control operation, including forcing and commitment, returns through a continuation |
| Inventory | [CLOSURES.md](CLOSURES.md) | Lambda sites, captures, continuation roles, and all data fields |
| Defunctionalized | [03-data.rkt](03-data.rkt), [03-defunc.rkt](03-defunc.rkt) | Continuations, resumptions, bind functions, outcomes, and handlers become explicit data and dispatch |
| Transitions | [04-machine.rkt](04-machine.rkt) | Tail calls become Call records and step transitions |
| Registers | [05-registers.rkt](05-registers.rkt) | Five operand registers and a PC dispatch loop |
| Generator | [derive.rkt](derive.rkt) | Reify the actual local defunctionalized bodies; reject control calls in primitive positions |

The register trampoline transfers between program counters. It introduces no
bounce closure or object Delay. All jump arguments are evaluated before any
register mutation; unused operand slots are cleared. Fuel/step counts are
runner diagnostics, not search observations.

## Ownership equations and their location

State remains `(state sub dis trail tag)`. Ordered local Owner groups retain
binder grouping, provenance tags, and empty introductions. `inherited`
caches the names on the enclosing Owner path; it is not a State field.
Answer-local Owners do not reserve names in siblings or residual search.

`prefix(O,S)` now operates only on active search. It concatenates O with
the root Owners of Empty, One, Yield, or Delay, preserving group order.
It does not move provenance into an Answer or touch a settled frontier:

- Empty retains the ancestry of that failed branch. A later merge may discard
  the failed operand according to the existing S merge-empty rule.
- One retains ancestry around its still-intermediate success; a subsequent
  bind needs that ancestry for evaluation and fresh allocation.
- Yield's root Owners apply to both its candidate and its residual; private
  Answer Owners remain private.
- Delay's root Owners scope the suspended computation. Restoring them after
  internal force preserves the enclosing path. This equation applies to
  reachable captures with matching ancestry, not arbitrary resumption moves.

Two further provenance movements are explicit semantic equations.
Merge of a left Yield distributes that left branch's common Owners into
its candidate Owners and its residual root before merging with the right
operand. Both left descendants retain their former path, while the unrelated
right operand does not acquire the left branch's allocation. This is the
independent S `mplus-yield` rule, with no sorting or deduplication.

Only commitment moves One's root Owners into the terminal Answer and places
empty Owners on Last. A terminal answer has no residual needing common
ownership; the complete ordered groups and tag data remain on its unique
answer path. This is the matrix's `commit-one` equation (with the same
ownership placement as its earlier `render-one`), applied
after pending goal obligations have finished. The former prefix-on-Last
shortcut is gone. Commit of Yield preserves both common and answer Owners.

Public Forced retains the crossed Delay's Owners as ancestry of the resumed
frontier. Prefixing them into the body as well would duplicate that path.
The transition checks compare exact S ownership placements, including failed
branches, shared groups, empty groups, and answer-local fresh allocations.

## Functional and data boundaries

[kernel-equations.rkt](../shared/kernel-equations.rkt) specializes the preserved S
primitive equations with native result producers. Direct/ANF/CPS use
functional outcomes. Stage 03 constructs Failure/Success data directly and
dispatches FEmpty/SOne handlers. There is no runtime conversion or functional
outcome hidden in a machine configuration.

The matrix independently uses native Failure/Success data in its kernel and
transition helpers. Static reuse of equations does not require sharing a
higher-order result representation across all stages.

Fresh binds lexical `x:` names and substitutes fresh logical `u:` names,
respecting shadowing. S retains grouped structural ownership; E records
cumulative ordered support; N records positions and a counter. Their explicit
maps erase different information. These allocation choices are separate from
CPS, defunctionalization, and the choice of public frontier interface.

## Correspondence and validation scope

[correspondence.rkt](correspondence.rkt) structurally maps active S and settled
F to the independent matrix's search and observation computations.
It unfolds resumption data into syntax without running it. The runtime
constructors and continuation frames determine the map's domain; there is no
caller-supplied root polarity. KCommit corresponds to the independently
stated source context `commit E`; pending More(Delay) is now a native
Frontier normal form on both sides. Advance and collection map to explicit
source operations, and every public operation finishes without a test-side
stopping condition.

[Transition checks](transition-tests.rkt) compare every reachable generated
machine step on the named witnesses with its prescribed zero or one named
source contraction in the independent refocused S machine. Only native
administrative traversal may surround that contraction. The tests never
search through extra semantic work for a matching future state. They also
check the existing fieldwise S/E/N maps and
their composition at intermediate configurations. No evaluator calls or
source normalization are hidden in the structural readback.

[machine-correspondence.rkt](machine-correspondence.rkt) additionally maps
actual functional controls and continuation fields directly into refocused
M controls and Frame/K fields. It does not reconstruct and decompose a whole
source term. KPrefix maps to the native strict `prefix(O,E)` frame, and
KCommit maps to `commit E`. The source now applies ownership to returned
Search instead of moving it onto a running computation. Raw public and bind
resumptions expose their bodies without synthetic force/redelay steps.
Separate tests align the resulting administrative phases and check the common
public stopping boundary. See the [factoring audit](../COMMITMENT.md#audit-of-the-remaining-differences)
for the remaining representation choices and proof obligations.

Run the aggregate and artifact checks with:

```sh
raco test racket-server/derivations/strict-search/s-functional/all.rkt
racket racket-server/derivations/strict-search/s-functional/derive.rkt --check
racket racket-server/derivations/strict-search/s-functional/show.rkt
```

The earlier functional-boundary checkpoint passed 12,488 S tests and 18,940
parent strict tests on Racket 9.3. The current checkpoint also includes the
native syntactic commitment boundary and direct machine correspondence;
its final aggregate result is recorded in [PIPELINE.md](../PIPELINE.md).

The fixtures include intermediate success followed by failure, a delayed
continuation that changes scheduling, strict sibling evaluation, nested
orientation, allocation, and preservation of every settled prefix across
resumption. They check exact work order and incoming States at each exposed
boundary, native data configurations, all control/closure families, generated
register decode squares, and finite S/E/N comparisons.

General adequacy, transformation correctness, capture coherence, and weak
simulation/commutation remain theorem obligations. Finite checks do not prove
productive infinite behavior, online fusion, relcall semantics, or correctness
of an independently derived primitive unifier. This repair introduces no new
scheduler policy and performs no fusion of active search with settled output.
