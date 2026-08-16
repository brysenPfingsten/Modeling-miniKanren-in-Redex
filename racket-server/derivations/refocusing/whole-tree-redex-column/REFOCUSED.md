# `D_m -> Z_m`: refocusing as a Redex fusion

## Grammar difference

The refocused stage gives the zipper an explicit syntax rather than silently
reusing `D`:

```text
Z ::= ZWork(W, WF) | ZFrontier(T, FF)
```

`D->Z` and `Z->D` are structural Redex metafunctions.  The contexts remain
actual-hole W→F and F→F families; no phase or sort field is added.

`QContract`, `QFrontier`, `QWork`, and `QResume` are private derivation-query
forms used by one self-recursive judgment.  They are program points of the
derivation, not machine states.

## Arrow presentations

`refocused-spec.rkt` contains the slow specification:

```text
refocus-spec(C) = D->Z(decompose/redex(plug-C(C)))
```

The operational `refocused.rkt` module contains the direct presentation
`refocus-query/direct`; it imports neither `plug-C` nor `decompose/redex` and
traverses only the replacement and retained actual-hole context.  It has
explicit down and up equations for
frontier prefixes, `WorkFresh`, conjunction, and both rail orientations.
`non-outcome/redex` is an executable Redex judgment that separates downward
search from completed-work resumption; host predicates do not choose clauses.

More-boundary priority remains visible in the direct rules:

```text
QWork(BR, hole, FF) -> ZWork(BR, FF[More(hole)])
```

Branch-local `WorkFresh` is focused only with a nonempty `TopW+` context.

The two refocused transition presentations contract the same `Z` state and
then use `refocus-spec` or `refocus-direct`.  `refocused-red/direct` is the
named reduction-relation projection used by `traces`; its computed label is
the first-class rule/owner pair produced by the direct judgment.

## Executable claim

On reachable states and contracta:

- `Z->D(D->Z(D)) = D` and `D->Z(Z->D(Z)) = Z`;
- both refocus judgments have one identical result;
- direct refocusing equals plug-and-redecompose structurally, not merely after
  readback;
- the direct/spec refocused step successor sets are identical;
- the named reduction relation exposes the same label and successor;
- readback gives the exact source successor; and
- the trace-carrying reachability judgment identifies the theorem domain.
