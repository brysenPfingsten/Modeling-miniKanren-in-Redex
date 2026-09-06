# Strict Search research artifact

The selected account is **retained-scope S, Search/rail**. Its
[interpreter](retained-scope/interpreter.rkt) and
[reduction semantics](retained-scope/source.rkt) have functional and syntactic
derivations connected by a machine-configuration map and finite transition
checks, followed by registers and one bounded atomic-outcome compression.
The [S/E/N matrix](matrix/README.md) carries that retained-scope factoring
through R/D/Z/M/B/Big in twelve native feature cells. Its Search/rail S row
is checked against this checkpoint, and configuration-level transition
checks connect the checkpoint machine to the native E/N machines.

Both accounts preserve strict left-to-right disjunction, eager `Yield` tails
and bind, exact allocation ancestry, and the Search/Frontier commitment
boundary. Only object-language `Delay` suspends computation:

```text
Search   ::= Empty(O) | One(O,σ) | Yield(O,A,Search) | Delay(O,R)
Frontier ::= Done(O) | Last(O,A) | Emit(O,A,Frontier)
           | Forced(O,Frontier) | More(Delay(O,R))
```

These are the S shapes; E/N carry their own allocation information.
`Yield` contains an active candidate and an eager Search tail. Unary `More`
holds unfinished Frontier work. `Done` and `Last` retain distinct completion
structure. Observations compare exact Frontiers, including suspended bodies.

## Reading order and maintained layout

1. Read the [correction log](CORRECTIONS.md) and its small witnesses.
2. Inspect [representations and primitives](shared/README.md), then the
   [interpreter](retained-scope/interpreter.rkt) and
   [source equations](retained-scope/source.rkt).
3. Follow the [derivation stages](retained-scope/README.md),
   [machine correspondence](retained-scope/CORRESPONDENCE.md), and
   [register/compression contracts](retained-scope/REGISTERIZATION.md).
4. Use the coordinate inventory below to read the
   [matrix source specification](matrix/README.md),
   [native stages](matrix/stages/README.md), and
   [Big equations and certificates](matrix/big/README.md).

| Location | Responsibility |
| --- | --- |
| [retained-scope/](retained-scope/README.md) | Selected S interpreter, source, functional/syntactic correspondence, registers, and first compression |
| [shared/](shared/README.md) | S/E/N variable/state languages, allocation and kernels, grammars, structural maps, well-formedness, and narrow transformation machinery |
| [matrix/](matrix/README.md) | Native retained-scope S/E/N feature instances through R/D/Z/M/B/Big and their connection to the selected S checkpoint |
| [test-support/](test-support/README.md) | Named witnesses, generated lexical goals, and reusable structural/transition assertions |
| [all.rkt](all.rkt) | Maintained aggregate: retained scope, matrix, constructor/dependency contracts, and the online-policy witness |

## Selected S derivation and evidence

```text
interpreter → CPS → data + defunc → functional machine → registers → compressed
                                        ↕ configuration correspondence
source → decomposition D → refocusing Z → native M → native B
```

Native B removes structural navigation around one source contraction.
Functional compression combines an atomic evaluation with its two
outcome-handler dispatches; these are distinct downstream transformations.

| Artifact | Implementation and checks | Remaining obligation |
| --- | --- | --- |
| Interpreter and CPS | [interpreter.rkt](retained-scope/interpreter.rkt), [cps.rkt](retained-scope/cps.rkt); [interpreter tests](retained-scope/interpreter-tests.rkt) | General direct/CPS correctness over the admitted domain |
| Defunctionalized program and machine | [data.rkt](retained-scope/data.rkt), [defunc.rkt](retained-scope/defunc.rkt), [machine.rkt](retained-scope/machine.rkt); [data/machine tests](retained-scope/defunc-tests.rkt) | General defunctionalization and generation correctness |
| Source and syntactic stages | [source.rkt](retained-scope/source.rkt), [stages.rkt](retained-scope/stages.rkt); [source tests](retained-scope/source-tests.rkt) | Domain preservation and general R/D/Z/M/B correspondence |
| Machine relation | [configuration map](retained-scope/machine-correspondence.rkt), independent [readback](retained-scope/readback.rkt), [administrative rank](retained-scope/administration.rkt); [transition checks](retained-scope/machine-correspondence-tests.rkt) | All-configuration labelled diagrams and native administrative progress; [contract](retained-scope/CORRESPONDENCE.md) |
| Registers and compression | [registers.rkt](retained-scope/registers.rkt), [compressed.rkt](retained-scope/compressed.rkt), [span maps](retained-scope/compression-correspondence.rkt); [register tests](retained-scope/register-tests.rkt), [span tests](retained-scope/register-compression-tests.rkt) | Generator/mutation correctness and prescribed spans on the full domain; [contract](retained-scope/REGISTERIZATION.md) |
| S/E/N correspondence | [source maps](shared/maps.rkt), [stage maps](shared/stages/maps.rkt), [domain predicates](shared/wf.rkt); [checkpoint transition checks](matrix/retained-scope-tests.rkt) | Universal source/stage diagrams and domain preservation; E/N functional interpreters and register programs are not separately derived |

