#lang racket

(require redex/reduction-semantics
         "./shared-host.rkt")

(provide define-pk-control-operations)

;; Shared control operations are instantiated in each precise Redex language
;; because Redex language identifiers are compile-time bindings.  The marker
;; support scan, resume traversal, and freeze traversal are otherwise the same
;; equations for every kernel.
(define-syntax-rule
  (define-pk-control-operations
    language-id
    whole-marker-support-id
    control-resume-id
    control-freeze-id)
  (begin
    (define-metafunction language-id
      whole-marker-support-id : F -> intro
      [(whole-marker-support-id F)
       ,(logical-vars-in (term F))])

    (define-metafunction language-id
      control-resume-id : S g -> W
      [(control-resume-id (Returned kst) g)
       (Work g kst)]
      [(control-resume-id (WorkFresh intro S tag) g)
       (WorkFresh intro (control-resume-id S g) tag)])

    (define-metafunction language-id
      control-freeze-id : S -> A
      [(control-freeze-id (Returned kst))
       (Answer kst)]
      [(control-freeze-id (WorkFresh intro S tag))
       (AnswerFresh intro (control-freeze-id S) tag)])))
