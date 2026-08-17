# Executable representative traces

This file is deterministically rendered by `racket export-traces.rkt`. The exporter aborts unless, for every witness below:

- the R, direct D, direct Z, and direct M label sequences are equal;
- every aligned D, Z, and M state satisfies the explicit readback/codec equations;
- the nonempty compressed spans partition that exact sequence;
- the closure certificate equals the direct compressed path;
- the closure specification and independently promoted big-step judgment return the same result; and
- source, exact, compressed, and promoted terminal readbacks agree.

These are executable traces of the selected witnesses, not universal proofs.

## Ktoy: nested fresh ownership

The boundary fresh owns the whole frontier; the branch-local fresh is replicated across exactly its two choice descendants.

### Source boundary

Initial whole frontier:

```racket
(More
 (Work
  (fresh
   (x:outer)
   (disj
    (fresh
     (x:inner)
     (disj
      (put (x:outer : x:inner) (label "inner-left"))
      (put (x:outer : x:inner) (label "inner-right"))
      (label "inner-split"))
     (label "branch-fresh"))
    (put x:outer (label "outer-right"))
    (label "outer-split"))
   (label "outer-fresh"))
  (state unit)))
```

The source has 13 exact edges and terminates at:

```racket
(FrontierFresh
 (u:0)
 (Emit
  (AnswerFresh (u:1) (Answer (state (u:0 : u:1))) (label "branch-fresh"))
  (Emit
   (AnswerFresh (u:1) (Answer (state (u:0 : u:1))) (label "branch-fresh"))
   (Last (Answer (state u:0)))))
 (label "outer-fresh"))
```

### Decomposition, refocusing, and exact-machine alignment

The independently stated R, direct D, direct Z, and direct M relations agree on all 13 labels. At every state, `plug-D(D) = R`, `D->Z(D) = Z`, and `encode-ZM(Z) = M`:

1. `(allocate-fresh core)`
2. `(expose-frontier-fresh core)`
3. `(expand-disjunction disj)`
4. `(allocate-fresh core)`
5. `(expand-disjunction disj)`
6. `(kernel work-put core)`
7. `(expose-choice-through-work-fresh disj)`
8. `(reassociate-left-result disj)`
9. `(commit-choice-answer disj)`
10. `(kernel work-put core)`
11. `(commit-choice-answer disj)`
12. `(kernel work-put core)`
13. `(finish-success core)`

Initial and terminal decomposition states:

```racket
(DecWork
 (Work
  (fresh
   (x:outer)
   (disj
    (fresh
     (x:inner)
     (disj
      (put (x:outer : x:inner) (label "inner-left"))
      (put (x:outer : x:inner) (label "inner-right"))
      (label "inner-split"))
     (label "branch-fresh"))
    (put x:outer (label "outer-right"))
    (label "outer-split"))
   (label "outer-fresh"))
  (state unit))
 (More #<hole>))
```

```racket
(DecFrontier
 (Last (Answer (state u:0)))
 (FrontierFresh
  (u:0)
  (Emit
   (AnswerFresh (u:1) (Answer (state (u:0 : u:1))) (label "branch-fresh"))
   (Emit
    (AnswerFresh (u:1) (Answer (state (u:0 : u:1))) (label "branch-fresh"))
    #<hole>))
  (label "outer-fresh")))
```

Initial and terminal refocused states:

```racket
(ZWork
 (Work
  (fresh
   (x:outer)
   (disj
    (fresh
     (x:inner)
     (disj
      (put (x:outer : x:inner) (label "inner-left"))
      (put (x:outer : x:inner) (label "inner-right"))
      (label "inner-split"))
     (label "branch-fresh"))
    (put x:outer (label "outer-right"))
    (label "outer-split"))
   (label "outer-fresh"))
  (state unit))
 (More #<hole>))
```

```racket
(ZFrontier
 (Last (Answer (state u:0)))
 (FrontierFresh
  (u:0)
  (Emit
   (AnswerFresh (u:1) (Answer (state (u:0 : u:1))) (label "branch-fresh"))
   (Emit
    (AnswerFresh (u:1) (Answer (state (u:0 : u:1))) (label "branch-fresh"))
    #<hole>))
  (label "outer-fresh")))
```

Exact-machine initial state:

```racket
(MWork
 (Work
  (fresh
   (x:outer)
   (disj
    (fresh
     (x:inner)
     (disj
      (put (x:outer : x:inner) (label "inner-left"))
      (put (x:outer : x:inner) (label "inner-right"))
      (label "inner-split"))
     (label "branch-fresh"))
    (put x:outer (label "outer-right"))
    (label "outer-split"))
   (label "outer-fresh"))
  (state unit))
 (More #<hole>))
```

