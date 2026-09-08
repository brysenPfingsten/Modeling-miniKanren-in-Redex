#lang racket

;; Earlier dormant-branch research, separate from the GUI's strict runtime.
(require (submod "tests/all.rkt" test)
         (submod "tests/functional-tests.rkt" test)
         (submod "tests/functional-source-tests.rkt" test)
         (submod "tests/source-tests.rkt" test)
         (submod "tests/orientation-tests.rkt" test)
         (submod "tests/barriers-tests.rkt" test)
         (submod "tests/picture-tests.rkt" test)
         (submod "tests/strict-policy-tests.rkt" test)
         (submod "tests/redex-fresh-scope-witness.rkt" test))
