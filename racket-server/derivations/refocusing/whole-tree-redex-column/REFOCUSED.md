# `D_m -> Z_m`: refocusing as a Redex fusion

## Grammar difference

The refocused stage gives the zipper an explicit syntax rather than silently
reusing `D`:

```text
Z ::= ZWork(BR, BF)
    | ZWork(LFR, LF)
    | ZWork(LR, WF)
    | ZFrontier(T, FF)
```

This is exactly the grammar-indexed image of `D`: boundary work, branch-local
fresh work, other local work, and terminal frontier results remain distinct in
the grammar without acquiring runtime sort or phase fields. `D->Z` and `Z->D`
are total structural Redex metafunctions in both directions.

The private query grammar is smaller than the earlier split-context version:

```text
Q ::= QContract(C) | QFrontier(F, FF) | QWork(W, WF)
```

Every work query now retains one complete W-to-F context. There is no
`QResume` form and no independent WW/FF pair that could describe a context
outside the indexed family.

## Arrow presentations

`refocused-spec.rkt` contains the slow specification:

```text
refocus-spec(C) = D->Z(decompose/redex(plug-C(C)))
```

The operational `refocused.rkt` module contains the direct presentation
`refocus-query/direct`; it imports neither `plug-C` nor `decompose/redex` and
traverses only the replacement and retained actual-hole context.

Boundary and local ownership are complete-context distinctions:

```text
QWork(BR, BF)  -> ZWork(BR, BF)
QWork(LFR, LF) -> ZWork(LFR, LF)
QWork(LR, WF)  -> ZWork(LR, WF)
```

Downward search moves one work frame into the full context. The WorkFresh
clause accepts only `LF`, so a WorkFresh directly below More cannot be entered:
it is focused by the `BF` equation. A branch-local WorkFresh can be entered
because the already-present nonfresh frame keeps the extended context in `LF`.

Completed work moves in the opposite direction. The context is matched as
`WF[WFrame]`, where `WFrame` contains exactly the frame adjacent to the hole,
and that frame is plugged around the completed result. The inverse
factorization is unique on `LF`; consequently resumption is an equation of the
same `QWork` program point rather than a separate control mode.

Frontier traversal analogously moves `Emit`, `FrontierFresh`, and `Forced`
frames into `FF`; entering More creates a `BF` context. The mutually recursive
grammar refinements `R` and `NW` partition completed from unfinished work.
Consequently the downward clauses accept `NW` directly while the upward clause
accepts `R`: no judgment or host predicate classifies the next focus.

The two refocused transition presentations contract the same `Z` state and
then use `refocus-spec` or `refocus-direct`. `refocused-red/direct` is the
named reduction-relation projection used by `traces`; its computed label is
the first-class rule/owner pair produced by the direct judgment.

## Executable claim

The tests check that:

- the D/Z codecs are inverse on the reachable image and on 1,000 generated
  raw terms in each grammar;
- every generated direct query has exactly one result;
- the boundary and branch-local WorkFresh examples choose different searches;
- direct refocusing equals plug-and-redecompose structurally, not merely after
  readback;
- the direct/spec refocused step successor sets are identical;
- the named reduction relation exposes the same label and successor;
- readback gives the exact source successor;
- all 28 source rule/owner labels survive; and
- the trace-carrying reachability judgment identifies the theorem domain.

The generated checks are executable bounded evidence, not universal proofs.
