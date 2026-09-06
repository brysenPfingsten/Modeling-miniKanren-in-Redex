# The retained-scope functional and refocused machines

The selected S interpreter has an explicit data machine and a structural
configuration map to the machine obtained by decomposition/refocusing of its
source. The [research guide](../README.md) owns the artifact inventory and
current coordinate status; this document states the machine relation.

## Functional derivation artifacts

```text
interpreter.rkt → cps.rkt → data.rkt + defunc.rkt → machine.rkt
                                                    │
                                             functional->M
                                                    │
source.rkt → decomposition → refocusing ──────────────┘
```

The direct/CPS reconstruction and defunctionalization are inspectable manual
passes. `derive.rkt` generates `machine.rkt` mechanically from every `/d`
definition, reusing the existing restricted tail-call reifier. The generated
machine has `Call(pc,operands)` and `Halted(value)` configurations. Every tail
transfer becomes a Call; the return from KDone becomes Halted. The driver is
an administrative trampoline. It introduces no object-language Delay and
performs no scheduling optimization.

`data.rkt` replaces all semantic closure families, including the functional
kernel's outcomes and handlers. The kernel produces Failure/Success data
directly at this stage. Runtime configurations contain no procedures or
closure descriptions. Neither defunctionalization nor the machine needs the
direct/CPS test observer to execute or to reconstruct source syntax.

The three resumption records are:

```text
REval(goal,state)
RMerge(right,left)
RBind(resume,continue)
```

Their application is `resume/d(resume,owners,inherited,k)`. They have no
captured allocation-support field. `GRight(goal)` is the separate pending
conjunction continuation. Ordinary continuation records still retain the
operands, root Owners, and inherited support needed by their pending operation.

## Structural configuration relation

Let F be the generated functional machine and M the native refocused machine.
Let Φ be `functional->M`, defined in `machine-correspondence.rkt`. It directly
constructs M's control and Frame/K fields from the fields of F. It performs
no machine step, source contraction, decomposition, or whole-tree plug.
Resumption readback traverses its data without executing the suspended work.

Let A normalize only native transitions classified `admin`. The relation on
well-formed reachable configurations is:

```text
R(f,m)  iff  A(Φ(f)) = A(m).
```

The harness retains m in administrative normal form, so its maintained
invariant is simply `A(Φ(f)) = m`. Native administrative normalization traverses
finite syntax and context frames up to the next source contraction or final
state; it never evaluates a goal or enters an object Delay.

The domain requires the exact allocation ancestry appropriate to each active
position. Inherited support in a control must equal the support contributed
by its continuation. Saved support fields in continuation records are checked
against the ancestry outside their own root Owners; KCollectResume's `here`
instead includes its retained Forced Owners. These are ordered equalities,
not set comparisons. Logical stores, constraints, trails, future goals and
answer-private introductions must satisfy source well-formedness. Search and
Frontier continuation inputs are distinct, and a public Halted configuration
contains a Frontier, including a permitted unfinished More(Delay).

For an independent check, `readback.rkt` reconstructs the whole source term
from the functional configuration. Tests require:

```text
readback-M(Φ(f)) = readback-F(f).
```

This equality checks two separately stated maps; the whole-tree map is not
used to implement Φ. Existing fieldwise S→E/N maps also agree with translating
the reconstructed source, including every pending computation and state.
These are structural representation squares. The matrix's E/N transition
systems still retain a unary prefix phase and are not asserted to have the
new S machine's operation granularity.

## Where the continuations go

| Functional data | Refocused structure |
| --- | --- |
| KConj | bind frame around the left goal's Search |
| KDisjLeft / KDisjRight | strict mplus left/right operand frames |
| KMergeYield | eager active Yield-tail frame |
| KBindHead / KBindTail | mplus operand frames from the eager bind-yield equation |
| KMergeForced(right,O,P,k) | mplus right-operand frame whose root carries O |
| KBindForced(continue,O,P,k) | bind frame whose root carries O |
| KCommit | explicit commit frame |
| KCommitEmit / KAdvanceEmit / KCollectEmit | Emit reconstruction frame |
| KAdvanceHistory / KAdvanceForced / KCollectHistory / KCollectForced | Forced reconstruction frame |
| KCollectResume(O,here,k) | collect frame inside a retained Forced(O,…) frame |

