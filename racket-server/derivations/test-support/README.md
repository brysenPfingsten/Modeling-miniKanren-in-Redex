# Shared validation support

These fixtures and assertions are used by the S reference account,
S/E/N matrix, experiments, and application checks. They are independent of
the evaluators and test suites that call them. Keeping neutral helpers here
avoids making a semantic account depend on an unrelated test suite.

| Module | Contents |
| --- | --- |
| `corpus.rkt` | Feature corpora and allocation fixtures |
| `witnesses.rkt` | Named strictness, ownership, and resumption witnesses |
| `generated-goals.rkt` | Deterministically generated lexical goal corpus |
| `frontiers.rkt` | Structural pending-frontier predicate |
| `stage-checks.rkt` | Reusable source/D/Z/M/B transition and map checks, parameterized by the source relation and stage |
| `random-test-support.rkt`, `generator-kernel.rkt` | Seeded randomness and common term/variable generation for property checks |
| `runtime-test-support.rkt` | Structural completed-Frontier and named-successor observations for strict and experimental carriers |
| `helpers-tests.rkt` | Focused assertions for the shared helper behavior |

The [S reference aggregate](../s-reference/all.rkt) and
[matrix aggregate](../matrix/all.rkt) own the actual checks. Each supplies its
source and stage to the reusable checker; these helpers do not select a
semantic policy. The [matrix checkpoint gate](../matrix/s-reference-tests.rkt)
also uses the named witnesses to connect the S reference machine to actual
native S/E/N transitions. The [correction log](../CORRECTIONS.md) connects
those witnesses to the distinctions they protect. Being shared validation
support does not make an experiment's source rules authoritative or add its
tests to the current strict aggregate.
