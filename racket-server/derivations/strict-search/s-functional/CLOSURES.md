# Closure families and representation decisions

[00-direct.rkt](00-direct.rkt) evaluates program syntax to active Search and
explicitly commits mature whole-search results to settled Frontier.
[01-anf.rkt](01-anf.rkt) exposes strict sequencing.
[02-cps.rkt](02-cps.rkt) labels the semantic closures below.
Fixed operation names are code, not captured runtime fields.

## Source closures before CPS

| Source lambda | Parameters | Captures | CPS family |
| --- | --- | --- | --- |
| Failure outcome | failure, success | none | Failure outcome |
| Success outcome | failure, success | state | Success outcome |
| Conjunction's right goal | state, owners, inherited | right | G0, with continuation parameter |
| Suspended body evaluation | none | body, state, here | R0, with continuation parameter |
| Delayed force-left-then-merge | none | left, right, here | R1, with C7 inside |
| Delayed resume-then-bind | none | resume, continue, here | R2, with C8 inside |
| Atomic failure consumer | none | owners | F0, additionally capturing k |
| Atomic success consumer | next | owners | S0, additionally capturing k |

Atomic computation finishes before its functional outcome is constructed.
Selection does not replay kernel work. Stage 03 instantiates the same static
equations with native Failure/Success data producers and corresponding data
consumers. No conversion of a returned closure is involved.

Direct commitment, advance, and collection are ordinary recursive functions.
CPS exposes their pending contexts. No CPS closure is an object-language
Delay unless it belongs to R0/R1/R2.

## Evaluation and scheduler continuations

Arguments received by a continuation are not additional saved fields.

| Label | Pending operation | Exact free variables in 02 | Data constructor |
| --- | --- | --- | --- |
| C0 | Return the public operation's Frontier | none | KDone() |
| C1 | Bind the mature left conjunction operand | right, owners, inherited, k | KConj(right,owners,inherited,k) |
| C2 | Evaluate right after receiving left | right, state, here, owners, inherited, k | KDisjLeft(right,state,owners,inherited,k) |
| C3 | Merge mature Search operands | left*, owners, inherited, k | KDisjRight(left,owners,inherited,k) |
| C4 | Construct Yield after its eager recursive merge | owners, answer*, k | KMergeYield(owners,answer,k) |
| C5 | Bind the residual after the head continuation | rest, continue, here, common, inherited, k | KBindHead(rest,continue,common,inherited,k) |
| C6 | Merge the completed bind head and residual | head, common, inherited, k | KBindTail(head,common,inherited,k) |
| C7 | Merge mature right with internally forced left | right, here, k* | KMergeForced(right,here,k) |
| C8 | Bind a completed internal resumption | continue, here, k* | KBindForced(continue,here,k) |
| C9 | Restore Delay Owners on active Search | owners, k | KPrefix(owners,k) |

C2 recovers here as owners-support(owners,inherited); C5 recovers it as
owners-support(common,inherited). These two source free variables are
redundant caches in those environments. Their removal is an explicit
environment representation decision justified by the defining equalities;
it does not inspect siblings or answer-private allocation.

C7/C8 capture the continuation supplied when their containing resumption
runs. R1/R2 do not capture that continuation permanently. C1–C9 receive
active Search, never settled Frontier.

## Commitment and consumer continuations

| Label | Pending operation | Exact free variables in 02 | Data constructor |
| --- | --- | --- | --- |
| P0 | Commit newly matured whole remaining Search | committed | KCommit(k) |
| P1 | Restore a settled Emit after committing its tail | owners, answer, k | KCommitEmit(owners,answer,k) |
| A0 | Restore Emit after advancing its residual once | owners, answer, k | KAdvanceEmit(owners,answer,k) |
| A1 | Restore existing Forced after advancing its residual | owners, k | KAdvanceHistory(owners,k) |
| A2 | Record a crossing around the committed next Frontier | owners, k | KAdvanceForced(owners,k) |
| L0 | Restore Emit after collecting its residual | owners, answer, k | KCollectEmit(owners,answer,k) |
| L1 | Restore existing Forced after collecting its residual | owners, k | KCollectHistory(owners,k) |
| L2 | Collect the Frontier committed after a resumption | owners, k | KCollectResume(owners,k) |
| L3 | Record that crossing around the collected residual | owners, k | KCollectForced(owners,k) |

P0 occurs in run, advance, and collect. All three lambda bodies are
`(lambda (search) (commit/k search committed))`; one constructor family
stores their sole free variable. This ordinary defunctionalization of the
same code shape preserves the different downstream continuations:
KDone, KAdvanceForced, or KCollectResume.

P0 consumes S and enters commit/d. P1, C0, and all A/L continuations consume F.
Basic run starts at eval/d with KCommit(KDone()). Public resumption starts a
raw search resumption with KCommit(KAdvanceForced(...)); collection uses
KCommit(KCollectResume(...)). Pending search binds live inside R data and
finish before these commitment frames receive a candidate chunk.

A2 returns without advancing the received Frontier again. L2 collects it.
A1/L1 retain existing history without recording another crossing. L3 is
constructed only when the L2 dispatcher begins collection of committed F.
No caller-supplied polarity determines these runtime roles.

## Goal continuations, resumptions, and outcomes

| Label/family | Parameters | Captures | Data constructor |
| --- | --- | --- | --- |
| G0 | state*, owners*, inherited*, k* | right | GRight(goal) |
| R0 | k* | body, state, here | REval(goal,state,here) |
| R1 | k* | right, left, here | RMerge(right,left,here) |
| R2 | k* | resume, continue, here | RBind(resume,continue,here) |
| F0 | none | owners, k | FEmpty(owners,k) |
| S0 | next | owners, k | SOne(owners,k) |
| Failure outcome | failure/success consumers | none | Failure() |
| Success outcome | failure/success consumers | state | Success(state) |

