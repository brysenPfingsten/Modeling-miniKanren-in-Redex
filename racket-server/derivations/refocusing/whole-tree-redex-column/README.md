# Whole-tree Redex column

This sibling rebuilds the marked vertical pilot as an explicit sequence of
Redex artifacts.  The earlier `whole-tree-pipeline-pilot` is frozen as a
behavioral oracle; no operational module in this directory imports it.

The selected cell remains:

- full search (delay plus disjunction join),
- late hoisting,
- factored fresh scopes,
- rail/flip-flop scheduling, and
- no relation-call overlay.

The intended column is

```text
R_m -> D_m -> Z_m <-> M_marked -> B_marked -> B_downarrow
```

Every arrow has a compositional specification and a separately stated direct
Redex artifact.  Arrow tests compare complete named successor sets and record
the exact correspondence claim: equality, labeled bisimulation, or a nonempty
ordered label span.  The Q column and feature lattice remain out of scope until
this marked column is complete.

The grammars keep unfinished work `W` internal and frontier terms `F` at the
root.  Context families are indexed by their grammatical input and output
categories.  The sorts are implicit in the grammar, with no reified sort tags.

[`REPORT.md`](REPORT.md) gives the end-to-end pilot verdict, the revised BF/LF
context rationale, compact arrow and label contracts, validation scope, and
remaining research boundary.  The completed `P[K]` instantiation has moved to
the canonical
[`whole-tree/reference/marked/`](../whole-tree/reference/marked/README.md),
whose [`TRACES.md`](../whole-tree/reference/marked/TRACES.md) is the checked-in
output of its self-validating representative-trace exporter.
