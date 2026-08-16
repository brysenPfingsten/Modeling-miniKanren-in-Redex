# `Z_m <-> M_marked`: explicit specialization

The earlier pilot reused decomposition states as machine states. This column
keeps the specialization arrow visible:

```text
Z ::= ZWork(BR,BF) | ZWork(LFR,LF) | ZWork(LR,WF)
    | ZFrontier(T,FF)

M ::= MWork(BR,BF) | MWork(LFR,LF) | MWork(LR,WF)
    | MFrontier(T,FF)
```

The derivation result is that transition specialization leaves no additional
control mode. That result is represented by two distinct, shape-isomorphic
Redex grammars, not by silently identifying the stages. The grammar is the
exact focused image: the broad product of any W with any WF has been removed,
so an unfocused term/context pair is not a machine state.

`encode-ZM` and `decode-MZ` are total structural metafunctions.
`machine.rkt` independently states the direct machine refocuser with its own
query grammar:

```text
MQ ::= MQContract(C) | MQFrontier(F,FF) | MQWork(W,WF)
```

It pushes complete actual-hole contexts, distinguishes boundary `BF` from
local `LF`, and pops the unique adjacent `WFrame` when work is complete. No
`MQResume` control form remains. The direct judgment never calls the Z
refocuser, the Z stepper, or either codec.

`machine-spec.rkt` defines the compositional presentation by transporting the
Z step across the codec. `ZM-step-square` makes the labeled commuting square
an executable correspondence judgment.

The direct module's dependency boundary is also executable. Its parsed
`require` form admits only:

- `contract/redex` and `contract-label` from decomposition;
- the label projection support; and
- the inherited Z language plus `non-outcome/redex`, which is shared static
  syntax classification rather than a Z transition or refocusing operation.

In particular, the direct machine does not import the source relation, root
decomposition, plugging, the slow refocuser, or either Z step relation.

The tests retain raw judgment results rather than deduplicating them. On every
state reached by the finite witness executions, the direct, transported, and
named-relation presentations have exactly one derivation when the state is a
work focus and none when it is a terminal frontier. The structural
correspondence judgment likewise has exactly one result.

Bounded Redex generation strengthens those image checks:

- 1,000 generated Z terms and 1,000 generated M terms satisfy both codec
  inverse laws;
- 1,000 generated MQ terms each refocus to exactly one M;
- 1,000 generated M terms have exactly one direct, transported, and named
  successor when nonterminal, and none when terminal; and
- 1,000 generated roots preserve the labeled Z/M square.

Reachability is additionally checked as a whole-trace property. The tests zip
the Z and M executions from a common source root, restart execution at every
suffix, and compare the raw outputs of both trace-carrying reachability
judgments with the complete set of trace prefixes. For each label prefix, the
reachable M is exactly `encode-ZM` of the reachable Z; duplicate reachability
derivations would fail separately rather than disappear during set comparison.

On that reachable image, all of the following are equivalent and their
readbacks agree:

- the Z state has constructor `ZFrontier`;
- the M state has constructor `MFrontier`;
- the whole readback belongs to the terminal frontier grammar `V`; and
- the Z, M, and source presentations have no successor.

These generated checks are executable bounded evidence, not universal proofs.
