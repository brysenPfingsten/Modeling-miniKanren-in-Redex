#lang racket

(require racket/match "../full-source.rkt" "../../shared/kernel.rkt"
         "../../shared/stages/schema.rkt" "../../shared/stages/views.rkt")
(provide SRel ERel NRel s-rel-status e-rel-status n-rel-status)

(define-S-view s-rel-view StrictSRel s-rel-value? s-rel-frontier?)
(define-ownerless-view e-rel-view StrictERel e-rel-value? e-rel-frontier?)
(define-ownerless-view n-rel-view StrictNRel n-rel-value? n-rel-frontier?)

(define (extend-support inherited owners)
  (if owners (owners-support owners inherited) inherited))
(define (preserve-support inherited _) inherited)

(define SRel (Stage 'Search+Relations/S s-rel-contract s-rel-view extend-support))
(define ERel (Stage 'Search+Relations/E e-rel-contract e-rel-view preserve-support))
(define NRel (Stage 'Search+Relations/N n-rel-contract n-rel-view preserve-support))

;; Status exposes the next syntactic phase without contracting it. In
;; particular it never replays a kernel operation, forces a Delay, expands a
;; call body, or invokes well-formedness's separate trail-replay validation.
(define (configuration-status stage frontier? observation? configuration)
  (with-handlers ([exn:fail? (lambda (_) 'stuck)])
    (match configuration
      [`(program ,_ ,_)
       (match (decompose stage configuration)
         [(DFinal value)
          (cond [(observation? value) 'complete]
                [(frontier? value) 'paused]
                [else 'stuck])]
         [(D control frames)
          (match control
            [`(force (Delay ,_ ...)) 'running]
            [`(force ,_) 'stuck]
            [(or `(eval ,_ (,(? relation-name? name) ,arguments ... ,_) ,_)
                 `(eval (,(? relation-name? name) ,arguments ... ,_) ,_))
             (match (assoc name (or (frame-environment frames) '()))
               [(list _ formals _) (if (= (length formals) (length arguments)) 'running 'stuck)]
               [#f 'stuck])]
            [_ 'running])])]
      [_ 'stuck])))

(define (s-rel-status configuration)
  (configuration-status SRel s-rel-frontier? s-rel-observation? configuration))
(define (e-rel-status configuration)
  (configuration-status ERel e-rel-frontier? e-rel-observation? configuration))
(define (n-rel-status configuration)
  (configuration-status NRel n-rel-frontier? n-rel-observation? configuration))
