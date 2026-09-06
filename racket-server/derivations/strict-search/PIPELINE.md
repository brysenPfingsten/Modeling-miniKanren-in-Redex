# Strict downstream stages: earlier numeric and matrix checkpoints

The preferred current route is [retained-scope/](retained-scope/README.md),
with its own [correspondence](retained-scope/CORRESPONDENCE.md) and
[register/compression contracts](retained-scope/REGISTERIZATION.md).
This document records the earlier numeric and explicit-prefix matrix
checkpoints. Their shared implementations now live in [shared/](shared/README.md).

The earlier numeric derivation column is:

```text
Rstrict → Dstrict → Zstrict ≅ Mtree,strict → Bstrict → Bigstrict
```

The independent functional derivation and numeric register machine connect to
the same strict source. No arrow here requires the optional online fusion
theorem. The production online calculus remains unchanged.

## Concrete numeric-state column

| Stage | Authoritative artifact | Construction and observation |
| --- | --- | --- |
| R | `source.rkt` | Redex strict contexts and named raw contractions |
| D | `decomposition.rkt` | Canonical redex/context decomposition; plug, contract, then redecompose |
| Z | `refocused.rkt` | Retained one-hole frames; named source edges and explicit administrative traversal |
| Mtree | `machine.rkt` | Independent direct rules over a nested first-order continuation tree |
| B | `compressed.rkt` | Direct residual equations; one source contraction and its finite following administration per edge |
| Big | `big-step.rkt` | Unbounded mutually inductive Search, merge, bind, force, and observation judgments |
| Fixed-point and finite certificates | `big-step-spec.rkt` | Open-recursive equations, finite proof trees, and exact R/B/M trace replay |
| Functional machine | `functional-machine.rkt` | Strict CPS then first-order command/continuation/resumption data |
| Register machine | `register-machine.rkt` | Direct PC dispatch and private operand registers, retaining the functional machine's strict merge frames |
| Functional predecessor | `denotational/semantics.rkt` | Functional goal meanings, Search/readback and native kernel outcomes |
| Numbered functional derivation | `a7-a9/` | ANF, explicit CPS forcing, defunctionalization, generated machine and register dispatcher |

The source and numeric machines use the direct interpreter's goal/State/kernel
boundary. The separate `matrix/` modules instantiate the same strict control
contract over the actual first-order S/E/N carriers.

The numeric route's kernel and Atom callbacks return native functional
Outcomes. Its stages eliminate that already-computed result directly, with
no compatibility conversion. K remains an opaque primitive parameter through
numeric control defunctionalization, so its result functions are retained.
The native S/E/N matrix constructs data outcomes directly; the S functional
routes instantiate shared kernel equations with functional producers and then
explicitly defunctionalize their producers and consumers.

## Native representation and feature matrix

Every cell below has R, D, Z, Mtree, B, and Big artifacts and correspondence
checks. Each feature restricts its goal, computation, value, and observer
grammars; a lower cell cannot accept an unsupported mature value.

| Feature | Structural Owners | Explicit Support | Numeric levels |
| --- | --- | --- | --- |
| Core | SCore | ECore | NCore |
| Delay | SDelay | EDelay | NDelay |
| Disjunction | SDisjunction | EDisjunction | NDisjunction |
| Search/rail | S | E | N |

Sources and Big judgments are statically specialized Redex declarations.
D/Z/Mtree/B are native Racket transition systems instantiated through a common
`Stage` record containing a local contraction, constructor view, and support
operation. They reuse the earlier construction organization; they do not
claim to reproduce its static Redex stage generator. No S/E cell executes by
encoding itself as N.

Direct S-to-E, E-to-N, and independently defined S-to-N maps operate on each
stage's actual controls and retained frame payloads. S retains grouped,
world-local Owner provenance; E retains ordered Support; N addresses variables
by position and allocates consecutive levels. The well-formed reachable domain
preserves trail replay and restricts future bind goals to inherited variables.
See [matrix/README.md](matrix/README.md) and the stage and Big notes it links.

Search/rail explicitly includes the direct interpreter's `mplus-delay`
interaction. It is not the literal union of the two child rule inventories.
The preserved online Search join's separate literal-union law is unchanged.
Other schedulers and relcalls are outside this strict matrix.

## Arrow contracts

**R to D.** D's `readback` plugs the stored redex into its context. Each D step
contracts exactly one raw source redex and recomputes the unique strict
decomposition. The contexts choose the left operand, then the right mature
operand, and never descend beneath Delay. The checked square compares the
complete labeled source successor list with the D readback, without
deduplicating raw Redex proofs. Reconstruction is checked at every visited
configuration.

**D to Z.** Z retains the same strict context traversal between contractions.
Plugging a Z administrative transition leaves the source term unchanged;
plugging a contraction yields one labeled R edge. D and Z are therefore
compared at source-contraction boundaries, not by equating all raw transition
counts. The traversal operates on finite syntax and contexts; it never runs a
kernel callback or unfolds a Fresh body as administration. A Fresh self-loop
remains a semantic contraction even when the term is unchanged.

**Z to Mtree.** `encode-ZM` folds the frame list into a continuation tree, and
`decode-MZ` unfolds it. These structural maps are inverse. The independent M
rules preserve every Z transition, including each administrative edge, with
the same label. Neither map evaluates a source term or runs either machine.

**Mtree to B.** A B state is a canonical residual dispatcher or a final value.
A B edge contains exactly one source label followed by the finite
administrative traversal needed to reach the next residual. Its `Span` is
nonempty. The direct B equations specialize that traversal structurally;
they do not invoke M's stepper until a stopping predicate holds. A separate
composition specification and label-sensitive replay check the exact M path.
No semantic force, suspension production, merge, bind, or observation step is
removed. Spans need not have the old online column's one-to-three-edge bound.

