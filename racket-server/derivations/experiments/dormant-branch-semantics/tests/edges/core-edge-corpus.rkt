#lang racket

(require redex/reduction-semantics
         (prefix-in core-lang:
                    "../../source/languages/core-lang.rkt")
         "./embedding-audit.rkt")

(provide CORE-GENERATED)

(define (generate-core-frontier)
  (generate-term core-lang:core-lang F GENERATED-TERM-DEPTH))

(define CORE-GENERATED
  (generated-corpus generate-core-frontier 2026081701))
