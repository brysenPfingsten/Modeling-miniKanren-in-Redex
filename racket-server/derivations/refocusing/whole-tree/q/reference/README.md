# Marked-to-lean source correspondence

This directory owns the explicit reference map from the independent marked
source to the independent lean source.  Neither reference imports this layer
or the other reference.

At the source stage, `Q_R` removes exactly the three fresh-ownership
constructors:

```text
Q_A(AnswerFresh(intro, A, tag))     = Q_A(A)
Q_W(WorkFresh(intro, W, tag))       = Q_W(W)
Q_R(FrontierFresh(intro, F, tag))   = Q_R(F)
```

Every other source constructor is mapped homomorphically.  In particular,
`Emit`, `Last`, and `Forced` remain, so answer/frontier shape and ordered force
history are not silently discarded with ownership.

The correspondence is weak and alpha-aware, not literal lockstep.  Five
marked ownership-administration rules have equal `Q_R` endpoints and no lean
edge.  Their exact labels are exported by `shared-host.rkt`, and each such edge
strictly decreases `fresh-marker-rank`.  Every other marked edge corresponds
to one lean edge with the same semantic label.  Allocation targets are compared
after first-occurrence alpha-normalization because an unused marked
introduction can disappear with its marker and permit a different canonical
name in lean.

Consequently the source observations divide deliberately:

- answer states, residual frontiers, `Emit`/`Last`, force history, allocation
  multiplicity, and visible rule labels are preserved modulo alpha;
- fresh-owner records are forgotten, with an explicit non-injectivity test;
- lean unit cost equals the marked label count after removing the five
  ownership-administration labels.

This checkpoint contains no `D`, `Z`, `M`, `B`, big-step, cache insertion, or
scheduler-policy derivation.
