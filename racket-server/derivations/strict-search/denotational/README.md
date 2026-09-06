# A function-based denotational predecessor of strict Search

This is a predecessor of the earlier numeric route. The preferred current S
source and interpreter are in [retained-scope/](../retained-scope/README.md).

This directory goes one step before the direct interpreter. Goals are
semantic functions, kernel outcomes and Search alternatives are Scott-encoded
functions, and exact readbacks are Scott-encoded functions. Suspensions contain
ordinary nullary functions. States, fresh variables, and atomic requests remain
primitive values; encoding integers, substitutions, or the unifier itself as
Church data is unnecessary for this control derivation.

The route is:

```text
compositional goal meanings + function-encoded Search and readback
  → goal syntax/eval + algebraic Search/readback
  → functional-search/direct-interpreter.rkt
  → strict-search/a7-a9/01-anf.rkt → 02-cps.rkt → … → 05-registers.rkt
```

This predecessor has a focused comparison gate, also included in the parent
strict aggregate. Its native functional kernel protocol is shared with the
direct interpreter and downstream strict stages.
The older `natural-interpreter.rkt` and `closure-interpreter.rkt` experiments
use dormant operands and thunked More tails, so their equations are not used
as the strict source here.

## The programs

| File | Role |
| --- | --- |
| [semantics.rkt](semantics.rkt) | Goal combinators, Scott Search/readback, strict merge and bind, and executable fixed-point unfolding. |
| [kernel.rkt](kernel.rkt) | Import/export boundary for the shared native kernel and functional outcome constructors. |
| [bridge.rkt](bridge.rkt) | Compositional `denote` from existing goal syntax, Search reification/reflection, and readback reification. |
| [observe.rkt](observe.rkt) | Finite inspection of explicit Delay bodies; no fuel in the semantics. |
| [tests.rkt](tests.rkt) | Independent direct-interpreter and final-register comparisons, work ordering, representation checks, and recursive witnesses. |
| [show.rkt](show.rkt) | A native functional program, eager-work trace, nested rail, and a productive recursive Search. |

```sh
raco test racket-server/derivations/strict-search/denotational/all.rkt
racket racket-server/derivations/strict-search/denotational/show.rkt
```

There is no call to the direct evaluator in `semantics.rkt` or `bridge.rkt`.
The latter translates syntax into semantic combinators. A Fresh body is
translated when it is applied to its newly allocated variables.

## Kernel outcomes

A native kernel has the direct-style interface `K : Request × State → Outcome`.
Its result is a function selecting a nullary failure handler or passing its
state to a success handler:

```racket
(define (failure-outcome)
  (lambda (on-failure _success) (on-failure)))
(define (success-outcome state)
  (lambda (_failure on-success) (on-success state)))

(define (atomic request)
  (lambda (K state)
    ((K request state)
     (lambda () (empty-search (State-next state)))
     one-search)))
```

The kernel finishes before its outcome is applied. An outcome selector holds
an already-computed result; applying it again does not rerun the kernel.
The failure handler preserves the incoming allocation supply. Neither handler
is a Search Delay, and the kernel does not take a continuation argument. This
changes the result representation while retaining direct-style evaluation.
Mathematically the kernel result domain remains the lifted sum `(1 + Σ)⊥`:
failure, success with a state, or divergence before an outcome is returned.

`semantics.rkt` exports the two outcome constructors for native custom kernels.
Their definitions live in the shared
[`functional-search/outcomes.rkt`](../../functional-search/outcomes.rkt).
Every `#:kernel` argument here and in the direct interpreter uses this same
functional result protocol. The default kernel constructs outcomes directly
for success/failure requests and returns an `Atom` callback's outcome unchanged.
An `Atom` callback therefore has type `State → Outcome`; it completes its work
before returning the result function. For example:

```racket
(atom (lambda (state)
        (success-outcome (struct-copy State state [tag 'answer]))))
```

The syntax/data-facing `bridge.rkt` runners pass the chosen kernel through
unchanged. There is no conversion from `#f` or `State` into an outcome in the
semantic source, default kernel, bridge, or tests. Algebraic success/failure
alternatives would enter through an explicit later defunctionalization of the
outcome functions.

## The domain and its information order

Fix a pure deterministic kernel and a state domain `Σ`, including the exact
substitution, constraints, trail, tag, and next-allocation supply. Treat `Σ`
and natural numbers as discrete domains of primitive values. Let `Σ*` be the
discrete domain of **finite** answer lists.

