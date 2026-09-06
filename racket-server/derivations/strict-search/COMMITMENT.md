# Meeting the strict machines at the observation boundary

The functional derivation retains its explicit KCommit phase. The native
S/E/N reduction semantics now states that boundary independently, and the
ordinary decomposition/refocusing construction retains the resulting context.

## Source operations and normal forms

The three roles are program goals g, active computations c with mature Search
values SV, and settled Frontiers F. Completed observations O are the subset
of F with no pending work. The public query is:

```text
query-initial(g) = commit(eval(g))

commit(Empty)       → Done
commit(One(state))  → Last(state)
commit(Yield(A,SV))  → Emit(A,commit(SV))
commit(Delay(c))    → More(Delay(c))
```

This schematic notation omits S ownership and E/N supply fields. In S,
commit-one moves the complete ordered local Owner groups to the terminal
Answer, preserving the placement of the earlier render-one rule. Eager-tail
commitment preserves both common and answer-private ownership.

The source context `commit E` requires the active operand to mature before
commit acts. Strict mplus/bind contexts and eager active Yield tails remain
unchanged. Neither Delay nor unary unfinished-work More contains a reduction
context. Therefore a returned F with More(Delay) is a genuine normal form.

`advance F` preserves Emit/Forced history and crosses exactly one exposed
Delay. `collect F` repeatedly consumes the remaining exposed boundaries.
These operations are in the source grammar and reduction relation; a test
driver does not choose when the machine should pause. Internal forcing during
a resumption remains distinct from the one new public Forced marker.

Public resumption exposes the stored body directly:

```text
advance(More(Delay(O,c))) → Forced(O,commit(c))
collect(More(Delay(O,c))) → Forced(O,collect(commit(c)))
```

Delayed bind likewise stores `bind(empty,c,g)` inside the new Delay. These
operations do not reconstruct an empty-owner Delay just to force it. The
older `render c` remains a separately named full-consumption operation and
also exposes the body directly. Finite comparisons with `collect(commit c)`
check results and ownership; their operation-label traces are different.

Internal forcing has an additional ownership operation, matching the strict
direct interpreter's `prefix(O,resume())`:

```text
force(Delay(O,c)) → prefix(O,c)
E ::= … | prefix(O,E)
prefix(O,SV) → prefix-value(O,SV)
```

The prefix context contributes O to allocation ancestry while c evaluates.
Only after Search matures does `prefix-value` prepend those ordered Owner
groups to its root. There is no context beneath Delay, including a Delay
returned by the resumed body. E/N retain the erased unary prefix operation
and its identity contraction, preserving exact labelled S/E/N step squares.

## What refocusing produces

[source-s.rkt](matrix/source-s.rkt) and the ownerless source schema define
commit/advance/collect before any machine construction.
[instances.rkt](matrix/stages/instances.rkt) gives their native constructor
views. The unchanged general [stage construction](shared/stages/schema.rkt)
uses those views in decomposition and retained refocusing:

```text
commit E  →  Frame(commit, before=(commit), after=(), owners=#f)
          →  K(commit-frame, remaining-continuation)
```

Eager settled tails similarly produce emit frames. Advance and collect have
their own contexts. D, Z, M, and B all stop on the same Frontier normal forms
using their ordinary finality rules. The new operations also have independent
inductive Big judgments, fixed-point equations, and mapped proof certificates.
The feature schemas carry this construction across all twelve native cells.

## Direct configuration correspondence

[functional->M](s-functional/machine-correspondence.rkt) constructs native M
control and Frame/K fields directly from the functional machine's Call and
continuation data. It does not plug and decompose an entire source term or
invoke a transition. Stored Search/resumption fields use structural leaf
maps, retaining their nested orientation and validating captured ancestry.

| Functional structure | Native syntactic structure |
| --- | --- |
| KConj | bind frame around the left operand |
| KDisjLeft / KDisjRight | merge-left / merge-right frames with the pending right computation or mature left value |
| KBindHead / KBindTail | merge operand frames for the source bind-yield expansion, retaining the residual bind or mature head |
| KMergeYield | eager active yield frame |
| REval / RMerge / RBind | suspended eval/mplus/bind/force syntax in Delay bodies |
| KPrefix | strict prefix frame with saved Owners |
| KCommit | commit frame |
| KCommitEmit | settled emit frame |
| KCollectResume | collect context inside the new Forced context |

