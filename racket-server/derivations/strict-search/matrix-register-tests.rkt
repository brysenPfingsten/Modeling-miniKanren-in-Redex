#lang racket

(require rackunit
         (prefix-in direct: "../functional-search/direct-interpreter.rkt")
         (prefix-in register: "register-machine.rkt")
         (prefix-in source: "matrix/source-n.rkt")
         (prefix-in wf: "shared/wf.rkt")
         (prefix-in oracle: "matrix/interpreter-oracle.rkt")
         (prefix-in stage: "shared/stages/schema.rkt")
         (prefix-in instance: "matrix/stages/instances.rkt")
         "test-support/corpus.rkt"
         "test-support/generated-goals.rkt")

;; Connect the native numeric matrix to the independently derived register
;; machine. The test-only interpreter adapter supplies the same first-order
;; kernel and lexical binder interpretation. The matrix never runs this
;; adapter as its implementation. In addition to completed frontiers, compare
;; the order and exact input states of all atomic kernel calls.
(define (native-result/events computation [events '()] [fuel 10000])
  (match computation
    [(stage:DFinal value) (values value (reverse events))]
    [(stage:D redex _)
     (when (zero? fuel) (error 'native-result/events "test budget exhausted"))
     (match-define (list label next) (stage:d-step instance:N computation))
     (define next-events
       (match label
         ["eval-atom"
          (match-define `(eval ,goal ,state) redex)
          (cons (list (last goal) (oracle:state->direct state)) events)]
         [_ events]))
     (native-result/events next next-events (sub1 fuel))]))

(define (direct-atomic-tag goal)
  (match goal
    [(direct:Succeed tag) tag]
    [(direct:FailGoal tag) tag]
    [(direct:Atom _ tag) tag]))

(module+ test
  (for* ([goal (in-list (append search-corpus generated-goals))]
         [state (in-list
                 '((state 0 () () () (label "initial"))
                   (state 3 ((2 0)) ((0 (sym "avoid")))
                          ((2 =? 0 (label "seed-alias"))) (label "initial"))))])
    (test-case (format "numeric matrix/register work order and frontier: ~s ~s" goal state)
      (check-true (wf:wf-n? (source:n-initial goal #:state state)))
      (define-values (native-result native-events)
        (native-result/events
         (stage:decompose instance:N `(render ,(source:n-initial goal #:state state)))))
      (define register-events '())
      (define (observed-kernel atomic incoming)
        (set! register-events
              (cons (list (direct-atomic-tag atomic) incoming) register-events))
        (direct:basic-kernel atomic incoming))
      (define result
        (register:run (oracle:goal->direct goal)
                      #:state (oracle:state->direct state)
                      #:kernel observed-kernel))
      (check-equal? result (oracle:observation->direct native-result))
      (check-equal? (reverse register-events) native-events))))
