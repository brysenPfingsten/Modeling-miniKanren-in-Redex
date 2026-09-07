# Strict representation and feature matrix

These native S/E/N feature instances use the retained-scope operation of the
selected S source and interpreter in
[retained-scope/](../retained-scope/README.md). Common grammars, kernels,
representation maps, and stage construction live in [shared/](../shared/README.md);
this directory owns the matrix's source and Big rules and their instances.
The [research guide](../README.md#sen-coordinate-inventory) owns the complete
coordinate inventory and remaining obligations. Source and R/D/Z/M/B/Big
equations use this factoring in all twelve feature cells. The
[checkpoint gate](retained-scope-tests.rkt) connects the independently stated
Search/rail S source and stages to the selected S functional machine and the
native E/N machine transitions.

This matrix adds the `strict-round` branch-evaluation coordinate to the
preserved S/E/N representation contract. Each row evaluates both operands of
`mplus` before merging, constructs eager `Yield` tails, and evaluates both
continuation and residual work in `bind`. Only `Delay` retains a suspended
computation. The source equations are new strict equations; the variable,
state, allocation, unification, and disequality machinery comes from the
selected older matrix, with exact provenance in [PROVENANCE.md](../shared/core/PROVENANCE.md).

Each row's atomic kernel directly returns first-order `Failure()` or
`Success(state)` data. Source and Big-step equations match that result to
construct their native Search values. Kernel work is eager; no callback is
stored in an outcome and no result adapter is involved. Primitive unifiers
retain their existing internal results. Native source, stage, and Big checks
obtain results independently within these matrix presentations.

## Program, active Search, and settled frontier

These are different semantic roles, independent of the S/E/N representation
coordinate:

| Role | Existing matrix syntax | Operational responsibility |
| --- | --- | --- |
| Program | `g`: atomic goals, fresh, conjunction, disjunction, suspend | Describes work to evaluate against a state. A disjunction in `g` is not a computed answer or a scheduler residual. |
| Active Search | `c`: eval/mplus/bind/force computations; mature `SV`: Empty/One/Yield/Delay | Retains strict work and mature eager chunks that merge/bind may still process. A mature answer is not automatically settled output. |
| Settled frontier | `F`: Done/Last/Emit/Forced and unary More(Delay); `O` is the completed subset | Contains committed answers and at most one explicit unfinished tip. It is a normal form even when that tip is pending. |

Observation computations `o` include `commit c`, `advance o`, and `collect o`.
The public query starts at `commit(eval(goal,state))`. The context `commit E`
matures its Search operand strictly before any commitment rule applies.
Commit converts Empty/One/active Yield to Done/Last/Emit, but converts Delay
to unary `More(Delay)` without forcing. There is no evaluation context under
that unfinished-work wrapper or under Delay.

`advance F` preserves the settled prefix and crosses one exposed Delay;
`collect F` explicitly consumes all remaining exposed Delays. Commitment
performs no forcing; the consumers have explicit crossing rules. Their
contexts and rules are
part of each native source, not test-runner stopping conditions.

The functional derivations and this matrix use `Yield` for active Search and
`More(Delay(...))` for unfinished Frontier work. Their structural maps preserve
these constructor names while mapping allocation information and resumption
representations. An active Yield is neither program disjunction nor settled
output. The matrix retains strict operand evaluation and eager Search tails.

The S `commit-one` rule marks the owner-transfer boundary:
`One(Owners,state)` becomes `Last(empty-Owners,Answer(Owners,state))`.
This preserves the placement used by the older `render-one` rule. Commit of
an eager tail preserves common and answer-private ownership; public advance
retains a crossed Delay's Owners on Forced and commits the unprefixed body.
Active merge/bind and internal force retain their own role and strict order.

Public advance/collect/render expose the stored body directly, as does the
resumption stored by delayed bind. Internal force instead retains the removed
Delay's introductions on the active body:

```text
S:   force(Delay(O,c)) → lift_O(c)
E/N: force(Delay(c))   → c
```

`lift_O` prepends O to the active body's root Owners and passes through a
`force` wrapper. S allocation therefore sees those introductions while the
body runs. E/N already carry the corresponding allocation world in states and
failed values. There is no syntactic `prefix` computation, `prefix-value`
contraction, or prefix frame in any row. The functional interpreter still
uses a `prefix` helper to attach Owners to an already mature Search; that
helper does not resume work or derive a pending continuation.

The older `render c` operation remains an explicit full-consumption observer
for comparison. It can resume repeatedly and is not the partial public query.
Finite equality with `collect(commit c)` is checked independently. This
extension introduces no fusion, scheduler, or branch-evaluation policy.

## Representation carriers

| Property | S | E | N |
| --- | --- | --- | --- |
| Runtime variables | Named `u:*` atoms | Named `u:*` atoms | Bare natural levels; numeric data is `(nat n)` |
| Logical state | `(state sub dis trail tag)` | `(state (Support u ...) sub dis trail tag)` | `(state next sub dis trail tag)` |
| Allocation history | Ordered tagged `(Owner intro tag)` groups at computation/value/observer positions | Ordered state-local Support | State-local next level |
| Failed world | `(Empty Owners)` / `(Done Owners)` | `(Empty Support)` / `(Done Support)` | `(Empty next)` / `(Done next)` |
| Fresh | Least unused canonical names from the active world path | Least unused canonical names from state Support | Consecutive interval starting at next |

S never stores cumulative support in its logical state. Its strict constructors
are:

```text
eval   ::= (eval Owners g state)
merge  ::= (mplus Owners c c)
bind   ::= (bind Owners c g)
Search ::= (Empty Owners)
         | (One Owners state)
         | (Yield Owners (Answer Owners state) Search)
         | (Delay Owners c)
```

Owners on `mplus`, `bind`, `Yield`, and `Emit` are common world prefixes. An
`Answer`'s Owner groups belong only to that answer; they never reserve names in
its residual or sibling. Source allocation reads exactly the Owner groups
along the active strict evaluation context. Empty binders retain an empty,
tagged Owner group and an `allocate-fresh` transition.

E and N erase those Owner positions and have ordinary ownerless strict
`eval`/`mplus`/`bind`/`Yield`/`Delay` constructors. The successful state carries
the cumulative supply. Failure retains only the supply summary, never the
failed substitution, constraints, trail, or state tag. Siblings copy their
incoming world independently and may allocate the same name/level after
splitting.

## Feature ownership and scheduler policy

Every feature has a separate recursive goal grammar, value/observation grammar,
and statically generated Redex rule set in each representation:

| Feature coordinate | Goals and carriers added | Strict rule count |
| --- | --- | --- |
| Core | Atomic goals, lexical fresh, conjunction; Empty/One, Done/Last, eval/bind and observation operations | 13 |
| Delay | suspend; Delay/force/Forced, unfinished More(Delay), explicit crossing | 22 |
| Disjunction | disjunction; active Yield/mplus/Emit | 22 |
| Search/rail | Both features plus the rail merge of Delay | 32 |

These counts describe unique rule labels, not test passes. Lower rows reject
absent constructors even inside a mature value or observer; they do not merely
disable source-goal parsing. `../shared/feature-schema.rkt` selects literal clauses and
grammar productions at expansion time. It does not gate a full relation with
a runtime feature predicate.

The full strict coordinate is **Search/rail**. Its `mplus-delay` rule is an
explicit interaction beyond the union of the two child rule sets. This is
where the direct interpreter's oriented rail policy acts. The old online
family's scheduler-neutral literal Search union is preserved in its own
policy; it is not asserted as a law of this strict interpreter coordinate.

## Direct representation maps and domain

`../shared/maps.rkt` independently defines `Q-SE`, `Q-EN`, and direct `Q-SN`. S maps
accumulate Owner introductions along each world path; E maps address names by
their positions in the ordered Support, including sparse and unused entries.
`Q-SN` never calls the other two maps. No source coordinate executes by
converting itself to N and invoking another evaluator.

`../shared/wf.rkt` checks grammatical membership, duplicate-free ordered world supply,
runtime-variable coverage, acyclic substitution, lexical scope, numeric bounds,
exact unification-trail replay from the empty substitution, and the support
available to future bind goals. Trail replay uses each preserved row kernel
and must reproduce the stored substitution including its order and alias
structure. Sparse initial stores therefore include their complete alias
trail. S future goals may use only
their enclosing world prefix. E future goals are checked against the common
ordered support prefix of the worlds reaching them. Named support alone does
not recover erased allocation ancestry: the intended prefix-coherent domain
is reachable configurations from well-formed roots and their explicit S/E/N
translations, with future goals referring only to inherited variables. A raw
grammar match is not a proof of that domain.

The core corpus includes empty, unused, multiple and shadowing fresh binders;
aliases, occurs checks and disequality failure; and allocation followed by
failure. Feature corpora add independent sibling allocation, shared outer
variables, eager bind tails, Delay-only behavior, and nested oriented rail.
The source suite checks exact named successor multiplicities, complete label
traces, all three vertical maps and direct composition at every reached state.
[property-tests.rkt](property-tests.rkt) extends those checks over generated
lexical goals using the native S/E/N rows.

[retained-scope-tests.rkt](retained-scope-tests.rkt) checks the independently
stated selected and matrix S sources and D/Z/M/B configurations at each edge.
It then maps the selected S functional configuration into native S/E/N M
configurations and checks actual native steps: one preclassified source
operation with only administrative normalization around it. Native B steps
must report and replay that exact M span. Direct S→N and
S→E→N remain separate checks. These checks include commit, advance, collect,
exact intermediate Frontiers and suspended bodies. They derive no separate
E/N functional interpreter or register program.

These are bounded executable correspondence checks. They do not constitute
universal adequacy, naturality, guarded fusion, or productive-stream proofs.
The source's `eval-atom` label is its strict atomic contraction; preserved
kernel operations do not imply identity with the old online source's work
trace.

## Full relation programs

[full-source.rkt](full-source.rkt) extends Search/rail in all three allocation
representations with named relations, recursive and mutually recursive calls,
and an explicit `(program Γ q)` environment. Call expansion is a named
`eval-call` step. It substitutes actual arguments without adding a Delay;
suspension comes from the program or the selected compilation profile.

[stages/full.rkt](stages/full.rkt) supplies SRel/ERel/NRel through D/Z/M/B.
Their program frames retain Γ as data. Its status predicates inspect the next
syntactic phase without performing kernel work: `running`, `paused` at a
Frontier ending in More/Delay, `complete`, or `stuck`.
[big/full.rkt](big/full.rkt) gives independent finite equations and certificates
whose recursive premises retain the same environment.

[full-tests.rkt](full-tests.rkt) checks exact source and stage edges, S/E/N
maps, well-formedness, finite and mutual recursion, bounded productive rounds,
unguarded calls, lexical shadowing, fresh across Delay, sparse ancestry, nested
rails, and pending bind. [big/full-tests.rkt](big/full-tests.rkt) checks the
finite judgments and direct certificate maps. The selected functional route's
[relation checks](../retained-scope/relation-tests.rkt) connect its independently
derived machine to these actual native configurations. This adds three full
language instances above the twelve call-free representation/feature cells;
it does not introduce separate E/N functional pipelines.

The compiler and GUI execute `strict-s-rel-red` from this module directly.
The twelve compiler profiles (associativity and delay placement) are distinct
from the matrix's twelve call-free representation/feature cells.

## Files and interfaces

- `source-s.rkt`, `source-e.rkt`, `source-n.rkt`: call-free Search/rail source rows.
- `full-source.rkt`, `full-tests.rkt`: full relation-program extension and checks.
- `features.rkt`: separately generated Core, Delay and Disjunction rows.
- `../shared/maps.rkt` and `../shared/wf.rkt`: direct source maps and executable domain checks.
- `kernel-tests.rkt`: native data outcomes, complete State preservation,
  unification/disequality results and failures; imported by the source gate.
- `commit-source-tests.rkt`: native commitment and public resumption rules,
  partial normal forms, ownership, and direct S/E/N squares.
- `stages/`: decomposition, refocusing, machine, compression, and stage maps;
  its README records the stage-specific construction and evidence.
- `big/`: direct finite Big equations over the actual row carriers.
- `property-tests.rkt`: generated-goal representation and source checks.
- `retained-scope-tests.rkt`: selected S checkpoint and actual S/E/N source
  and machine transition checks.
- `all.rkt`: aggregate source, feature, property, stage, and Big checks.

Each source exposes its own named relation, `contract`, Search-value,
complete-observation, and partial-frontier predicates. `initial` constructs
an eval computation; `query-initial` constructs its public commit computation.
`s-contract(redex, prefix)` accepts
the active world's ordered named support; S stages derive that prefix from
their actual Owner-bearing frames. E/N contracts accept the same optional
argument and read supply from their own focused state. Public source run/trace
budgets reject negative values; exhaustion is an error, not a terminal value.

Run the full matrix aggregate from the repository root:

```sh
raco test racket-server/derivations/strict-search/matrix/all.rkt
```

The focused source/feature, [stage](stages/README.md), and [Big](big/README.md)
suites remain independently runnable. A source-only run does not establish
the complete horizontal pipeline. The gate checks the retained-scope S/E/N
connection over finite witnesses; it does not establish a universal machine
correspondence or productive streams. Relation programs have the separate
finite and bounded checks described above; these are not universal proofs.