There are 27 semantic closure/outcome families: ten C continuations, two P,
three A, four L, one G, three R, two handlers, and two outcomes. The
outcome dispatcher selects Failure/Success and dispatches FEmpty/SOne.
These handlers construct active Empty/One, not settled Done/Last.

G0 retains goal syntax because State and allocation vary by candidate.
R0 retains a suspended goal, State, and effective support.
R1 retains mature right Search and the delayed left operand in their original
orientation. R2 retains a raw resumption and pending conjunction. Raw
resumptions return S with no Forced history.

The observer parameter is test instrumentation outside configurations.
Primitive allocation/substitution/unification/constraint operations are fixed
code over data. The matrix independently uses native data outcomes too.
No semantic closure survives in the S data machine's configurations.

## Data present before defunctionalization

| Category | Constructor | Meaning |
| --- | --- | --- |
| Goal | atoms, fresh, conjunction, disjunction, suspend syntax | Program dependencies; not scheduler nodes |
| Allocation | Owner(intro,tag), Owners(groups...) | Ordered grouped structural provenance, including empty groups |
| State | state(sub,dis,trail,tag) | Logical store with no cumulative allocation carrier |
| Candidate/answer payload | Answer(owners,state) | Private introductions; enclosing S or F determines candidate versus committed answer |
| Active Search | Empty(owners) | Failed intermediate search |
| Active Search | One(owners,state) | Single intermediate success, still subject to bind |
| Active Search | Yield(owners,answer,S) | Candidate with an eager residual and common Owners |
| Active Search | Delay(owners,R) | The only suspended search computation |
| Settled Frontier | Done(owners) | Terminated output with no final answer |
| Settled Frontier | Last(Owners(),answer) | Committed terminal answer |
| Settled Frontier | Emit(owners,answer,F) | Committed answer and its immutable ordered prefix position |
| Settled Frontier | More(Delay(owners,R)) | Explicit unfinished work at the output tip |
| Settled Frontier | Forced(owners,F) | Evidence of an exposed crossing |

An Answer payload is shared data, but its role is structurally explicit:
inside Yield it is a candidate; inside Emit/Last it is committed. S and F
have disjoint root constructors. No Emit occurs inside active Search.

Prefix operates only on S root Owners. It never moves provenance into a
settled Answer. Merge distributes its left common ownership only over left
descendants, following the independent S rule. Commit alone transfers
One's ordered Owner groups into the terminal Answer, following commit-one
with the same ownership placement as the older render-one.
See the [ownership equations](README.md#ownership-equations-and-their-location)
for the path argument and distinction between internal force and Forced.

The strict syntactic source retains pending `prefix(O,c)` as a computation.
Its context supplies O as allocation ancestry while c runs; prefix-value
attaches O only to the mature result. Refocusing derives the corresponding
prefix frame, so C9/KPrefix has a direct frame image. Public resumption and
RBind use raw bodies and introduce no empty-owner force/redelay phase.

The inherited support cache records enclosing Owner names without erasing
grouping/tags from the structure. Resumption captures must agree with that
ancestry. Arbitrary relocation is not permitted by the correspondence.

Lexical x: binders, allocated logical u: variables, and Racket interpreter
parameters are different classes. The preserved N source's host binder
callbacks are a separate interface choice, not a consequence of N allocation.

## Reifying calls and registerizing

| Carrier | Origin and fields |
| --- | --- |
| Call(pc,operands) | Tail call to one of thirteen /d functions; evaluated operands in signature order |
| Halted(value) | return/d with KDone; a public result is F and may retain More(Delay) |
| Registers(pc,r0,r1,r2,r3,r4,steps) | Up to five operands; steps is a driver diagnostic |

| PC | r0 | r1 | r2 | r3 | r4 |
| --- | --- | --- | --- | --- | --- |
| eval/d | goal | State | local Owners | inherited support | k |
| merge/d | left S | right S | local Owners | inherited support | k |
| bind/d | S | GRight | local Owners | inherited support | k |
| continue/d | GRight | State | local Owners | inherited support | k |
| resume/d | R | k | unused | unused | unused |
| force/d | Delay | k | unused | unused | unused |
| commit/d | S | k | unused | unused | unused |
| advance/d | F | k | unused | unused | unused |
| collect/d | F | k | unused | unused | unused |
| outcome/d | Outcome | FEmpty | SOne | unused | unused |
| failure/d | FEmpty | unused | unused | unused | unused |
| success/d | SOne | State | unused | unused | unused |
| return/d | value | k | unused | unused | unused |
| halt | value | unused | unused | unused | unused |

All jump! arguments finish evaluation before register mutation; unused slots
are cleared to #f. The trampoline is a tail-recursive PC loop, with no new
search thunk or object Delay. Fuel and budget exceptions are runner diagnostics.

Structural readback uses actual value and continuation constructors to
distinguish the domains. KCommit maps to the independent commit context;
More(Delay) maps to a native Frontier normal form. The refocused machine now
stops there by its own transitions. Its direct machine correspondence maps
continuation fields to Frame/K fields, including a commit Frame, without
rebuilding and decomposing a whole computation. The prefix Frame also maps
directly, retaining its saved Owners. These maps do not execute or force
anything. Each classified semantic functional step is checked against one
prescribed source contraction; other functional steps preserve the native
image after administrative normalization. Finite checks validate instances; general transformation and
capture-coherence theorems remain obligations.