Exact-machine terminal state:

```racket
(MFrontier
 (Last (Answer (state u:0)))
 (FrontierFresh
  (u:0)
  (Emit
   (AnswerFresh (u:1) (Answer (state (u:0 : u:1))) (label "branch-fresh"))
   (Emit
    (AnswerFresh (u:1) (Answer (state (u:0 : u:1))) (label "branch-fresh"))
    #<hole>))
  (label "outer-fresh")))
```

### Salient source edges

Edge 2, `(expose-frontier-fresh core)`:

Before:

```racket
(More
 (WorkFresh
  (u:0)
  (Work
   (disj
    (fresh
     (x:inner)
     (disj
      (put (u:0 : x:inner) (label "inner-left"))
      (put (u:0 : x:inner) (label "inner-right"))
      (label "inner-split"))
     (label "branch-fresh"))
    (put u:0 (label "outer-right"))
    (label "outer-split"))
   (state unit))
  (label "outer-fresh")))
```

After:

```racket
(FrontierFresh
 (u:0)
 (More
  (Work
   (disj
    (fresh
     (x:inner)
     (disj
      (put (u:0 : x:inner) (label "inner-left"))
      (put (u:0 : x:inner) (label "inner-right"))
      (label "inner-split"))
     (label "branch-fresh"))
    (put u:0 (label "outer-right"))
    (label "outer-split"))
   (state unit)))
 (label "outer-fresh"))
```

Edge 7, `(expose-choice-through-work-fresh disj)`:

Before:

```racket
(FrontierFresh
 (u:0)
 (More
  (DisjL
   (WorkFresh
    (u:1)
    (DisjL
     (Returned (state (u:0 : u:1)))
     (Work (put (u:0 : u:1) (label "inner-right")) (state unit)))
    (label "branch-fresh"))
   (Work (put u:0 (label "outer-right")) (state unit))))
 (label "outer-fresh"))
```

After:

```racket
(FrontierFresh
 (u:0)
 (More
  (DisjL
   (DisjL
    (WorkFresh (u:1) (Returned (state (u:0 : u:1))) (label "branch-fresh"))
    (WorkFresh
     (u:1)
     (Work (put (u:0 : u:1) (label "inner-right")) (state unit))
     (label "branch-fresh")))
   (Work (put u:0 (label "outer-right")) (state unit))))
 (label "outer-fresh"))
```

### Compressed boundary

The direct compressed path has 9 nonempty certified macro edges:

1. `(transition-span (allocate-fresh core) (expose-frontier-fresh core))`
2. `(transition-span (expand-disjunction disj))`
3. `(transition-span (allocate-fresh core))`
4. `(transition-span (expand-disjunction disj))`
5. `(transition-span (kernel work-put core) (expose-choice-through-work-fresh disj))`
6. `(transition-span (reassociate-left-result disj))`
7. `(transition-span (commit-choice-answer disj))`
8. `(transition-span (kernel work-put core) (commit-choice-answer disj))`
9. `(transition-span (kernel work-put core) (finish-success core))`

Compressed initial state:

```racket
(BRun
 (Work
  (fresh
   (x:outer)
   (disj
    (fresh
     (x:inner)
     (disj
      (put (x:outer : x:inner) (label "inner-left"))
      (put (x:outer : x:inner) (label "inner-right"))
      (label "inner-split"))
     (label "branch-fresh"))
    (put x:outer (label "outer-right"))
    (label "outer-split"))
   (label "outer-fresh"))
  (state unit))
 (More #<hole>))
```

Compressed terminal state:

```racket
(BFinal
 (Last (Answer (state u:0)))
 (FrontierFresh
  (u:0)
  (Emit
   (AnswerFresh (u:1) (Answer (state (u:0 : u:1))) (label "branch-fresh"))
   (Emit
    (AnswerFresh (u:1) (Answer (state (u:0 : u:1))) (label "branch-fresh"))
    #<hole>))
  (label "outer-fresh")))
```

### Big-step boundary

The closure specification's ordered certificate is exactly the compressed span list above. The independently promoted judgment returns:

```racket
(FinalResult
 (Last (Answer (state u:0)))
 (FrontierFresh
  (u:0)
  (Emit
   (AnswerFresh (u:1) (Answer (state (u:0 : u:1))) (label "branch-fresh"))
   (Emit
    (AnswerFresh (u:1) (Answer (state (u:0 : u:1))) (label "branch-fresh"))
    #<hole>))
  (label "outer-fresh")))
```

