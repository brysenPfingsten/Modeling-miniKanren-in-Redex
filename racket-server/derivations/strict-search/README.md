# Strict Search derivation

Start with [retained-scope/](retained-scope/README.md), the preferred current
S account. Its [direct interpreter](retained-scope/interpreter.rkt) and
[reduction semantics](retained-scope/source.rkt) retain introductions on the
computation while it runs. Both preserve strict disjunction, eager `Yield`
tails and bind, and the explicit Search/Frontier commitment boundary. Only
object-language `Delay` suspends computation.

The functional and syntactic presentations use the same constructor names:

```text
Search   ::= Empty(O) | One(O,σ) | Yield(O,A,Search) | Delay(O,R)
Frontier ::= Done(O) | Last(O,A) | Emit(O,A,Frontier)
           | Forced(O,Frontier) | More(Delay(O,R))
```

`Yield` retains an eager candidate and its Search tail. `More` marks only
unfinished Frontier work. The S/E/N payloads and representation maps retain
their own allocation information; no name-conversion adapter is involved.

## Current executable pipeline

```text
Within retained-scope/:

interpreter → CPS → data + defunc → machine → registers → compressed
                                      ↕ configuration correspondence
source → decomposition → refocused M
```

The [stage guide](retained-scope/README.md),
[machine correspondence](retained-scope/CORRESPONDENCE.md), and
[registerization/compression contracts](retained-scope/REGISTERIZATION.md)
identify the executable maps, prescribed transition spans, and remaining
proof obligations. The retained-scope route has its own source and machine
instances; its use of S/E/N representation maps does not establish retained
scope at every older matrix coordinate or at Big.

Run the current route or the aggregate of current and comparison routes from
the repository root:

```sh
raco test racket-server/derivations/strict-search/retained-scope/all.rkt
raco test racket-server/derivations/strict-search/all.rkt
```

After the constructor rename, the combined gate passed **37,620 tests on
Racket 9.3 (2026-09-06)**. This includes retained scope's 582 tests, six
constructor-contract tests, and five dependency-boundary tests, alongside
the earlier comparison routes. All seven affected generated artifacts were
regenerated and checked. Static audits preserve unary Frontier wrappers,
allocation/tag data, work-event data, and primitive kernel hashes.

## Directory roles

| Location | Role |
| --- | --- |
| [retained-scope/](retained-scope/README.md) | Preferred current S source, interpreter, corresponding machines, registers, and first compression |
| [shared/](shared/README.md) | Common grammars, allocation/kernel operations, representation maps, well-formedness, stage construction, and control transformation; contains no route's evaluator |
| [test-support/](test-support/README.md) | Shared witnesses, generated goals, and reusable checkers; imports no historical evaluator or test suite |
| [s-functional/](s-functional/README.md) | Earlier strict S checkpoint: explicit pending `prefix`/`KPrefix`, captured-scope resumptions, and ANF-to-register sequence |
| [matrix/](matrix/README.md) | Earlier strict S/E/N source instances and twelve feature cells through Big; still used for explicit comparison tests |
| Top-level numeric modules, [denotational/](denotational/README.md), [a7-a9/](a7-a9/README.md) | Earlier numeric and functional checkpoints with their own contracts and tests |
| `all.rkt`, `constructor-tests.rkt`, `layout-tests.rkt` | Combined aggregate and cross-route naming/dependency contracts |

The shared implementations are used directly by both the current route and
the earlier checkpoints. Retained-scope runtime and derivation modules do not
import those checkpoints. Its source comparison tests and `show.rkt` still
import `matrix/source-s.rkt` explicitly to compare the ownership operations.

The production `dormant-right / online` rules remain a different semantic
policy. See the [policy matrix](../../../docs/semantic-policy-matrix.md).

## Earlier numeric and matrix checkpoints

The rest of this file describes the earlier numeric column and its associated
matrix. [PIPELINE.md](PIPELINE.md) gives those stage contracts and evidence
scope; [COMMITMENT.md](COMMITMENT.md) records the earlier S commitment/prefix
factoring. These are comparison checkpoints, not the starting point for the
retained-scope interpreter.

