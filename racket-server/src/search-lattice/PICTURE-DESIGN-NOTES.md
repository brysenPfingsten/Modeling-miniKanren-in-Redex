# Picture design notes

The application uses [../search-picture.rkt](../search-picture.rkt) for both
Lattice search and Strict Search. It projects each family's native
configuration directly; it neither executes work while rendering nor converts
one operational carrier into the other. The lattice defaults to Railroad and
also exposes No Interleave and Flip-Flop. Strict Search is a separate view.

The earlier local `picture.rkt` remains available to its source-specific
property tests. Its extensional picture and deliberately collapsed completion
edges describe that earlier projection, not the current GUI contract.

## Current operational picture

The operational picture preserves control structure that matters while
stepping:

- Lattice `Work`, `Returned`, and `Dead` retain their own visible nodes.
  A returned state is displayed as a `Candidate`, without counting it as a
  committed answer.
- Strict `eval`, `mplus`, `bind`, `force`, and `commit` retain their explicit
  pending operations; `One` and `Yield` contain candidates.
- Lattice `PendingDelay` and strict `Delay` render as suspended `Delay` nodes;
  the actual saved configurations retain their native constructors.
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

## Phase and history boundaries

The payload carries the actual named step and `running`, `paused`, `complete`,
or `stuck` status. Lattice `force-delay` at the exposed Frontier tip is its
public operation. Strict public advancement first records an explicit
`advance` invocation, then follows the source's reductions; strict internal
`force-delay` remains an ordinary reduction. These histories preserve each
source's granularity rather than manufacturing matching frame sequences.

Current completion pictures distinguish `Returned` from `Last` and `Dead` from
`Done`, so `finish-success` and `finish-failure` no longer have the earlier
renderer’s invisible-edge exception. A picture remains a projection; exact
transition claims come from the saved configuration and named source rule.

## Property boundary

The current application and picture checks cover:

- direct projection of strict and native lattice configurations;
- exact owner nesting, including empty and multi-name owner records;
- visible node vocabulary and serialized AST shape;
- candidates versus committed answers and persistent Done/Last structure;
- public boundaries, exact saved-history replay, and source/state selection;
- absence of solver work during status inspection and rendering.

`Forced` remains semantic cost and provenance evidence. Sharing a renderer
does not equate the two sources' work order, forcing cost, or Frontiers, and
does not integrate the distributed-conjunction experiment.