The interpreters do not execute the source relation. The functional machine
map constructs native controls and continuation fields directly. Independent
whole-source readback checks that map; completed-answer equality alone is
not the correspondence criterion.

## S/E/N coordinate inventory

S uses named variables with ordered tagged introduction groups on the active
world path. E uses named variables with ordered state-local Support. N uses
positional variables with a state-local allocation counter. The live
[primitive providers](shared/core/PROVENANCE.md) retain each representation's
unification and disequality kernels. [Kernel checks](matrix/kernel-tests.rkt)
exercise their native outcomes and state preservation.

Every cell below has native R/D/Z/M/B and Big implementations under the
retained-scope equations. Internal S force puts the removed Delay's Owners
on its active body; E/N force enters the body directly because allocation
support is already in their states. There is no syntactic `prefix` operation
or prefix continuation in these cells.

| Feature | S source | E source | N source | Correspondence checks |
| --- | --- | --- | --- | --- |
| Core | [StrictSCore](matrix/features.rkt) | [StrictECore](matrix/features.rkt) | [StrictNCore](matrix/features.rkt) | [features](matrix/feature-tests.rkt), [stages](matrix/stages/tests.rkt), [Big](matrix/big/tests.rkt) |
| Delay | [StrictSDelay](matrix/features.rkt) | [StrictEDelay](matrix/features.rkt) | [StrictNDelay](matrix/features.rkt) | [features](matrix/feature-tests.rkt), [stages](matrix/stages/tests.rkt), [Big](matrix/big/tests.rkt) |
| Disjunction | [StrictSDisjunction](matrix/features.rkt) | [StrictEDisjunction](matrix/features.rkt) | [StrictNDisjunction](matrix/features.rkt) | [features](matrix/feature-tests.rkt), [stages](matrix/stages/tests.rkt), [Big](matrix/big/tests.rkt) |
| Search/rail | [S](matrix/source-s.rkt) | [E](matrix/source-e.rkt) | [N](matrix/source-n.rkt) | [source maps](matrix/tests.rkt), [generated goals](matrix/property-tests.rkt), [stages](matrix/stages/tests.rkt), [Big](matrix/big/tests.rkt) |

[Stage instances](matrix/stages/instances.rkt) instantiate all twelve cells.
Big uses [S](matrix/big/s.rkt), [E](matrix/big/e.rkt), and [N](matrix/big/n.rkt)
for Search/rail and [features.rkt](matrix/big/features.rkt) for the other nine.
[Big maps](matrix/big/maps.rkt) map every recursive certificate node; target
proofs are obtained independently. The
[source commitment checks](matrix/commit-source-tests.rkt) and
[stage commitment checks](matrix/stages/commit-tests.rkt) cover exact public
boundaries and direct S→E, E→N, and S→N squares.

The [checkpoint gate](matrix/retained-scope-tests.rkt) compares the independently
stated S sources and native stages, then checks the selected functional
machine's mapped configurations against actual S/E/N machine transitions.
These are prescribed source-operation and administrative spans, not only
readback equalities. Big independently supplies finite judgments and mapped
certificates for the aligned source rows. General adequacy, preservation,
machine correspondence, and productivity proofs remain open.

## Generated artifacts and reproduction

The three checked-in generated programs are:

