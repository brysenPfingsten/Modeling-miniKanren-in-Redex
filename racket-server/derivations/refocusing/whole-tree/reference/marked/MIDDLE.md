# P[K] middle column: decomposition to marked machine

This directory factors the refocused and marked-machine stages into one shared
control schema and two precise instances:

```text
refocused-schema.rkt       toy/refocused.rkt       mk/refocused.rkt
refocused-spec-schema.rkt  toy/refocused-spec.rkt  mk/refocused-spec.rkt
machine-schema.rkt         toy/machine.rkt         mk/machine.rkt
machine-spec-schema.rkt    toy/machine-spec.rkt    mk/machine-spec.rkt
```

The schema boundary is intentionally narrow. The direct refocused schema is
given a decomposition language, contraction judgment, label projection, and
names for the resulting bindings. The machine schema receives the same
decomposition/label interface plus the refocused language. Neither schema is
given `kernel-step`, fresh allocation, unification, a state predicate, or an
observation function. Kernel behavior has already been sealed behind the
preceding source and contraction artifacts.

Each thin instance expands the same schema in a precise language:

```text
P[Ktoy] uses pk-toy-decomposition-lang
P[Kmk]  uses pk-mk-decomposition-lang
```

Consequently the shared equations cannot inspect a toy payload or a
miniKanren substitution. Mixed-kernel states do not match either instance
grammar; no runtime kernel tag or compatibility check is added.

## D to Z

The refocused state grammar is exactly the decomposition image:

```text
Z ::= ZWork(BR,BF)
    | ZWork(LFR,LF)
    | ZWork(LR,WF)
    | ZFrontier(T,FF)
```

`D->Z/K` and `Z->D/K` are explicit inverse metafunctions. The slow
`refocus-spec/K` reconstructs a complete frontier with `plug-C/K` and invokes
`decompose/K`. The independently stated `refocus-query/direct/K` retains and
traverses actual-hole contexts directly.

Its only private program points are:

```text
Q ::= QContract(C) | QFrontier(F,FF) | QWork(W,WF)
```

There is no resume form. Downward search pushes one work frame into the full
W-to-F context. WorkFresh descent is restricted to `LF`, making a boundary
WorkFresh in `BF` ineligible. Completed work pops the unique adjacent
`WFrame`. Thus boundary ownership and branch-local ownership are properties of
the complete indexed context, not of a state flag.

## Z to M

The marked machine has the shape-isomorphic exact image:

```text
M ::= MWork(BR,BF)
    | MWork(LFR,LF)
    | MWork(LR,WF)
    | MFrontier(T,FF)
```

`encode-ZM/K` and `decode-MZ/K` keep the conceptual specialization arrow
visible. The direct M relation independently repeats the full-context
equations in `MQ` syntax and does not call the Z refocuser or either codec.
`machine-step/spec/K` instead transports the Z step across the codec, and
`ZM-step-square/K` records their exact labeled commuting square.

Both stages retain trace-carrying reachability judgments. Their theorem domain
is selected by the kernel-specific root well-formedness judgment supplied only
to the specification/reachability modules.

The middle tests run the same raw grammar, direct/specification, codec,
labeled-bisimulation, named-relation, and exact reachability checks for both
instances. Generated checks are bounded executable evidence rather than
universal proofs.
