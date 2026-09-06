#lang racket/base

;; Native explicit-prefix S/E/N source, feature, derivation, and Big checks.
;; These coordinates have not yet adopted the selected retained-scope account.
(require (submod "tests.rkt" test)
         (submod "feature-tests.rkt" test)
         (submod "commit-source-tests.rkt" test)
         (submod "property-tests.rkt" test)
         (submod "work-tests.rkt" test)
         (submod "stages/tests.rkt" test)
         (submod "stages/domain-tests.rkt" test)
         (submod "stages/commit-tests.rkt" test)
         (submod "big/tests.rkt" test))