| Generated file | Generator and input |
| --- | --- |
| [machine.rkt](retained-scope/machine.rkt) | [derive.rkt](retained-scope/derive.rkt) reifies the `/d` bodies of [defunc.rkt](retained-scope/defunc.rkt) |
| [registers.rkt](retained-scope/registers.rkt) | [register-derive.rkt](retained-scope/register-derive.rkt) transforms the same control bodies into PC/register dispatch |
| [compressed.rkt](retained-scope/compressed.rkt) | [compression-derive.rkt](retained-scope/compression-derive.rkt) checks the atomic-handler rewrite, then uses the register generator |

Each generator accepts `--check` for freshness; omit it to regenerate.
The retained-scope and overall aggregates also check freshness. Feature/source,
stage, and Big macros construct literal instances at module expansion without
additional checked-in generated programs. The
[tail-call transformer](shared/control-transform.rkt) and
[stage schema](shared/stages/schema.rkt) expose specific transformations;
they are not a universal semantic framework.

Run from the repository root:

```sh
racket racket-server/derivations/strict-search/retained-scope/derive.rkt --check
racket racket-server/derivations/strict-search/retained-scope/register-derive.rkt --check
racket racket-server/derivations/strict-search/retained-scope/compression-derive.rkt --check
raco test racket-server/derivations/strict-search/retained-scope/all.rkt
raco test racket-server/derivations/strict-search/matrix/all.rkt
raco test racket-server/derivations/strict-search/all.rkt
racket racket-server/derivations/strict-search/retained-scope/show.rkt
racket racket-server/derivations/strict-search/retained-scope/show-machines.rkt
racket racket-server/derivations/strict-search/retained-scope/show-register-compression.rkt
```

The aggregate includes [constructor contracts](constructor-tests.rkt),
[dependency boundaries](layout-tests.rkt), and the narrow
[strict/online work-order witness](policy-tests.rkt). Removed comparison suites
are not evidence for the maintained artifact; the
[correction log](CORRECTIONS.md#retired-and-deferred-results) records their
deliberately deferred unique results.

The maintained aggregate excludes retired numeric-interpreter/register
comparisons and their additional host-language domains. Native S/E/N
[work checks](matrix/work-tests.rkt) compare actual atomic work directly;
literal ownership, settled-prefix persistence, and independent register-bank
assertions remain in the selected account. These do not retain the older
numeric Big proof-search or productive host-recursion results. Application
checks and their separate scope are described in
[TEST-LANES.md](../../tests/TEST-LANES.md).

### Current validation

The test runs used `PLTCOMPILEDROOTS=/private/tmp/matrix-retained-cache:` and
`racket -y -l raco -- test`. These separately run gates overlap; their counts
are not additive.

| Gate | Result |
| --- | --- |
| [Full aggregate](all.rkt) | 3,214 tests passed |
| [Selected S aggregate](retained-scope/all.rkt) | 510 tests passed |
| Focused source, feature, and stage suites | 308 tests passed |
| [Selected checkpoint to S/E/N](matrix/retained-scope-tests.rkt) | 31 tests passed |
| [Big judgments and certificates](matrix/big/tests.rkt) | 139 tests passed |
| Three generator `--check` commands above | Passed; generated artifacts unchanged |
| Three `show` demonstrations above | Passed |

## Next correspondence and application boundary

Hold the selected Search/rail behavior and machine fixed while turning the
checked S/E/N configuration diagrams into general correspondence and domain
preservation arguments. The native E/N machines now connect to the selected
S functional machine; separate E/N direct/CPS/defunctionalized/register
programs remain to be derived. Relation calls, productive infinite behavior,
and compact κ/Q/π rail compression remain outside the demonstrated account.

The GUI still runs the live online policy through
[search-runtime.rkt](../../src/search-runtime.rkt) and
[app.rkt](../../src/app.rkt). Its dormant-right work order differs from strict
evaluation. Connecting the selected account to the GUI is a separate task
requiring an explicit operation and observation interface. A fusion argument
is needed only to claim that the online policy is an equivalent optimization;
neither GUI integration nor S/E/N alignment depends on that claim. See the
[semantic policy matrix](../../../docs/semantic-policy-matrix.md).
