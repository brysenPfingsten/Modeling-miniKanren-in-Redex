# Marked source artifact `R_m`

`language.rkt` defines the stratified source grammar and actual-hole context
families.  `source.rkt` defines the complete named `reduction-relation`; it
does not wrap a Racket step function.  The active path is selected by the
grammar:

| Context | Index | Purpose |
| --- | --- | --- |
| `WW` | W -> W | local active-work path |
| `FF` | F -> F | committed frontier prefix |
| `WF` | W -> F | active work below `More` and an `FF` prefix |
| `WF+` | W -> F | branch-local path with a non-fresh frame below `More` |

`TopW`, used inside `WF`, does not contain a first `WorkFresh` frame.  This
makes `More (WorkFresh ...)` select `expose-frontier-fresh`.  `WF+` admits a
`WorkFresh` only below a conjunction or active disjunction frame, where
`expose-choice-through-work-fresh` copies the existing introduction marker.

Every rule name has the form `source-name/owner`; `redex-name->label` and
`label->redex-name` are inverse Redex metafunctions over the finite label
grammar.  Rule selection remains in Redex.  `kernel-toy.rkt` supplies only
fresh-name choice, lexical substitution, state update, success resumption,
answer freezing, and well-formedness judgments.

The source suite checks:

- grammar stratification and context-family membership,
- executable toy-kernel well-formedness,
- the complete label/name bijection,
- deterministic closure on bounded Redex-generated well-formed terms,
- exact named successor equality with the frozen pilot oracle, and
- complete representative traces, including both fresh-exposure cases.

The oracle dependency occurs only in tests.

