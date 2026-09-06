# Shared validation support

These fixtures and assertions are used by the retained-scope account and
S/E/N matrix. They are independent of historical evaluators and of the test
suites that call them.

| Module | Contents |
| --- | --- |
| `corpus.rkt` | Feature corpora and allocation fixtures |
| `witnesses.rkt` | Named strictness, ownership, and resumption witnesses |
| `generated-goals.rkt` | Deterministically generated lexical goal corpus |
| `frontiers.rkt` | Structural pending-frontier predicate |
| `stage-checks.rkt` | Reusable source/D/Z/M/B transition and map checks, parameterized by the source relation and stage |

The [retained-scope aggregate](../retained-scope/all.rkt) and
[matrix aggregate](../matrix/all.rkt) own the actual checks. Each supplies its
source and stage to the reusable checker; these helpers do not select a
semantic policy. The [correction log](../CORRECTIONS.md) connects the named
witnesses to the distinctions they protect.
