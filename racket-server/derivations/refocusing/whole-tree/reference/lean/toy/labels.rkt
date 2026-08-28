#lang racket

(require redex/reduction-semantics
         "../labels-schema.rkt"
         "./language.rkt")

(provide label->redex-name/lean-toy
         redex-name->label/lean-toy)

(define toy-kernel-labels
  '((kernel work-succeed core)
    (kernel work-fail core)
    (kernel work-put core)))

(define (kernel-label->redex-name/lean-toy/host label)
  (and (member label toy-kernel-labels)
       (match label
         [`(kernel ,name core)
          (format "~a/core" name)])))

(define (redex-name->kernel-label/lean-toy/host name)
  (for/first ([label (in-list toy-kernel-labels)]
              #:when (equal?
                      name
                      (kernel-label->redex-name/lean-toy/host label)))
    label))

(define-lean-labels
  lean-toy-lang
  label->redex-name/lean-toy
  redex-name->label/lean-toy
  kernel-label->redex-name/lean-toy/host
  redex-name->kernel-label/lean-toy/host)
