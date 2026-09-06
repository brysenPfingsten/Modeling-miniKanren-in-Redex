# Strict Big and fixed-point stages in the representation matrix

This directory completes the finite Big presentation for the twelve current
coordinates: Core, Delay, Disjunction, and Search/rail, each in S, E, and N.
The source is the strict Search semantics. There is no dormant-right policy
or strict-to-online fusion in these artifacts.

## Native equations and feature instances

`s-schema.rkt` defines the S equations over local `Owners`, answer-local
ownership, and the original four-field logical state. An explicit ordered
support parameter records the enclosing active Owner path. Both operands of
strict `mplus`, an eager `Yield` tail, and recursive bind residuals inherit the
appropriate shared prefix. Answer-local owners do not enter the residual.
Internal forcing evaluates a strict `prefix(Owners,c)` premise. Its saved
Owners supply allocation ancestry while `c` evaluates; the returned mature
Search receives those Owners only after that premise finishes. The native
E/N equations retain unary `prefix(c)` and its `prefix-value` contraction,
preserving the same premise tree and exact labels after ownership erasure.

`ownerless.rkt` specializes the equations separately for E and N at macro
expansion. E retains named variables and ordered `Support`; N retains
positional variables and its numeric counter. Each uses its selected native
kernel and allocator. Execution does not encode a row into another row.

Atomic premises match native `Failure`/`Success(state)` results as data.
They do not apply functional result selectors. The primitive equations
complete eagerly before the premise constructs its Search result; this
first-order boundary is shared with the matrix's source rules.

The Search judgments describe active computation and mature residuals.
`commit-big` constructs a partial settled frontier `F` from mature Search,
stopping at `Delay` with unary `More(Delay(...))`. It neither forces that body
nor changes the strict operand schedule. `advance-big` crosses one exposed
suspension and commits its next mature chunk; `collect-big` explicitly crosses
every remaining suspension and concludes a completed observation `O`.

In S, committing `One(Owners,state)` places those Owners on the terminal
Answer under an empty outer Last. That transfer is an explicit observation
boundary. Both the syntactic and functional presentations use Yield for the
active Search cell; unary Frontier More holds unfinished Delay work.

Legacy `render-big` retains its existing collect-all behavior; its `render-*`
labels distinguish the constructor cases. The general `observe-big` judgment now concludes partial
`F`, including complete `O`, and accepts native `commit`, `advance`, and
`collect` query contexts as well as legacy `render`. Its value clause admits
partial frontiers without evaluating their suspended tips.

`s.rkt`, `e.rkt`, and `n.rkt` instantiate Search/rail. `features.rkt`
instantiates the remaining nine coordinates using the corresponding
restricted source grammar. `feature-schema.rkt` removes unavailable literal
judgment rules and fixed-point constructor cases during macro expansion.
Smaller coordinates have no runtime feature switch. Public fixed-point
entries check their actual feature domain, including control constructors.

The operation judgments are `search-big/<coordinate>`,
`merge-big/<coordinate>` where disjunction exists, `bind-big/<coordinate>`,
`render-big/<coordinate>`, `commit-big/<coordinate>`,
`advance-big/<coordinate>`, `collect-big/<coordinate>`, and
`observe-big/<coordinate>`. Coordinates are
`s`, `e`, `n` for Search/rail, or names such as `s-core`, `e-delay`, and
`n-disjunction`. S judgments additionally take the inherited support prefix.

These are mutually inductive, unbounded judgments. They give a mature Search
or exact partial/completed frontier and an ordered list of source contraction labels.
There is no transition relation, normalized machine execution, or numeric
fuel inside their premises. `promote/<coordinate>` ties the corresponding
constructor-erased recursive equations directly; it is an independent
unbounded fixed-point evaluator, not a call to judgment search.

