#lang racket

;; Earlier dormant-branch research, separate from the GUI's strict runtime.
(require (submod "functional-tests.rkt" test)
         (submod "functional-source-tests.rkt" test)
         (submod "source-tests.rkt" test)
         (submod "orientation-tests.rkt" test)
         (submod "barriers-tests.rkt" test))
