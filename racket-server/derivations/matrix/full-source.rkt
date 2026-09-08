#lang racket

(require redex/reduction-semantics
         "../shared/relation-grammar.rkt" "../shared/kernel.rkt"
         (only-in "../shared/grammar-s.rkt" context-support/s)
         (prefix-in s: "source-s.rkt")
         (prefix-in e: "source-e.rkt")
         (prefix-in n: "source-n.rkt"))

(provide StrictSRel StrictERel StrictNRel
         strict-s-rel-red strict-e-rel-red strict-n-rel-red
         s-rel-contract e-rel-contract n-rel-contract
         s-rel-value? e-rel-value? n-rel-value?
         s-rel-frontier? e-rel-frontier? n-rel-frontier?
         s-rel-observation? e-rel-observation? n-rel-observation?
         s-rel-query-initial e-rel-query-initial n-rel-query-initial
         s-rel-run e-rel-run n-rel-run)

;; Extend the maintained equations into the larger goal domain. Calls are
;; separate named contractions; the relation environment remains in program
;; syntax while base operations execute under the same strict contexts.
(define s-rel-control (extend-reduction-relation s:s-control-raw StrictSRel))
(define e-rel-control (extend-reduction-relation e:e-raw StrictERel))
(define n-rel-control (extend-reduction-relation n:n-raw StrictNRel))

(define (s-rel-raw inherited definitions)
  (extend-reduction-relation
   s-rel-control StrictSRel
   [--> (eval owners (∃ (x ...) g tag) σ)
        ,(allocate/s (term owners) (term (x ...)) (term g) (term tag) (term σ) inherited)
        allocate-fresh]
   [--> (eval owners call σ)
        (eval owners g σ)
        (where g ,(instantiate-relation definitions (term call))) eval-call]))

(define (e-rel-raw definitions)
  (extend-reduction-relation
   e-rel-control StrictERel
   [--> (eval call σ) (eval g σ)
        (where g ,(instantiate-relation definitions (term call))) eval-call]))

(define (n-rel-raw definitions)
  (extend-reduction-relation
   n-rel-control StrictNRel
   [--> (eval call σ) (eval g σ)
        (where g ,(instantiate-relation definitions (term call))) eval-call]))

(define strict-s-rel-red
  (union-reduction-relations
   (context-closure s-rel-control StrictSRel C)
   (reduction-relation
    StrictSRel #:domain q
    [--> (in-hole C (eval owners (∃ (x ...) g tag) σ))
         (in-hole C ,(allocate/s (term owners) (term (x ...)) (term g) (term tag)
                                 (term σ) (context-support/s (term C)))) allocate-fresh]
    [--> (program Γ (in-hole C (eval owners call σ)))
         (program Γ (in-hole C (eval owners g σ)))
         (where g ,(instantiate-relation (term Γ) (term call))) eval-call])))

(define strict-e-rel-red
  (union-reduction-relations
   (context-closure e-rel-control StrictERel C)
   (reduction-relation
    StrictERel #:domain q
    [--> (program Γ (in-hole C (eval call σ)))
         (program Γ (in-hole C (eval g σ)))
         (where g ,(instantiate-relation (term Γ) (term call))) eval-call])))

(define strict-n-rel-red
  (union-reduction-relations
   (context-closure n-rel-control StrictNRel C)
   (reduction-relation
    StrictNRel #:domain q
    [--> (program Γ (in-hole C (eval call σ)))
         (program Γ (in-hole C (eval g σ)))
         (where g ,(instantiate-relation (term Γ) (term call))) eval-call])))

(define (contract relation computation)
  (match (apply-reduction-relation/tag-with-names relation computation)
    ['() #f]
    [(list edge) edge]
    [edges (error 'full-contract "nonunique source proof: ~e" edges)]))

(define (s-rel-contract computation [inherited '()] [definitions '()])
  (contract (s-rel-raw inherited definitions) computation))
(define (e-rel-contract computation [inherited '()] [definitions '()])
  (contract (e-rel-raw definitions) computation))
(define (n-rel-contract computation [inherited '()] [definitions '()])
  (contract (n-rel-raw definitions) computation))

(define-syntax-rule (define-predicates value? frontier? observation? language)
  (begin
    (define (value? value)
      (match value
        [`(program ,_ ,body) (redex-match? language SV body)]
        [_ (redex-match? language SV value)]))
    (define (frontier? value)
      (match value
        [`(program ,_ ,body) (redex-match? language F body)]
        [_ (redex-match? language F value)]))
    (define (observation? value)
      (match value
        [`(program ,_ ,body) (redex-match? language O body)]
        [_ (redex-match? language O value)]))))

(define-predicates s-rel-value? s-rel-frontier? s-rel-observation? StrictSRel)
(define-predicates e-rel-value? e-rel-frontier? e-rel-observation? StrictERel)
(define-predicates n-rel-value? n-rel-frontier? n-rel-observation? StrictNRel)

(define (s-rel-query-initial goal #:relations [definitions '()]
                             #:owners [owners '(Owners)]
                             #:state [state '(state () () () (label "initial"))])
  `(program ,definitions (commit (eval ,owners ,goal ,state))))
(define (e-rel-query-initial goal #:relations [definitions '()]
                             #:state [state '(state (Support) () () () (label "initial"))])
  `(program ,definitions (commit (eval ,goal ,state))))
(define (n-rel-query-initial goal #:relations [definitions '()]
                             #:state [state '(state 0 () () () (label "initial"))])
  `(program ,definitions (commit (eval ,goal ,state))))

(define (run relation value? frontier? current fuel)
  (cond
    [(or (value? current) (frontier? current)) current]
    [(zero? fuel) (error 'full-run "full source fuel exhausted")]
    [else
     (match (apply-reduction-relation relation current)
       [(list next) (run relation value? frontier? next (sub1 fuel))]
       [edges (error 'full-run "stuck or nonunique source proof: ~e" edges)])]))

(define (s-rel-run current [fuel 100000])
  (run strict-s-rel-red s-rel-value? s-rel-frontier? current fuel))
(define (e-rel-run current [fuel 100000])
  (run strict-e-rel-red e-rel-value? e-rel-frontier? current fuel))
(define (n-rel-run current [fuel 100000])
  (run strict-n-rel-red n-rel-value? n-rel-frontier? current fuel))
