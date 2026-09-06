#lang racket

(require "semantics.rkt" (only-in "bridge.rkt" denote reify-frontier) "observe.rkt"
         (prefix-in d: "../../functional-search/direct-interpreter.rkt"))

(module+ main
  (define (put value)
    (atom (lambda (state) (success-outcome (struct-copy d:State state [tag value])))
          value))
  (define events '())
  (define (work tag)
    (atom (lambda (state)
            (set! events (append events (list tag)))
            (success-outcome (struct-copy d:State state [tag tag])))
          tag))
  (define example
    (disj (disj (put 'A) (put 'B)) (conj (work 'p) (work 'q))))
  (define result (run-search example))
  (printf "Work already performed before inspecting Search: ~s\n" events)
  (printf "Mature Search: ~s\n" (snapshot result #:state d:State-tag))
  (printf "Exact readback: ~s\n" (d:frontier-shape (reify-frontier (render result))))
  (printf "Nested rail: ~s\n"
          (d:frontier-shape (reify-frontier (run (denote d:nested-rail-witness)))))
  (define answers (fix-goal (lambda (self) (disj (put 'A) (suspend self)))))
  (printf "Productive recursive Search, three Delay bodies inspected: ~s\n"
          (snapshot (run-search answers) #:delays 3 #:state d:State-tag)))