KPrefix now maps directly to the independently derived prefix frame. The map
does not push its Owners into another frame or prefix a running computation.

Several functional continuations have the same residual syntactic
context. KCommitEmit, KAdvanceEmit, and KCollectEmit all reconstruct Emit;
several history/crossing continuations reconstruct Forced. Outcome/handler
dispatch can have the same source image across multiple functional steps.
Those distinctions remain in the executable functional machine. The comparison
identifies their images; it does not implement a runtime fusion or claim a
constructor bijection.

The checked relation compares exact native M configurations after native
administrative normalization. `functional-step-label` classifies each
functional transition before either machine steps. A semantic transition
must match exactly that single named source contraction; a functional
administrative transition must preserve the normalized image. Neither test
searches forward through arbitrary source contractions for a matching target.
Both public endpoints are ordinary halted Frontiers, including pending
More(Delay), with no special stopping exception.

## Audit of the remaining differences

The source audit precedes the correspondence claim. Two previous differences
required source repairs: synthetic force/redelay phases in raw resumption,
and moving ownership onto a computation before it returned. The latter had
implicitly assumed an ownership-commuting transformation. Explicit strict
prefix removes that assumption from the configuration map.

| Remaining difference | Explanation and obligation |
| --- | --- |
| Specialized bind/merge continuation families | Lambda-site environments encode saved operands and pending operations that native frames retain as syntax. Preserve those fields in any consolidation. |
| Three Emit and four Forced reconstruction families | Their respective return clauses construct the same value shape. A later explicit consolidation can identify equal code shapes; it must retain the incoming control and saved fields. |
| KCollectResume versus two frames | This continuation packages `Forced(O,collect[ ])`; applying it enters collection under KCollectForced. Collection remains a separate operation. |
| GRight and REval/RMerge/RBind dispatch | Expose saved code and its pending context without evaluating an atom, allocating, or committing. RBind no longer inserts a force contraction. |
| Outcome and handler dispatch | The kernel has already run before outcome/d. These bounded calls select Failure/Success and construct active Empty/One. |
| Captured inherited support | A redundant representation of structural ancestry, checked against the saved context. Its preservation remains a proof obligation. |
| Return/halt and native traversal | Context reconstruction and explicit finality packaging. Returning through KPrefix is the exception: it performs the named prefix-value operation. |
| Register layout and PC loop | Generated tail-call reification preserves arguments before mutation; it creates no object Delay or search fusion. |

KCommit continues to separate mature Search from settled Frontier. Strict
operand frames and the actual RMerge force retain their work boundaries.
No closure family has been merged just to make constructor counts agree.

## Evidence and next obligations

The source and stage gates check commitment, public forcing, strict work,
ownership, and S/E/N maps. The functional comparison follows all twenty
validation witnesses through initial run and every advance/collect boundary.
It checks actual machine states, a separate whole-tree readback square, and
native D/Z/B endpoints. Big checks cover partial endpoints, exact native
operation traces, proof certificates, and the full-consumption comparison.

The full strict aggregate passed **37,027 tests on Racket 9.3** after this
factoring repair. The twenty validation witnesses plus focused failed-bind
and internal-force cases cover every non-render source label in the
prescribed-step check. The paired-machine demo and generated-artifact check
also passed. The dependency-aware invocation is recorded in
[PIPELINE.md](PIPELINE.md). The earlier commitment checkpoint passed 32,209.

Run the paired-machine example with:

```sh
racket racket-server/derivations/strict-search/s-functional/show-correspondence.rkt
```

The general correspondence theorem still needs a preserved configuration
relation and a termination argument for administrative stuttering. The
prescribed-step checks establish finite instances, not universal closure of
the relation or reverse coverage of every native administrative state. Tests do
not prove productive infinite behavior, sharing identity, or cost preservation.
The core strict operand/resumption information and the commitment boundary
remain visible. Whether some dispatch and reconstruction frames can be
compressed is now a separate, inspectable question. No compact rail machine
or guarded online fusion is derived by these changes.