All four terminal readbacks (source, exact machine, compressed machine, and promoted result) are identical:

```racket
(FrontierFresh
 (u:0)
 (Emit
  (AnswerFresh (u:1) (Answer (state (u:0 : u:1))) (label "branch-fresh"))
  (Emit
   (AnswerFresh (u:1) (Answer (state (u:0 : u:1))) (label "branch-fresh"))
   (Last (Answer (state u:0)))))
 (label "outer-fresh"))
```

## Ktoy: late hoisting

A settled branch is distributed only after conjunction work has become available.

### Source boundary

Initial whole frontier:

```racket
(More
 (Work
  (conj
   (disj
    (put (sym "left") (label "left"))
    (put (sym "right") (label "right"))
    (label "split"))
   (succeed (label "continue"))
   (label "and"))
  (state unit)))
```

The source has 10 exact edges and terminates at:

```racket
(Emit (Answer (state (sym "left"))) (Last (Answer (state (sym "right")))))
```

### Decomposition, refocusing, and exact-machine alignment

The independently stated R, direct D, direct Z, and direct M relations agree on all 10 labels. At every state, `plug-D(D) = R`, `D->Z(D) = Z`, and `encode-ZM(Z) = M`:

1. `(expand-conjunction core)`
2. `(expand-disjunction disj)`
3. `(kernel work-put core)`
4. `(late-distribute-settled disj)`
5. `(kernel work-succeed core)`
6. `(commit-choice-answer disj)`
7. `(kernel work-put core)`
8. `(conj-return core)`
9. `(kernel work-succeed core)`
10. `(finish-success core)`

Initial and terminal decomposition states:

```racket
(DecWork
 (Work
  (conj
   (disj
    (put (sym "left") (label "left"))
    (put (sym "right") (label "right"))
    (label "split"))
   (succeed (label "continue"))
   (label "and"))
  (state unit))
 (More #<hole>))
```

```racket
(DecFrontier
 (Last (Answer (state (sym "right"))))
 (Emit (Answer (state (sym "left"))) #<hole>))
```

Initial and terminal refocused states:

```racket
(ZWork
 (Work
  (conj
   (disj
    (put (sym "left") (label "left"))
    (put (sym "right") (label "right"))
    (label "split"))
   (succeed (label "continue"))
   (label "and"))
  (state unit))
 (More #<hole>))
```

```racket
(ZFrontier
 (Last (Answer (state (sym "right"))))
 (Emit (Answer (state (sym "left"))) #<hole>))
```

Exact-machine initial state:

```racket
(MWork
 (Work
  (conj
   (disj
    (put (sym "left") (label "left"))
    (put (sym "right") (label "right"))
    (label "split"))
   (succeed (label "continue"))
   (label "and"))
  (state unit))
 (More #<hole>))
```

Exact-machine terminal state:

```racket
(MFrontier
 (Last (Answer (state (sym "right"))))
 (Emit (Answer (state (sym "left"))) #<hole>))
```

### Salient source edges

Edge 4, `(late-distribute-settled disj)`:

Before:

```racket
(More
 (Conj
  (DisjL
   (Returned (state (sym "left")))
   (Work (put (sym "right") (label "right")) (state unit)))
  (succeed (label "continue"))))
```

After:

```racket
(More
 (DisjL
  (Work (succeed (label "continue")) (state (sym "left")))
  (Conj
   (Work (put (sym "right") (label "right")) (state unit))
   (succeed (label "continue")))))
```

### Compressed boundary

The direct compressed path has 6 nonempty certified macro edges:

1. `(transition-span (expand-conjunction core))`
2. `(transition-span (expand-disjunction disj))`
3. `(transition-span (kernel work-put core) (late-distribute-settled disj))`
4. `(transition-span (kernel work-succeed core) (commit-choice-answer disj))`
5. `(transition-span (kernel work-put core) (conj-return core))`
6. `(transition-span (kernel work-succeed core) (finish-success core))`

Compressed initial state:

```racket
(BRun
 (Work
  (conj
   (disj
    (put (sym "left") (label "left"))
    (put (sym "right") (label "right"))
    (label "split"))
   (succeed (label "continue"))
   (label "and"))
  (state unit))
 (More #<hole>))
```

Compressed terminal state:

```racket
(BFinal
 (Last (Answer (state (sym "right"))))
 (Emit (Answer (state (sym "left"))) #<hole>))
```

### Big-step boundary

The closure specification's ordered certificate is exactly the compressed span list above. The independently promoted judgment returns:

```racket
(FinalResult
 (Last (Answer (state (sym "right"))))
 (Emit (Answer (state (sym "left"))) #<hole>))
```

