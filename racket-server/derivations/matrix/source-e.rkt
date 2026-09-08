#lang racket

(require "../shared/grammar-e.rkt"
         "../shared/kernel.rkt"
         "ownerless-source.rkt")

(define-ownerless-strict-control e StrictE atomic/e allocate/e '(Support))