The strict premises evaluate the left operand, evaluate the right operand,
and then merge. Bind over `Yield` evaluates the continuation result and the
recursive residual before merging. A `Delay` is a value without a premise
for its body. Internal forcing enters the body through pending `prefix`;
public consumers resume the stored computation directly. Observations retain exact
`Emit`, `Forced`, `Last`, and `Done` structure and all native state fields.
An exposed advancement records `advance-delay`, then the resumed computation's
strict search labels, then its `commit-*` labels. It introduces no synthetic
`force-delay` or `prefix-value` event. Collection additionally
performs the recursive `collect-*` premises. Existing `Forced` prefixes are
retained through `advance-forced` or `collect-forced`; merely constructing
unary `More(Delay(...))` records no forcing event.
Delayed bind likewise stores the computation directly under the pending
bind. Its public resumption does not reconstruct and force an empty-owner
`Delay`. A genuine delayed merge still uses internal force, retaining both
the force boundary and the final attachment of its saved owners.

## Finite certificates and vertical maps

`evaluate/<coordinate>` returns `(list value source-labels)`.
`raw-derivations/<coordinate>` returns Redex derivation trees without
deduplicating identical conclusions. The tests require exactly one raw
derivation for each admitted witness, including mature/pending
`Yield`, `Emit`, and `Forced` cases.

`maps.rkt` extracts `BigCertificate` from those native derivation trees. Each
node retains its operation, feature/row coordinate, inherited S prefix,
native input, native result, ordered labels, and every recursive premise.
Only presentation names of rules are omitted; the operation, input, and
premise tree determine the rule. Thus saved mature chunks and prefix-sensitive
fresh premises remain visible inside the certificate.

The exported `QBig-SE`, `QBig-EN`, and independently defined `QBig-SN` map
every node's input and result, not just the root's final observation. S maps
use that node's inherited prefix before erasing or addressing ownership.
The target E/N certificate has no implicit ownership prefix. Labels,
premise order, and the feature coordinate are preserved.

The intended vertical contract, on the source row's well-formed domain, is:

```text
QBig-SE(CertS(q ⇓ v, labels)) = CertE(Q-SE(q) ⇓ Q-SE(v), labels)
QBig-EN(CertE(q ⇓ v, labels)) = CertN(Q-EN(q) ⇓ Q-EN(v), labels)
QBig-SN(CertS) = QBig-EN(QBig-SE(CertS))
```

These equalities compare full recursive certificates. Tests obtain the
target certificate independently from its native judgment before comparing.

For each finite witness, Big's ordered labels equal the exact R trace and
the semantic labels of B's spans. Each B span is independently replayed in
M, and its final readback equals the Big conclusion. The finite-run
correspondence argument follows the Big derivation: lift operand premises
under strict contexts, perform the named local contraction, and lift the
remaining premises under the resulting constructors. There is no lift
beneath an unforced `Delay`. Conversely, a finite deterministic source run
splits at those strict context boundaries; the established B/M spans carry
the same finite run.

## Validation and scope

```sh
raco test racket-server/derivations/strict-search/matrix/big/tests.rkt
```

The full gate contains **138 test cases**. Its preserved original 113 cases
comprise 108 feature-corpus cases and five
targeted cases. Each corpus case checks both mature Search and complete
observation in all three native rows, exact source/B labels, M span replay,
fixed-point agreement, raw proof uniqueness, the direct interpreter oracle,
and recursive QBig squares/composition. Additional cases cover intermediate
nested-rail states, inherited and sparse support, shared versus answer-local
ownership, constructor overlaps, and rejection of absent features.

The native-frontier extension adds the 20 pure allocation/settlement witnesses
from `../../test-support/witnesses.rkt`. At every exposed boundary it checks
partial value proofs, commit, advancement, and explicit collection against
exact R/B results and label traces, fixed-point equations, unique raw proofs,
and full recursive S/E/N certificate maps. Further cases assert exact forcing
labels and exercise the new operations in all twelve feature/row instances.
Complete results are also compared with the preserved legacy render result.
Three source-factoring regressions check pending-prefix allocation and
attachment order, the full internal-force/prefix certificate subtree, direct
resumption in delayed bind and public render, and exclusion of prefix control
from Core and Disjunction. Delay and Search both exercise the new phase in
all three native rows.

This is an executable finite derivation and correspondence checkpoint.
The unbounded inductive presentations are not bounded interpreters; the
finite witness gate is not a general mechanized preservation, adequacy,
productivity, or coinductive stream proof. Relcalls and strict-to-online
fusion are outside these coordinates. The direct strict Big checkpoint in
`../../big-step-spec.rkt` separately distinguishes bounded proof-search exhaustion
from a semantic result and checks unguarded divergence witnesses.
