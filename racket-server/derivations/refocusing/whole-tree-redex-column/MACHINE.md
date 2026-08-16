# `Z_m <-> M_marked`: explicit specialization

The earlier pilot reused `DecWork` and `DecFrontier` as machine states.  This
column keeps the arrow visible:

```text
Z ::= ZWork(W,WF)     | ZFrontier(T,FF)
M ::= MWork(W,WF)     | MFrontier(T,FF)
```

The derivation result is that exact refocusing leaves no additional control
mode.  That result is represented by two distinct but shape-isomorphic Redex
grammars, not by silently identifying the stages.

`encode-ZM` and `decode-MZ` are total structural metafunctions.  The direct
machine relation is independently stated in `machine.rkt`: its own
`MQContract`/`MQFrontier`/`MQWork`/`MQResume` judgment traverses retained
contexts and never calls the Z refocuser or Z stepper.  The shared contraction
judgment and completed-work classification are inert inputs to both stages.

`machine-spec.rkt` defines the compositional presentation by transporting the
Z step across the codec.  `ZM-step-square` makes the labeled commuting square
an executable correspondence judgment.

On reachable states the tests establish both codec round trips, exact labeled
successor equality between transported and direct presentations, named
reduction-relation equality, terminal/readback agreement, and trace-certified
reachability.  This is a strong labeled bisimulation, not a stuttering claim.

