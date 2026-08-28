#lang racket

(require redex/reduction-semantics
         "./shared-host.rkt")

(provide define-lean-labels)

(define-syntax-rule
  (define-lean-labels
    language-id
    label->redex-name-id
    redex-name->label-id
    kernel-label->redex-name/host-id
    redex-name->kernel-label/host-id)
  (begin
    (define-metafunction language-id
      label->redex-name-id : ell -> string
      [(label->redex-name-id cell-ell)
       ,(cell-label->redex-name/host (term cell-ell))]
      [(label->redex-name-id kell)
       ,(kernel-label->redex-name/host-id (term kell))])

    (define-metafunction language-id
      redex-name->label-id : string -> ell
      [(redex-name->label-id string)
       ,(or (redex-name->cell-label/host (term string))
            (redex-name->kernel-label/host-id (term string)))])))
