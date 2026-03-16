#lang racket

(require redex/reduction-semantics
         "./context-l1.rkt"
         "./core-common.rkt"
         "./context-pipeline.rkt")

(check-redundancy #t)

(provide L1
         L1/K
         core-cfg/l1)

(define core-redex/l1 (extend-core-redex L1))

(define-cfg/one-stage core-cfg/l1 core-redex/l1 L1/K K)