All four terminal readbacks (source, exact machine, compressed machine, and promoted result) are identical:

```racket
(Emit (Answer (state (sym "left"))) (Last (Answer (state (sym "right")))))
```

## Ktoy: rail / flip-flop scheduling

Two delayed branches exercise the rail turn and return rules.

### Source boundary

Initial whole frontier:

```racket
(More
 (Work
  (disj
   (suspend (put (sym "left") (label "left")) (label "left-delay"))
   (suspend (put (sym "right") (label "right")) (label "right-delay"))
   (label "split"))
  (state unit)))
```

The source has 11 exact edges and terminates at:

```racket
(Forced
 (Forced (Emit (Answer (state (sym "left"))) (Last (Answer (state (sym "right")))))))
```

### Decomposition, refocusing, and exact-machine alignment

The independently stated R, direct D, direct Z, and direct M relations agree on all 11 labels. At every state, `plug-D(D) = R`, `D->Z(D) = Z`, and `encode-ZM(Z) = M`:

1. `(expand-disjunction disj)`
2. `(suspend-goal delay)`
3. `(rail-enter-right search-join)`
4. `(force-delay delay)`
5. `(suspend-goal delay)`
6. `(rail-return-left search-join)`
7. `(force-delay delay)`
8. `(kernel work-put core)`
9. `(commit-choice-answer disj)`
10. `(kernel work-put core)`
11. `(finish-success core)`

Initial and terminal decomposition states:

```racket
(DecWork
 (Work
  (disj
   (suspend (put (sym "left") (label "left")) (label "left-delay"))
   (suspend (put (sym "right") (label "right")) (label "right-delay"))
   (label "split"))
  (state unit))
 (More #<hole>))
```

```racket
(DecFrontier
 (Last (Answer (state (sym "right"))))
 (Forced (Forced (Emit (Answer (state (sym "left"))) #<hole>))))
```

Initial and terminal refocused states:

```racket
(ZWork
 (Work
  (disj
   (suspend (put (sym "left") (label "left")) (label "left-delay"))
   (suspend (put (sym "right") (label "right")) (label "right-delay"))
   (label "split"))
  (state unit))
 (More #<hole>))
```

```racket
(ZFrontier
 (Last (Answer (state (sym "right"))))
 (Forced (Forced (Emit (Answer (state (sym "left"))) #<hole>))))
```

Exact-machine initial state:

```racket
(MWork
 (Work
  (disj
   (suspend (put (sym "left") (label "left")) (label "left-delay"))
   (suspend (put (sym "right") (label "right")) (label "right-delay"))
   (label "split"))
  (state unit))
 (More #<hole>))
```

Exact-machine terminal state:

```racket
(MFrontier
 (Last (Answer (state (sym "right"))))
 (Forced (Forced (Emit (Answer (state (sym "left"))) #<hole>))))
```

### Salient source edges

Edge 3, `(rail-enter-right search-join)`:

Before:

```racket
(More
 (DisjL
  (PendingDelay (Work (put (sym "left") (label "left")) (state unit)))
  (Work
   (suspend (put (sym "right") (label "right")) (label "right-delay"))
   (state unit))))
```

After:

```racket
(More
 (PendingDelay
  (DisjR
   (Work (put (sym "left") (label "left")) (state unit))
   (Work
    (suspend (put (sym "right") (label "right")) (label "right-delay"))
    (state unit)))))
```

Edge 6, `(rail-return-left search-join)`:

Before:

```racket
(Forced
 (More
  (DisjR
   (Work (put (sym "left") (label "left")) (state unit))
   (PendingDelay (Work (put (sym "right") (label "right")) (state unit))))))
```

After:

```racket
(Forced
 (More
  (PendingDelay
   (DisjL
    (Work (put (sym "left") (label "left")) (state unit))
    (Work (put (sym "right") (label "right")) (state unit))))))
```

### Compressed boundary

The direct compressed path has 7 nonempty certified macro edges:

1. `(transition-span (expand-disjunction disj))`
2. `(transition-span (suspend-goal delay) (rail-enter-right search-join))`
3. `(transition-span (force-delay delay))`
4. `(transition-span (suspend-goal delay) (rail-return-left search-join))`
5. `(transition-span (force-delay delay))`
6. `(transition-span (kernel work-put core) (commit-choice-answer disj))`
7. `(transition-span (kernel work-put core) (finish-success core))`

Compressed initial state:

