#lang racket/base
;; Includes active-Search/settled-Frontier separation, exact incremental
;; boundaries, primitive outcome defunctionalization, and data-only machines.
(require (submod "source-tests.rkt" test)
         (submod "incremental-tests.rkt" test)
         (submod "anf-tests.rkt" test)
         (submod "cps-tests.rkt" test)
         (submod "defunc-tests.rkt" test)
         (submod "strictness-tests.rkt" test)
         (submod "machine-tests.rkt" test)
         (submod "allocation-tests.rkt" test)
         (submod "coverage-tests.rkt" test)
         (submod "predecessor-machine-tests.rkt" test)
         (submod "transition-tests.rkt" test)
         (submod "machine-correspondence-tests.rkt" test))
