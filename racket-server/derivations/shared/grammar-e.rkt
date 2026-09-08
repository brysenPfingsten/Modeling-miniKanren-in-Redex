#lang racket

(require (only-in "core/e/language.rkt" core-e-oracle-lang)
         "ownerless-grammar.rkt")
(provide StrictE)

(define-ownerless-strict-language StrictE core-e-oracle-lang support)
