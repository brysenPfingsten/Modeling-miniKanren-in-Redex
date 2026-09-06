# Registers and bounded atomic-outcome compression

The reference is the retained-scope `machine.rkt`: the thirteen-control
functional machine generated from `defunc.rkt`, whose configurations correspond
to the independently refocused `RetainedS` machine through `functional->M`.
The [research guide](../README.md) owns the inventory and reproduction
commands; this document states the register decoder and compression contracts.

```text
defunc.rkt ── derive.rkt ─────────────────────> machine.rkt
    ├──────── register-derive.rkt ────────────> registers.rkt
    └──────── compression-derive.rkt
                  └── register generator ───> compressed.rkt

compressed ── compressed->registers ──> registers
registers  ── decode ──> machine ── functional->M ──> refocused M
```

The representation maps are structural; generation arrows transform
program syntax. Neither register dispatcher calls the functional transition
function, a reduction relation, or an observer table to execute the program.

## Registerization

`register-derive.rkt` reuses the existing restricted tail-position transformer
on the actual retained-scope `/d` definitions. The generated `registers.rkt`
contains a mutable bank with an explicit PC, five operand registers, and a step
counter. Its signature table states the meaning of each live register at each
PC. For example:

| PC | r0 | r1 | r2 | r3 | r4 |
| --- | --- | --- | --- | --- | --- |
| eval/d | goal | state | owners | inherited | continuation |
| merge/d | left Search | right Search | owners | inherited | continuation |
| bind/d | Search | goal continuation | owners | inherited | continuation |
| resume/d | resumption | owners | inherited | continuation | unused |
| force/d | delayed Search | inherited | continuation | unused | unused |
| commit/d | Search | continuation | unused | unused | unused |
| advance/d, collect/d | Frontier | inherited | continuation | unused | unused |
| return/d | value | continuation | unused | unused | unused |
| halt | Frontier | unused | unused | unused | unused |

The other three PCs dispatch the data kernel outcome and its failure/success
handler. All continuations and `REval`, `RMerge`, `RBind` resumptions remain the
functional machine's data records. No suspended body is evaluated by decoding.

Every dispatch first binds its incoming operands from the bank. Every outgoing
`jump!` evaluates its arguments left to right before assigning any register;
only then does it update the bank and PC. Thus an operand can read an old
register even when an earlier outgoing operand will replace that register.
Unused registers are cleared to `#f`. The step counter is diagnostic metadata,
not object-language state.

The tail-recursive dispatch loop is the host trampoline. It creates no thunk
and introduces no object-language `Delay`. A public run halts with a Frontier,
including an unfinished `More(Delay(...))`; an exposed Delay is resumed only by
the existing public advancement/collection or internal force operations.

Let δ be `registers.rkt`'s `decode`. At a running PC it reconstructs
`Call(pc, live-operands)`; at halt it reconstructs `Halted(frontier)`. For a
well-formed bank its intended diagram is exact:

```text
δ(initial-R(g,O,σ)) = initial-F(g,O,σ)
δ(step-R(r))        = step-F(δ(r))
```

Here `step-R(r)` denotes the bank after one successful `step!`. At halt,
`step!` returns `#f` and leaves the bank unchanged, matching F's lack of a
successor. The decoder ignores the diagnostic counter. It validates the
register layout; semantic ancestry and Search/Frontier phase are additionally
checked through the functional machine's structural maps.

Registerization adds no abstract-machine transition. It retains the original
administrative controls and their classification by `functional-step-label`.
Composition `functional->M ∘ δ` gives the explicit relation to refocused M.

## What the first compression removes

Inspecting the actual atomic clause reveals a fixed sequence:

```text
eval/d(atom,σ,O,P,k)
  → outcome/d(atomic/data(atom,σ), FEmpty(O,k), SOne(O,k))
  → failure/d(FEmpty(O,k))       or success/d(SOne(O,k),σ′)
  → return/d(Empty(O),k)         or return/d(One(O,σ′),k)
```

The kernel runs in the first transition. The following two transitions merely
select and apply a handler whose only action is to build Empty/One and return.
Neither handler runs a goal, forces a Delay, applies pending bind, or commits an
answer. Both retain exactly the same O and k as the atomic call.

`compression-derive.rkt` validates these exact source clauses, rewrites only
the atomic clause to inspect the native Failure/Success outcome directly, and
removes the now-unreachable outcome/failure/success control definitions. It
passes the resulting definitions through the same register generator. The
other control bodies are retained unchanged. Source drift at the compressed
clauses is rejected instead of silently broadening the rewrite.

```text
eval/d(atom,σ,O,P,k)
  → return/d(Empty(O),k)         or return/d(One(O,σ′),k)
```

This reduces thirteen PCs to ten and three atomic dispatch transitions to one.
It also avoids constructing the transient FEmpty/SOne handler records at that
site. The kernel still produces native Failure/Success data; no functional
outcome adapter is introduced. Shared `data.rkt` retains all its definitions
for the uncompressed machine.

