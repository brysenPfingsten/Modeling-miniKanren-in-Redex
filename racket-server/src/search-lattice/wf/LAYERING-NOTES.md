# Structural well-formedness layering

The WF layer validates the owner-annotated W/F carrier. It does not choose
control transitions, synthesize observation summaries, or add runtime scope,
support, or counter fields.

## Inherited visible introductions

Every non-root judgment receives a metatheoretic list of logic-variable
introductions visible along the grammatical path to its subject. A root begins
with `()`.

For an explicitly tagged `(Owners owner ...)` stack ordered
outermost-to-innermost, `wf-owner-stack?` checks records sequentially:

1. the record's `intro` is duplicate-free;
2. its names are disjoint from the inherited introductions;
3. the visible list is extended by that record;
4. the next record is checked under the extension.

The node payload is then checked under the resulting visibility. Shared node
constructors such as `Conj`, `DisjL`, and `Emit` pass that same extended
visibility to both children. Rail's `DisjR` extension obeys the same rule.
Branch-local owner stacks extend only their own paths.

States have shape `(state sub dis trail tag)`. Conjunction has shape
`(Conj owners W g)`. Neither stores cumulative allocated-name support. That
support is derived independently from logical-variable occurrences in the
complete live frontier `F_support` when allocation steps.

## Kernels and schemas

`kernel-base.rkt` defines owner-stack validation, logic-variable membership,
fresh extension, substitution, disequality, trail, and state judgments. The
shared schema generators are:

- `wf-schema.rkt` for call-free frontiers;
- `relcall-wf-schema.rkt` for relation environments `Γ` and configurations
  `(Γ F)`.

Feature modules contribute clauses only for constructors they own. The schemas
produce direct Redex judgments; there is no summary-producing judgment and no
host dispatcher.

`define-search-well-formedness` and its relcall counterpart package the exact
delay/disjunction union once. Search instantiates that package with no extra
work clause. Rail instantiates the same package with exactly one local clause
for its right-active work constructor, so the rail WF modules remain thin
carrier extensions rather than copies of the assembled search checker.

## Public judgments

Call-free modules export names such as:

```text
wf-goal/search?
wf-answer/search?
wf-settled/search?
wf-work/search?
wf-frontier/search?
wf-cfg/search?
```

The goal judgment receives lexical variables and visible introductions.
Answer, settled, work, and frontier judgments receive visible introductions.
The root judgment supplies the empty list.

Relcall modules export the corresponding configuration-aware names:

```text
wf-goal/search-relcall?
wf-answer/search-relcall?
wf-settled/search-relcall?
wf-work/search-relcall?
wf-frontier/search-relcall?
wf-rel-env/search-relcall?
wf-config/search-relcall?
```

`Γ` is threaded only through judgments that can inspect goals.

Rail exports parallel `wf-*/rail?` and `wf-*/rail-relcall?` judgments. Ordinary
production search and search-relcall WF exclude `DisjR`; the rail judgments extend those
domains with the right-active carrier while preserving the same inherited
visible-introduction discipline.

The isolated distributed presentation intentionally retains its older common
right-active carrier. Its tests use the larger right-active WF domain for
distributed search, DFS, flip, and rail terms without widening the production
search judgments.

## Independent observations

`../structural-observations.rkt` defines independent folds for:

- owner-record occurrences;
- introduced-name occurrences;
- committed `Answer` occurrences;
- `Forced` occurrences.

These functions measure explicit syntax. The `Owners` wrapper contributes no
count of its own. They do not define WF, and their occurrence counts are not
allocation-event counts.

## Scheduler boundary

Production DFS and flip use `search-wf.rkt` and `search-relcall-wf.rkt`; those judgments
describe the literal delay/disjunction union and reject `DisjR`. Rail is still
a scheduler fiber, but its execution representation adds right-active syntax,
so `rail-wf.rkt` and `rail-relcall-wf.rkt` validate that strictly larger
carrier. Production strategy-domain checks select the matching judgment rather
than admitting every rail state into ordinary search.
