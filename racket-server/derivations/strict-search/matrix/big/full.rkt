#lang racket

(require redex/reduction-semantics
         "../full-source.rkt" "../../shared/kernel.rkt"
         "s-schema.rkt" "ownerless.rkt"
         (for-syntax racket/base racket/syntax syntax/parse))

;; The existing equations receive an explicit relation environment at every
;; recursive premise and fixed-point call. Call-free instances keep their
;; original signatures; no transition evaluator or dynamic environment is used.
(define-s-big s-rel StrictBigSRel StrictSRel s-rel-value? s-rel-observation?
  full #:relations Γ)
(define-ownerless-big e-rel StrictBigERel StrictERel e-rel-value? e-rel-observation?
  atomic/e allocate/e full #:relations Γ)
(define-ownerless-big n-rel StrictBigNRel StrictNRel n-rel-value? n-rel-observation?
  atomic/n allocate/n full #:relations Γ)

;; Keep Γ around the complete result, including a paused More(Delay(...)).
;; The wrapper adds no source label and exposes its actual recursive premise
;; in the finite proof. S begins with empty inherited allocation ancestry.
(define-syntax (define-program-boundary stx)
  (syntax-parse stx
    [(_ row:id language:id search:id observe:id promote:id (ancestry ...))
     #:with program-big (format-id #'row "program-big/~a-rel" #'row)
     #:with evaluate-full (format-id #'row "evaluate-full/~a" #'row)
     #:with promote-full (format-id #'row "promote-full/~a" #'row)
     #:with raw-full (format-id #'row "raw-derivations-full/~a" #'row)
     #'(begin
         (provide program-big evaluate-full promote-full raw-full)
         (define-judgment-form language
           #:mode (program-big I O O)
           #:contract (program-big p p trace)
           [(search Γ ancestry ... c SV trace)
            ----------------------------------------------- "program search"
            (program-big (program Γ c) (program Γ SV) trace)]
           [(observe Γ ancestry ... o F trace)
            ----------------------------------------------- "program observation"
            (program-big (program Γ o) (program Γ F) trace)])
         (define (evaluate-full computation)
           (match (judgment-holds (program-big ,computation p trace) (p trace))
             [(list result) result]
             [other (error 'evaluate-full "nonunique or missing finite full Big derivation: ~e" other)]))
         (define (promote-full computation)
           (unless (redex-match? language p computation)
             (raise-argument-error 'promote-full "full program" computation))
           (match-define `(program ,definitions ,body) computation)
           `(program ,definitions ,(promote definitions body)))
         (define (raw-full computation)
           (build-derivations (program-big ,computation any_value any_trace))))]))

(define-program-boundary s StrictBigSRel search-big/s-rel observe-big/s-rel promote/s-rel (()))
(define-program-boundary e StrictBigERel search-big/e-rel observe-big/e-rel promote/e-rel ())
(define-program-boundary n StrictBigNRel search-big/n-rel observe-big/n-rel promote/n-rel ())
