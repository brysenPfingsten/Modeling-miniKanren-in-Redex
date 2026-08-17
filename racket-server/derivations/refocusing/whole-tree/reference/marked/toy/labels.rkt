#lang racket

(require redex/reduction-semantics
         "../labels-schema.rkt"
         "./language.rkt")

(provide label->redex-name/toy
         redex-name->label/toy
         label->legacy/toy
         legacy->label/toy)

(define toy-kernel-labels
  '((kernel work-succeed core)
    (kernel work-fail core)
    (kernel work-put core)))

(define (kernel-label->redex-name/toy/host label)
  (and (member label toy-kernel-labels)
       (match label
         [`(kernel ,name core)
          (format "~a/core" name)])))

(define (redex-name->kernel-label/toy/host name)
  (for/first ([label (in-list toy-kernel-labels)]
              #:when (equal?
                      name
                      (kernel-label->redex-name/toy/host label)))
    label))

(define-pk-labels
  pk-toy-lang
  label->redex-name/toy
  redex-name->label/toy
  kernel-label->redex-name/toy/host
  redex-name->kernel-label/toy/host)

;; Explicit bridge to the committed 28-label toy oracle.  It is intentionally
;; not hidden in the generic label schema.
(define-metafunction pk-toy-lang
  label->legacy/toy : ell -> any
  [(label->legacy/toy cell-ell) cell-ell]
  [(label->legacy/toy (kernel work-succeed core))
   (work-succeed core)]
  [(label->legacy/toy (kernel work-fail core))
   (work-fail core)]
  [(label->legacy/toy (kernel work-put core))
   (work-put core)])

(define-metafunction pk-toy-lang
  legacy->label/toy : any -> ell
  [(legacy->label/toy cell-ell) cell-ell]
  [(legacy->label/toy (work-succeed core))
   (kernel work-succeed core)]
  [(legacy->label/toy (work-fail core))
   (kernel work-fail core)]
  [(legacy->label/toy (work-put core))
   (kernel work-put core)])