| Artifact | Construction |
| --- | --- |
| `source.rkt` | Independent Redex `Rstrict`, explicit computation/value grammar, strict contexts, raw contractions, finite observer |
| `decomposition.rkt` | Explicit D stage: canonical decomposition, contraction, plugging, and redecomposition |
| `refocused.rkt` | Independent decomposition and plugging; a machine retaining those context frames between contractions |
| `machine.rkt` | Independent Mtree rules and exact structural Z/M maps |
| `compressed.rkt` | Direct residual dispatch, separate M-path specification, and exact nonempty span certificates |
| `big-step.rkt`, `big-step-spec.rkt` | Inductive Big semantics, fixed-point equations, and finite R/B/M proof certificates |
| `functional-machine.rkt` | Independent strict CPS equations, then first-order continuations, commands, Delay resumptions, and readback |
| `correspondence.rkt` | Structural decoding of functional configurations into `Rstrict`, without invoking either evaluator |
| `register-machine.rkt` | Private mutable registers and direct PC dispatch preserving the strict functional machine |
| `denotational/` | Functional goal meanings, Search/readback and native kernel outcomes, with no kernel-result conversion |
| `a7-a9/` | Separate ANF, full CPS forcing, defunctionalization, and mechanically generated machine/register programs |
| `s-functional/` | Strict S direct → ANF → CPS → data/dispatch → transitions → registers, with explicit commitment and incremental settled prefixes |
| `matrix/` | Native S/E/N sources and direct maps; twelve feature instances through D/Z/Mtree/B/Big |
| `tests.rkt` | Direct/Redex/refocused/CPS/defunctionalized comparisons, source-step correspondence, strictness and bounded-divergence witnesses |
| `fusion-tests.rkt` | Finite exact-readback comparisons to the preserved production rail semantics, plus the intentional work-order mismatch |
| `all.rkt` | Aggregate gate, including retained scope, earlier strict routes, and strictness-audit tests |

