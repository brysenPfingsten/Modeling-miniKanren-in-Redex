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

The direct module's dependency boundary is also executable.  Its parsed
`require` form admits only:

- `contract/redex` and `contract-label` from decomposition;
- the label projection support; and
- the inherited Z language plus `non-outcome/redex`, which is shared static
  syntax classification rather than a Z transition or refocusing operation.

In particular, the direct machine does not import the source relation, root
decomposition, plugging, the slow refocuser, or either Z step relation.

The tests retain raw judgment results rather than deduplicating them.  On every
state reached by the finite witness executions, the direct, transported, and
named-relation presentations therefore have exactly one derivation when the
state is nonterminal and none when it is terminal.  The structural
correspondence judgment likewise has exactly one result.  Separate bounded
Redex generation (1,000 attempts in each direction) checks both codec inverse
laws on raw `Z` and raw `M` terms, not only on initialized examples.

Reachability is checked as a whole trace property.  The tests zip the Z and M
executions from a common source root, restart execution at every suffix, and
compare the raw outputs of both trace-carrying reachability judgments with the
complete set of trace prefixes.  For each label prefix, the reachable M is
exactly `encode-ZM` of the reachable Z; duplicate reachability derivations
would fail separately rather than disappear during set comparison.

On that reachable image, all of the following are equivalent and their
readbacks agree:

- the Z state has constructor `ZFrontier`;
- the M state has constructor `MFrontier`;
- the whole readback belongs to the terminal frontier grammar `V`; and
- the Z, M, and source presentations have no successor.

Progress is deliberately qualified by reachability: every reachable
nonterminal state in the checked executions has one exact next step.  The raw
`M` grammar also admits indexed focus/context pairs that have not yet been
refocused; such a term can be nonterminal and stuck, and the tests include one
to prevent accidentally broadening the progress claim.  Thus the arrow is an
exact labeled (non-stuttering) correspondence on its reachable image, not a
claim that every grammar-admitted M term is operationally focused.
