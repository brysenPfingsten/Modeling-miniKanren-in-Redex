# Strict registerization

`register-machine.rkt` replaces the strict functional machine's command
constructor with a program counter and a private mutable register bank.
It retains the existing first-order Search, resumption, and continuation
data. In particular, strictness still requires `AfterDisjRight(S1,k)` and
`AfterBindTail(head,k)`; neither stored mature Search becomes a delayed job.

The kernel remains an eager primitive returning a native functional Outcome.
Atomic evaluation applies that result directly to failure/success handlers.
This control registerization introduces neither Outcome records nor an
Outcome conversion; it does not defunctionalize a closed kernel implementation.

The bank is `(pc, x, y, k, kernel, steps)`. Its live operands are:

| PC | x | y |
| --- | --- | --- |
| eval | goal | State |
| mplus | mature left Search | mature right Search |
| bind | mature Search | Continue(goal) |
| force | actual Delay resumption | unused |
| render | mature Search | unused |
| return | Search or completed frontier | unused |

Unused operands are cleared to `#f`. `kernel` is a fixed run parameter;
`steps` is a diagnostic transition counter. Separate banks can be interleaved
without sharing active registers or kernel environments. `drive!` is a tail
recursive PC dispatcher; it adds no host trampoline thunk or semantic Delay.

## Representation correspondence

`registers-from-machine` and `decode-machine` are structural maps. Operational
dispatch neither decodes a functional command nor invokes that machine's
stepper. It directly evaluates each PC's corresponding clause and updates the
live registers. There is no call to the direct interpreter or reduction runner.

The representation relation fixes the kernel environment and identifies the
six live-operand arrangements with their respective functional commands:
`Eval`, `Mplus`, `Bind`, `Force`, `Render`, and `Return`. It ignores only the
diagnostic counter. On canonical banks (unused operands are `#f`), encoding
and decoding are inverse on live data.

The one-step equation is:

```text
decode(step-register(encode(M))) = step-functional(M)
```

for a nonfinal well-formed functional configuration and the same kernel
operation. The proof argument is a case split over PC and then the shared
data constructor. Eval writes the same goal/State/continuation triple; mplus
and bind write the same already-eager operands; force dispatches the same
resumption constructor; render retains the same exact frontier constructor;
and return implements each continuation clause with the same live operands.
`jump!` evaluates its arguments before assigning them, so updates cannot
overwrite a needed operand. No extra machine edge occurs inside a jump.

Final `Return(value,Halt)` corresponds exactly to a halted return PC. Calling
`register-step!` there reports no edge and does not advance the counter. Thus
the registerization introduces no silent loop: every nonfinal PC dispatch
corresponds to one functional-machine transition, including a genuine
unguarded Fresh self-loop. Finite paths correspond by induction on their
length. The same one-for-one step relation preserves infinite machine paths,
conditional on the kernel/body operations themselves returning.

This is the representation argument for the given strict functional machine,
not an online fusion theorem. Its composition with the syntactic pipeline
uses the separate functional-to-source decoder and stage correspondence.
Opaque kernel and Fresh callbacks remain a parameter boundary: these
arguments do not prove arbitrary Racket callbacks total or extensionally
equivalent. Literal `equal?` tests use stable captured callback objects;
callbacks creating new procedures also receive separate exact-State tests.

## Executable evidence

```sh
raco test racket-server/derivations/strict-search/register-tests.rkt
```

The tests exercise every PC and continuation-dispatch clause, compare whole
paths against the functional machine, compose the decoder with strict source
steps, and compare exact final States/frontiers with the direct interpreter.
They include eager bind residuals, retained-left identity, nested rail,
nonzero fresh allocation, independent interleaved banks, Delay barriers, and
bounded prefixes of unguarded object-level divergence.

Fuel belongs to the runner, not the transition relation. Exhaustion reports a
still-running configuration and never becomes Empty, Done, or a successful
Big-step derivation. It cannot interrupt a nonterminating opaque host callback.

The bank represents the direct interpreter's numeric-state strict machine.
`matrix-register-tests.rkt` connects the native N matrix to this bank under
the preserved numeric kernel. It checks exact frontiers and every atomic
call's order and incoming State from empty and nonzero allocation supplies.
The native S/E/N matrix itself covers R through Big; this register artifact
is a numeric endpoint, not three separate register coordinates.
