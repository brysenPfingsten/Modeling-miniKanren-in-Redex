#lang racket

(require rackunit
         "../test-support/generated-goals.rkt"
         redex/reduction-semantics
         (prefix-in s: "source-s.rkt")
         (prefix-in e: "source-e.rkt")
         (prefix-in n: "source-n.rkt")
         (prefix-in q: "../shared/maps.rkt")
         (prefix-in wf: "../shared/wf.rkt"))

(define (check-source-path configuration [remaining 10000])
  (define mapped-e (q:Q-SE configuration))
  (define mapped-n (q:Q-SN configuration))
  (check-true (wf:wf-s? configuration))
  (check-true (wf:wf-e? mapped-e))
  (check-true (wf:wf-n? mapped-n))
  (check-equal? (q:Q-EN mapped-e) mapped-n)
  (define successors
    (apply-reduction-relation/tag-with-names s:strict-s-red configuration))
  (define e-successors
    (apply-reduction-relation/tag-with-names e:strict-e-red mapped-e))
  (define n-successors
    (apply-reduction-relation/tag-with-names n:strict-n-red mapped-n))
  (check-equal?
   e-successors
   (for/list ([edge (in-list successors)])
     (match-define (list label next) edge)
     (list label (q:Q-SE next))))
  (check-equal?
   n-successors
   (for/list ([edge (in-list successors)])
     (match-define (list label next) edge)
     (list label (q:Q-SN next))))
  (match successors
    ['()
     (check-true (s:s-observation? configuration))
     configuration]
    [(list (list _ next))
     (when (zero? remaining) (error 'check-source-path "generated trace budget exhausted"))
     (check-source-path next (sub1 remaining))]
    [_ (fail-check "multiple raw source derivations")]))

(module+ test
  (for* ([goal (in-list generated-goals)]
         [sparse? (in-list '(#f #t))])
    (test-case (format "generated strict representation trace (~a): ~s" sparse? goal)
      (define owners
        (if sparse?
            '(Owners (Owner (u:2) (label "ancestor"))
                     (Owner () (label "empty-ancestor"))
                     (Owner (u:0 u:8) (label "shared")))
            '(Owners)))
      (define state
        (if sparse?
            '(state ((u:8 u:2)) ((u:2 (sym "avoid")))
                    ((u:8 =? u:2 (label "seed-alias"))) (label "initial"))
            '(state () () () (label "initial"))))
      (define initial (s:s-initial goal #:owners owners #:state state))
      (void (check-source-path `(render ,initial))))))
