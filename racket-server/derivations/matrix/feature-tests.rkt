#lang racket

(require rackunit redex/reduction-semantics
         "features.rkt" "../shared/feature-schema.rkt" "source-s.rkt" "source-e.rkt" "source-n.rkt"
         "../shared/maps.rkt" "../test-support/corpus.rkt")

(define (source-closure relation start [fuel 100000] [reversed '()])
  (match (apply-reduction-relation/tag-with-names relation start)
    ['() (values start (reverse reversed))]
    [(list (list label next))
     (when (zero? fuel) (error 'source-closure "fuel exhausted"))
     (source-closure relation next (sub1 fuel) (cons label reversed))]
    [results (error 'source-closure "nonunique source proof ~e" results)]))

(module+ test
  (define core '(succeed (label "core")))
  (define delayed `(suspend ,core (label "delay")))
  (define choice `(,core ∨ ,core (label "choice")))
  (define mixed `(,delayed ∨ ,core (label "search")))
  (test-case "each feature has its own recursive goal domain"
    (for ([g (in-list (list core delayed choice mixed))]
          [expected (in-list '((#t #t #t #t) (#f #t #f #t) (#f #f #t #t) (#f #f #f #t)))])
      (check-equal? (list (redex-match? StrictSCore g g) (redex-match? StrictSDelay g g)
                          (redex-match? StrictSDisjunction g g) (redex-match? StrictS g g)) expected)
      (check-equal? (list (redex-match? StrictECore g g) (redex-match? StrictEDelay g g)
                          (redex-match? StrictEDisjunction g g) (redex-match? StrictE g g)) expected)
      (check-equal? (list (redex-match? StrictNCore g g) (redex-match? StrictNDelay g g)
                          (redex-match? StrictNDisjunction g g) (redex-match? StrictN g g)) expected)))

  (test-case "literal rule ownership and Search/rail interaction"
    (for ([relations (in-list (list (list strict-s-core-red strict-e-core-red strict-n-core-red)
                                   (list strict-s-delay-red strict-e-delay-red strict-n-delay-red)
                                   (list strict-s-disjunction-red strict-e-disjunction-red strict-n-disjunction-red)
                                   (list strict-s-red strict-e-red strict-n-red)))]
          [expected (in-list (list (feature-labels core) (feature-labels delay)
                                  (feature-labels disjunction) (feature-labels search)))])
      (for ([relation (in-list relations)])
        (check-equal? (sort (map symbol->string (reduction-relation->rule-names relation)) string<?)
                      (sort expected string<?)))))

  (test-case "absent value and observation constructors are rejected"
    (define s-state '(state () () () (label "state")))
    (define e-state '(state (Support) () () () (label "state")))
    (define n-state '(state 0 () () () (label "state")))
    (check-false (s-core-value? `(Delay (Owners) (eval (Owners) ,core ,s-state))))
    (check-false (e-core-value? `(Delay (eval ,core ,e-state))))
    (check-false (n-core-value? `(Delay (eval ,core ,n-state))))
    (check-false (s-delay-value? `(Yield (Owners) (Answer (Owners) ,s-state) (Empty (Owners)))))
    (check-false (e-delay-value? `(Yield ,e-state (Empty (Support)))))
    (check-false (n-delay-value? `(Yield ,n-state (Empty 0))))
    (check-false (s-disjunction-observation? '(Forced (Owners) (Done (Owners)))))
    (check-false (e-disjunction-observation? '(Forced (Done (Support)))))
    (check-false (n-disjunction-observation? '(Forced (Done 0)))))

  (test-case "Search adds exactly the strict rail interaction to the child union"
    (define child-union
      (remove-duplicates (append (feature-labels delay) (feature-labels disjunction))))
    (check-equal? (filter (lambda (label) (not (member label child-union)))
                          (feature-labels search))
                  '("mplus-delay"))
    (check-equal? (sort (cons "mplus-delay" child-union) string<?)
                  (sort (feature-labels search) string<?)))

  (test-case "retired prefix computations and contexts are rejected in every feature"
    (define s '(prefix (Owners) (Empty (Owners))))
    (define e '(prefix (Empty (Support))))
    (define n '(prefix (Empty 0)))
    (check-equal? (list (redex-match? StrictSCore q s) (redex-match? StrictSDelay q s)
                        (redex-match? StrictSDisjunction q s) (redex-match? StrictS q s))
                  '(#f #f #f #f))
    (check-equal? (list (redex-match? StrictECore q e) (redex-match? StrictEDelay q e)
                        (redex-match? StrictEDisjunction q e) (redex-match? StrictE q e))
                  '(#f #f #f #f))
    (check-equal? (list (redex-match? StrictNCore q n) (redex-match? StrictNDelay q n)
                        (redex-match? StrictNDisjunction q n) (redex-match? StrictN q n))
                  '(#f #f #f #f))
    (check-false (redex-match? StrictSDelay E (term (prefix (Owners) hole))))
    (check-false (redex-match? StrictEDelay E (term (prefix hole))))
    (check-false (redex-match? StrictNDelay E (term (prefix hole))))
    (check-false (s-value? s))
    (check-false (e-value? e))
    (check-false (n-value? n))
    (check-false (redex-match? StrictS q '(prefix (Owners) (Done (Owners)))))
    (check-false (redex-match? StrictE q '(prefix (Done (Support)))))
    (check-false (redex-match? StrictN q '(prefix (Done 0)))))

  (for ([corpus (in-list (list core-corpus delay-corpus disjunction-corpus))]
        [s-relation (in-list (list strict-s-core-red strict-s-delay-red strict-s-disjunction-red))]
        [e-relation (in-list (list strict-e-core-red strict-e-delay-red strict-e-disjunction-red))]
        [n-relation (in-list (list strict-n-core-red strict-n-delay-red strict-n-disjunction-red))]
        [name (in-list '(core delay disjunction))])
    (for ([goal (in-list corpus)] [index (in-naturals)])
      (test-case (format "~a feature embedding and vertical square ~a" name index)
        (define s0 `(render ,(s-initial goal)))
        (define e0 (Q-SE s0))
        (define n0 (Q-SN s0))
        (define-values (s-out s-labels) (source-closure s-relation s0))
        (define-values (e-out e-labels) (source-closure e-relation e0))
        (define-values (n-out n-labels) (source-closure n-relation n0))
        (check-equal? (Q-SE s-out) e-out)
        (check-equal? (Q-SN s-out) n-out)
        (check-equal? s-labels e-labels)
        (check-equal? s-labels n-labels)
        (check-equal? s-out (s-run s0))
        (check-equal? e-out (e-run e0))
        (check-equal? n-out (n-run n0))
        (check-equal? s-labels (map first (s-trace s0)))))))
