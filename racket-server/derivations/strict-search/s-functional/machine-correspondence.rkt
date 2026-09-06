#lang racket

(require "03-data.rkt"
         (prefix-in f: "04-machine.rkt")
         (prefix-in a: "../shared/stages/schema.rkt")
         (only-in "../shared/kernel.rkt" owners-support)
         (only-in "correspondence.rkt"
                  reify-search reify-frontier reify-resumption reify-value
                  continuation-prefix))

(provide functional->M functional-step-label)

;; This map writes native M control and Frame/K fields directly. It never
;; reconstructs a whole machine readback, decomposes a tree, invokes a source
;; or machine transition, or runs a resumption. The shared structural leaf
;; maps expose only values/resumption bodies stored in individual fields.

(define (goal-of continue)
  (match continue [(GRight goal) goal]))

(define (check-inherited who inherited k)
  (define structural (continuation-prefix k))
  (unless (equal? inherited structural)
    (error who "captured ancestry ~e differs from continuation ancestry ~e"
           inherited structural)))

(define (frame kind before [after '()] [owners #f])
  (a:Frame kind before after owners))

;; Frames are outermost first while the translated continuation is assembled.
;; Every pending ownership operation remains an explicit prefix frame.
(define (attach control frames k)
  (match k
    [(KDone) (a:M control (foldl a:K 'halt frames))]
    [(KConj right owners _ rest)
     (attach control (cons (frame 'bind `(bind ,owners) (list right) owners) frames) rest)]
    [(KDisjLeft right state owners _ rest)
     (attach control
             (cons (frame 'merge-left `(mplus ,owners)
                          (list `(eval (Owners) ,right ,state)) owners) frames) rest)]
    [(KDisjRight left owners _ rest)
     (define here (owners-support owners (continuation-prefix rest)))
     (attach control
             (cons (frame 'merge-right `(mplus ,owners ,(reify-search left here))
                          '() owners) frames) rest)]
    [(KMergeYield owners answer rest)
     (attach control (cons (frame 'yield `(Yield ,owners ,answer) '() owners) frames) rest)]
    [(KBindHead tail continue common _ rest)
     (define here (owners-support common (continuation-prefix rest)))
     (attach control
             (cons (frame 'merge-left `(mplus ,common)
                          (list `(bind (Owners) ,(reify-search tail here) ,(goal-of continue)))
                          common) frames) rest)]
    [(KBindTail head common _ rest)
     (define here (owners-support common (continuation-prefix rest)))
     (attach control
             (cons (frame 'merge-right `(mplus ,common ,(reify-search head here))
                          '() common) frames) rest)]
    [(KMergeForced right here rest)
     (attach control
             (cons (frame 'merge-right `(mplus (Owners) ,(reify-search right here))
                          '() '(Owners)) frames) rest)]
    [(KBindForced continue _ rest)
     (attach control
             (cons (frame 'bind '(bind (Owners)) (list (goal-of continue)) '(Owners)) frames) rest)]
    [(KPrefix owners rest)
     (attach control (cons (frame 'prefix `(prefix ,owners) '() owners) frames) rest)]
    [(KCommit rest)
     (attach control (cons (frame 'commit '(commit)) frames) rest)]
    [(or (KCommitEmit owners answer rest)
         (KAdvanceEmit owners answer rest) (KCollectEmit owners answer rest))
     (attach control (cons (frame 'emit `(Emit ,owners ,answer) '() owners) frames) rest)]
    [(KCollectResume owners rest)
     (attach control
             (cons (frame 'forced `(Forced ,owners) '() owners)
                   (cons (frame 'collect '(collect)) frames)) rest)]
    [(or (KAdvanceForced owners rest) (KAdvanceHistory owners rest)
         (KCollectHistory owners rest) (KCollectForced owners rest))
     (attach control (cons (frame 'forced `(Forced ,owners) '() owners) frames) rest)]))

(define (with-continuation control k)
  (continuation-prefix k)
  (attach control '() k))

;; The audited semantic boundary of each functional transition. #f means
;; closure/handler dispatch or context reconstruction; a string requires that
;; exact single source contraction. This classification neither steps a
;; machine nor infers a label by searching for a matching future state.
(define (functional-step-label configuration)
  (match configuration
    [(f:Call 'eval/d (list goal _ _ _ _))
     (match goal
       [`(∃ ,_ ,_ ,_) "allocate-fresh"]
       [`(,_ ∧ ,_ ,_) "eval-conj"]
       [`(,_ ∨ ,_ ,_) "eval-disj"]
       [`(suspend ,_ ,_) "eval-suspend"]
       [_ "eval-atom"])]
    [(f:Call 'merge/d (list search _ _ _ _))
     (match search
       [`(Empty ,_) "mplus-empty"]
       [`(One ,_ ,_) "mplus-one"]
       [`(Yield ,_ ,_ ,_) "mplus-yield"]
       [`(Delay ,_ ,_) "mplus-delay"])]
    [(f:Call 'bind/d (list search _ _ _ _))
     (match search
       [`(Empty ,_) "bind-empty"]
       [`(One ,_ ,_) "bind-one"]
       [`(Yield ,_ ,_ ,_) "bind-yield"]
       [`(Delay ,_ ,_) "bind-delay"])]
    [(f:Call 'force/d _) "force-delay"]
    [(f:Call 'commit/d (list search _))
     (match search
       [`(Empty ,_) "commit-empty"]
       [`(One ,_ ,_) "commit-one"]
       [`(Yield ,_ ,_ ,_) "commit-yield"]
       [`(Delay ,_ ,_) "commit-delay"])]
    [(f:Call 'advance/d (list frontier _))
     (match frontier
       [`(Done ,_) "advance-done"]
       [`(Last ,_ ,_) "advance-last"]
       [`(Emit ,_ ,_ ,_) "advance-emit"]
       [`(Forced ,_ ,_) "advance-forced"]
       [`(More ,_) "advance-delay"])]
    [(f:Call 'collect/d (list frontier _))
     (match frontier
       [`(Done ,_) "collect-done"]
       [`(Last ,_ ,_) "collect-last"]
       [`(Emit ,_ ,_ ,_) "collect-emit"]
       [`(Forced ,_ ,_) "collect-forced"]
       [`(More ,_) "collect-delay"])]
    [(f:Call 'return/d (list _ (KPrefix _ _))) "prefix-value"]
    [(f:Call (or 'return/d 'continue/d 'resume/d 'outcome/d 'failure/d 'success/d) _) #f]
    [(f:Halted _) #f]
    [_ (raise-argument-error 'functional-step-label "functional machine configuration" configuration)]))

(define (functional->M configuration)
  (match configuration
    [(f:Halted value) (a:M (reify-frontier value) 'halt)]
    [(f:Call 'eval/d (list goal state owners inherited k))
     (check-inherited 'eval/d inherited k)
     (with-continuation `(eval ,owners ,goal ,state) k)]
    [(f:Call 'merge/d (list left right owners inherited k))
     (check-inherited 'merge/d inherited k)
     (define here (owners-support owners inherited))
     (with-continuation `(mplus ,owners ,(reify-search left here) ,(reify-search right here)) k)]
    [(f:Call 'bind/d (list search continue owners inherited k))
     (check-inherited 'bind/d inherited k)
     (with-continuation `(bind ,owners ,(reify-search search (owners-support owners inherited))
                               ,(goal-of continue)) k)]
    [(f:Call 'continue/d (list continue state owners inherited k))
     (check-inherited 'continue/d inherited k)
     (with-continuation `(eval ,owners ,(goal-of continue) ,state) k)]
    [(f:Call 'resume/d (list resume k))
     (with-continuation (reify-resumption resume (continuation-prefix k)) k)]
    [(f:Call 'force/d (list search k))
     (with-continuation `(force ,(reify-search search (continuation-prefix k))) k)]
    [(f:Call 'commit/d (list search k))
     (with-continuation `(commit ,(reify-search search (continuation-prefix k))) k)]
    [(f:Call 'advance/d (list frontier k))
     (with-continuation `(advance ,(reify-frontier frontier (continuation-prefix k))) k)]
    [(f:Call 'collect/d (list frontier k))
     (with-continuation `(collect ,(reify-frontier frontier (continuation-prefix k))) k)]
    [(f:Call 'return/d (list value k))
     (with-continuation (reify-value value (continuation-prefix k)) k)]
    [(f:Call 'outcome/d (list outcome (FEmpty owners k) (SOne owners* k*)))
     (unless (and (equal? owners owners*) (equal? k k*))
       (error 'functional->M "outcome handlers disagree"))
     (with-continuation
      (match outcome [(Failure) `(Empty ,owners)] [(Success state) `(One ,owners ,state)]) k)]
    [(f:Call 'failure/d (list (FEmpty owners k)))
     (with-continuation `(Empty ,owners) k)]
    [(f:Call 'success/d (list (SOne owners k) state))
     (with-continuation `(One ,owners ,state) k)]
    [_ (raise-argument-error 'functional->M "functional machine configuration" configuration)]))
