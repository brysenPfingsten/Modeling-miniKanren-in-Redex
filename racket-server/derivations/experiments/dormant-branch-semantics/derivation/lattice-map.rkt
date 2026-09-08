#lang racket

(require (only-in redex/reduction-semantics term)
         "source.rkt"
         (only-in "../../../shared/kernel.rkt" owners-append)
         (prefix-in kernel: "../source/languages/core-lang.rkt"))
(provide (all-defined-out))

;; The representation relation is first defined on the whole syntax so its
;; limitations are inspectable. Exact transition squares are claimed only for
;; the allocation-free, empty-Owners fragment. Owner scope transport and the
;; lattice's whole-Frontier freshness are separate full-language obligations.
(define (work computation)
  (match computation
    [`(eval ,owners ,goal ,state) `(Work ,owners ,goal ,state)]
    [`(mplus ,owners ,left ,right) `(DisjL ,owners ,(work left) ,(work right))]
    [`(mplusR ,owners ,left ,right) `(DisjR ,owners ,(work left) ,(work right))]
    [`(bind ,owners ,left ,goal) `(Conj ,owners ,(work left) ,goal)]
    [`(Empty ,owners) `(Dead ,owners)]
    [`(One ,owners ,state) `(Returned ,owners ,state)]
    [`(Yield ,owners (Answer ,private ,state) ,tail)
     `(DisjL ,owners (Returned ,private ,state) ,(work tail))]
    [`(YieldR ,owners ,tail (Answer ,private ,state))
     `(DisjR ,owners ,(work tail) (Returned ,private ,state))]
    [`(Delay ,owners ,body) `(PendingDelay ,owners ,(work body))]))
(define (frontier observation)
  (match observation
    [`(commit ,body) `(More ,(work body))]
    [`(advance ,body) (frontier body)]
    [`(Done ,owners) `(Done ,owners)]
    [`(Last ,owners (Answer ,private ,state))
     `(Last ,(owners-append owners private) (Answer (Owners) ,state))]
    [`(Emit ,owners ,answer ,tail) `(Emit ,owners ,answer ,(frontier tail))]
    [`(Forced ,owners ,tail) `(Forced ,owners ,(frontier tail))]
    [`(More ,delay) `(More ,(work delay))]))
(define (source->lattice program)
  (match-define `(program ,_ ,definitions ,body) program)
  `(,definitions ,(frontier body)))

(define administrative-labels
  '("mplus-one" "commit-delay" "advance-terminal" "advance-emit" "advance-forced"))
(define (administrative? label) (and (member label administrative-labels) #t))

;; A global natural-number ranking function for the source-only normalization:
;; count every mplus and commit; weight advance by its remaining Frontier spine
;; plus one. Include suspended subterms in the weight, although normalization
;; never evaluates them. Each listed administrative contraction decreases it.
(define (spine-length value)
  (match value
    [(or `(Emit ,_ ,_ ,tail) `(Forced ,_ ,tail)) (add1 (spine-length tail))]
    [_ 0]))
(define (administrative-weight term)
  (match term
    [`(program ,_ ,_ ,body) (administrative-weight body)]
    [(or `(mplus ,_ ,left ,right) `(mplusR ,_ ,left ,right))
     (+ 1 (administrative-weight left) (administrative-weight right))]
    [`(bind ,_ ,body ,_) (administrative-weight body)]
    [`(commit ,body) (add1 (administrative-weight body))]
    [`(advance ,body) (+ 1 (spine-length body) (administrative-weight body))]
    [(or `(Yield ,_ ,_ ,tail) `(YieldR ,_ ,tail ,_) `(Delay ,_ ,tail)
         `(Emit ,_ ,_ ,tail) `(Forced ,_ ,tail) `(More ,tail))
     (administrative-weight tail)]
    [_ 0]))

;; Refining the already shared atomic kernel's coarse eval-atom label does not
;; run a search operand. It identifies the primitive branch of its equation.
(define (atomic-label atom state)
  (match-define `(state ,sub ,dis ,_ ,_) state)
  (match atom
    [`(succeed ,_) "succeed"]
    [`(fail ,_) "fail"]
    [`(,left =? ,right ,_)
     (define next (term (kernel:unify (kernel:walk ,left ,sub)
                                    (kernel:walk ,right ,sub) ,sub)))
     (cond [(not next) "unify-fail"]
           [(term (kernel:invalid? ,next ,dis)) "unify-violates-disequality"]
           [else "unify-success"])]
    [`(,left != ,right ,_)
     (if (term (kernel:invalid? ,sub ((,left ,right) ,@dis)))
         "disequality-fail" "disequality-success")]))

(define (native-label program label)
  (match-define `(program ,policy ,_ ,body) program)
  (define redex (focus-term (decompose body)))
  (match label
    ["eval-disj" "expand-disjunction"]
    ["eval-conj" "expand-conjunction"]
    ["eval-fresh" "allocate-fresh"]
    ["eval-suspend" "suspend-goal"]
    ["eval-call" "expand-relcall"]
    ["eval-atom" (match redex [`(eval ,_ ,atom ,state) (atomic-label atom state)])]
    ["mplus-empty" (match redex [`(mplus ,_ ,_ ,_) "skip-left-failure"]
                                  [`(mplusR ,_ ,_ ,_) "skip-right-failure"])]
    ["mplus-yield"
     (match redex
       [`(mplus ,_ (Yield ,_ ,_ ,_) ,_) "reassociate-left-result"]
       [`(mplus ,_ (YieldR ,_ ,_ ,_) ,_) "reassociate-left-result/search-join"]
       [`(mplusR ,_ ,_ (Yield ,_ ,_ ,_)) "reassociate-right-result/left-nested"]
       [`(mplusR ,_ ,_ (YieldR ,_ ,_ ,_)) "reassociate-right-result/right-nested"])]
    ["mplus-delay"
     (match policy
       ['dfs "dfs-delay-left"]
       ['flip "flip-delay-left"]
       ['rail (match redex [`(mplus ,_ ,_ ,_) "rail-enter-right"]
                          [`(mplusR ,_ ,_ ,_) "rail-return-left"])])]
    ["bind-empty" "conj-fail"]
    ["bind-one" "conj-return"]
    ["bind-yield" "resume-left-choice-success"]
    ["bind-yield-right" "resume-right-choice-success"]
    ["bind-delay" "bubble-delay-through-conj"]
    ["commit-empty" "finish-failure"]
    ["commit-one" "finish-success"]
    ["commit-yield" "commit-choice-answer"]
    ["commit-yield-right" "commit-right-choice-answer"]
    ["advance-delay" "force-delay"]
    [_ (if (administrative? label) #f
           (raise-argument-error 'native-label "known derived-source label" label))]))

;; Public advance has a prescribed span, obtained from the existing prefix.
;; No matching-result search is involved: one invocation, one traversal per
;; Emit/Forced node, then exactly one advance-delay contraction.
(define (public-span program)
  (define started (advance program))
  (define (cross current remaining [states (list started)])
    (match-define (list label next) (step current))
    (cond
      [(zero? remaining)
       (unless (equal? label "advance-delay") (error 'public-span "expected Delay crossing"))
       (reverse (cons next states))]
      [else
       (unless (member label '("advance-emit" "advance-forced"))
         (error 'public-span "expected prefix traversal"))
       (cross next (sub1 remaining) (cons next states))]))
  (match-define `(program ,_ ,_ ,body) program)
  (cross started (spine-length body)))
