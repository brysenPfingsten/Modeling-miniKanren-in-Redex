#lang racket

(require "03-data.rkt"
         (only-in "../shared/kernel.rkt" owners-support valid-support?)
         (only-in "../shared/wf.rkt" wf-s?))

(provide reify-search reify-frontier reify-resumption reify-value reify-continuation
         continuation-prefix continuation-input-kind
         readback-call readback-halted valid-call?)

;; This is a structural map, not an evaluator. In particular, opening REval,
;; RMerge, or RBind constructs a suspended source computation without running
;; it. Cached inherited supports are checked against the structural position
;; at which the resulting computation will occur. Exact Owners, Answer owners,
;; states, tags, and left/right orientation survive this map. Active Search and
;; settled Frontier have disjoint constructors. The map selects their images
;; from those constructors, without a caller-supplied interpretation mode.
(define (check-prefix who captured structural)
  (unless (and (valid-support? captured) (equal? captured structural))
    (error who "captured support ~e disagrees with structural ancestry ~e"
           captured structural)))

(define (extend owners inherited)
  (define here (owners-support owners inherited))
  (unless (valid-support? here)
    (error 'readback "invalid structural allocation ancestry: ~e" here))
  here)

(define (continuation-goal continue)
  (match continue
    [(GRight goal) goal]
    [_ (raise-argument-error 'continuation-goal "GRight continuation" continue)]))

(define (reify-search search [inherited '()])
  ;; QS preserves Yield and its exact ownership on both sides. More is the
  ;; Frontier constructor holding unfinished Delay work.
  (match search
    [`(Empty ,owners)
     (extend owners inherited)
     `(Empty ,owners)]
    [`(One ,owners ,state)
     (extend owners inherited)
     `(One ,owners ,state)]
    [`(Yield ,owners (Answer ,answer-owners ,state) ,tail)
     (define here (extend owners inherited))
     (extend answer-owners here)
     `(Yield ,owners (Answer ,answer-owners ,state) ,(reify-search tail here))]
    [`(Delay ,owners ,resume)
     `(Delay ,owners ,(reify-resumption resume (extend owners inherited)))]
    [_ (raise-argument-error 'reify-search "defunctionalized active S Search" search)]))

(define (reify-resumption resume [inherited '()])
  (match resume
    [(REval goal state here)
     (check-prefix 'REval here inherited)
     `(eval (Owners) ,goal ,state)]
    [(RMerge right left here)
     (check-prefix 'RMerge here inherited)
     `(mplus (Owners) ,(reify-search right here)
             (force ,(reify-search left here)))]
    [(RBind rest continue here)
     (check-prefix 'RBind here inherited)
     `(bind (Owners)
            ,(reify-resumption rest here)
            ,(continuation-goal continue))]
    [_ (raise-argument-error 'reify-resumption "defunctionalized S resumption" resume)]))

(define (reify-frontier frontier [inherited '()])
  ;; QF retains a native source Frontier, including its explicitly unfinished
  ;; More(Delay). It is a value on both sides, not a paused render computation.
  (match frontier
    [`(Done ,owners)
     (extend owners inherited)
     frontier]
    [`(Last (Owners) (Answer ,answer-owners ,_))
     (extend answer-owners inherited)
     frontier]
    [`(Emit ,owners (Answer ,answer-owners ,state) ,tail)
     (define here (extend owners inherited))
     (extend answer-owners here)
     `(Emit ,owners (Answer ,answer-owners ,state) ,(reify-frontier tail here))]
    [`(Forced ,owners ,tail)
     `(Forced ,owners ,(reify-frontier tail (extend owners inherited)))]
    [`(More ,(and delay `(Delay ,_ ,_)))
     `(More ,(reify-search delay inherited))]
    [_ (raise-argument-error 'reify-frontier "defunctionalized settled S Frontier" frontier)]))

(define (reify-value value [inherited '()])
  (match value
    [`(,(or 'Empty 'One 'Yield 'Delay) ,_ ...) (reify-search value inherited)]
    [`(,(or 'Done 'Last 'Emit 'Forced 'More) ,_ ...) (reify-frontier value inherited)]
    [_ (raise-argument-error 'reify-value "defunctionalized S Search or Frontier" value)]))

;; Read from the outermost continuation inward. This reconstructs the active
;; world's ancestry without inspecting siblings or answer-local introductions.
;; KPrefix is the pending strict source prefix context: its Owners contribute
;; ancestry while the body runs and attach to Search only when it returns.
(define (continuation-prefix k [root '()])
  (match k
    [(KDone)
     (check-prefix 'KDone root root)
     root]
    [(or (KConj _ owners inherited rest)
         (KDisjLeft _ _ owners inherited rest)
         (KDisjRight _ owners inherited rest)
         (KBindHead _ _ owners inherited rest)
         (KBindTail _ owners inherited rest))
     (define outside (continuation-prefix rest root))
     (check-prefix 'continuation-prefix inherited outside)
     (extend owners outside)]
    [(or (KMergeYield owners _ rest)
         (KPrefix owners rest)
         (KCommitEmit owners _ rest)
         (KAdvanceEmit owners _ rest)
         (KAdvanceHistory owners rest)
         (KAdvanceForced owners rest)
         (KCollectEmit owners _ rest)
         (KCollectHistory owners rest)
         (KCollectResume owners rest)
         (KCollectForced owners rest))
     (extend owners (continuation-prefix rest root))]
    [(KCommit rest) (continuation-prefix rest root)]
    [(or (KMergeForced _ here rest) (KBindForced _ here rest))
     (define outside (continuation-prefix rest root))
     (check-prefix 'continuation-prefix here outside)
     outside]
    [_ (raise-argument-error 'continuation-prefix "defunctionalized S continuation" k)]))

;; Continuation constructors determine the required value kind. KCommit is
;; the explicit Search-to-Frontier boundary; public roots receive Frontiers.
(define (continuation-input-kind k)
  (match k
    [(or (KDone) (KCommitEmit _ _ _)
         (KAdvanceEmit _ _ _) (KAdvanceHistory _ _) (KAdvanceForced _ _)
         (KCollectEmit _ _ _) (KCollectHistory _ _) (KCollectResume _ _)
         (KCollectForced _ _))
     'frontier]
    [(or (KCommit _)
         (KConj _ _ _ _) (KDisjLeft _ _ _ _ _) (KDisjRight _ _ _ _)
         (KMergeYield _ _ _) (KBindHead _ _ _ _ _) (KBindTail _ _ _ _)
         (KMergeForced _ _ _) (KBindForced _ _ _) (KPrefix _ _))
     'search]
    [_ (raise-argument-error 'continuation-input-kind "defunctionalized S continuation" k)]))

(define (source-kind computation)
  (match computation
    [`(More (Delay ,_ ,_)) 'frontier]
    [`(,(or 'eval 'mplus 'bind 'force 'prefix 'Empty 'One 'Yield 'Delay) ,_ ...) 'search]
    [`(,(or 'commit 'advance 'collect 'render 'Done 'Last 'Emit 'Forced) ,_ ...) 'frontier]
    [_ (raise-argument-error 'source-kind "independent S computation" computation)]))

;; The input is an already reified computation/value at k's active position.
;; Saved Searches are reified under their own structural prefix. Constructors
;; determine both sides of the boundary; mismatches are rejected.
(define (reify-continuation computation k [root '()])
  (continuation-prefix k root)
  (unless (equal? (source-kind computation) (continuation-input-kind k))
    (error 'reify-continuation "~e consumes ~e, received ~e image"
           k (continuation-input-kind k) (source-kind computation)))
  (match k
    [(KDone) computation]
    [(KConj right owners _ rest)
     (reify-continuation `(bind ,owners ,computation ,right) rest root)]
    [(KDisjLeft right state owners _ rest)
     (reify-continuation
      `(mplus ,owners ,computation (eval (Owners) ,right ,state)) rest root)]
    [(KDisjRight left owners _ rest)
     (define here (extend owners (continuation-prefix rest root)))
     (reify-continuation `(mplus ,owners ,(reify-search left here) ,computation) rest root)]
    [(KMergeYield owners answer rest)
     (reify-continuation `(Yield ,owners ,answer ,computation) rest root)]
    [(KBindHead tail continue common _ rest)
     (define here (extend common (continuation-prefix rest root)))
     (reify-continuation
      `(mplus ,common ,computation
              (bind (Owners) ,(reify-search tail here) ,(continuation-goal continue)))
      rest root)]
    [(KBindTail head common _ rest)
     (define here (extend common (continuation-prefix rest root)))
     (reify-continuation `(mplus ,common ,(reify-search head here) ,computation) rest root)]
    [(KMergeForced right here rest)
     (reify-continuation `(mplus (Owners) ,(reify-search right here) ,computation) rest root)]
    [(KBindForced continue _ rest)
     (reify-continuation `(bind (Owners) ,computation ,(continuation-goal continue)) rest root)]
    [(KPrefix owners rest)
     (reify-continuation `(prefix ,owners ,computation) rest root)]
    [(KCommit rest) (reify-continuation `(commit ,computation) rest root)]
    [(or (KCommitEmit owners answer rest)
         (KAdvanceEmit owners answer rest) (KCollectEmit owners answer rest))
     (reify-continuation `(Emit ,owners ,answer ,computation) rest root)]
    [(KAdvanceForced owners rest)
     (reify-continuation `(Forced ,owners ,computation) rest root)]
    [(KCollectResume owners rest)
     (reify-continuation `(Forced ,owners (collect ,computation)) rest root)]
    [(or (KAdvanceHistory owners rest) (KCollectHistory owners rest)
         (KCollectForced owners rest))
     (reify-continuation `(Forced ,owners ,computation) rest root)]))

(define (checked-readback computation)
  (unless (wf-s? computation)
    (error 'readback "reification violates the independent S allocation contract: ~e"
           computation))
  computation)

;; pc and operands are the generated machine's Call fields, kept separate here
;; so this map does not depend on the generator or invoke a machine transition.
;; An eval/d atomic transition computes the native data Outcome. Consequently
;; outcome/d, failure/d, and success/d all reify its already selected Empty/One;
;; selecting the handler is administrative, not a second atomic evaluation.
(define (readback-call pc operands)
  (checked-readback
   (match (cons pc operands)
     [(list 'eval/d goal state owners inherited k)
      (check-prefix 'eval/d inherited (continuation-prefix k))
      (reify-continuation `(eval ,owners ,goal ,state) k)]
     [(list 'merge/d left right owners inherited k)
      (check-prefix 'merge/d inherited (continuation-prefix k))
      (define here (extend owners inherited))
      (reify-continuation
       `(mplus ,owners ,(reify-search left here) ,(reify-search right here)) k)]
     [(list 'bind/d search continue owners inherited k)
      (check-prefix 'bind/d inherited (continuation-prefix k))
      (reify-continuation
       `(bind ,owners ,(reify-search search (extend owners inherited))
              ,(continuation-goal continue)) k)]
     [(list 'continue/d continue state owners inherited k)
      (check-prefix 'continue/d inherited (continuation-prefix k))
      (reify-continuation `(eval ,owners ,(continuation-goal continue) ,state) k)]
     [(list 'resume/d resume k)
      (reify-continuation (reify-resumption resume (continuation-prefix k)) k)]
     [(list 'force/d search k)
      (reify-continuation `(force ,(reify-search search (continuation-prefix k))) k)]
     [(list 'commit/d search k)
      (reify-continuation `(commit ,(reify-search search (continuation-prefix k))) k)]
     [(list 'advance/d frontier k)
      (reify-continuation `(advance ,(reify-frontier frontier (continuation-prefix k))) k)]
     [(list 'collect/d frontier k)
      (reify-continuation `(collect ,(reify-frontier frontier (continuation-prefix k))) k)]
     [(list 'return/d value k)
      (reify-continuation (reify-value value (continuation-prefix k)) k)]
     [(list 'outcome/d outcome (FEmpty owners k) (SOne owners* k*))
      (unless (and (equal? owners owners*) (equal? k k*))
        (error 'readback "outcome consumers disagree on Owners or continuation"))
      (reify-continuation
       (match outcome
         [(Failure) `(Empty ,owners)]
         [(Success state) `(One ,owners ,state)]) k)]
     [(list 'failure/d (FEmpty owners k))
      (reify-continuation `(Empty ,owners) k)]
     [(list 'success/d (SOne owners k) state)
      (reify-continuation `(One ,owners ,state) k)]
     [_ (raise-arguments-error 'readback-call "unknown generated machine call"
                               "pc" pc "operands" operands)])))

(define (readback-halted value)
  (checked-readback (reify-frontier value)))

(define (valid-call? pc operands)
  (with-handlers ([exn:fail? (lambda (_) #f)])
    (readback-call pc operands)
    #t))

;; Each functional transition exposes zero or one source contraction.
;; Commit crosses commit-empty/one/yield/delay and returns a genuine Frontier
;; normal form. Advance/collect explicitly traverse and force the exposed tip;
;; Raw resumption dispatch exposes its body without inventing a force redex.
;; Returning through KPrefix performs the named prefix-value contraction.
;; No reductions or resumption invocations are performed by this mapper.
