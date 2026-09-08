# Strict downstream matrix stages

These stages use the matrix's retained-scope source equations across all
twelve native S/E/N feature coordinates; see the
[research inventory](../../README.md#sen-coordinate-inventory).

`instances.rkt` instantiates the common construction in
[`shared/stages/schema.rkt`](../../shared/stages/schema.rkt) directly
over the native strict S, E, and N sources. S retains grouped Owner provenance
and four-field logical states; E retains ordered named Support in its states
and failures; N retains numeric allocation and addressed variables. No stage
executes an S/E-to-N codec round trip.

Each feature uses its own literal source rule set, recursive goal/computation
grammar, and value/observation predicates. The exported native instances are:

| Feature | S | E | N |
| --- | --- | --- | --- |
| Core | `SCore` | `ECore` | `NCore` |
| Delay | `SDelay` | `EDelay` | `NDelay` |
| Disjunction | `SDisjunction` | `EDisjunction` | `NDisjunction` |
| Search/rail | `S` | `E` | `N` |

Relcalls are outside these source grammars. `tests.rkt` exercises all twelve
coordinates at every downstream stage, including exact feature-inclusion
edges and rejection of absent constructors. Lower coordinates do not merely
run a restricted goal corpus using the full Search machine. Even explicitly
constructed D/B terminal states are checked against their feature's value
grammar before being accepted as complete.

| Stage | State and transition |
| --- | --- |
| D | Canonical redex and frame list; contract, reconstruct whole source, and decompose again. |
| Z | Control and retained frame list; one source contraction or one administrative descent/ascent. |
| Mtree | Control and nested first-order continuation; independent direct transition equations, with structural Z/M inverses. |
| B | Canonical residual dispatcher; one source contraction followed by structural administrative normalization, with the complete exact M label span. |

Each row supplies its local source contraction, a pure constructor view, and
its support-prefix operation. These are shared language/kernel boundaries,
not calls to another stage's transition. Source context closure remains an
independent reference for exact labeled successor comparisons.

Those host operations form a fixed implementation descriptor; they are not
stored in D/Z/M/B semantic configurations. Runtime controls and continuations
are first-order data, and atomic contraction now inspects native
`Failure`/`Success(state)` data. A function-valued kernel result is not hidden
behind the shared boundary. Program goals, active Search, and settled
observations remain the distinct roles described in the
[matrix contract](../README.md#program-active-search-and-settled-frontier).

The observation boundary is derived from the source context `commit E`.
The native view descends through it with a `commit` Frame, which D retains
in its frame list and Z/M retain while refocusing. Eager output construction
similarly produces `emit` frames. Public `advance` and `collect` have their
own source contexts and frame kinds. These views operate on native source
syntax and do not import the functional machine.

Internal S force lifts the removed Delay's Owners onto its stored computation
before that computation runs. Ordinary eval, mplus, and bind controls and
frames retain that ancestry; there is no separate prefix Frame or K
constructor. E/N force enters the stored computation directly, retaining
the same labeled force operation because their state supply already records
the allocation world. Public resumption retains S Owners on Forced and
enters the unprefixed body, while delayed bind also enters its stored
computation directly. Neither reconstructs an empty-owner Delay to force.

`More(Delay)` is a native Frontier normal form in every feature that admits
Delay. D returns DFinal, Z/M finish with empty continuations, and B returns
BFinal at that value without forcing it. Public resumption is a new source
computation, `advance F`; it is not an external cut in a collect-all run.

S allocation reads the ordered owner prefix on the active ancestor path.
Frame metadata records only each ancestor constructor's Owners. Answer-only
Owners and sibling Owners never enter that prefix. Tests compare the retained
frame calculation with the source's separate context calculation at every
reachable zipper state, including sparse initial support and an answer-local
allocation that must not affect the residual.

`../../shared/stages/maps.rkt` defines direct S-to-E, E-to-N, and S-to-N maps at D, Z, Mtree, and B.
They map controls and retained frame payloads without reconstructing or
re-decomposing a source term. The E-to-N map addresses a retained bind goal
using the prefix common to its possible input worlds. Yield heads and choice
siblings keep their individual supports. Their union is never treated as a
shared allocation world.

Compression removes administration only. Each nonempty span contains one
source label followed by the exact administrative labels needed to reach the
next residual. A B step cannot hide unbounded eager search work. Delay
production, forcing, and observer events remain separate source-labeled
edges. The independent `b-step/spec` composes exact M edges, while
`replay-span` checks their order and endpoint. The executable B dispatcher
calls neither that specification nor M/Z transitions.

Run the downstream matrix checks with:

```sh
raco test racket-server/derivations/matrix/stages/tests.rkt
raco test racket-server/derivations/matrix/stages/domain-tests.rkt
raco test racket-server/derivations/matrix/stages/commit-tests.rkt
```

The checks cover every intermediate labeled successor, source readback,
Z/M inverse and transition equation, B direct/specification/exact replay
square, direct vertical map composition, and tampered compression
certificates. The gate also uses independently generated,
scope-aware mixed goals at depth four/five, each from both empty and sparse
ordered initial support with aliasing and disequalities. Every generated
path checks native intermediate states and all three direct vertical maps.
The domain gate additionally checks absent values in manually constructed
terminal states and the retained mature left chunk while the right operand
is still evaluating, in both Mtree and B.

The commitment gate runs commit/advance/collect through R/D/Z/M/B and all
three direct representation maps, including every boundary of the named
validation witnesses. Partial results must terminate by each stage's own
rules. The gate also checks the absence of prefix frames, sparse allocation
beneath retained active Owners, and the separation of force,
resumed evaluation, and commitment at every stage and in all three carriers.

[The checkpoint gate](../retained-scope-tests.rkt) additionally compares the
matrix S stages to the selected source's independently instantiated stages,
then checks the selected functional machine against actual native S/E/N M
steps through its structural configuration maps. Its administrative spans
cannot skip source work, and its native B steps must report and replay the
same exact M spans. No separate E/N functional or register derivation
is implied by this native machine connection.

These check executable correspondence over the supplied corpora. They are not
a general adequacy, guardedness, or coinductive productivity proof.
Administrative normalization is defined over
finite, well-formed reachable controls and contexts; forged frame metadata is
outside that domain.

Construction provenance: the original decomposition, retained-refocusing,
machine reification, and direct/specification compression organization was
inspected at repository commit `229bb0cd277d53533f76a5872cd35e88938fa932`
(`codex/whole-tree-redex-column`), principally
`racket-server/derivations/refocusing/whole-tree-redex-column/{decomposition,machine,compressed,compression-spec}.rkt`
and
`racket-server/derivations/refocusing/whole-tree/reference/marked/machine-schema.rkt`.
Those dormant-right transition rules are not copied or imported here. The
strict constructor views, native stage implementation, and stage maps are
new instances of the reusable construction ideas.
