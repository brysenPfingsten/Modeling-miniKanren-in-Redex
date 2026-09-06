#lang racket

(require redex/reduction-semantics
         "../test-support/frontiers.rkt"
         (only-in "../shared/kernel.rkt" owners-append)
         (prefix-in s: "../matrix/source-s.rkt"))

(provide search->partial partial-shape oracle-initial oracle-resume-once oracle-collect-all)

;; This oracle retains the independent reduction semantics' raw computation
;; under Delay. It never inspects a functional implementation's resumption.
;; The independent oracle's Empty/One/Yield are committed only AFTER it reaches
;; mature Search. The resulting frontier's unary More holds unfinished Delay
;; work. No independent source rule or scheduler is changed by this test-only
;; structural readback.
(define (search->partial search)
  (match search
    [`(Empty ,owners) `(Done ,owners)]
    [`(One ,owners ,state) `(Last (Owners) (Answer ,owners ,state))]
    [`(Yield ,owners ,answer ,rest)
     `(Emit ,owners ,answer ,(search->partial rest))]
    [`(Delay ,owners ,body) `(More (Delay ,owners ,body))]))

;; A common comparison shape hides only the raw body, functional closure, or
;; defunctionalized resumption at an actual suspended tip. Every existing
;; observation constructor, Owner, Answer, and complete State remains exact.
(define (partial-shape frontier)
  (match frontier
    [`(Done ,owners) `(Done ,owners)]
    [`(Last ,owners ,answer) `(Last ,owners ,answer)]
    [`(Emit ,owners ,answer ,rest)
     `(Emit ,owners ,answer ,(partial-shape rest))]
    [`(Forced ,owners ,rest) `(Forced ,owners ,(partial-shape rest))]
    [`(More (Delay ,owners ,_)) `(More (Delay ,owners pending))]
    [_ (raise-argument-error 'partial-shape "partial S frontier" frontier)]))

(define atomic-focus
  (term-match/single s:StrictS
    [(in-hole C (eval owners a σ)) (list (term a) (term σ))]))

;; Put the computation inside a genuine source observation context so fresh
;; allocation sees the complete inherited Owner ancestry. Stop BEFORE render
;; processes the mature Search: s-run on this wrapper would instead collect
;; every later suspension. The Forced wrapper is oracle context only and is
;; removed on return; it neither contributes an observed event nor an answer.
(define (mature-in-context computation ancestry)
  (reduce-to-chunk `(Forced ,ancestry (render ,computation))))

(define (reduce-to-chunk current [fuel 100000] [reversed-work '()])
  (match current
    [`(Forced ,_ (render ,(? s:s-value? search)))
     (values search (reverse reversed-work))]
    [_
     (when (zero? fuel) (error 'partial-oracle "chunk exhausted source fuel"))
     (match (apply-reduction-relation/tag-with-names s:strict-s-red current)
       [(list (list label next))
        (reduce-to-chunk
         next (sub1 fuel)
         (if (equal? label "eval-atom")
             (cons (atomic-focus current) reversed-work)
             reversed-work))]
       [other (error 'partial-oracle "stuck or nonunique source step: ~e" other)])]))

(define (oracle-initial goal #:owners [owners '(Owners)]
                        #:state [state '(state () () () (label "initial"))])
  (define-values (search work)
    (mature-in-context `(eval ,owners ,goal ,state) '(Owners)))
  (values (search->partial search) work))

;; Descend through the already completed prefix and cross its first exposed
;; Delay exactly once. Answer-local Owners never become residual ancestry.
;; Internal forces performed while evaluating body remain ordinary strict
;; source work, and do not manufacture additional exposed Forced markers.
(define (oracle-resume-once frontier [ancestry '(Owners)])
  (match frontier
    [`(,(or 'Done 'Last) ,_ ,_ ...) (values frontier '())]
    [`(Emit ,owners ,answer ,rest)
     (define-values (next work)
       (oracle-resume-once rest (owners-append ancestry owners)))
     (values `(Emit ,owners ,answer ,next) work)]
    [`(Forced ,owners ,rest)
     (define-values (next work)
       (oracle-resume-once rest (owners-append ancestry owners)))
     (values `(Forced ,owners ,next) work)]
    [`(More (Delay ,owners ,body))
     (define-values (search work)
       (mature-in-context body (owners-append ancestry owners)))
     (values `(Forced ,owners ,(search->partial search)) work)]))

(define (oracle-collect-all frontier [reversed-work '()])
  (if (pending? frontier)
      (let-values ([(next work) (oracle-resume-once frontier)])
        (oracle-collect-all next (append (reverse work) reversed-work)))
      (values frontier (reverse reversed-work))))
