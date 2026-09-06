# Retained-scope interpreter and corresponding machines

This is the selected S, Search/rail account. When internal force removes a
Delay, its introductions remain on the running computation before the body
evaluates. The parent [research guide](../README.md) owns the artifact
inventory, current coordinate status, generation commands, and reading order.

Both derivations use `Yield(O,A,S)` for the eager active Search cell and
reserve `More(Delay(O,R))` for unfinished Frontier work. The eager-tail frame
is `KMergeYield`/`yield`; the corresponding source cases are `mplus-yield`,
`bind-yield`, `render-yield`, and `commit-yield`. These names identify the same
operations and stopping boundaries in both presentations.

Both presentations preserve scope while work runs. The existing owner field
of `eval`, `mplus`, or `bind` carries O; there is no pending `prefix` context.

The parent [strict-search guide](../README.md) selects this route as the main
entry point, and its aggregate includes this directory's `all.rkt`. Common
grammars, kernels, stage construction and control transformation live in
[shared/](../shared/README.md); fixtures and reusable checks live in
[test-support/](../test-support/README.md). Runtime and derivation modules
depend on those shared implementations directly. The native S/E/N matrix
now uses the same source factoring. Its independently stated S equations and
stages are checked against this checkpoint; the functional interpreter does
not execute any matrix source or machine.

## Inspectable path from syntax to interpreter

The source-guided reconstruction can be inspected in this order:

1. [source.rkt](source.rkt): the strict source equations and owner lifting.
2. [stages.rkt](stages.rkt): the source instantiated in the existing
   decomposition/refocusing construction, giving D, Z, M, and B.
3. [cps.rkt](cps.rkt): the specialized functional continuations corresponding
   to those strict operations and contexts.
4. [interpreter.rkt](interpreter.rkt): direct-style equations with those
   continuations discharged through ordinary calls and returns.

The functional pipeline now continues explicitly:

```text
interpreter.rkt → cps.rkt → data.rkt + defunc.rkt → machine.rkt
                                                    │
                                             functional->M
                                                    │
source.rkt → decomposition → refocused M ─────────────┘
```

The direct/CPS reconstruction and defunctionalization are manual passes.
[derive.rkt](derive.rkt) mechanically generates the first-order machine from
the actual defunctionalized control bodies. Neither functional evaluator calls
a reduction relation or another machine driver.

[machine-correspondence.rkt](machine-correspondence.rkt) maps every functional
control and continuation into native refocused control and Frame/K fields.
Each functional transition corresponds to either one prescribed named source
operation or administrative identity, with only native structural traversal
around it. [readback.rkt](readback.rkt) independently reconstructs whole source
terms; the two maps agree on the corpus. No observer descriptions or suspended
procedure calls occur in these data-machine maps.

[CORRESPONDENCE.md](CORRESPONDENCE.md) states the configuration relation,
continuation mapping, labelled diagrams and administrative progress measure.
The checks now cover complete intermediate machine configurations. A universal
proof of domain preservation and correspondence remains an obligation.

## Registerization and first compression

The corresponding functional machine is the reference for two further
executable stages:

```text
machine.rkt ← decode ← registers.rkt ← structural embedding ← compressed.rkt
```

[register-derive.rkt](register-derive.rkt) generates the explicit PC/register
dispatcher in [registers.rkt](registers.rkt) from the defunctionalized
program. Each register step decodes to one functional-machine step. The host dispatch
loop and object-language Delay remain separate.

[compression-derive.rkt](compression-derive.rkt) checks and rewrites one
redundant atomic outcome-handler sequence, then reuses that generator to emit
[compressed.rkt](compressed.rkt). It replaces three atomic dispatch steps with
one, reducing thirteen PCs to ten. The step ends at the original `return/d`
configuration, with its continuation still pending. All continuation and
resumption families remain.

[compression-correspondence.rkt](compression-correspondence.rkt) defines the
structural maps and exact original span for each compressed transition. The
tests check these prescribed one- or three-step spans, their operation labels,
scope and actual work, rather than searching for a matching later result.
[REGISTERIZATION.md](REGISTERIZATION.md) gives the diagrams, termination
argument, concrete before/after example, reproduction commands, and remaining
proof obligations. [show-register-compression.rkt](show-register-compression.rkt)
prints the paired atomic traces with commitment still pending.

## Retaining introductions on active computation

Let `O ++ L` concatenate introduction groups, preserving their names, order,
group boundaries, and tags. `lift_O` prepends O to the root owner field of an
active computation or Search. It passes through a `force` wrapper, whose own
syntax carries no owners:

```text
lift_O(eval(L,g,σ))     = eval(O ++ L,g,σ)
lift_O(mplus(L,c₁,c₂)) = mplus(O ++ L,c₁,c₂)
lift_O(bind(L,c,g))     = bind(O ++ L,c,g)
lift_O(Empty(L))        = Empty(O ++ L)
lift_O(One(L,σ))        = One(O ++ L,σ)
lift_O(Yield(L,A,c))     = Yield(O ++ L,A,c)
lift_O(Delay(L,c))      = Delay(O ++ L,c)
lift_O(force(c))       = force(lift_O(c))

force(Delay(O,c))      → lift_O(c)
```

There is no pending `prefix` computation or context in this source language.
Attaching introductions to an existing mature value remains part of mplus's
ordinary equations. Common introductions are never distributed individually
onto the two operands or mixed with answer-private introductions.

