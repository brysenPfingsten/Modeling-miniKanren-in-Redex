#lang racket

(require redex/reduction-semantics
         "../labels-schema.rkt"
         "./language.rkt")

(provide label->redex-name/lean-mk
         redex-name->label/lean-mk)

(define mk-kernel-labels
  '((kernel succeed core)
    (kernel fail core)
    (kernel unify-success core)
    (kernel unify-violates-disequality core)
    (kernel unify-fail core)
    (kernel disequality-success core)
    (kernel disequality-fail core)))

(define (kernel-label->redex-name/lean-mk/host label)
  (and (member label mk-kernel-labels)
       (match label
         [`(kernel ,name core)
          (format "kernel:~a/core" name)])))

(define (redex-name->kernel-label/lean-mk/host name)
  (for/first ([label (in-list mk-kernel-labels)]
              #:when (equal?
                      name
                      (kernel-label->redex-name/lean-mk/host label)))
    label))

(define-lean-labels
  lean-mk-lang
  label->redex-name/lean-mk
  redex-name->label/lean-mk
  kernel-label->redex-name/lean-mk/host
  redex-name->kernel-label/lean-mk/host)
