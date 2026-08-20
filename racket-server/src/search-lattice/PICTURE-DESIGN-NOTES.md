# Picture design notes

`picture.rkt` is the single renderer-facing view of the production
owner-annotated carrier. The app and tests consume this module rather than
reconstructing visible trees from raw Redex terms.

## Operational and extensional pictures

The operational picture preserves control structure that matters while
stepping:

- `PendingDelay` renders as `Delay`;
- `Forced` renders as the friendly `Deferred` wrapper;
- `DisjL` and production-rail-local `DisjR` share a branch shape but select
  different active children; the isolated distributed experiment retains the
  same right-active syntax on its common carrier;
- `Conj`, `Emit`, work goals, and committed answers remain explicit.

The extensional picture follows the same traversal but erases `Forced`.
It does not turn the frontier into an answer stream: `Emit` and `Last`
remain structural answer evidence.

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
list is traversal evidence, not allocated-name support and not a runtime cache.
Reification uses the largest
visible numeric logic-variable identifier rather than the list length, so
gapped identifiers created by sibling ownership are handled correctly.

The renderer recognizes only owner-annotated operational syntax. It does not
reconstruct or accept the retired fresh-marker constructors.

## Deliberately invisible phase edges

`More` and `Last` are not visible nodes, while `Dead` and `Done` both
render as `Empty`. Consequently exactly these named transitions may leave the
operational picture unchanged:

```text
finish-success
finish-failure
```

The response `stepName` certifies which edge produced a picture. Every other
representative adjacent named transition must change the visible tree. This is
a finite, testable exception set rather than a blanket visual-change claim.

## Property boundary

The permanent tests cover:

- operational and extensional pictures over core and assembled-search traces;
- exact owner nesting, including empty and multi-name owner records;
- visible node vocabulary and serialized AST shape;
- committed-answer and force counts through independent structural
  observations;
- the two visibility-neutral completion edges;
- visible change for every other representative adjacent transition.

`Forced` remains semantic cost and provenance evidence in the operational
frontier even though the extensional picture erases its wrapper. Answer-only
equality therefore does not imply equal forcing cost.