```racket
(BRun
 (Work
  (disj
   (suspend (put (sym "left") (label "left")) (label "left-delay"))
   (suspend (put (sym "right") (label "right")) (label "right-delay"))
   (label "split"))
  (state unit))
 (More #<hole>))
```

Compressed terminal state:

```racket
(BFinal
 (Last (Answer (state (sym "right"))))
 (Forced (Forced (Emit (Answer (state (sym "left"))) #<hole>))))
```

### Big-step boundary

The closure specification's ordered certificate is exactly the compressed span list above. The independently promoted judgment returns:

```racket
(FinalResult
 (Last (Answer (state (sym "right"))))
 (Forced (Forced (Emit (Answer (state (sym "left"))) #<hole>))))
```

All four terminal readbacks (source, exact machine, compressed machine, and promoted result) are identical:

```racket
(Forced
 (Forced (Emit (Answer (state (sym "left"))) (Last (Answer (state (sym "right")))))))
```

## Ktoy: right-active local fresh

A delayed-left choice rotates right while its fresh scope remains branch-local, exposing the search-join-owned symmetric rule.

### Source boundary

Initial whole frontier:

```racket
(More
 (Work
  (conj
   (conj
    (fresh (x:q) (put x:q (label "seed")) (label "fresh"))
    (disj
     (suspend (put (sym "later") (label "later")) (label "delay"))
     (put (sym "now") (label "now"))
     (label "split"))
    (label "seed-and-choice"))
   (succeed (label "continue"))
   (label "outer-and"))
  (state unit)))
```

The source has 21 exact edges and terminates at:

```racket
(Forced
 (Emit
  (AnswerFresh (u:0) (Answer (state (sym "now"))) (label "fresh"))
  (FrontierFresh (u:0) (Last (Answer (state (sym "later")))) (label "fresh"))))
```

### Decomposition, refocusing, and exact-machine alignment

The independently stated R, direct D, direct Z, and direct M relations agree on all 21 labels. At every state, `plug-D(D) = R`, `D->Z(D) = Z`, and `encode-ZM(Z) = M`:

1. `(expand-conjunction core)`
2. `(expand-conjunction core)`
3. `(allocate-fresh core)`
4. `(kernel work-put core)`
5. `(conj-return core)`
6. `(expand-disjunction disj)`
7. `(suspend-goal delay)`
8. `(rail-enter-right search-join)`
9. `(bubble-delay-through-fresh delay)`
10. `(bubble-delay-through-conj delay)`
11. `(force-delay delay)`
12. `(kernel work-put core)`
13. `(expose-choice-through-work-fresh search-join)`
14. `(late-distribute-right-settled search-join)`
15. `(kernel work-succeed core)`
16. `(commit-right-choice-answer search-join)`
17. `(kernel work-put core)`
18. `(conj-return core)`
19. `(expose-frontier-fresh core)`
20. `(kernel work-succeed core)`
21. `(finish-success core)`

Initial and terminal decomposition states:

```racket
(DecWork
 (Work
  (conj
   (conj
    (fresh (x:q) (put x:q (label "seed")) (label "fresh"))
    (disj
     (suspend (put (sym "later") (label "later")) (label "delay"))
     (put (sym "now") (label "now"))
     (label "split"))
    (label "seed-and-choice"))
   (succeed (label "continue"))
   (label "outer-and"))
  (state unit))
 (More #<hole>))
```

```racket
(DecFrontier
 (Last (Answer (state (sym "later"))))
 (Forced
  (Emit
   (AnswerFresh (u:0) (Answer (state (sym "now"))) (label "fresh"))
   (FrontierFresh (u:0) #<hole> (label "fresh")))))
```

Initial and terminal refocused states:

```racket
(ZWork
 (Work
  (conj
   (conj
    (fresh (x:q) (put x:q (label "seed")) (label "fresh"))
    (disj
     (suspend (put (sym "later") (label "later")) (label "delay"))
     (put (sym "now") (label "now"))
     (label "split"))
    (label "seed-and-choice"))
   (succeed (label "continue"))
   (label "outer-and"))
  (state unit))
 (More #<hole>))
```

```racket
(ZFrontier
 (Last (Answer (state (sym "later"))))
 (Forced
  (Emit
   (AnswerFresh (u:0) (Answer (state (sym "now"))) (label "fresh"))
   (FrontierFresh (u:0) #<hole> (label "fresh")))))
```

Exact-machine initial state:

```racket
(MWork
 (Work
  (conj
   (conj
    (fresh (x:q) (put x:q (label "seed")) (label "fresh"))
    (disj
     (suspend (put (sym "later") (label "later")) (label "delay"))
     (put (sym "now") (label "now"))
     (label "split"))
    (label "seed-and-choice"))
   (succeed (label "continue"))
   (label "outer-and"))
  (state unit))
 (More #<hole>))
```

