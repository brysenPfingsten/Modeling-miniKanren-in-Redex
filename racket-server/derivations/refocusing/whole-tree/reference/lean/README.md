# Lean whole-tree source reference

This subtree is the independent source-level reference for the lean
representation of the selected whole-tree search cell.  It is handwritten
separately from [`../marked/`](../marked/README.md): no lean semantic module
imports, generates from, or operationally calls the marked reference.

The checkpoint deliberately erases only persistent fresh-ownership wrappers:

```text
WorkFresh(intro,W,tag)      -> W
AnswerFresh(intro,A,tag)    -> A
FrontierFresh(intro,F,tag)  -> F
```

`Emit`, `Forced`, `Last`, goal and state tags, and exact transition labels
remain part of the lean source artifact.  Erasing completed history or adding
a cached scope is a different representation decision and is not folded into
this reference.

## Carrier

The source carrier is stratified without a reified work/frontier tag:

```text
A  ::= Answer(kst)
S  ::= Returned(kst)
SC ::= DisjL(S,W) | DisjR(W,S)

W  ::= Work(g,kst)
     | Returned(kst)
     | Dead
     | Conj(W,g)
     | PendingDelay(W)
     | DisjL(W,W)
     | DisjR(W,W)

F  ::= More(W)
     | Done
     | Last(A)
     | Emit(A,F)
     | Forced(F)
```

One actual-hole work context is sufficient after fresh wrappers are removed:

```text
WW ::= hole | Conj(WW,g) | DisjL(WW,W) | DisjR(W,WW)
WF ::= More(WW) | Emit(A,WF) | Forced(WF)
FF ::= hole | Emit(A,FF) | Forced(FF)
```

`Ktoy` and `Kmk` replace the abstract atomic goal, state, and kernel-label
leaves before any relation or theorem is stated.  Mixed-kernel terms are
therefore outside both precise languages.

## Source relation

The shared lean relation contains 20 genuine, statically named Redex clauses.
`Ktoy` adds three atomic clauses, for 23 total rules; `Kmk` adds seven, for 27.
The five marked fresh-administration clauses have no lean transition:

```text
expose-frontier-fresh/core
expose-choice-through-work-fresh/disj
expose-choice-through-work-fresh/search-join
erase-dead-fresh/core
bubble-delay-through-fresh/delay
```

Those five labels are the intended stuttering class for the later reference
`Q_R`.  Every surviving label and owner is retained exactly.

Fresh allocation is stated directly:

```text
WF[Work(fresh(x*,g,tag),kst)]
  -> WF[Work(g[u*/x*],kst)]
```

The allocator chooses the least canonical `u` names absent from actual runtime
variable occurrences in the complete lean frontier.  It stores no ownership
or cached support.  Consequently a marked introduction that is unused outside
an erased marker can permit later name reuse in lean.  The intended `Q_R`
claim is therefore alpha-aware weak correspondence, not unconditional literal
name lockstep.

## Well-formedness and imports

Lean well-formedness retains lexical scope, kernel state validity,
capture-avoiding fresh substitution, substitution acyclicity, and
disequality/trail consistency.  It intentionally has no runtime-introduction
scope parameter: allocated `u` identities are valid runtime syntax without a
persistent ownership proof.

Semantic modules may import only other lean modules, Redex/Racket libraries,
and the two approved atomic Kmk helpers.  Corpus fixtures, tests, Q, marked,
retired semantics, and production search-control modules are excluded by the
intrinsic dependency gate.

## Focused check

From the repository root:

```sh
racket -y racket-server/derivations/refocusing/whole-tree/reference/lean/tests/run.rkt
```

This source-only checkpoint does not claim lean decomposition, refocusing,
machine, compression, or finite big-step artifacts.
