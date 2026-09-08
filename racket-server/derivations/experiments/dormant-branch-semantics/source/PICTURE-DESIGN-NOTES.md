# Dormant work-tree picture notes

The experiment's [inspection.rkt](inspection.rkt) projects its native dormant
work-tree configurations directly. The application's
[search-picture.rkt](../../../../src/search-picture.rkt) projects only current
strict scheduler configurations. Both reuse logical-state, Owner, and goal
drawing from [search-picture-common.rkt](../../../../src/search-picture-common.rkt).
Neither projection executes work or converts one operational carrier into another.

The earlier local `picture.rkt` remains available to its source-specific
property tests. Its extensional picture and deliberately collapsed completion
edges describe that earlier projection, not the current GUI contract.

## Direct work-tree inspection

The operational picture preserves control structure that matters while
stepping:

- `Work`, `Returned`, and `Dead` retain their own visible nodes.
  A returned state is displayed as a `Candidate`, without counting it as a
  committed answer.
- `PendingDelay` renders as a suspended `Delay` node; the saved
  configuration retains the native constructor.
- `Forced`, `More`, `Done`, and `Last` remain visible; terminal failure and
  terminal success are not flattened into an emitted-answer stream.
- `DisjL` and lattice-rail-local `DisjR` share a branch shape but select
  different active children; the isolated distributed experiment retains the
  same right-active syntax on its common carrier.
- `Conj`, `Emit`, work goals, and committed answers remain explicit. Only
  answers on the outer `Emit`/`Last` Frontier spine contribute to the answer
  count; pending bind or nested work cannot contribute an answer early.

Active-child metadata determines highlighting. The frontend does not infer
execution order from a node-name table, and suspended children stay inactive.

## Owner stacks

Every owner-bearing semantic node stores an explicit owner stack:

```text
Owners(Owner(intro, label) ...)
```

Records are ordered outermost-to-innermost. The renderer unwraps `Owners` and
displays each record as one nested `Freshened` node; the stack wrapper is not a
visible node. Record
boundaries, lexical introduction order, labels, and empty introduction lists
are preserved. A node's owner view wraps that node once; shared owners around a
choice or `Emit` are not duplicated into its children.

While descending, the renderer also accumulates the introductions visible on
that structural path and supplies them when rendering a state. That inherited
list is display evidence, not an E runtime Support field or an allocation
cache. The renderer walks the existing substitution directly for reification;
it does not allocate fresh variables or replay the solver. Unused introductions
and sparse ancestry remain in the scope display. State inspection uses both
the actual state and its inherited introductions to distinguish states that
share a source tag.

The renderer recognizes only owner-annotated operational syntax. It does not
reconstruct or accept the retired fresh-marker constructors.

## Phase boundaries

Dormant `force-delay` at the exposed Frontier tip is a native source rule.
Strict public advancement instead records `advance` before the source's
reductions, and its internal `force-delay` is a different operation. Those
differences belong to the source traces, not to drawing or node traversal.

Current completion pictures distinguish `Returned` from `Last` and `Dead` from
`Done`, so `finish-success` and `finish-failure` no longer have the earlier
renderer’s invisible-edge exception. A picture remains a projection; exact
transition claims come from the saved configuration and named source rule.

## Property boundary

The experiment's picture checks cover:

- direct projection of native dormant configurations;
- exact owner nesting, including empty and multi-name owner records;
- visible node vocabulary and serialized AST shape;
- candidates versus committed answers and persistent Done/Last structure;
- source/state selection and absence of solver work during rendering.

Current strict application/history checks remain in `racket-server/tests/`.
The experiment's [picture tests](../tests/picture-tests.rkt) stay with its
inspection provider, alongside the older source-specific picture properties.

`Forced` remains semantic cost and provenance evidence. Sharing a renderer
does not equate the two sources' work order, forcing cost, or Frontiers, and
does not integrate the distributed-conjunction experiment.