Exact-machine terminal state:

```racket
(MFrontier
 (Last (Answer (state (sym "later"))))
 (Forced
  (Emit
   (AnswerFresh (u:0) (Answer (state (sym "now"))) (label "fresh"))
   (FrontierFresh (u:0) #<hole> (label "fresh")))))
```

### Salient source edges

Edge 8, `(rail-enter-right search-join)`:

Before:

```racket
(More
 (Conj
  (WorkFresh
   (u:0)
   (DisjL
    (PendingDelay (Work (put (sym "later") (label "later")) (state u:0)))
    (Work (put (sym "now") (label "now")) (state u:0)))
   (label "fresh"))
  (succeed (label "continue"))))
```

After:

```racket
(More
 (Conj
  (WorkFresh
   (u:0)
   (PendingDelay
    (DisjR
     (Work (put (sym "later") (label "later")) (state u:0))
     (Work (put (sym "now") (label "now")) (state u:0))))
   (label "fresh"))
  (succeed (label "continue"))))
```

Edge 13, `(expose-choice-through-work-fresh search-join)`:

Before:

```racket
(Forced
 (More
  (Conj
   (WorkFresh
    (u:0)
    (DisjR
     (Work (put (sym "later") (label "later")) (state u:0))
     (Returned (state (sym "now"))))
    (label "fresh"))
   (succeed (label "continue")))))
```

After:

```racket
(Forced
 (More
  (Conj
   (DisjR
    (WorkFresh
     (u:0)
     (Work (put (sym "later") (label "later")) (state u:0))
     (label "fresh"))
    (WorkFresh (u:0) (Returned (state (sym "now"))) (label "fresh")))
   (succeed (label "continue")))))
```

Edge 14, `(late-distribute-right-settled search-join)`:

Before:

```racket
(Forced
 (More
  (Conj
   (DisjR
    (WorkFresh
     (u:0)
     (Work (put (sym "later") (label "later")) (state u:0))
     (label "fresh"))
    (WorkFresh (u:0) (Returned (state (sym "now"))) (label "fresh")))
   (succeed (label "continue")))))
```

After:

```racket
(Forced
 (More
  (DisjR
   (Conj
    (WorkFresh
     (u:0)
     (Work (put (sym "later") (label "later")) (state u:0))
     (label "fresh"))
    (succeed (label "continue")))
   (WorkFresh
    (u:0)
    (Work (succeed (label "continue")) (state (sym "now")))
    (label "fresh")))))
```

Edge 19, `(expose-frontier-fresh core)`:

Before:

```racket
(Forced
 (Emit
  (AnswerFresh (u:0) (Answer (state (sym "now"))) (label "fresh"))
  (More
   (WorkFresh
    (u:0)
    (Work (succeed (label "continue")) (state (sym "later")))
    (label "fresh")))))
```

After:

```racket
(Forced
 (Emit
  (AnswerFresh (u:0) (Answer (state (sym "now"))) (label "fresh"))
  (FrontierFresh
   (u:0)
   (More (Work (succeed (label "continue")) (state (sym "later"))))
   (label "fresh"))))
```

### Compressed boundary

The direct compressed path has 14 nonempty certified macro edges:

1. `(transition-span (expand-conjunction core))`
2. `(transition-span (expand-conjunction core))`
3. `(transition-span (allocate-fresh core))`
4. `(transition-span (kernel work-put core) (conj-return core))`
5. `(transition-span (expand-disjunction disj))`
6. `(transition-span (suspend-goal delay) (rail-enter-right search-join))`
7. `(transition-span (bubble-delay-through-fresh delay))`
8. `(transition-span (bubble-delay-through-conj delay))`
9. `(transition-span (force-delay delay))`
10. `(transition-span (kernel work-put core) (expose-choice-through-work-fresh search-join))`
11. `(transition-span (late-distribute-right-settled search-join))`
12. `(transition-span (kernel work-succeed core) (commit-right-choice-answer search-join))`
13. `(transition-span (kernel work-put core) (conj-return core) (expose-frontier-fresh core))`
14. `(transition-span (kernel work-succeed core) (finish-success core))`

Compressed initial state:

```racket
(BRun
 (Work
  (conj
   (conj
    (fresh (x:q) (put x:q (label "seed")) (label "fresh"))
    (disj
     (suspend (put (sym "later") (label "later")) (label "delay"))
     (put (sym "now") (label "now"))
     (label "split"))
    (label "seed-and-choice"))
   (succeed (label "continue"))
   (label "outer-and"))
  (state unit))
 (More #<hole>))
```

