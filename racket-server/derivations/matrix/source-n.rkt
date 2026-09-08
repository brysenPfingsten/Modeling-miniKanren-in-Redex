#lang racket

(require "../shared/grammar-n.rkt"
         "../shared/kernel.rkt"
         "ownerless-source.rkt")

(define-ownerless-strict-control n StrictN atomic/n allocate/n 0)
