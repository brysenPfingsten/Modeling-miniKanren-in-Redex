#lang racket/base

;; Native retained-scope S/E/N source, feature, derivation, and Big checks,
;; including the selected functional machine's native transition squares.
(require (submod "tests.rkt" test)
         (submod "feature-tests.rkt" test)
         (submod "commit-source-tests.rkt" test)
         (submod "property-tests.rkt" test)
         (submod "work-tests.rkt" test)
         (submod "s-reference-tests.rkt" test)
         (submod "full-tests.rkt" test)
         (submod "scheduler-tests.rkt" test)
         (submod "stages/tests.rkt" test)
         (submod "stages/domain-tests.rkt" test)
         (submod "stages/commit-tests.rkt" test)
         (submod "big/tests.rkt" test)
         (submod "big/full-tests.rkt" test))