Compressed terminal state:

```racket
(BFinal
 (Last (Answer (state (sym "later"))))
 (Forced
  (Emit
   (AnswerFresh (u:0) (Answer (state (sym "now"))) (label "fresh"))
   (FrontierFresh (u:0) #<hole> (label "fresh")))))
```

### Big-step boundary

The closure specification's ordered certificate is exactly the compressed span list above. The independently promoted judgment returns:

```racket
(FinalResult
 (Last (Answer (state (sym "later"))))
 (Forced
  (Emit
   (AnswerFresh (u:0) (Answer (state (sym "now"))) (label "fresh"))
   (FrontierFresh (u:0) #<hole> (label "fresh")))))
```

All four terminal readbacks (source, exact machine, compressed machine, and promoted result) are identical:

```racket
(Forced
 (Emit
  (AnswerFresh (u:0) (Answer (state (sym "now"))) (label "fresh"))
  (FrontierFresh (u:0) (Last (Answer (state (sym "later")))) (label "fresh"))))
```

## Kmk: unification, delay, and disequality

The same control column runs over the c-free miniKanren kernel and retains its tagged atomic labels.

### Source boundary

Initial whole frontier:

```racket
(More
 (Work
  (fresh
   (x:q)
   (disj
    (conj
     (x:q =? (sym "cat") (label "bind"))
     (suspend (succeed (label "resume")) (label "delay"))
     (label "and"))
    (x:q != (sym "dog") (label "neq"))
    (label "or"))
   (label "query"))
  (state () () () (label "s"))))
```

The source has 13 exact edges and terminates at:

```racket
(FrontierFresh
 (u:0)
 (Forced
  (Emit
   (Answer (state () ((u:0 (sym "dog"))) () (label "s")))
   (Last
    (Answer
     (state
      ((u:0 (sym "cat")))
      ()
      ((u:0 =? (sym "cat") (label "bind")))
      (label "s"))))))
 (label "query"))
```

### Decomposition, refocusing, and exact-machine alignment

The independently stated R, direct D, direct Z, and direct M relations agree on all 13 labels. At every state, `plug-D(D) = R`, `D->Z(D) = Z`, and `encode-ZM(Z) = M`:

1. `(allocate-fresh core)`
2. `(expose-frontier-fresh core)`
3. `(expand-disjunction disj)`
4. `(expand-conjunction core)`
5. `(kernel unify-success core)`
6. `(conj-return core)`
7. `(suspend-goal delay)`
8. `(rail-enter-right search-join)`
9. `(force-delay delay)`
10. `(kernel disequality-success core)`
11. `(commit-right-choice-answer search-join)`
12. `(kernel succeed core)`
13. `(finish-success core)`

Initial and terminal decomposition states:

```racket
(DecWork
 (Work
  (fresh
   (x:q)
   (disj
    (conj
     (x:q =? (sym "cat") (label "bind"))
     (suspend (succeed (label "resume")) (label "delay"))
     (label "and"))
    (x:q != (sym "dog") (label "neq"))
    (label "or"))
   (label "query"))
  (state () () () (label "s")))
 (More #<hole>))
```

```racket
(DecFrontier
 (Last
  (Answer
   (state ((u:0 (sym "cat"))) () ((u:0 =? (sym "cat") (label "bind"))) (label "s"))))
 (FrontierFresh
  (u:0)
  (Forced (Emit (Answer (state () ((u:0 (sym "dog"))) () (label "s"))) #<hole>))
  (label "query")))
```

Initial and terminal refocused states:

```racket
(ZWork
 (Work
  (fresh
   (x:q)
   (disj
    (conj
     (x:q =? (sym "cat") (label "bind"))
     (suspend (succeed (label "resume")) (label "delay"))
     (label "and"))
    (x:q != (sym "dog") (label "neq"))
    (label "or"))
   (label "query"))
  (state () () () (label "s")))
 (More #<hole>))
```

```racket
(ZFrontier
 (Last
  (Answer
   (state ((u:0 (sym "cat"))) () ((u:0 =? (sym "cat") (label "bind"))) (label "s"))))
 (FrontierFresh
  (u:0)
  (Forced (Emit (Answer (state () ((u:0 (sym "dog"))) () (label "s"))) #<hole>))
  (label "query")))
```

Exact-machine initial state:

```racket
(MWork
 (Work
  (fresh
   (x:q)
   (disj
    (conj
     (x:q =? (sym "cat") (label "bind"))
     (suspend (succeed (label "resume")) (label "delay"))
     (label "and"))
    (x:q != (sym "dog") (label "neq"))
    (label "or"))
   (label "query"))
  (state () () () (label "s")))
 (More #<hole>))
```

