#lang racket

(require rackunit
         rackunit/text-ui
         "./nodes/core-tests.rkt"
         "./nodes/delay-tests.rkt"
         "./nodes/disjunction-tests.rkt"
         "./nodes/search-tests.rkt"
         "./edges/core-delay-tests.rkt"
         "./edges/core-disjunction-tests.rkt"
         "./edges/delay-search-tests.rkt"
         "./edges/disjunction-search-tests.rkt"
         "./join/search-join-tests.rkt"
         "./grammar/frame-grammar-tests.rkt"
         "./fibers/dfs-fiber-tests.rkt"
         "./fibers/flip-fiber-tests.rkt"
         "./fibers/rail-fiber-tests.rkt"
         "./fibers/scheduler-progress-tests.rkt"
         "./overlays/relcall-overlay-tests.rkt"
         "./laws/determinism-tests.rkt"
         "./laws/wf-preservation-tests.rkt"
         "./laws/structural-allocation-tests.rkt"
         "./laws/frontier-observation-tests.rkt"
         "../../derivations/distributed-search/tests.rkt")

(provide SEARCH-LATTICE-SEMANTICS)

(define-test-suite SEARCH-LATTICE-SEMANTICS
  CORE-NODE-TESTS
  DELAY-NODE-TESTS
  DISJUNCTION-NODE-TESTS
  SEARCH-NODE-TESTS
  CORE-DELAY-EDGE
  CORE-DISJUNCTION-EDGE
  DELAY-SEARCH-EDGE
  DISJUNCTION-SEARCH-EDGE
  SEARCH-JOIN
  FRAME-GRAMMAR
  DFS-FIBER-TESTS
  FLIP-FIBER-TESTS
  RAIL-FIBER-TESTS
  SCHEDULER-PROGRESS
  RELCALL-OVERLAY-TESTS
  DETERMINISM-LAWS
  WF-PRESERVATION
  STRUCTURAL-ALLOCATION
  FRONTIER-OBSERVATIONS
  DISTRIBUTED-PRESENTATION)

(module+ test
  (run-tests SEARCH-LATTICE-SEMANTICS))
