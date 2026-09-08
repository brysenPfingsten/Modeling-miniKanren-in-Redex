#lang racket

;; Alternative semantics and their evidence. The current derivation gate does
;; not import this module; the broad application gate runs both accounts.
(require rackunit/text-ui
         "dormant-branch-semantics/all.rkt"
         "early-conjunction-distribution/tests.rkt"
         (submod "architecture-tests.rkt" test))

;; Import the suite itself: its standalone test entry point exits the process.
(define failures (run-tests DISTRIBUTED-PRESENTATION))
(unless (zero? failures)
  (error 'DISTRIBUTED-PRESENTATION "~a test case(s) failed" failures))