Strict left-then-right disjunction, eager Yield tails, eager bind, and the
Search/Frontier commitment boundary are explicit source rules. No context
descends beneath Delay. Public advancement still crosses only the exposed tip:

```text
advance(More(Delay(O,c))) → Forced(O,commit(c))
```

The retained `Forced` already carries O. Applying `lift_O` to its body as well
would duplicate the introduction. The same consideration governs collection
and delayed bind.

## What interpreter the source suggests

The three possible delayed bodies created from goals are initially rooted at
`eval`, `mplus`, or `bind`, with empty local Owners. Each body therefore becomes
a function accepting the root Owners O and inherited support P at entry:

```text
REval(g,σ)(O,P)
  = eval(g,σ,O,P)

RMerge(right,left)(O,P)
  = mplus(right, force(left,P ++ names(O)), O,P)

RBind(r,f)(O,P)
  = bind(r(empty,P ++ names(O)), f,O,P)
```

These equations follow the three source roots. RMerge evaluates the required
force before applying mplus; RBind evaluates its operand before applying bind.
The saved right Search in RMerge has already matured, as required by strict
disjunction.

Internal force and public advancement use different placements of the same
scope:

```text
force(Delay(O,r),P)
  = r(O,P)

advance(More(Delay(O,r)),P)
  = Forced(O,commit(r(empty,P ++ names(O))))
```

The corresponding CPS force tail-calls `r(O,P,k)`. It has no continuation
waiting to prefix the returned value. The root ownership is already present
in the computation, and an ordinary merge or bind continuation retains it
when an operand is being evaluated. Defunctionalization produces the ordinary
KMergeForced/KBindForced frames carrying that root ownership, and preserves
KCommit and strict operand continuations. There is no KPrefix data constructor.

This is a changed resumption interface: direct resumptions accept `(O,P)`;
CPS resumptions accept `(O,P,k)`. They are context-parameterized suspended
computations. Only Delay suspends search work. They do not cache an inherited
`here` value. Public consumers instead reconstruct inherited support by
following common Owners through Emit and Forced, excluding answer-private
Owners. Ordinary evaluator calls still use a derived support list and the
existing fresh-name kernel.

## Representation maps and remaining domain argument

The active-computation obligation is ownership equivariance. If c steps at
inherited support `P ++ names(O)`, `lift_O(c)` should step with the same label
at P to the lifted successor. Fresh sees the same ordered support; the other
active cases use associativity of owner concatenation. Internal force uses
`lift_O(lift_L(c)) = lift_(O ++ L)(c)`. The rule argument and finite allocation
checks support this lemma; they are not a mechanized universal proof.

Restrict this argument to active computations. Moving ownership naively
through commitment changes S's exact placement: `commit(One(O,σ))` places O
on its terminal Answer rather than on Last. Public commitment rules therefore
remain explicit.

The existing S→E/N maps account for allocation along owner paths. At the same
caller support the basic identity is
`Q(lift_O(V),P) = Q(V,P ++ names(O))` for mature Search.
[machine-correspondence-tests.rkt](machine-correspondence-tests.rkt) checks
structural squares for complete configurations. The matrix's E/N sources
use the same force boundary without unary prefix phases. The
[matrix checkpoint gate](../matrix/retained-scope-tests.rkt) goes beyond
structural squares: it checks actual S/E/N source and machine transitions
against this checkpoint, including the independent direct S→N map. Each
functional step prescribes one source label or administrative identity; the
native comparison performs only the specified operation and structural
normalization. There are still no separately derived E/N functional
interpreters or register programs.

## Examples and validation

[show.rkt](show.rkt) displays internal force and the native bind frame that
retains an introduction while its operand runs; the later fresh variable
must account for that allocation. [show-machines.rkt](show-machines.rkt)
displays corresponding functional and refocused configurations and checks
their prescribed transition diagram.
[show-register-compression.rkt](show-register-compression.rkt) prints paired
atomic success/failure traces with commitment still pending.

[source-tests.rkt](source-tests.rkt) checks native R/D/Z/M/B transitions,
allocation support, owner lifting, and exact incremental Frontiers.
[interpreter-tests.rkt](interpreter-tests.rkt) compares direct/CPS boundaries,
suspended bodies, and actual atomic work. Its test observer records real
closure captures without executing a Delay.
[defunc-tests.rkt](defunc-tests.rkt) extends those checks to first-order data
and generated machine execution.
[machine-correspondence-tests.rkt](machine-correspondence-tests.rkt) checks
every reached configuration, prescribed source labels, administrative rank,
constructor coverage, and invalid ancestry/phase rejection.
The [register tests](register-tests.rkt) and
[compression tests](register-compression-tests.rkt) check decoding, update
order, exact one/three-step spans, and work preservation.

The [shared witnesses](../test-support/witnesses.rkt) cover empty and unused
introductions, sparse ancestry, fresh across Delay, existing variables,
saved-right reuse, eager bind, terminal structure, and nested rail
orientation. [all.rkt](all.rkt) aggregates this account's checks, including
freshness of its three generated programs; commands are in the
[parent guide](../README.md#generated-artifacts-and-reproduction).

These are finite checks of the selected account and its downstream
transformations. General domain preservation, administrative progress on the
native side, universal S/E/N correspondence, productive streams, and compact
κ/Q/π rail compression remain obligations. The aligned
[matrix Big](../matrix/big/README.md) supplies finite judgments and certificate
checks for these source rows; it does not add a separate register-to-Big map
or a productive-stream theorem.
