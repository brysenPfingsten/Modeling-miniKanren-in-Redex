#lang racket

(require redex
         redex/reduction-semantics
         rackunit)
(check-redundancy #t)

(require "../src/definitions.rkt"
         "../src/judgment-forms.rkt"
         "../src/reduction-relations/reduction-relations.rkt")

(module+ test
  (define two-relations-delay-body
    (term ((delay ())
           ((r:+ () (∃ () ⊤ (sym "oZ")))
            (r:X () (∃ () ⊤ (sym "HYvONcWjZNW")))))))

  (let ([pn (apply-reduction-relation/tag-with-names red two-relations-delay-body)])
    (test-true
     "Regression: decomposing relation env with no relcall should stay deterministic"
     (or (null? pn) (null? (cdr pn)))))

  (define relcall-body
    (term ((proceed ((r:N (nat 4) (sym "r-tag")) (state () 0 () (sym "s"))))
           ((r:N (x:w) (∃ () (∃ () ⊤ (nat 1)) (sym "f")))))))

  (let ([pn (apply-reduction-relation/tag-with-names red relcall-body)])
    (test-true
     "Proceed-body substitution path should remain deterministic"
     (or (null? pn) (null? (cdr pn))))))
