# Shared validation support

These fixtures and assertions are used by several derivation routes. They
are independent of historical evaluators and of the test suites that call
them.

| Module | Contents |
| --- | --- |
| `corpus.rkt` | Feature corpora and allocation fixtures |
| `witnesses.rkt` | Named strictness, ownership, and resumption witnesses |
| `generated-goals.rkt` | Deterministically generated lexical goal corpus |
| `frontiers.rkt` | Structural pending-frontier predicate |
| `stage-checks.rkt` | Reusable source/D/Z/M/B transition and map checks, parameterized by the source relation and stage |

Cross-checks against an earlier semantics remain in the calling test suite.
For example, retained-scope `source-tests.rkt` explicitly imports the older
matrix S source to compare ownership factoring. Running the retained-scope
interpreter or its generated machines does not load that source.