A completed eager evaluation exposes a finite Yield spine ending in Empty,
One, or Delay. This gives a convenient standard recursive domain equation:

```text
D ≅ (Σ* × (Nat + Σ + D))⊥
```

The three sum alternatives are distinct tags: an Empty supply, a final One
state, or the denotation of a Delay body. The outer lifting adds divergence
before any mature Search is produced. Equivalently, write the elements as:

```text
⊥
empty-end(answers, n)
one-end(answers, σ)
delay-end(answers, d)       where d ∈ D
```

Bottom is below every element. Nonbottom elements compare only when they
have the same finite answer list and the same end tag. Terminal payloads
must agree exactly; Delay payloads compare recursively by the order on D.
The usual least solution includes infinite chains of Delay unfoldings, with
a finite mature chunk at every produced boundary. It does not introduce an
infinite eager Yield spine as a successfully returned Search.

The familiar constructors are operations on this domain:

```text
Empty(n)           = empty-end([], n)
One(σ)             = one-end([], σ)
Delay(d)           = delay-end([], d)
Yield(σ, ⊥)         = ⊥
Yield(σ, (xs, end)) = (σ :: xs, end)
```

Thus `Delay(⊥) ≠ ⊥`, while `Yield(σ, ⊥) = ⊥`. A nullary function in the
executable presentation represents the Delay payload without computing it
while the enclosing Search value is constructed. This is ordinary lifting,
product, sum, and recursive-domain machinery; the finite-chunk presentation
makes the strictness requirement explicit.

`Empty(n)` retains the original branch allocation observation. It is not a
count of answers or a recursion budget. `mplus(Empty(n), y)` discards that
branch's supply and returns y's own world. Removing n would choose a coarser
observation than the current interpreter.

## Compositional equations and recursion

With K fixed, a goal denotes a continuous function `Σ → D`. The source
constructors denote these operations:

```text
⟦succeed⟧ σ       = One(σ)
⟦fail⟧ σ          = Empty(next(σ))
⟦g1 ∨ g2⟧ σ      = M(⟦g1⟧ σ, ⟦g2⟧ σ)
⟦g1 ∧ g2⟧ σ      = B(⟦g1⟧ σ, ⟦g2⟧)
⟦suspend g⟧ σ    = Delay(⟦g⟧ σ)
```

Atoms apply the selected kernel; a diverging kernel call yields bottom and
failure yields Empty with the incoming supply. Fresh allocates its finite
interval in lexical order, then applies the body meaning at the updated
state. Kernel and Fresh callbacks belong to this mathematical account when
they implement the stated pure continuous operations. Host exceptions and
introspection of procedure identity are outside that interface.

Merge is strict in both operands, and bind is strict in its Search operand:

```text
M(⊥, y) = M(x, ⊥) = ⊥             B(⊥, f) = ⊥
M(Empty(n), y) = y                  B(Empty(n), f) = Empty(n)
M(One(σ), y) = Yield(σ, y)           B(One(σ), f) = f(σ)
M(Yield(σ,x), y) = Yield(σ, M(x,y))   B(Yield(σ,x), f) = M(f(σ), B(x,f))
M(Delay(x), y) = Delay(M(y,x))      B(Delay(x), f) = Delay(B(x,f))
```

The nonbottom constructor equations apply to mature operands. These
equations define continuous operations using the standard least fixed-point
construction. A recursive goal functional `F : (Σ → D) → (Σ → D)` has meaning

```text
fix(F) = ⨆n Fⁿ(λσ. ⊥).
```

`fix-goal` is the executable unfolding of this equation. Its eta-expanded
self function supplies recursion in strict Racket; it inserts no Delay.
For example:

```racket
(define omega (fix-goal (lambda (self) self)))
(define answers
  (fix-goal (lambda (self) (disj (succeed) (suspend self)))))
```

Omega denotes bottom. Answers produces an infinite Search with one answer
per recursive unfold and an explicit Delay between successive chunks.
`disj(succeed, omega)` denotes bottom before any Search returns. Guardedness
is not needed to assign these meanings. It determines which finite boundary
observations can actually be produced.