All eighteen continuation constructors and all three resumption constructors
remain. In particular, the resulting `return/d` still has the same k: it has
not applied KCommit, KConj, KBindHead, or any other pending continuation.

## Representation and prescribed spans

`compression-correspondence.rkt` provides `compressed->functional` and
`compressed->registers`. These decode/repack live fields without stepping;
the latter starts the target's diagnostic counter at zero. The compressed
domain excludes the three removed PCs. Arbitrary uncompressed configurations
paused at those eliminated controls are not inputs to the compressed machine.

Before either machine steps, `compressed-step-span` describes the original
transitions represented by the next compressed transition:

| Current compressed control | Required original PC sequence | Labels |
| --- | --- | --- |
| atomic eval/d | eval/d, outcome/d, then failure/d or success/d | eval-atom, admin, admin |
| any other running control | that same PC, once | its existing semantic label or admin |
| halt | empty | no transition |

`OriginalStep` records the allowed PC(s) and exact operation label; `#f` denotes
administration. The final handler PC has two possible constructors because its
selection depends on the kernel result. Computing that choice in advance
would duplicate actual kernel work. The descriptor permits precisely those
two alternatives and fixes the span length independently of the result.

Writing ε for the structural embedding into F, the intended diagram is:

```text
ε(c) ── prescribed 1- or 3-transition span ──> ε(step-C(c)).
```

The executable checks replay that prescribed span, checking every PC, label,
intermediate configuration and endpoint. They do not search ahead until an
answer or matching state happens to appear. The two internal atomic-dispatch
edges preserve whole-source readback. Thus each compressed semantic transition
still represents exactly one meaningful source contraction; it never absorbs
the next semantic operation.

There is no administrative normalization loop in this compression. For the
eliminated suffix the rank is 2 at outcome/d, 1 at failure/d or success/d, and
0 at return/d. It strictly decreases, with a uniform bound of two. Other
administrative transitions remain explicit. The earlier structural rank in
`administration.rkt` and native traversal obligation remain applicable when
composing with the functional/refocused correspondence.

## Concrete example

For `succeed`, with k = KCommit(KDone), the original PCs are:

```text
eval/d → outcome/d → success/d → return/d
```

The compressed machine takes:

```text
eval/d ── eval-atom ──> return/d(One(O,σ), KCommit(KDone))
```

Both then take the unchanged continuation-application step to `commit/d`,
the `commit-one` step, and the final return to halt. The complete simple run
therefore takes six original transitions and four compressed transitions.
Its atomic work is identical. The same example with `fail` selects failure/d
in the original span and produces Empty before the unchanged commitment.

`show-register-compression.rkt` prints and checks actual configurations for
both cases, including the still-pending KCommit and final Frontier.

## Validation and proof scope

`register-tests.rkt` checks generation, decoding, register-update order and
runner boundaries. `register-compression-tests.rkt` checks the original
transition and the prescribed compressed spans at every reached configuration.
It uses the existing strictness, nested-rail, retained-scope, sparse-ancestry,
fresh-across-Delay, unused-introduction and pending-bind witnesses. It compares
the exact public Frontiers, their unforced bodies, and actual atomic goal/state
work in order. Decoders and maps are checked without kernel execution or
closure observers. These tests join the retained-scope aggregate.

The [matrix checkpoint gate](../matrix/retained-scope-tests.rkt) connects S
functional configurations to actual native S/E/N M transitions. The register
decoder and prescribed compression spans provide the preceding maps. This
connection does not supply separately generated E/N register programs or a
direct register-to-Big certificate map.

For every checked public operation, the gate also verifies the exact count
equation `register dispatches - compressed dispatches = 2 × atomic evaluations`.
All other original transitions remain represented individually.

Run the aggregate, freshness checks, and demonstration listed in the
[parent guide](../README.md#generated-artifacts-and-reproduction).

The local justification is a syntactic transformation with explicit decoder
and span equations. The finite gates are evidence for, rather than a universal
proof of, those equations. Remaining proof obligations include preservation
of the well-formed reachable domain, correctness of the restricted generation
pass and mutation protocol, all-configuration span correspondence, and the
earlier functional/refocused domain and native-administration arguments.
Step budgets count transitions of the selected machine; equal numeric fuel
is not an observation preserved by compression. Infinite productive behavior
and relation calls are not established by this finite witness corpus.

## How compact is the result?

It is an explicit register machine with fewer dispatch controls and transient
handler allocations. It preserves the semantic control structure we worked to
expose: strict operand maturation, eager bind, actual resumptions, commitment,
and retained scope. It has not compressed the continuation stack or the nested
delayed-search structure into κ/Q/π. This first step justifies removing a
specific piece of dispatch overhead; it does not yet establish that the
hoped-for compact rail representation follows. No runtime speedup is claimed
from transition counts alone.