The aggregate checks retained scope as well as the earlier direct interpreter,
strict derivations, exact intermediate stage and representation squares, compression certificates,
inductive/fixed-point Big results, feature inclusions, and register dispatch.
It includes 120 independently generated lexical goals from both empty and
sparse initial support, exact atomic-work ordering across the numeric matrix
and registers, and the intentional online work-order mismatch.
[PIPELINE.md](PIPELINE.md#evidence-and-scope) records the aggregate checkpoint.
These finite checks retain the general theorem obligations described below.

Implemented goals are core atoms, fresh allocation, conjunction, disjunction,
and explicit suspension, with the direct interpreter's nested rail merge.
Kernel and fresh-body procedures, goal structures, States, and final frontier
structures are shared with the direct interpreter. Search evaluation is
independent. The native matrix instead uses the preserved first-order S/E/N
kernels, variable domains, state carriers, and allocation policies. Its
test-only numeric bridge connects it to the same strict interpreter and
register machine. Relcalls are rejected and remain a later coordinate.

## Native kernel contract

The shared kernel interface is `K(request, state) → Outcome`, and an Atom
callback has interface `state → Outcome`. Both directly return a function
selecting failure or passing the completed State to a success handler.
The constructors live in `functional-search/outcomes.rkt` and are re-exported
by the direct interpreter. Kernel execution finishes before the result is
selected; selecting it again does not repeat kernel work.

The denotational source and older numeric functional derivation use this
contract. The S/E/N matrix instead constructs native Failure/Success data and
consumes it with explicit case analysis. The S functional derivation uses
functional outcomes through CPS and explicitly defunctionalizes both their
producers and consumers at stage 03. No runtime result conversion is needed.

The older parameterized numeric control derivation treats K and its result elimination as an
eager primitive boundary. Its continuation and Delay-resumption families are
defunctionalized explicitly; the parameterized kernel's outcomes remain
functions. A closed derivation of a particular kernel may defunctionalize
those outcome functions at that later step. The current stages introduce no
compatibility adapter. Its opaque kernel boundary is a narrower claim than
the S functional route's procedure-free semantic configurations.

## Strict source

```text
S ::= Empty(n) | One(σ) | Yield(σ,S) | Delay(c)
c ::= S | eval(g,σ) | mplus(c,c) | bind(c,g) | Yield(σ,c) | force(c)
E ::= □ | mplus(E,c) | mplus(S,E) | bind(E,g) | Yield(σ,E) | force(E)
```

`bind(c,g)` is the explicit representation of the specific continuation
`λσ. eval(g,σ)` created by this goal language. It is not an arbitrary host
function. There is no context under `Delay`.

The critical contractions are:

```text
eval(g1 ∨ g2,σ)       → mplus(eval(g1,σ),eval(g2,σ))
eval(g1 ∧ g2,σ)       → bind(eval(g1,σ),g2)
eval(suspend g,σ)     → Delay(eval(g,σ))
mplus(Yield(σ,S1),S2)  → Yield(σ,mplus(S1,S2))
bind(Yield(σ,S),g)     → mplus(eval(g,σ),bind(S,g))
```

The contexts require both operands to mature before any `mplus` contraction.
They also require the recursive merge beneath `Yield` to finish before that
cell is a value. A mature left answer does not release the right operand from
evaluation. The same requirement applies to both operands created by
`bind-yield`.

`render` is a separate finite observer producing the exact
`Emit`/`Forced`/`Last`/`Done` syntax. An internal `force` runs an existing
resumption; it does not itself add an outward `Forced`. Only observation of a
Search `Delay` adds that marker. The observer distinguishes `Emit(A,Done(n))`
from `Last(A)`.

The Redex grammar deliberately leaves kernel data and callbacks opaque. It
also admits ill-formed computations such as `force(One(σ))`; these are stuck.
Progress and correspondence statements concern reachable, well-formed
configurations from valid initial goals, States, and kernel parameters, not
every term matched by the broad grammar.

## Eager progress lemma and guarded extension

For the finite, fresh-free fragment, suppose every atomic kernel invocation
terminates and returns a success/failure outcome whose selection terminates.
Then `eval(g,σ)` terminates in a
finite mature Search without evaluating beneath a Delay.

The proof is by structural induction on `g`, simultaneously for all input
States. Atoms terminate by hypothesis and suspension immediately returns a
Delay. For disjunction, both smaller goals terminate by induction; `mplus`
terminates by induction on its first operand's finite mature spine, stopping
at Empty, One, or Delay. For conjunction, the left goal terminates by
induction; `bind` traverses its finite mature spine. Each head invokes the
smaller right goal, and the residual bind terminates by spine induction.
Each resulting merge terminates by the preceding `mplus` argument. Eager
`Yield` construction therefore still finishes. This proves finite eager work,
not a bound on how much work it takes.

Fresh extends this argument when each eager fresh-body expansion terminates
and the expansion relation before the next suspension is well founded, with
finite branching. Use its well-founded rank together with the preceding
structural/spine induction. Require the same condition again for every
reachable Delay resumption. This is the guarded domain used here; arbitrary
Racket callbacks are not statically certified members of it. A future relcall
judgment must state and establish the analogous condition, including explicit
relation-entry suspension policy. The lemma is a mathematical proof argument;
there is no mechanized guardedness checker or general adequacy theorem yet.

`tests.rkt` also builds an unguarded self-expanding `Fresh 0` whose host body
returns immediately, so machine fuel bounds it. On `success(A) ∨ Ω`, the
strict source cannot produce its first Search value or emit A before fuel
runs out. This is distinct from testing divergence inside an opaque host Atom,
which the transition budget cannot interrupt. Bounded exhaustion demonstrates
the witness's finite prefixes; the self-loop explains its divergence.

## Two machine derivations

The CPS equations retain the direct interpreter's left-to-right operand
evaluation. Defunctionalization produces `AfterDisjLeft(g2,σ,k)` followed by
`AfterDisjRight(S1,k)`. Bind similarly retains its head Search while computing
the recursive residual. `ResumeEval`, `ResumeMerge`, and `ResumeBind` are
formed only as payloads of genuine Delay values. They retain the orientation
and grouping of nested choices.

The syntactic machine retains frames from the strict contexts: in particular,
`MergeRight(S1)` retains the mature left Search while the right computation
runs. It shares the source's raw contraction relation, but implements context
search independently rather than invoking the whole context-closed relation.

The decoder relates the functional machine to the same source terms. Tests
check that each functional step preserves its decoded source term or performs
one source step, and that each refocused administrative step preserves its
plugged term while each contraction matches one labeled source step. They also
check decomposition/plugging reconstruction. Thus the checkpoint checks
intermediate correspondence, not just coincident completed answers.

These machines are related through the common source; their raw state
constructors and administrative step counts are not identical. A general
divergence-sensitive correspondence still requires an invariant and an
administrative-progress proof. An unchanged decoded term alone is not evidence
that a step is administrative: the unguarded Fresh witness has real source
self-loops. Pure fresh callbacks that construct new Racket procedures also
require an extensional treatment at the kernel boundary; `equal?` cannot
prove arbitrary closures equivalent. The step corpus uses stable captured
procedures; fresh identity/allocation receives separate exact State checks.

All fueled entry points reject invalid budgets. A single run budget includes
evaluation, forced resumptions, and readback; it does not bound arbitrary host
kernel/body execution. A first-order functional Search rendered in a separate
call must use the same kernel environment as its `run-search` call.

## Guarded fusion remains a separate obligation

The strict witness executes `p; q; emit`, while the retained online witness
executes `emit; p; q`. Changing `WorkPath` or only moving answer commitment
would not repair eager `bind`. The old semantics remains the source of its
existing exact pipeline; it is now a proposed guarded fusion of this strict
source.

The fusion tests retain exact final State data and
`Emit`/`Forced`/`Last`/`Done`, erasing only owner wrappers. They cover finite
core/disjunction/conjunction/suspension witnesses, including nested rail and
bind residuals. This bridge does not cover fresh-owner provenance, relcalls,
or infinite streams. Instrumented work-order kernels are diagnostics, not
effectful kernels admitted by a pure-kernel fusion theorem.

Before promoting fusion, specify its observation, prove it under explicit
guardedness and pure deterministic kernel hypotheses, and separate finite
completed readbacks from productive streams and eventual-answer sets. This
obligation applies to adopting the online optimization. The strict downstream
pipeline, representation matrix, and strict registerization proceed
independently, retaining the chunks and merge frames that strictness requires.
The old source-relative Big fixed-point results neither discharge the fusion
obligation nor establish productive infinite behavior.
