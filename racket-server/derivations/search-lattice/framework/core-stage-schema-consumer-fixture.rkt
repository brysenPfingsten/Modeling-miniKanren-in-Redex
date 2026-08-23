#lang racket

(require redex/reduction-semantics
         "./core-stage-schema-source-fixture.rkt"
         "./core-stage-schema.rkt"
         (submod "./core-stage-schema.rkt" test-support))

(provide foreign-core/D
         foreign-core/row
         foreign-core/identity-row
         foreign-core-D-lang
         foreign-core-decompose
         foreign-core-contract
         foreign-core-step
         foreign-core-refocus-phase
         foreign-core-Z-step/direct
         foreign-core-machineize
         foreign-core-M-step/direct
         foreign-core-compress
         foreign-core-B-step/direct
         foreign-core-promote
         foreign-core-D-square?
         foreign-core-Z-square?
         foreign-core-M-square?
         foreign-core-B-square?
         foreign-core-Big-square?
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
    #:Q-root-focus-export _Q-root-focus-export
    #:Q-root-focus-rebuild _Q-root-focus-rebuild
    #:Q-failure-focus-export _Q-failure-focus-export
    #:Q-failure-focus-rebuild _Q-failure-focus-rebuild
    #:Q-terminal-export _Q-terminal-export
    #:Q-terminal-rebuild _Q-terminal-rebuild
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

(define-selected-decomposition-stage foreign-core/D
  #:from foreign-core/staged
  #:language foreign-core-D-lang
  #:plug-D foreign-core-plug-D
  #:plug-C foreign-core-plug-C
  #:contract-label foreign-core-contract-label
  #:decompose foreign-core-decompose
  #:contract foreign-core-contract
  #:step foreign-core-step)

(define-selected-compression-policy foreign-core-policy
  #:settled-producers
  (succeed unify-success disequality-success)
  #:dead-producers
  (fail unify-violates-disequality unify-fail disequality-fail)
  #:settled-followers
  (conj-return finish-success)
  #:dead-followers
  (conj-fail finish-failure)
  #:singletons
  (expand-conjunction allocate-fresh
   conj-return conj-fail finish-success finish-failure)
  #:retained-observation rule-labels
  #:maximum-span 2)

(define-selected-refocused-stage foreign-core/Z
  #:from foreign-core/D
  #:language foreign-core-Z-lang
  #:refocus-phase foreign-core-refocus-phase
  #:D->Z foreign-core-D->Z
  #:Z->D foreign-core-Z->D
  #:readback foreign-core-readback-Z
  #:refocus-spec foreign-core-refocus/spec
  #:refocus-work-direct foreign-core-refocus-work/direct
  #:refocus-direct foreign-core-refocus/direct
  #:step-spec foreign-core-Z-step/spec
  #:step-direct foreign-core-Z-step/direct)

(define-selected-machine-isomorphism-stage foreign-core/M
  #:from foreign-core/Z
  #:language foreign-core-M-lang
  #:machineize foreign-core-machineize
  #:encode-ZM foreign-core-encode-ZM
  #:decode-MZ foreign-core-decode-MZ
  #:D->M foreign-core-D->M
  #:M->D foreign-core-M->D
  #:readback foreign-core-readback-M
  #:refocus-work-direct foreign-core-machine-refocus-work/direct
  #:refocus-direct foreign-core-machine-refocus/direct
  #:step-direct foreign-core-M-step/direct
  #:corresponds foreign-core-ZM-corresponds
  #:step-spec foreign-core-M-step/spec
  #:square foreign-core-ZM-step-square)

(define-selected-compressed-stage foreign-core/B
  #:from foreign-core/M
  #:policy foreign-core-policy
  #:language foreign-core-B-lang
  #:compress foreign-core-compress
  #:encode-MB foreign-core-encode-MB
  #:decode-BM foreign-core-decode-BM
  #:readback foreign-core-readback-B
  #:span-labels foreign-core-span-labels
  #:produce-settled foreign-core-produce-settled/direct
  #:produce-dead foreign-core-produce-dead/direct
  #:advance-settled foreign-core-advance-settled/direct
  #:advance-dead foreign-core-advance-dead/direct
  #:step-direct foreign-core-B-step/direct
  #:corresponds foreign-core-MB-corresponds
  #:replay foreign-core-replay/M
  #:step-spec foreign-core-B-step/spec
  #:square foreign-core-MB-step-square)

(define-selected-fixed-point-stage foreign-core/Big
  #:from foreign-core/B
  #:language foreign-core-Big-lang
  #:readback foreign-core-readback-Big
  #:dispatch foreign-core-big-dispatch/direct
  #:run foreign-core-big-run/direct
  #:settled foreign-core-big-settled/direct
  #:dead foreign-core-big-dead/direct
  #:final foreign-core-big-final/direct
  #:evaluate foreign-core-big-evaluate/direct
  #:spec-language foreign-core-Big-spec-lang
  #:initialize foreign-core-initialize-B/spec
  #:close foreign-core-close-B/spec
  #:flatten foreign-core-flatten-BTrace
  #:promote foreign-core-promote
  #:evaluate-spec foreign-core-big-evaluate/spec
  #:unfold-square foreign-core-B-Big-unfold-square
  #:closure-square foreign-core-B-Big-closure-square
  #:root-square foreign-core-B-Big-root-square)

;; Identity is the smallest post-generation StageExtension and proves that
;; application consumes the already-generated coordinate bindings.
(define-syntax-rule
  (define-foreign-staged-row
    #:language source-language
    #:Q-export _Q-export
    #:Q-rebuild _Q-rebuild
    #:Q-focus-export _Q-focus-export
    #:Q-focus-rebuild _Q-focus-rebuild
    #:Q-root-focus-export _Q-root-focus-export
    #:Q-root-focus-rebuild _Q-root-focus-rebuild
    #:Q-failure-focus-export _Q-failure-focus-export
    #:Q-failure-focus-rebuild _Q-failure-focus-rebuild
    #:Q-terminal-export _Q-terminal-export
    #:Q-terminal-rebuild _Q-terminal-rebuild
    row)
  (define-selected-staged-row row
    #:source-language source-language
    #:D foreign-core/D
    #:Z foreign-core/Z
    #:M foreign-core/M
    #:B foreign-core/B
    #:Big foreign-core/Big))

(foreign-core-source
 #:visit define-foreign-staged-row
 foreign-core/row)

(define-selected-stage-extension foreign-core/identity-extension
  #:identity
  #:feature-singletons ())

(apply-selected-stage-extension foreign-core/identity-row
  #:extension foreign-core/identity-extension
  #:base foreign-core/row)

(assert-selected-staged-row-metadata
 foreign-core/identity-row
 #:same-as foreign-core/row)

(define (foreign-Q-R value) value)
(define (foreign-Q-focus payload context) (list payload context))
(define (foreign-Q-root-focus payload context) (list payload context))
(define (foreign-Q-failure-focus payload context) (list payload context))
(define (foreign-Q-terminal terminal) terminal)

(define-decomposition-representation-map
  #:source foreign-core/D
  #:target foreign-core/D
  #:Q-R foreign-Q-R
  #:Q-focus foreign-Q-focus
  #:Q-root-focus foreign-Q-root-focus
  #:Q-terminal foreign-Q-terminal
  #:Q-D foreign-Q-D
  #:commutes foreign-core-D-square?)

(define-refocused-representation-map
  #:source foreign-core/Z
  #:target foreign-core/Z
  #:Q-D foreign-Q-D
  #:Q-focus foreign-Q-focus
  #:Q-root-focus foreign-Q-root-focus
  #:Q-terminal foreign-Q-terminal
  #:Q-Z foreign-Q-Z
  #:commutes foreign-core-Z-square?)

(define-machine-representation-map
  #:source foreign-core/M
  #:target foreign-core/M
  #:Q-Z foreign-Q-Z
  #:Q-focus foreign-Q-focus
  #:Q-root-focus foreign-Q-root-focus
  #:Q-terminal foreign-Q-terminal
  #:Q-M foreign-Q-M
  #:commutes foreign-core-M-square?)

(define-compressed-representation-map
  #:source foreign-core/B
  #:target foreign-core/B
  #:Q-M foreign-Q-M
  #:Q-focus foreign-Q-focus
  #:Q-failure-focus foreign-Q-failure-focus
  #:Q-terminal foreign-Q-terminal
  #:Q-B foreign-Q-B
  #:commutes foreign-core-B-square?)

(define-fixed-point-representation-map
  #:source foreign-core/Big
  #:target foreign-core/Big
  #:Q-B foreign-Q-B
  #:Q-terminal foreign-Q-terminal
  #:Q-Big foreign-Q-Big
  #:commutes foreign-core-Big-square?)
