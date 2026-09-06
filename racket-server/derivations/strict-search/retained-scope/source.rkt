#lang racket

(require redex/reduction-semantics
         (only-in "../shared/grammar-s.rkt" StrictS context-support/s)
         "../shared/kernel.rkt")

(provide ScopeS retained-red retained-contract
         retained-value? retained-frontier? retained-observation?
         retained-initial retained-query-initial retained-run retained-trace
         lift-owners erase-prefixes
         (rename-out [context-support/s retained-context-support]))

;; The checkpoint's strict Search/Frontier distinction is unchanged. This
;; variant has no pending prefix computation: internal force retains a
;; removed Delay's introductions on the root of its running computation.
(define-extended-language ScopeS StrictS
  [c SV (eval owners g σ) (mplus owners c c) (bind owners c g)
     (Yield owners A c) (force c)]
  [E hole (mplus owners E c) (mplus owners SV E)
     (bind owners E g) (Yield owners A E) (force E)])

;; Attach at the active root, passing only through the transparent force
;; wrapper. In particular this neither descends beneath Delay nor distributes
;; common introductions onto sibling subtrees. It is not a Frontier operation.
(define (lift-owners owners computation)
  (unless (redex-match? ScopeS c computation)
    (raise-argument-error 'lift-owners "retained-scope active computation" computation))
  (match computation
    [`(force ,inner) `(force ,(lift-owners owners inner))]
    [`(,constructor ,local ,rest ...)
     `(,constructor ,(owners-append owners local) ,@rest)]))

;; A structural bridge from the checkpoint, not an evaluator. Translating a
;; suspended body traverses its syntax without executing its computation.
;; Each checkpoint prefix-value step maps to identity; the other control
;; steps have the corresponding retained-source operation label.
(define (erase-prefixes computation)
  (match computation
    [`(prefix ,owners ,inner)
     (lift-owners owners (erase-prefixes inner))]
    [`(mplus ,owners ,left ,right)
     `(mplus ,owners ,(erase-prefixes left) ,(erase-prefixes right))]
    [`(bind ,owners ,inner ,goal)
     `(bind ,owners ,(erase-prefixes inner) ,goal)]
    [`(,(and constructor (or 'Yield 'Emit)) ,owners ,answer ,tail)
     `(,constructor ,owners ,answer ,(erase-prefixes tail))]
    [`(,(and constructor (or 'Delay 'Forced)) ,owners ,inner)
     `(,constructor ,owners ,(erase-prefixes inner))]
    [`(,(and constructor (or 'force 'render 'commit 'advance 'collect 'More)) ,inner)
     `(,constructor ,(erase-prefixes inner))]
    [`(eval ,_ ,_ ,_) computation]
    [`(,(or 'Empty 'Done) ,_) computation]
    [`(,(or 'One 'Last) ,_ ,_) computation]
    [_ (raise-argument-error 'erase-prefixes "strict S computation or Frontier" computation)]))

(define (atomic-search owners goal state)
  (match (atomic/s goal state)
    [(Failure) `(Empty ,owners)]
    [(Success next) `(One ,owners ,next)]))

;; These are the checkpoint's strict S control equations, with its value-only
;; prefix helper replaced by active root attachment. The sole changed source
;; contraction is force-delay; prefix-value has no counterpart here.
(define retained-control-raw
  (reduction-relation
   ScopeS #:domain q
   [--> (eval owners a σ)
        ,(atomic-search (term owners) (term a) (term σ)) eval-atom]
   [--> (eval owners (g_1 ∧ g_2 tag) σ)
        (bind owners (eval (Owners) g_1 σ) g_2) eval-conj]
   [--> (eval owners (g_1 ∨ g_2 tag) σ)
        (mplus owners (eval (Owners) g_1 σ) (eval (Owners) g_2 σ)) eval-disj]
   [--> (eval owners (suspend g tag) σ)
        (Delay owners (eval (Owners) g σ)) eval-suspend]
   [--> (mplus owners (Empty owners_1) SV)
        ,(lift-owners (term owners) (term SV)) mplus-empty]
   [--> (mplus owners (One owners_1 σ) SV)
        (Yield owners (Answer owners_1 σ) SV) mplus-one]
   [--> (mplus owners (Yield owners_1 (Answer owners_2 σ) SV_1) SV_2)
        (Yield owners
              (Answer ,(owners-append (term owners_1) (term owners_2)) σ)
              (mplus (Owners) ,(lift-owners (term owners_1) (term SV_1)) SV_2))
        mplus-yield]
   [--> (mplus owners (Delay owners_1 c) SV)
        (Delay owners (mplus (Owners) SV (force (Delay owners_1 c)))) mplus-delay]
   [--> (bind owners (Empty owners_1) g)
        (Empty ,(owners-append (term owners) (term owners_1))) bind-empty]
   [--> (bind owners (One owners_1 σ) g)
        (eval ,(owners-append (term owners) (term owners_1)) g σ) bind-one]
   [--> (bind owners (Yield owners_1 (Answer owners_2 σ) SV) g)
        (mplus ,(owners-append (term owners) (term owners_1))
               (eval owners_2 g σ) (bind (Owners) SV g)) bind-yield]
   [--> (bind owners (Delay owners_1 c) g)
        (Delay ,(owners-append (term owners) (term owners_1))
               (bind (Owners) c g)) bind-delay]
   [--> (force (Delay owners c)) ,(lift-owners (term owners) (term c)) force-delay]
   [--> (render (Empty owners)) (Done owners) render-empty]
   [--> (render (One owners σ)) (Last (Owners) (Answer owners σ)) render-one]
   [--> (render (Yield owners A SV)) (Emit owners A (render SV)) render-yield]
   [--> (render (Delay owners c)) (Forced owners (render c)) render-delay]
   [--> (commit (Empty owners)) (Done owners) commit-empty]
   [--> (commit (One owners σ)) (Last (Owners) (Answer owners σ)) commit-one]
   [--> (commit (Yield owners A SV)) (Emit owners A (commit SV)) commit-yield]
   [--> (commit (Delay owners c)) (More (Delay owners c)) commit-delay]
   [--> (advance (Done owners)) (Done owners) advance-done]
   [--> (advance (Last owners A)) (Last owners A) advance-last]
   [--> (advance (Emit owners A F)) (Emit owners A (advance F)) advance-emit]
   [--> (advance (Forced owners F)) (Forced owners (advance F)) advance-forced]
   [--> (advance (More (Delay owners c))) (Forced owners (commit c)) advance-delay]
   [--> (collect (Done owners)) (Done owners) collect-done]
   [--> (collect (Last owners A)) (Last owners A) collect-last]
   [--> (collect (Emit owners A F)) (Emit owners A (collect F)) collect-emit]
   [--> (collect (Forced owners F)) (Forced owners (collect F)) collect-forced]
   [--> (collect (More (Delay owners c)))
        (Forced owners (collect (commit c))) collect-delay]))

;; ScopeS contexts are a subset of the checkpoint's contexts. Its support
;; fold already reads exactly their ancestor Owner fields and never siblings.
(define retained-allocation-red
  (reduction-relation
   ScopeS #:domain q
   [--> (in-hole C (eval owners (∃ (x ...) g tag) σ))
        (in-hole C ,(allocate/s (term owners) (term (x ...)) (term g)
                               (term tag) (term σ) (context-support/s (term C))))
        allocate-fresh]))

(define retained-red
  (union-reduction-relations
   (context-closure retained-control-raw ScopeS C)
   retained-allocation-red))

(define (retained-raw [inherited '()])
  (extend-reduction-relation
   retained-control-raw ScopeS
   [--> (eval owners (∃ (x ...) g tag) σ)
        ,(allocate/s (term owners) (term (x ...)) (term g)
                     (term tag) (term σ) inherited)
        allocate-fresh]))

(define (retained-contract computation [inherited '()])
  (match (apply-reduction-relation/tag-with-names (retained-raw inherited) computation)
    ['() #f]
    [(list result) result]
    [results (error 'retained-contract "nonunique raw proof: ~e" results)]))

(define (retained-value? value) (redex-match? ScopeS SV value))
(define (retained-frontier? value) (redex-match? ScopeS F value))
(define (retained-observation? value) (redex-match? ScopeS O value))
(define (retained-initial goal #:owners [owners '(Owners)]
                          #:state [state '(state () () () (label "initial"))])
  `(eval ,owners ,goal ,state))
(define (retained-query-initial goal #:owners [owners '(Owners)]
                                #:state [state '(state () () () (label "initial"))])
  `(commit ,(retained-initial goal #:owners owners #:state state)))

(define (retained-trace computation [fuel 100000] [reversed '()])
  (unless (exact-nonnegative-integer? fuel)
    (raise-argument-error 'retained-trace "exact-nonnegative-integer?" fuel))
  (match (apply-reduction-relation/tag-with-names retained-red computation)
    ['()
     (unless (or (retained-value? computation) (retained-frontier? computation))
       (error 'retained-trace "stuck computation: ~e" computation))
     (reverse reversed)]
    [(list (and step (list _ next)))
     (when (zero? fuel) (error 'retained-trace "fuel exhausted"))
     (retained-trace next (sub1 fuel) (cons step reversed))]
    [results (error 'retained-trace "nonunique source proof: ~e" results)]))

(define (retained-run computation [fuel 100000])
  (unless (exact-nonnegative-integer? fuel)
    (raise-argument-error 'retained-run "exact-nonnegative-integer?" fuel))
  (cond
    [(or (retained-value? computation) (retained-frontier? computation)) computation]
    [else
     (when (zero? fuel) (error 'retained-run "fuel exhausted"))
     (match (apply-reduction-relation retained-red computation)
       [(list next) (retained-run next (sub1 fuel))]
       [results (error 'retained-run "stuck or nonunique source proof: ~e" results)])]))
