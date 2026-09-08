#lang racket

(require redex/reduction-semantics
         (prefix-in base: "source-s.rkt")
         (prefix-in full: "full-source.rkt")
         "../shared/relation-grammar.rkt"
         "../shared/kernel.rkt"
         (only-in "../shared/grammar-s.rkt" context-support/s)
         (only-in "../shared/wf.rkt" wf-s-rel?)
         (only-in "stages/full.rkt" s-rel-status))

(provide StrictRail
         strict-dfs-red strict-rail-red
         (rename-out [full:strict-s-rel-red strict-flip-red])
         erase-orientation erase-rule
         scheduler-value? scheduler-in-domain? scheduler-well-formed?
         scheduler-status)

;; Railroad changes the stored orientation, not operand strictness. In a
;; right-oriented merge the right operand is the first logical argument:
;; mature it, then mature the left, then apply the right-oriented merge rule.
;; YieldR's residual is eager too. No context enters Delay or Frontier More.
(define-extended-language StrictRail StrictSRel
  [SV .... (YieldR owners SV A)]
  [c .... (mplusR owners c c) (YieldR owners c A)]
  [E .... (mplusR owners c E) (mplusR owners E SV) (YieldR owners E A)])

;; An inspection/representation map, never an execution adapter. It preserves
;; owners and source/state data literally, and forgets only saved orientation.
(define (erase-orientation term)
  (match term
    [`(program ,definitions ,body) `(program ,definitions ,(erase-orientation body))]
    [`(mplusR ,owners ,left ,right)
     `(mplus ,owners ,(erase-orientation right) ,(erase-orientation left))]
    [`(YieldR ,owners ,tail ,answer) `(Yield ,owners ,answer ,(erase-orientation tail))]
    [`(mplus ,owners ,left ,right)
     `(mplus ,owners ,(erase-orientation left) ,(erase-orientation right))]
    [`(bind ,owners ,body ,goal) `(bind ,owners ,(erase-orientation body) ,goal)]
    [`(,(and constructor (or 'Yield 'Emit)) ,owners ,answer ,tail)
     `(,constructor ,owners ,answer ,(erase-orientation tail))]
    [`(,(and constructor (or 'Delay 'Forced)) ,owners ,body)
     `(,constructor ,owners ,(erase-orientation body))]
    [`(,(and constructor (or 'force 'render 'commit 'advance 'collect 'More)) ,body)
     `(,constructor ,(erase-orientation body))]
    [_ term]))

(define (erase-rule name)
  (match name
    [(or "mplus-yield/right-nested" "mplus-right-yield" "mplus-right-yield/right-nested") "mplus-yield"]
    ["mplus-right-empty" "mplus-empty"]
    ["mplus-right-one" "mplus-one"]
    ["mplus-right-delay" "mplus-delay"]
    ["bind-yield-right" "bind-yield"]
    ["commit-yield-right" "commit-yield"]
    ["render-yield-right" "render-yield"]
    [_ name]))

(define (lift-owners owners computation)
  (match computation
    [`(force ,body) `(force ,(lift-owners owners body))]
    [`(,constructor ,local ,fields ...) `(,constructor ,(owners-append owners local) ,@fields)]))

(define dfs-control
  (extend-reduction-relation
   base:s-control-raw StrictSRel
   [--> (mplus owners (Delay owners_1 c) SV)
        (Delay owners (mplus (Owners) (force (Delay owners_1 c)) SV)) mplus-delay]))

(define rail-control
  (extend-reduction-relation
   base:s-control-raw StrictRail
   ;; Override the owner-attachment cases so the extended syntax stays native.
   [--> (mplus owners (Empty owners_1) SV)
        ,(lift-owners (term owners) (term SV)) mplus-empty]
   [--> (force (Delay owners c)) ,(lift-owners (term owners) (term c)) force-delay]
   [--> (mplus owners (Yield owners_1 (Answer owners_2 σ) SV_1) SV_2)
        (Yield owners (Answer ,(owners-append (term owners_1) (term owners_2)) σ)
               (mplus (Owners) ,(lift-owners (term owners_1) (term SV_1)) SV_2)) mplus-yield]
   [--> (mplus owners (YieldR owners_1 SV_1 (Answer owners_2 σ)) SV_2)
        (Yield owners (Answer ,(owners-append (term owners_1) (term owners_2)) σ)
               (mplus (Owners) ,(lift-owners (term owners_1) (term SV_1)) SV_2)) mplus-yield/right-nested]
   [--> (mplus owners (Delay owners_1 c) SV)
        (Delay owners (mplusR (Owners) (force (Delay owners_1 c)) SV)) mplus-delay]
   [--> (mplusR owners SV (Empty owners_1))
        ,(lift-owners (term owners) (term SV)) mplus-right-empty]
   [--> (mplusR owners SV (One owners_1 σ))
        (YieldR owners SV (Answer owners_1 σ)) mplus-right-one]
   [--> (mplusR owners SV_1 (Yield owners_1 (Answer owners_2 σ) SV_2))
        (YieldR owners (mplusR (Owners) SV_1 ,(lift-owners (term owners_1) (term SV_2)))
                (Answer ,(owners-append (term owners_1) (term owners_2)) σ)) mplus-right-yield]
   [--> (mplusR owners SV_1 (YieldR owners_1 SV_2 (Answer owners_2 σ)))
        (YieldR owners (mplusR (Owners) SV_1 ,(lift-owners (term owners_1) (term SV_2)))
                (Answer ,(owners-append (term owners_1) (term owners_2)) σ)) mplus-right-yield/right-nested]
   [--> (mplusR owners SV (Delay owners_1 c))
        (Delay owners (mplus (Owners) SV (force (Delay owners_1 c)))) mplus-right-delay]
   [--> (bind owners (YieldR owners_1 SV (Answer owners_2 σ)) g)
        (mplusR ,(owners-append (term owners) (term owners_1))
                (bind (Owners) SV g) (eval owners_2 g σ)) bind-yield-right]
   [--> (commit (YieldR owners SV A)) (Emit owners A (commit SV)) commit-yield-right]
   [--> (render (YieldR owners SV A)) (Emit owners A (render SV)) render-yield-right]))

(define-syntax-rule (define-scheduler-source name language control)
  (define name
    (union-reduction-relations
     (context-closure control language C)
     (reduction-relation
      language #:domain q
      [--> (in-hole C (eval owners (∃ (x (... ...)) g tag) σ))
           (in-hole C ,(allocate/s (term owners) (term (x (... ...))) (term g) (term tag)
                                   (term σ) (context-support/s (erase-orientation (term C)))))
           allocate-fresh]
      [--> (program Γ (in-hole C (eval owners call σ)))
           (program Γ (in-hole C (eval owners g σ)))
           (where g ,(instantiate-relation (term Γ) (term call))) eval-call]))))

(define-scheduler-source strict-dfs-red StrictSRel dfs-control)
(define-scheduler-source strict-rail-red StrictRail rail-control)

(define (scheduler-value? value) (redex-match? StrictRail SV value))
(define (scheduler-in-domain? policy configuration)
  (match policy
    ["rail" (redex-match? StrictRail p configuration)]
    [(or "dfs" "flip") (redex-match? StrictSRel p configuration)]))
(define (scheduler-well-formed? configuration)
  (wf-s-rel? (erase-orientation configuration)))
(define (scheduler-status configuration)
  (s-rel-status (erase-orientation configuration)))
