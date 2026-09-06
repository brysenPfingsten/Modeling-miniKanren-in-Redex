# Retained-scope interpreter and corresponding machines

This is the preferred S interpreter candidate. It preserves the previous
strict S correspondence as a checkpoint and develops the source factoring
where a removed Delay's introductions are placed on the running computation
before its body evaluates.

Both derivations use `Yield(O,A,S)` for the eager active Search cell and
reserve `More(Delay(O,R))` for unfinished Frontier work. The eager-tail frame
is `KMergeYield`/`yield`; the corresponding source cases are `mplus-yield`,
`bind-yield`, `render-yield`, and `commit-yield`. These names identify the same
operations and stopping boundaries as before the constructor rename.

Both presentations preserve scope while work runs. In the checkpoint, a
dedicated `prefix(O,c)` context carries O and attaches it to mature Search on
return. Here, the existing owner field of `eval`, `mplus`, or `bind` carries O.
No checkpoint file or matrix coordinate is replaced by this experiment.

The parent [strict-search guide](../README.md) selects this route as the main
entry point, and its aggregate includes this directory's `all.rkt`. Common
grammars, kernels, stage construction and control transformation live in
[shared/](../shared/README.md); fixtures and reusable checks live in
[test-support/](../test-support/README.md). Runtime and derivation modules
depend on those shared implementations directly. Only the explicit source
comparison tests and demo import the earlier matrix source as an oracle.

## Inspectable path from syntax to interpreter

The source-guided reconstruction can be inspected in this order:

1. [source.rkt](source.rkt): the strict source equations and structural bridge.
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

The corresponding functional machine is now the preserved checkpoint for two
further executable stages:

```text
machine.rkt ← decode ← registers.rkt ← structural embedding ← compressed.rkt
```

[register-derive.rkt](register-derive.rkt) generates the explicit PC/register
dispatcher in [registers.rkt](registers.rkt) from the unchanged defunctionalized
program. Each register step decodes to one checkpoint step. The host dispatch
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

## The changed source operation

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
Search/Frontier commitment boundary retain their checkpoint rules. No context
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
existing fresh-name kernel; this experiment does not eliminate those.

## Relationship with the checkpoint and E/N

The structural map `T = erase-prefixes` makes the comparison concrete:

```text
T(prefix(O,c)) = lift_O(T(c))
T(other constructors) = the same constructor with translated computations
```

It does not evaluate anything, including suspended syntax. The intended local
simulation is:

```text
checkpoint q --prefix-value--> q'   implies T(q) = T(q')
checkpoint q --other label--> q'    implies T(q) --same label--> T(q')
```

The source tests check this prescribed square for every reached edge; they do
not search forward through arbitrary target work. The tested finite ordinary-goal
Frontiers are literally equal, including their unforced bodies. For arbitrary
source terms containing pending prefixes beneath Delay, compare via T rather
than asserting literal equality of those suspended bodies.

The key active-computation lemma is ownership equivariance. If c steps at
inherited support `P ++ names(O)`, `lift_O(c)` should step with the same label
at P to the lifted successor. Fresh sees the same ordered support, and the
other active rule cases use associativity of owner concatenation. The
force case uses `lift_O(lift_L(c)) = lift_(O ++ L)(c)`. The rule argument and
finite checks support the lemma; they are not a mechanized universal proof.
Consecutive erased `prefix-value` steps terminate because each removes a
pending prefix node and none creates another.

Restrict this lemma to active computations. Moving ownership naively through
commitment changes S's exact placement: `commit(One(O,σ))` places O on its
terminal Answer, rather than on the Last node. Public commitment rules are
therefore preserved explicitly.

The existing S→E/N maps still account for allocation along owner paths. At the
same caller support, the basic identity is
`Q(lift_O(V),P) = Q(V,P ++ names(O))` for mature Search. The retained source is
an experimental S column, not a replacement for current E/N reduction rules:
those retain unary prefix-value phases for their exact checkpoint squares.
Matching a compressed E/N source is a separate next extension.

## Reproduce and inspect

The expanded aggregate passed **582 test cases** on 2026-09-06: the existing
490 source/interpreter/machine cases, 7 register-generation/decoder cases, and
85 register/compression correspondence cases. Generation freshness checks for
the checkpoint, registerized and compressed artifacts are included. The
before/after register demonstration also passed for success and failure,
including sparse and empty introduction groups.

Checkpoint coverage requires every continuation, resumption, and outcome
family to be applied, as well as every program counter and applicable source
label to be exercised. The new gate checks every admitted register PC and each
prescribed compression span, with exact endpoints and actual work order.

```sh
PLTCOMPILEDROOTS=/private/tmp/strict-factoring-cache: \
  racket -y -l raco -- test \
  racket-server/derivations/strict-search/retained-scope/all.rkt

PLTCOMPILEDROOTS=/private/tmp/strict-factoring-cache: \
  racket -y racket-server/derivations/strict-search/retained-scope/show.rkt

PLTCOMPILEDROOTS=/private/tmp/strict-factoring-cache: \
  racket -y racket-server/derivations/strict-search/retained-scope/derive.rkt --check

PLTCOMPILEDROOTS=/private/tmp/strict-factoring-cache: \
  racket -y racket-server/derivations/strict-search/retained-scope/show-machines.rkt
```

The original example prints both force contractions, the refocused bind frame that
retains the introduction while its operand runs, and the final direct result
where the earlier x remains allocated and the later y is u:1. The paired-machine
example checks the transition diagram while displaying corresponding functional
and refocused states, including their ordinary bind frames and final Frontiers.

Tests compare the source bridge, well-formedness, intermediate D/Z/M/B
transitions, exact incremental Frontiers, and the actual atomic work of the
direct and CPS interpreters. Their test readback records actual closure captures
through an observer without executing a Delay. Defunctionalized and generated
machine configurations instead contain only first-order data and are inspected
directly. Tests exercise every control, continuation, resumption, outcome and
applicable source operation, check the S/E/N structural squares, reject malformed
ancestry/phase inputs, and verify the administrative rank decreases.

The corpus includes empty/unused introductions, sparse ancestry, fresh before
and after suspension, previously allocated variables, nested Delay, saved
right-operand reuse, eager bind, and nested rail orientation. This is finite
evidence for this factoring and its downstream transformations. It does not
establish a general productive-stream theorem or a derivation of the compact
κ/Q/π rail machine.
