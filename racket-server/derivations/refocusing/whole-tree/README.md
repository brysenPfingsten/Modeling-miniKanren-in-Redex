# Canonical whole-tree derivation

This directory is the consolidation home for the whole-tree search calculus.
It is not another source-design experiment and it is not a replacement for the
decorated production lattice by fiat.  The monolithic references are temporary
independent oracles used to derive and validate one durable modular family.

The selected cell is exactly:

```text
full search carrier (delay plus disjunction join)
+ late hoisting
+ factored fresh
+ rail / flip-flop scheduling
+ no relcall overlay
```

The selected marked source keeps the complete answer frontier, fresh ownership,
and force/cost evidence in the tree.  Its grammatical categories and contexts
carry their own indices; decompositions and states do not contain reified W/F
sort tags.

## Present references and intended family

The current kernel-parametric `P[K]` column is the **sole temporary marked
reference**.  During consolidation it remains at
[`../whole-tree-redex-column/pk/`](../whole-tree-redex-column/pk/).  Its
authoritative account and generated witnesses are:

- [`../whole-tree-redex-column/REPORT.md`](../whole-tree-redex-column/REPORT.md)
- [`../whole-tree-redex-column/pk/README.md`](../whole-tree-redex-column/pk/README.md)
- [`../whole-tree-redex-column/pk/TRACES.md`](../whole-tree-redex-column/pk/TRACES.md)

It will move once to `reference/marked/` after its legacy parity checks and
corpus dependencies have been separated.  The concrete Redex column, the
handwritten pilot, and the broad spike are transition oracles, not additional
canonical marked implementations.

An independently stated lean reference will live at `reference/lean/`.  It
must have its own genuine named source relation and complete derivation:

```text
R -> D -> Z <-> M -> B -> finite big step
```

It must not be generated from, or operationally call, the marked reference.
The reference Q layer will state the marked-to-lean maps and laws explicitly,
including separate decisions for fresh ownership and force/cost evidence.
Cache insertion belongs to a separate lean-to-cached bridge; it is not folded
into an indiscriminate erasure.

The durable result is a modular family indexed along three axes:

```text
feature/policy selection i
representation rho = marked | lean | cached, when justified
stage T = R | D | Z | M | B | Big

artifact: T[i, rho]
```

Feature components, representation components, and derivation transformations
must remain visibly compositional.  For the selected cell, the modular marked
and lean instantiations must reproduce the independent references before those
references may be retired.  Adding an additive feature must commute with every
derived stage; policy comparisons use their stated observational laws rather
than being mislabeled conservative extensions.

## Retirement of the monolithic references

The handwritten marked and lean implementations may be removed only after the
modular instantiations agree on all of the following:

- accepted source terms and complete named successor sets;
- rule labels, owners, terminal forms, and answer frontiers;
- fresh allocation, marker identity, and ownership boundaries;
- force/cost observations where retained;
- unique decompositions and direct refocusing results;
- explicit machine codecs and labeled machine steps;
- nonempty compression spans and exact span partitions;
- finite big-step outcomes and the stated observation maps;
- stagewise Q and feature-naturality squares;
- both `Ktoy` and `Kmk` coverage; and
- every retained regression and explanatory witness.

At retirement, tests are redirected from monolith equality to the durable
algebraic laws.  The corpus, generated traces, correspondence laws, and concise
architectural explanation remain; duplicate operational monoliths do not.

## Production boundary

The production worktree remains untouched while the canonical marked/lean/Q
and initial naturality work is completed and formally accepted.  Acceptance
does not merge this research implementation wholesale.  The accepted grammar,
named relations, contracts, and regression witnesses are back-ported into the
modular `language-refactor` production work, which is then rebased onto the
then-current Brysen `main` and run through the production, lattice, runtime,
and correspondence gates.

See [`BASELINE.md`](BASELINE.md) for the immutable Phase 0 evidence and
[`RETENTION.md`](RETENTION.md) for the artifact ledger, import boundaries, and
deletion gates.
