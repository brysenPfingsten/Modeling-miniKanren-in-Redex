#lang racket

(require rackunit
         rackunit/text-ui
         "./decomposition-tests.rkt"
         "./source-tests.rkt")

(define reference-Q-tests
  (test-suite
   "marked-to-lean reference Q"
   reference-Q-source-tests
   reference-Q-decomposition-tests))

(exit (if (zero? (run-tests reference-Q-tests)) 0 1))
