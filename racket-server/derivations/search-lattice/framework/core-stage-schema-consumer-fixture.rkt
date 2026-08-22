#lang racket

(require redex/reduction-semantics
         "./core-stage-schema-source-fixture.rkt"
         "./core-stage-schema.rkt"
         (only-in "./stage-generators.rkt"
                  define-decomposition-stage))

(provide foreign-core/D
         foreign-core-D-lang
         foreign-core-decompose
         foreign-core-contract
         foreign-core-step
         foreign-interface-Q
         foreign-interface-focus-roundtrip)

;; Adversarial same-spelled bindings in the consumer must not capture the
;; source module's private Redex metafunctions retained by the interface.
(define (allocate/private-fixture . _arguments)
  (error 'consumer-capture "captured private allocation helper"))
(define (advance/private-fixture . _arguments)
  (error 'consumer-capture "captured private supply helper"))

(define-syntax-rule
  (define-interface-probes
    #:language _language
    #:Q-export Q-export
    #:Q-rebuild Q-rebuild
    #:Q-focus-export Q-focus-export
    #:Q-focus-rebuild Q-focus-rebuild
    whole-probe
    focus-probe)
  (begin
    (define (whole-probe frontier)
      (Q-rebuild (Q-export frontier)))
    (define (focus-probe focused focus)
      (Q-focus-rebuild (Q-focus-export focused focus)))))

;; The visitor is the Q-side protocol retained by the source interface.  Its
;; hook references stay bound to the private source module definitions.
(foreign-core-source
 #:visit define-interface-probes
 foreign-interface-Q
 foreign-interface-focus-roundtrip)

(define-generated-core-stage-instance
  #:source-interface foreign-core-source
  #:instance foreign-core/staged)

(define-decomposition-stage foreign-core/D
  #:from foreign-core/staged
  #:language foreign-core-D-lang
  #:plug-D foreign-core-plug-D
  #:plug-C foreign-core-plug-C
  #:contract-label foreign-core-contract-label
  #:decompose foreign-core-decompose
  #:contract foreign-core-contract
  #:step foreign-core-step)
