#lang racket

(require rackunit
         rackunit/text-ui
         redex/reduction-semantics
         "./s/source.rkt"
         "./s/wf.rkt"
         "./e/source.rkt"
         "./e/wf.rkt"
         "./n/source.rkt"
         "./n/wf.rkt"
         "./vertical.rkt")

(provide CORE-R-VERTICAL-TESTS)

(define sigma-empty
  (term (state () () () (label "state"))))

(define owners-empty (term (Owners)))
(define owners-u0
  (term (Owners (Owner (u:0) (label "u0")))))
(define owners-u1
  (term (Owners (Owner (u:1) (label "u1")))))

(define rule-representatives
  (list
   (list
    'expand-conjunction
    (term
     (More
      (Work
       ,owners-u0
       ((succeed (label "left"))
        ∧
        (u:0 =? u:0 (label "right"))
        (label "conjunction"))
       ,sigma-empty))))
   (list
    'succeed
    (term (More (Work ,owners-u0 (succeed (label "yes")) ,sigma-empty))))
   (list
    'fail
    (term (More (Work ,owners-u0 (fail (label "no")) ,sigma-empty))))
   (list
    'conj-return
    (term
     (More
      (Conj
       ,owners-u0
       (Returned ,owners-u1 ,sigma-empty)
       (u:0 =? u:0 (label "continue"))))))
   (list
    'conj-fail
    (term
     (More
      (Conj
       ,owners-u0
       (Dead ,owners-u1)
       (u:0 =? u:0 (label "inert-continuation"))))))
   (list
    'unify-success
    (term
     (More
      (Work
       ,owners-u0
       (u:0 =? (nat 0) (label "unify"))
       ,sigma-empty))))
   (list
    'unify-violates-disequality
    (term
     (More
      (Work
       ,owners-u0
       (u:0 =? (nat 0) (label "violates"))
       (state () ((u:0 (nat 0))) () (label "violates-state"))))))
   (list
    'unify-fail
    (term
     (More
      (Work
       ,owners-empty
       ((nat 0) =? (nat 1) (label "unify-fail"))
       ,sigma-empty))))
   (list
    'disequality-success
    (term
     (More
      (Work
       ,owners-u0
       (u:0 != (nat 0) (label "disequality-success"))
       ,sigma-empty))))
   (list
    'disequality-fail
    (term
     (More
      (Work
       ,owners-empty
       ((nat 0) != (nat 0) (label "disequality-fail"))
       ,sigma-empty))))
   (list
    'finish-success
    (term (More (Returned ,owners-u0 ,sigma-empty))))
   (list
    'finish-failure
    (term (More (Dead ,owners-u0))))
   (list
    'allocate-fresh
    (term
     (More
      (Conj
       ,owners-u0
       (Work
        (Owners (Owner (u:2) (label "u2")))
        (∃ (x:new)
           (x:new =? u:0 (label "body"))
           (label "allocate-u1"))
        ,sigma-empty)
       (u:0 != (nat 7) (label "future"))))))))

(define (wf-s? frontier)
  (judgment-holds (wf-core-oracle/s? ,frontier)))

(define (wf-e? frontier)
  (judgment-holds (wf-core-oracle/e? ,frontier)))

(define (wf-n? frontier)
  (judgment-holds (wf-core-oracle/n? ,frontier)))

(define (normalize-name name)
  (string->symbol (~a name)))

(define (only-successor relation source)
  (match (apply-reduction-relation/tag-with-names relation source)
    [(list (list name target)) (list (normalize-name name) target)]
    [results
     (error 'only-successor
            "expected one named successor for ~e, received ~e"
            source
            results)]))

(define sibling-left
  (term
   (More
    (Work
     ,owners-u0
     (∃ (x:left)
        (x:left =? u:0 (label "left-body"))
        (label "left-allocation"))
     ,sigma-empty))))

(define sibling-right
  (term
   (More
    (Work
     ,owners-u0
     (∃ (x:right)
        (x:right != u:0 (label "right-body"))
        (label "right-allocation"))
     ,sigma-empty))))

(define trace-source
  (term
   (More
    (Work
     (Owners)
     (∃ (x:q)
        ((x:q =? (sym "cat") (label "bind"))
         ∧
         (x:q != (sym "dog") (label "constrain"))
         (label "and"))
        (label "fresh"))
     ,sigma-empty))))

