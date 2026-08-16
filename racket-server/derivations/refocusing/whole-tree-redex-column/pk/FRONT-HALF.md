# P[K] front-half arrow contracts

The front half contains the source artifact and the decomposition arrow for
both `Ktoy` and `Kmk`.

## Source

`source-red/K` is the primary source semantics.  Its 25 shared control
equations are genuine, individually named `reduction-relation` clauses under
the grammar-defined `FF`, `WF`, and `LF` contexts.

```text
F --rule-name--> F'
```

Each precise instance also supplies a direct leaf reduction relation over
`W`, with one statically named clause per kernel outcome.  The shared schema
uses `context-closure` to lift those clauses through `WF`, then unions the
result with the 25 control clauses.  `Ktoy` therefore has 28 actual source
rules and `Kmk` has 32.  There is no generic source clause whose premise asks
a judgment which rule or successor to choose.  The finite rule-name maps
recover the exact first-class `ell`, so successor, label, owner, and trace
comparisons remain executable.

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

- BF and LF are disjoint, and every generated LF has exactly one raw
  innermost work-frame pop while BF has none.
- The four grammar-only `in-hole` factorizations form a unique cover of `F`;
  decomposition then has exactly one raw proof and reconstructs its input in
  both precise languages.
- The source relations expose exactly 28 static rules for `Ktoy` and 32 for
  `Kmk`; tests reject a generic judgment-backed source projection.
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
direct source relation, grammatical decomposition judgment, and independent
derived presentations make the intended theorem statements inspectable and
leave a clear route to stronger proofs.
