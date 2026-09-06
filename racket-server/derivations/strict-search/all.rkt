#lang racket/base

;; Current retained-scope route plus the preserved comparison checkpoints:
;; native S/E/N feature matrices through Big and the diagnostic online comparison.
(require (submod "constructor-tests.rkt" test)
         "retained-scope/all.rkt"
         (submod "layout-tests.rkt" test)
         (submod "../functional-search/direct-interpreter.rkt" test)
         (submod "../functional-search/guarded-strictness-audit.rkt" test)
         (submod "functional-machine.rkt" test)
         (submod "tests.rkt" test)
         (submod "fusion-tests.rkt" test)
         (submod "downstream-tests.rkt" test)
         (submod "big-step-tests.rkt" test)
         (submod "register-tests.rkt" test)
         (submod "native-outcome-tests.rkt" test)
         (submod "matrix/tests.rkt" test)
         (submod "matrix/feature-tests.rkt" test)
         (submod "matrix/commit-source-tests.rkt" test)
         (submod "matrix/stages/tests.rkt" test)
         (submod "matrix/stages/domain-tests.rkt" test)
         (submod "matrix/stages/commit-tests.rkt" test)
         (submod "matrix/big/tests.rkt" test)
         (submod "matrix-property-tests.rkt" test)
         (submod "matrix-register-tests.rkt" test)
         (submod "denotational/tests.rkt" test)
         (submod "a7-a9/tests.rkt" test)
         "s-functional/all.rkt")
