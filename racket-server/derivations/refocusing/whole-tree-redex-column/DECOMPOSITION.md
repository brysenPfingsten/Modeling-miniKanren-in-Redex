# `R_m -> D_m`: indexed decomposition

## Grammar difference

The source grammar is extended with terminal frontier `T`, boundary-redex
`BR`, local-fresh redex `LFR`, other local redex `LR`, decomposition result
`D`, and contraction result `C`:

```text
D ::= DecWork(BR, BF)
    | DecWork(LFR, LF)
    | DecWork(LR, WF)
    | DecFrontier(T, FF)
C ::= ContractWork(label, W, WF)
    | ContractFrontier(label, F, FF)
```

`WW`, `BF`, `LF`, `WF`, and `FF` remain genuine Redex contexts containing
`hole`.  Their input/output categories are their grammar indices; neither `D`
nor `C` carries a W/F field.  `BF` and `LF` are the boundary/local partition
of complete W-to-F contexts.  Consequently the grammar of `D`, not a dynamic
predicate, excludes impossible pairs such as a bare `Returned` focus beneath
a conjunction frame.

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
| ordinary local W redex in `WF` | `DecWork(LR,WF)` | `ContractWork(label,W',WF)` |
| branch-local fresh redex in `LF` | `DecWork(LFR,LF)` | `ContractWork(label,W',LF)` |
| W redex immediately below `More` in `BF` | `DecWork(BR,BF)` | `ContractFrontier(label,F',FF)` |
| terminal in `FF` | `DecFrontier(T,FF)` | none |

Every source rule maps to the identically named/owned contract clause.  The
six `More` rules are exactly the clauses producing `ContractFrontier`; all
other rules produce `ContractWork`.

## Executable claim

On toy-kernel well-formed source terms:

1. The raw match counts for `(in-hole BF BR)`, `(in-hole LF LFR)`,
   `(in-hole WF LR)`, and `(in-hole FF T)` sum to exactly one, before the
   decomposition judgment is invoked.
2. `decompose/redex(F,D)` has exactly one raw derivation, not merely one
   deduplicated result.
3. `plug-D(D) = F`.
4. The source named successor set equals the set obtained by decomposition,
   contraction, and `plug-C` (preservation and reflection).
5. The compositional and direct decomposed successor sets are identical.
6. Successor decompositions read back to the exact source successor.

`decomposition-image` and the trace-carrying
`reachable-decomposition/via` judgment state the meaningful target domain.
Generated checks also establish that `BF` has no work-frame pop and every
`LF` has exactly one innermost `WFrame` decomposition.  This is the structural
fact used by the full-context refocuser: it can push with `in-hole` and pop the
innermost frame without storing separate `WW` and `FF` components.
