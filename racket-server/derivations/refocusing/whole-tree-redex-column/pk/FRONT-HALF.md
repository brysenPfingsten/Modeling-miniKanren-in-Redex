# P[K] front-half arrow contracts

The front half contains the source artifact and the decomposition arrow for
both `Ktoy` and `Kmk`.

## Source

`source-step/K` is the primary labeled Redex judgment:

```text
source-step/K(F, ell, F')
```

Its two atomic clauses invoke `kernel-step/K`.  Success produces
`Returned(kst')`; failure produces `Dead`.  No kernel rule selects a search
context, priority rule, fresh rule, or scheduler rule.  All other clauses are
shared control equations over BF/LF/WF.

`source-red/K` is the named reduction-relation presentation of that judgment.
The name is computed from the exact `ell`, so successor, label, owner, and
trace comparisons remain executable.

The selected fresh equations are unchanged:

```text
More(WorkFresh(u,W,tag))
  -> FrontierFresh(u,More(W),tag)

LF[WorkFresh(u,DisjL(S,W),tag)]
  -> LF[DisjL(WorkFresh(u,S,tag),WorkFresh(u,W,tag))]
```

The right-active form is symmetric and retains owner `search-join`.  The rule
is named `expose-choice-through-work-fresh`; it is an operational exposure,
not a general scope equation.

## Decomposition

The decomposition language retains grammatical result shape:

```text
D ::= DecWork(BR,BF)
    | DecWork(LFR,LF)
    | DecWork(LR,WF)
    | DecFrontier(T,FF)

C ::= ContractWork(ell,W,WF)
    | ContractFrontier(ell,F,FF)
```

There is no W/F tag or dynamic compatibility check.  BF/LF/WF and the D/C
constructors encode compatibility as an indexed inductive structure.

The specification presentation is:

```text
decompose/K(F,D)
contract/K(D,C)
plug-C/K(C) = F'
decompose/K(F',D')
--------------------------------
decomposed-step/spec/K(D,ell,D')
```

The direct presentation repeats every transformed contractum in
`decomposed-step/direct/K` and calls only root re-decomposition.  It does not
invoke `contract/K`.  Thus agreement is evidence about two independently
stated Redex presentations rather than a common Racket dispatcher or a clause
table used twice.

## Executable claims in this checkpoint

- BF and LF are disjoint, and every generated LF has exactly one innermost
  work-frame pop while BF has none.
- Decomposition is total, unique, and reconstructing under generated bounded
  enumeration for both precise languages.
- Source successors equal contraction-and-plug successors.
- Direct D successors equal compositional D successors, including labels.
- Both source and D steps preserve shared marker-indexed well-formedness on
  generated well-formed terms.
- `Ktoy` source states, labels, contracta, decompositions, and direct D steps
  match the committed oracle on the representative reachable corpus after the
  explicit tagged-label translation.
- `Kmk` exercises all seven atomic outcomes and a compound fresh/disjunction/
  conjunction/delay trace through the same arrow suite.
- Toy terms are rejected by the `Kmk` F/D grammars and miniKanren terms are
  rejected by the `Ktoy` F/D grammars.

These are executable bounded checks, not universal mechanized proofs.  The
separate judgments and direct relations make the intended theorem statements
inspectable and leave a clear route to stronger proofs.
