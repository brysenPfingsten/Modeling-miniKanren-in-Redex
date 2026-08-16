# `R_m -> D_m`: indexed decomposition

## Grammar difference

The source grammar is extended with terminal frontier `T`, boundary-redex
`BR`, local-fresh redex `LFR`, other local redex `LR`, decomposition result
`D`, and contraction result `C`:

```text
D ::= DecWork(W, WF) | DecFrontier(T, FF)
C ::= ContractWork(label, W, WF)
    | ContractFrontier(label, F, FF)
```

`WW`, `WF`, and `FF` remain genuine Redex contexts containing `hole`.  Their
input/output categories are their grammar indices; neither `D` nor `C` carries
a W/F field.

## Arrow presentations

`decompose/redex` is a four-clause judgment that lets Redex enumerate the
unique focus/context pair.  `contract/redex` is a named relational table for
all 28 rule/owner pairs.  `plug-D` and `plug-C` are category-specific
metafunctions implemented with `in-hole`.

The compositional step is:

```text
contract/redex(D,C)   decompose/redex(plug-C(C),D')
--------------------------------------------------
              D --label(C)-->spec D'
```

`decomposed-red/direct` is separately stated as 28 Redex reduction clauses.
It repeats each contraction pattern and reconstructs the next decomposition;
it does not invoke `contract/redex`.  Its shared root-redecomposition operation
is a Redex metafunction whose output is bound by `decompose/redex`, not a host
Racket dispatcher.  This duplication is deliberate evidence: Redex checks
that the direct relation has exactly the same labeled successor set as the
compositional judgment.

## Constructor and rule translations

| Source position | Decomposition | Contractum |
| --- | --- | --- |
| local W redex in `WF` | `DecWork(redex,WF)` | `ContractWork(label,W',WF)` |
| W redex immediately below `More` in `FF` | `DecWork(redex,FF[More(hole)])` | `ContractFrontier(label,F',FF)` |
| terminal in `FF` | `DecFrontier(T,FF)` | none |

Every source rule maps to the identically named/owned contract clause.  The
six `More` rules are exactly the clauses producing `ContractFrontier`; all
other rules produce `ContractWork`.

## Executable claim

On toy-kernel well-formed source terms:

1. `decompose/redex(F,D)` has exactly one result.
2. `plug-D(D) = F`.
3. The source named successor set equals the set obtained by decomposition,
   contraction, and `plug-C` (preservation and reflection).
4. The compositional and direct decomposed successor sets are identical.
5. Successor decompositions read back to the exact source successor.

`decomposition-image` and the trace-carrying
`reachable-decomposition/via` judgment state the meaningful target domain.
