# Semantic policy and integration status

The [strict-search inventory](../racket-server/derivations/strict-search/README.md)
records the maintained derivations and remaining proofs. The
[organization guide](semantics-ladder.md) connects them to the application;
the [correction log](../racket-server/derivations/strict-search/CORRECTIONS.md)
keeps the history of superseded choices.

The GUI must preserve **No Interleave, Flip-Flop, and Railroad** as runtime
choices. They are part of the intended application, independently of the
compiler's associativity and delay-placement controls. Partial interpreter
correspondence is acceptable while these operational accounts are connected;
the strict interpreter's present coverage does not determine which GUI choices
may remain.

| Account | Current role | Operational contract |
| --- | --- | --- |
| [Retained-scope S](../racket-server/derivations/strict-search/retained-scope/README.md) | Selected interpreter, independently stated source, corresponding machines, registers and first compression | Strict disjunction, eager Yield tails and bind; explicit commitment; only Delay suspends |
| [Native S/E/N matrix](../racket-server/derivations/strict-search/matrix/README.md) | Twelve call-free representation/feature cells and three full relation cells through source, data stages and finite Big | Same retained-scope operations, expressed using syntax-owned introductions, state support, or numeric supply |
| [Lattice search](../racket-server/src/search-lattice/SEMILATTICE.md) | GUI default Railroad; No Interleave (`dfs`), Flip-Flop (`flip`), and Railroad (`rail`) remain runtime choices | Native `(Γ F)` configurations; DFS and Flip use `DisjL`, while Railroad extends the grammar with `DisjR` and its right-active work path |
| [Strict Search view](../racket-server/src/search-runtime.rkt) | Separate GUI view and default API/library selection; executes `strict-s-rel-red` directly | Native `(program Γ q)` syntax, explicit calls and exact source steps; no online conversion |

The GUI sends an explicit lattice scheduler; Strict Search sends
`{ "model": "strict" }`. Omitting selection at the API/library boundary uses
the distinct `(strict-search)` model. Strict Search is not a fourth scheduler,
and the lattice `rail` selector runs oriented Railroad rather than the strict
`mplus`/`bind`/`Delay` equations. The historical “Search/rail” phrase inside the
strict derivation describes its Search feature and does not identify these
two sources.

## Choices that must remain separate

- **Compiler profiles:** two conjunction associations × two disjunction
  associations × three delay placements gives twelve compiled goal shapes.
  These choices may change work order or delay rounds; the finite comparison
  witness does not prove all profiles observationally equivalent.
- **Runtime scheduling:** No Interleave retains the active left branch at a
  delay; Flip-Flop swaps branches while retaining a `DisjL` node. Railroad
  represents orientation explicitly with `DisjL` and `DisjR`. This grammar
  extension is part of its operational account, not an associativity or
  delay-placement compilation flag.
- **Representation and features:** S/E/N × Core/Delay/Disjunction/Search gives
  twelve call-free cells. Full Search with relations adds three more cells.
- **Derivation stages:** R/D/Z/M/B/Big and functional/register representations
  expose the same operations through different data and transition functions.
- **Consumption:** manual stepping can continue past a source `run n` request;
  the automatic consumer in [minikanren.rkt](../racket-server/src/minikanren.rkt)
  handles positive limits at the next exposed Delay or terminal Frontier.
  It does not stop just because an answer is visible; an unguarded lattice
  residual can prevent reaching that boundary even after enough answers exist.

Relation expansion adds no implicit Delay. Γ is explicit in the program and
retained data frames; suspension is present in the compiled goal itself.
Query-variable identities come from compiler metadata, not a scan of a changing
search tree. The [picture projection](../racket-server/src/search-picture.rkt)
distinguishes active candidates from committed answers and retains Done/Last,
common/private introductions, and exposed delayed residuals.
Both families share compiled goals and source identity; native initialization
wraps them in the selected carrier. Session history retains that carrier.
Strict public advancement records `advance` before reduction; lattice public
advancement is its own named `force-delay` reduction. Their operational
semantics are unchanged by sharing controls, history infrastructure, and a
renderer.

## Scope of correspondence

The two selected S derivations and native S/E/N machines have structural maps
and configuration-level transition checks, including the full relation
extension. Register decoders and compressed steps use prescribed original
spans. Big equations and certificate maps provide independent finite evidence.
This does not supply separate E/N functional or register derivations, universal
correspondence proofs, or productive-stream theorems.

The accepted GUI scheduler family need not have a completed interpreter
correspondence before it is usable. Each implemented correspondence must name
the scheduler, representation, and observation boundaries it covers. The
current strict checks do not establish equivalence of DFS, Flip, and oriented
Railroad. Native application integration does not complete that correspondence.

Strict-to-online fusion is a different prospective theorem. It can move finite
sibling work across commitment; without guardedness, `success(A) ∨ Ω` already
distinguishes answer prefixes. The current strict runtime does not rely on
that fusion, and no `κ / Q / π` compression is claimed. Earlier online
source-relative tests do not establish the current strict application's
contract.

The [distributed-conjunction experiment](../racket-server/derivations/distributed-search/README.md)
remains a separate source-policy experiment. Distributing pending conjunction
into branches is a different question from retaining the three GUI schedulers;
the experiment is not integrated into the matrix or application.