The complete `render` maps into the flat domain of exact finite
Done/Last/Emit/Forced readbacks plus bottom. Emit and Forced tails are eager.
Consequently a productive infinite Search need not have a terminating complete
render. `snapshot` can instead inspect a finite number of Delay bodies. Its
`Unforced` marker is an observer cutoff, never a semantic Empty or an assertion
of divergence; forcing an unproductive body may still fail to return.

## Why these lambdas yield the direct interpreter's data

The labels identify actual lambda sites in `semantics.rkt`. The outcome
constructors are defined in the shared `functional-search/outcomes.rkt`:

| Closure family | Captured fields | Reified form |
| --- | --- | --- |
| failure-outcome / success-outcome | none / state | Functional kernel outcomes retained in the direct interpreter; a later defunctionalization can introduce Failure / Success(state). |
| G0 | atomic request | The atomic goal supplied to K. |
| G1 | arity, body | Fresh syntax and its body parameter. |
| G2 / G3 | left, right | Conj / Disj syntax. |
| G4 | goal | Suspend syntax. |
| S0 / S1 | next / state | Empty / One. |
| S2 | state, mature rest | Yield with an eager Search tail. |
| S3 | nullary resume | Delay with a suspended body. |
| O0 / O1 | next / state | Done / Last(Answer(state)). |
| O2 / O3 | state and tail / tail | Emit / Forced. |
| R0 / R1 / R2 | suspended eval / merge / bind environment | The remaining Delay functions, later CPS-converted in a7–a9. |

These are constructor-generated, uniform case selectors. Arbitrary Racket
procedures accepting four arguments are not automatically valid Search
denotations. Choosing a Scott encoding explains the constructor/match
representation; it does not add laziness to every represented value.
Racket evaluates the tail argument to `yield-search` before constructing S2.
Only S3's captured resumption is deliberately unevaluated.

`denote` gives the forward syntax-to-meaning map, with unused composite syntax
tags omitted and all atomic request/state fields retained. The table explains
the reverse closure-family reification; no claim is made that arbitrary host
functions can be inspected to recover source syntax. Fresh bodies and kernel
operations remain host primitives at both ends.

The correspondence argument proceeds by source composition and the Search
constructor equations. Reification commutes with strict merge and bind,
retains eager Yield tails, and crosses Delay only inside the saved resumption.
It also commutes with finite readback. At recursive goals, the continuous,
bottom-preserving correspondence extends from finite unfoldings to their
least upper bound. This is the mathematical argument; the executable tests
check instances rather than mechanizing the general continuity/adequacy proof.

## Evidence and scope

The local aggregate completed with **361 tests passed**. The executed demo
reported `(p q)` before Search inspection, then
`(Yield A (Yield B (One q)))` and exact readback
`(Emit A (Emit B (Last q)))`. Its nested rail witness retained four Forced
markers, and its recursive example exposed four answer chunks while
inspecting three Delay bodies.

The local gate compares the new denotations with the independent direct
interpreter and the final generated a7–a9 register machine. It checks exact
States, terminal supplies, finite frontiers, atomic-call order, incoming
States, and mature Search boundaries from zero and nonzero supplies.
Additional witnesses inspect native functional values, forcing/capture and
reuse, bind strictness, fresh allocation across suspension, nested rail,
productive recursion, and finite fixed-point approximants. Kernel witnesses
check exclusive handler selection, eager outcome production, reuse without
repeating kernel work, unchanged Atom outcome identity, rejected nonfunctional
Atom results, and a shared custom kernel across Delay forcing.
Instrumented kernels are sequencing diagnostics; the mathematical domain
above assumes pure kernel operations.

The pure semantic code has no transition budget or artificial bottom value.
The divergence tests use bounded Racket engines solely as a host test harness;
their finite prefixes do not prove nontermination. The identity fixed-point
equation supplies that particular bottom example's mathematical justification.

Recursive meanings are available through `fix-goal`. The syntax adapter and
downstream a7–a9 comparison continue to cover the no-relcall fragment. This
does not add a relation-call coordinate to the machine matrix or discharge
the separate strict-to-online fusion theorem.

Background for the standard domain constructions and fixed-point machinery:
[Graham Hutton's domain-theory outline](https://people.cs.nott.ac.uk/pszgmh/domains.html)
and [Bauer and Scott's domain-model overview](https://www.cs.cmu.edu/~birkedal/ltc/papers/EQULogic_abstract.html).
The strict Search domain and the correspondence equations above are the
construction instantiated for this repository.