**B to Big.** The Big judgments have ordered inductive premises for both
operands and the merge/bind result. Their conclusion retains the exact source
contraction trace. A materialized finite proof replays that trace against R,
then against B and each B/M span. Conversely, a finite well-formed source run
splits at the strict operand and constructor boundaries into the corresponding
premises. This is the finite-run proof argument; the executable corpus and
certificate checkers are evidence for it, not a mechanized universal proof.

Big itself has no fuel. Its proof-search harness returns
`ProofSearchExhausted` when a supplied depth bound is reached, which is neither
a Big derivation nor evidence that none exists. The unbounded fixed-point
promotion may diverge exactly where proof search has no finite result. A
productive Search can have a finite Delay boundary while its complete
observation has no finite Big derivation.

**Older numeric functional to register machine.** The six program-counter cases directly
implement the functional command clauses. Every nonfinal dispatch corresponds
to exactly one functional transition. In particular the register machine
retains mature left operands and bind-head results while evaluating the
remaining eager work. See [REGISTERIZATION.md](REGISTERIZATION.md) for the
live-register map and its argument.

The earlier [S functional derivation](s-functional/README.md) supplies the
explicit direct/ANF/CPS/data/transition/register sequence with an incremental
interface. Its thirteen control points include commitment of mature active
Search into settled Frontier. KCommit is a runtime continuation, and the
generated data machine has no functional outcomes or resumptions in its
configurations. Its structural correspondence checks intermediate S/E/N
machine states and stops at unforced observation tips. This is distinct from
the older parameterized numeric experiment's opaque kernel boundary.

## Evidence and scope

The concrete aggregate gate is:

```sh
raco test racket-server/derivations/strict-search/all.rkt
```

After consistently naming active Search `Yield` and reserving `More` for
unfinished Frontier work, the combined gate passed **37,620 tests on
Racket 9.3 (2026-09-06)**. The six new constructor-contract tests reject the
obsolete active spelling and aliases, distinguish Search/Frontier grammars,
and check eager contexts and public Delay advancement. The existing stage,
representation, work-order, register, and compression checks run with the
renamed constructors, frames, and operation labels. All seven affected
generated artifacts were regenerated and checked.

After extracting shared implementations and adding retained scope to this
entry point, the combined gate passed **37,614 tests on Racket 9.3
(2026-09-06)**. It includes retained scope's 582 tests and five source-compiled
dependency checks. The extraction preserves generated control bodies apart
from their import paths and retains the original primitive kernel hashes.

Before retained scope was added to this entry point, the combined working-tree
gate passed **37,027 tests on Racket 9.3** after
repairing source resumption/prefix factoring and replacing arbitrary
correspondence spans with prescribed zero-or-one source contractions. It
includes commit/advance/collect and pending prefix through the applicable
S/E/N feature cells and R/D/Z/M/B/Big,
the S functional aggregate, all 20 validation witnesses, intermediate
configuration comparisons with native stopping, and the earlier numeric and
functional comparisons. The 32,209-test checkpoint covered commitment before
this factoring audit; 18,940 covered the preceding functional-boundary repair.
The older 6,449-test checkpoint preceded both.

The verified invocation uses a writable compiled overlay and dependency
checking, avoiding stale expanded macro consumers:

```sh
PLTCOMPILEDROOTS=/private/tmp/strict-factoring-cache: \
  racket -y -l raco -- test racket-server/derivations/strict-search/all.rkt
```

The paired-machine demo shows KCommit and the independently decomposed
commit Frame, then equal naturally halted pending/completed Frontiers. It
also shows KPrefix as the independently derived strict prefix Frame before
fresh allocation, followed by equal output with the saved Owners restored.
Generated functional artifacts still match their unchanged derivation source.
See [COMMITMENT.md](COMMITMENT.md) for the remaining non-isomorphic cases and
the distinction between finite correspondence checks and a general theorem.

The aggregate includes direct interpreter comparisons, every visited D/R and
Z/M edge, B direct/specification and exact span replay, inductive/fixed-point
Big results and finite certificates, all twelve native matrix cells and their
feature inclusions, direct vertical squares and composition, register
dispatch clauses and traces, and negative certificate/divergence witnesses.
The independently generated corpus exercises sparse ordered support, aliases,
disequalities, lexical shadowing, eager bind tails, and mixed delay/choice.
The numeric matrix/register bridge compares exact completed frontiers and
atomic-kernel call order with full incoming States. These finite checks do
not constitute universal adequacy or a coinductive stream theorem.

In the older numeric experiment, kernel and fresh-body callbacks remain
opaque parameters. Tests requiring
literal equality of intermediate terms use stable captured procedures;
fresh-body factories that allocate new closures are tested on exact state
data and contraction labels. Arbitrary host termination and extensional
closure equivalence are not decided by these checkers.

## Reused construction lineage

The downstream construction follows the preserved marked column at
`229bb0cd277d53533f76a5872cd35e88938fa932`, under
`racket-server/derivations/refocusing/whole-tree-redex-column/`: canonical
decomposition; structural Z/M reification with direct machine equations;
direct compression separated from exact-path specification; nonempty labeled
span certificates; and finite fixed-point correspondence. Its dormant-right
contractions and online-specific compression corridor are not copied into the
strict semantics.

The representation matrix separately reuses the actual S/E/N language and
kernel architecture from `a937fb96960959153e31db72c2875294c248f0d4`; its extracted
files and hashes are recorded in `shared/core/PROVENANCE.md`. The native matrix
retains S's grouped world-local provenance, E's ordered support and failure
summary, N's numeric allocation levels, and direct Q maps between them.