Exact-machine terminal state:

```racket
(MFrontier
 (Last
  (Answer
   (state ((u:0 (sym "cat"))) () ((u:0 =? (sym "cat") (label "bind"))) (label "s"))))
 (FrontierFresh
  (u:0)
  (Forced (Emit (Answer (state () ((u:0 (sym "dog"))) () (label "s"))) #<hole>))
  (label "query")))
```

### Salient source edges

Edge 2, `(expose-frontier-fresh core)`:

Before:

```racket
(More
 (WorkFresh
  (u:0)
  (Work
   (disj
    (conj
     (u:0 =? (sym "cat") (label "bind"))
     (suspend (succeed (label "resume")) (label "delay"))
     (label "and"))
    (u:0 != (sym "dog") (label "neq"))
    (label "or"))
   (state () () () (label "s")))
  (label "query")))
```

After:

```racket
(FrontierFresh
 (u:0)
 (More
  (Work
   (disj
    (conj
     (u:0 =? (sym "cat") (label "bind"))
     (suspend (succeed (label "resume")) (label "delay"))
     (label "and"))
    (u:0 != (sym "dog") (label "neq"))
    (label "or"))
   (state () () () (label "s"))))
 (label "query"))
```

Edge 8, `(rail-enter-right search-join)`:

Before:

```racket
(FrontierFresh
 (u:0)
 (More
  (DisjL
   (PendingDelay
    (Work
     (succeed (label "resume"))
     (state ((u:0 (sym "cat"))) () ((u:0 =? (sym "cat") (label "bind"))) (label "s"))))
   (Work (u:0 != (sym "dog") (label "neq")) (state () () () (label "s")))))
 (label "query"))
```

After:

```racket
(FrontierFresh
 (u:0)
 (More
  (PendingDelay
   (DisjR
    (Work
     (succeed (label "resume"))
     (state ((u:0 (sym "cat"))) () ((u:0 =? (sym "cat") (label "bind"))) (label "s")))
    (Work (u:0 != (sym "dog") (label "neq")) (state () () () (label "s"))))))
 (label "query"))
```

### Compressed boundary

The direct compressed path has 8 nonempty certified macro edges:

1. `(transition-span (allocate-fresh core) (expose-frontier-fresh core))`
2. `(transition-span (expand-disjunction disj))`
3. `(transition-span (expand-conjunction core))`
4. `(transition-span (kernel unify-success core) (conj-return core))`
5. `(transition-span (suspend-goal delay) (rail-enter-right search-join))`
6. `(transition-span (force-delay delay))`
7. `(transition-span (kernel disequality-success core) (commit-right-choice-answer search-join))`
8. `(transition-span (kernel succeed core) (finish-success core))`

Compressed initial state:

```racket
(BRun
 (Work
  (fresh
   (x:q)
   (disj
    (conj
     (x:q =? (sym "cat") (label "bind"))
     (suspend (succeed (label "resume")) (label "delay"))
     (label "and"))
    (x:q != (sym "dog") (label "neq"))
    (label "or"))
   (label "query"))
  (state () () () (label "s")))
 (More #<hole>))
```

Compressed terminal state:

```racket
(BFinal
 (Last
  (Answer
   (state ((u:0 (sym "cat"))) () ((u:0 =? (sym "cat") (label "bind"))) (label "s"))))
 (FrontierFresh
  (u:0)
  (Forced (Emit (Answer (state () ((u:0 (sym "dog"))) () (label "s"))) #<hole>))
  (label "query")))
```

### Big-step boundary

The closure specification's ordered certificate is exactly the compressed span list above. The independently promoted judgment returns:

```racket
(FinalResult
 (Last
  (Answer
   (state ((u:0 (sym "cat"))) () ((u:0 =? (sym "cat") (label "bind"))) (label "s"))))
 (FrontierFresh
  (u:0)
  (Forced (Emit (Answer (state () ((u:0 (sym "dog"))) () (label "s"))) #<hole>))
  (label "query")))
```

All four terminal readbacks (source, exact machine, compressed machine, and promoted result) are identical:

```racket
(FrontierFresh
 (u:0)
 (Forced
  (Emit
   (Answer (state () ((u:0 (sym "dog"))) () (label "s")))
   (Last
    (Answer
     (state
      ((u:0 (sym "cat")))
      ()
      ((u:0 =? (sym "cat") (label "bind")))
      (label "s"))))))
 (label "query"))
```