(define-test-suite CORE-R-VERTICAL-TESTS
  (test-case
   "Q_SE, Q_EN, and direct Q_SN close every core source rule"
   (for ([representative (in-list rule-representatives)])
     (match-define (list expected-name source) representative)
     (define e-source (Q-SE/F source))
     (define support (S-world-support source))
     (define n-source (Q-SN/F source))

     (check-true (wf-s? source) (format "S WF for ~a" expected-name))
     (check-true (wf-e? e-source) (format "E WF for ~a" expected-name))
     (check-true (wf-n? n-source) (format "N WF for ~a" expected-name))
     (check-equal? (Q-EN/F e-source support) n-source)
     (check-true (Q-SN-composition? source))
     (check-true (Q-SE-step-square/raw? source))
     (check-true (Q-EN-step-square/raw? e-source support))
     (check-true (Q-SN-step-square/raw? source))

     (match-define (list s-name s-target)
       (only-successor core-s-oracle-red source))
     (match-define (list e-name e-target)
       (only-successor core-e-oracle-red e-source))
     (match-define (list n-name n-target)
       (only-successor core-n-oracle-red n-source))
     (check-equal? s-name expected-name)
     (check-equal? e-name expected-name)
     (check-equal? n-name expected-name)
     (check-equal? (Q-SE/F s-target) e-target)
     (check-equal? (Q-SN/F s-target) n-target)
     (check-equal?
      (Q-EN/F e-target (S-world-support s-target))
      n-target)
     (check-true (wf-s? s-target))
     (check-true (wf-e? e-target))
     (check-true (wf-n? n-target))))

  (test-case
   "Q_EN uses support order rather than atom spelling"
   (define sparse-e
     (term
      (More
       (Work
        (u:7 =? u:2 (label "sparse"))
        (state
         (Support u:7 u:2)
         ()
         ()
         ()
         (label "sparse-state"))))))
   (check-equal?
    (Q-EN/F sparse-e)
    (term
     (More
      (Work
       (0 =? 1 (label "sparse"))
       (state 2 () () () (label "sparse-state"))))))
   (check-true (wf-e? sparse-e))
   (check-true (wf-n? (Q-EN/F sparse-e))))

  (test-case
   "sparse E fresh appends a name but N advances by support length"
   (define sparse-allocation
     (term
      (More
       (Work
        (∃ (x:new)
           (x:new =? u:7 (label "body"))
           (label "fresh"))
        (state
         (Support u:7 u:2)
         ()
         ()
         ()
         (label "sparse-state"))))))
   (check-true (wf-e? sparse-allocation))
   (check-true (Q-EN-step-square/raw? sparse-allocation))
   (match-define (list _ e-target)
     (only-successor core-e-oracle-red sparse-allocation))
   (match-define (list _ n-target)
     (only-successor core-n-oracle-red (Q-EN/F sparse-allocation)))
   (check-match
    e-target
    `(More
      (Work
       (u:0 =? u:7 (label "body"))
       (state (Support u:7 u:2 u:0) . ,_))))
   (check-match
    n-target
    `(More
      (Work
       (2 =? 0 (label "body"))
       (state 3 . ,_))))
   (check-equal? (Q-EN/F e-target) n-target))

  (test-case
   "the transient dead continuation uses theorem-side addressing only"
   (define dead-s
     (second (assoc 'conj-fail rule-representatives)))
   (define dead-e (Q-SE/F dead-s))
   (define support (S-world-support dead-s))
   (check-equal? support '(u:0 u:1))
   (check-exn exn:fail? (lambda () (Q-EN/F dead-e)))
   (check-exn exn:fail? (lambda () (Q-EN/F dead-e '(u:0 u:0))))
   (check-exn exn:fail? (lambda () (Q-EN/F dead-e '(u:1))))
   (check-equal? (Q-EN/F dead-e support) (Q-SN/F dead-s))
   (check-true (Q-EN-step-square/raw? dead-e support))
   ;; No Support, next, Owner, or Fresh syntax was added to either carrier.
   (check-false (member 'Support (flatten dead-e)))
   (check-false (member 'Owner (flatten dead-e))))

  (test-case
   "copied sibling worlds reuse one post-prefix allocation independently"
   (for ([source (in-list (list sibling-left sibling-right))])
     (define s-target
       (second (only-successor core-s-oracle-red source)))
     (define e-source (Q-SE/F source))
     (define e-target
       (second (only-successor core-e-oracle-red e-source)))
     (define n-source (Q-SN/F source))
     (define n-target
       (second (only-successor core-n-oracle-red n-source)))
     (check-equal? (S-world-support s-target) '(u:0 u:1))
     (check-match e-target
                  `(More (Work ,_ (state (Support u:0 u:1) . ,_))))
     (check-match n-target `(More (Work ,_ (state 2 . ,_))))
     (check-equal? (Q-SE/F s-target) e-target)
     (check-equal? (Q-SN/F s-target) n-target)))

  (test-case
   "a complete finite trace remains in exact three-row lockstep"
   (let trace ([s-source trace-source]
               [expected-labels
                '(allocate-fresh
                  expand-conjunction
                  unify-success
                  conj-return
                  disequality-success
                  finish-success)])
     (define e-source (Q-SE/F s-source))
     (define support (S-world-support s-source))
     (define n-source (Q-SN/F s-source))
     (check-true (Q-SN-composition? s-source))
     (check-true (Q-SE-step-square/raw? s-source))
     (check-true (Q-EN-step-square/raw? e-source support))
     (check-true (Q-SN-step-square/raw? s-source))
     (match expected-labels
       ['()
        (check-equal? (raw-successors/s s-source) '())
        (check-equal? (raw-successors/e e-source) '())
        (check-equal?
         (apply-reduction-relation/tag-with-names
          core-n-oracle-red
          n-source)
         '())]
       [(cons expected-label remaining)
        (match-define (list actual-label s-target)
          (only-successor core-s-oracle-red s-source))
        (check-equal? actual-label expected-label)
        (trace s-target remaining)]))))

(module+ test
  (run-tests CORE-R-VERTICAL-TESTS))
