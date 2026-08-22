# Independent core representation oracles

This subtree is the Checkpoint 2 source layer selected by
[`../../ARCHITECTURE-CONTRACT.md`](../../ARCHITECTURE-CONTRACT.md). It contains
three independently written Redex source languages, reduction relations, and
well-formedness judgments:

```text
R[S]  world-local Owner introductions
R[E]  ordered named support in logical states
R[N]  numeric logic variables plus state-local next
```

None of these source relations is emitted from the stage generator, imported
from production, or generated from a shared semantic table. Their common rule
names are compared only after all three direct artifacts exist. Representation
strategy extraction is deliberately deferred to Checkpoint 3.

## Carrier and allocation choices

S retains ordered `(Owner intro tag)` records on provenance-bearing syntax.
Its allocator reads only the Owner records on the selected core world path.
Two independently selected sibling worlds can therefore copy an outer prefix
and reuse the same later `u` atom without creating a global frontier supply.

E has no Owner or repeated Support carrier slots. Its logical state is:

```text
(state (Support u ...) sub dis trail tag)
```

Fresh appends the first missing canonical `u` atoms to that ordered support.
Conjunction threads the Returned state; two independently copied worlds evolve
their supports independently.

N has bare naturals as runtime logic variables, distinct from object-language
`(nat number)` data. Its logical state is:

```text
(state next sub dis trail tag)
```

A `k`-binder fresh at `next = n` allocates `n` through `n+k-1` and advances to
`n+k`. Empty fresh therefore retains the counter while still taking the named
`allocate-fresh` transition.

All three fresh contractions substitute only the current lexical binders,
simultaneously and in binder order. Nested binders shadow equal lexical names;
other lexical variables and already allocated runtime variables remain intact.

## Vertical maps at R

[`vertical.rkt`](vertical.rkt) defines three direct structural maps:

- `Q-SE/F` flattens Owner introductions along the active world path into E
  state support and erases persistent Owner syntax;
- `Q-EN/F` addresses E support by its stored order and sets `next` to its
  length; and
- `Q-SN/F` traverses S directly and assigns the same numeric addresses without
  calling either other map.

`Q-SN-composition?` checks the direct map against `Q-EN/F` after `Q-SE/F`.
The one-step square checks compare complete named successor multisets and exact
rule labels for all thirteen core rules.

There is one explicit proof-domain wrinkle, not a carrier change. A failed
left conjunct reaches `(Conj (Dead) g)` before `conj-fail`; E has intentionally
discarded the only logical state, although the inert `g` may still contain
named runtime atoms. On that short supportless administrative corridor,
`Q-EN/F` is indexed by the ordered address witness obtained from the preceding
state/world ancestry. State-bearing E configurations determine that witness
themselves. The witness exists only in the correspondence relation: it is not
Support, Owner, Fresh, or `next` syntax added back to E or N.

The current executable claims are scoped to well-formed reachable core
configurations paired with that witness when necessary. They include every
rule, sparse/noncanonical E support, sibling-local reuse, exact label order,
WF preservation, direct `Q_SN = Q_EN o Q_SE`, and a finite successful trace.
These checks are evidence, not a universal Redex proof and not a feature-level
naturality claim.

## Focused gate

From the repository root:

```text
raco test racket-server/derivations/search-lattice/oracles/core/tests.rkt
```

The production search lattice remains unchanged and does not import this
subtree.
