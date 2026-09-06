#lang racket

(require rackunit "../../shared/stages/schema.rkt" "instances.rkt"
         (prefix-in q: "../../shared/maps.rkt")
         (prefix-in s: "../source-s.rkt"))

(module+ test
  (for ([row (in-list (list (list SCore SDisjunction values)
                            (list ECore EDisjunction q:Q-SE)
                            (list NCore NDisjunction q:Q-SN)))])
    (match-define (list core disjunction map-source) row)
    (define value
      (map-source `(Delay (Owners) ,(s:s-initial '(succeed (label "later"))))))
    (for ([stage (in-list (list core disjunction))])
      ;; Even externally constructed terminal states cannot smuggle the full
      ;; Search value vocabulary into a lower feature coordinate.
      (check-exn exn:fail:contract? (lambda () (d-step stage (DFinal value))))
      (check-exn exn:fail:contract? (lambda () (d-trace stage (DFinal value))))
      (check-exn exn:fail:contract? (lambda () (z-step stage (Z value '()))))
      (check-exn exn:fail:contract? (lambda () (m-step stage (M value 'halt))))
      (check-exn exn:fail:contract? (lambda () (b-step stage (BFinal value))))
      (check-exn exn:fail:contract? (lambda () (b-trace stage (BFinal value))))
      ;; Prefix belongs to the same Delay extension as internal forcing;
      ;; its body alone is otherwise admitted by these lower coordinates.
      (define pending-prefix
        (map-source `(prefix (Owners) ,(s:s-initial '(succeed (label "body"))))))
      (check-exn exn:fail:contract? (lambda () (initial-M stage pending-prefix)))))

  ;; A strict machine retains the complete mature left answer chunk while
  ;; evaluating the right operand. Administrative compression retains that
  ;; merge frame in its own residual state.
  (define goal
    '(((succeed (label "left-A")) ∨ (succeed (label "left-B")) (label "left-choice"))
      ∨ (∃ (x:q) (x:q =? (sym "right") (label "right-use")) (label "right-fresh"))
      (label "outer-choice")))
  (define (retains-chunk? control continuation)
    (and (pair? control) (eq? (first control) 'eval)
         (match continuation
           [(K (Frame 'merge-right before '() _) _)
            (match (last before) [`(Yield ,_ ...) #t] [_ #f])]
           [_ #f])))
  (for ([row (in-list (list (list S values) (list E q:Q-SE) (list N q:Q-SN)))])
    (match-define (list stage map-source) row)
    (define computation (map-source `(render ,(s:s-initial goal))))
    (define m-start (initial-M stage computation))
    (check-not-false
     (for/or ([state (in-list (cons m-start (map second (m-trace stage m-start))))])
       (retains-chunk? (M-control state) (M-continuation state))))
    (define b-start (initial-B stage computation))
    (check-not-false
     (for/or ([state (in-list (cons b-start (map second (b-trace stage b-start))))])
       (match state
         [(BRun control continuation) (retains-chunk? control continuation)]
         [_ #f])))))
