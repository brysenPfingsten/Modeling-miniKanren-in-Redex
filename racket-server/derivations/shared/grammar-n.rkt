#lang racket

(require (only-in "core/n/language.rkt" core-n-oracle-lang)
         "ownerless-grammar.rkt")
(provide StrictN)

(define-ownerless-strict-language StrictN core-n-oracle-lang next)
