#lang racket

(require redex/reduction-semantics
         "./context-l2.rkt"
         "./core-common.rkt"
         "./context-pipeline.rkt")

(check-redundancy #t)

(provide L2
         L2/K
         core-cfg/l2)

(define core-redex/l2 (extend-core-redex L2))

(define-cfg/two-stage core-cfg/l2 core-redex/l2 L2/K Kcore Kleft)
