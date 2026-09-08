#lang racket
(require "../source-e.rkt" "../../shared/kernel.rkt" "ownerless.rkt")
(define-ownerless-big e StrictBigE StrictE e-value? e-observation? atomic/e allocate/e search)