There is no KPrefix record and no native prefix frame. Several functional
lambda sites still reconstruct the same native constructor. This is not a
claim of constructor bijection, nor a consolidation of those lambda sites.

Resumption entry is particularly direct:

```text
resume/d(REval(g,σ),O,P,k)
  ↦ M(eval(O,g,σ), ΦK(k))

resume/d(RMerge(right,left),O,P,k)
  ↦ M(mplus(O,Q(right),force(Q(left))), ΦK(k))

resume/d(RBind(r,f),O,P,k)
  ↦ M(bind(O,Qr(r,empty),goal(f)), ΦK(k))
```

All children are interpreted under `P ++ names(O)`. Their retained local
Owners are unchanged. Dispatch of RMerge/RBind exposes the ordinary mplus or
bind context, without performing a source operation. Internal force itself
performs the source's `force-delay` contraction, supplying O before entry.

## Prescribed step diagram

`functional-step-label` inspects the current PC and data constructor before
either machine steps. It returns one exact source label or `#f` for
administration. For a functional transition `f → f'`, the checks are:

```text
label = #f:
    A(Φ(f)) = A(Φ(f'))
    readback-F(f) = readback-F(f')

label = ℓ:
    A(Φ(f)) --ℓ--> m₁ --admin*--> A(Φ(f'))
    readback-F(f) --ℓ, retained-red--> readback-F(f')
```

The second diagram permits exactly one named source contraction. The tests
do not seek a convenient later target by skipping additional source work.
Every non-render label in this source is covered, along with every control,
continuation, resumption, and outcome family.

The semantic cases are eval, mplus, bind, force, commit, advance and collect.
Outcome selection, continuation application and resumption dispatch are
administrative. For example, an atomic eval computes the native outcome once;
the subsequent outcome/failure/success controls read back its already chosen
Empty or One, without a second kernel evaluation.

## Administrative progress

`administration.rkt` supplies an explicit natural-number rank for consecutive
functional administrative steps, independently of the test fuel bound:

* A return control has rank one plus the number of consecutive continuation
  frames that reconstruct a value and return again.
* A resumption control has rank one plus its leading RBind depth. Each RBind
  dispatch enters a strict subterm; REval and RMerge enter semantic eval/force
  controls. Increasing continuation depth during RBind dispatch does not
  invalidate this measure.
* A goal-continuation dispatch has rank one.
* Failure/success dispatch adds one to its eventual return rank; outcome
  dispatch adds two.
* Semantic controls and Halted have rank zero.

Each administrative clause strictly decreases this rank. Tests check that
inequality on every reached administrative edge. Thus the functional side's
bookkeeping cannot by itself postpone a next semantic operation forever.
The corresponding native requirement is finite structural traversal of its
strict evaluation context.

These progress facts explain how a forward prescribed-step simulation can
support reverse matching at semantic checkpoints: expose the functional
machine's next semantic operation through a finite administrative span, then
use determinism and the labelled diagram. A universal correspondence theorem
still requires proving domain preservation and the diagrams for all admitted
configurations, as well as the native traversal property. Finite test coverage
is evidence for those obligations, not a machine-checked proof of them.

## Scope of the result

The executable comparison concerns complete machine configurations at
every transition, not only final answers or public boundaries. Separate tests
also compare direct, CPS, defunctionalized, and generated machine executions
at every public boundary, including exact suspended bodies and actual atomic
work with incoming states. No observation is weakened to answer sets.

Strictness, eager bind, commitment, and retained introduction placement are
the common specification. [Machine checks](machine-correspondence-tests.rkt)
exercise the diagrams and domain conditions above. The subsequent
[registerization and compression](REGISTERIZATION.md) compose with this
relation under their own contracts. Retained-scope E/N transitions, productive
infinite behavior, relation calls, and the compact rail machine remain open.
