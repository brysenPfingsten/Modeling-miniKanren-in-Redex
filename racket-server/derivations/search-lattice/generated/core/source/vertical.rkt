#lang racket

(require "../../../framework/core-source-schema.rkt"
         "./s.rkt"
         "./e.rkt"
         "./n.rkt")

(provide Q-SE/generated
         Q-EN/generated
         Q-SN/generated
         Q-SN-composition/generated?
         Q-SE/focus/generated
         Q-EN/focus/generated
         Q-SN/focus/generated
         Q-SN/focus-composition/generated?)

;; These maps are emitted from the three selected strategy descriptors.  The
;; direct S-to-N map consumes S's neutral export and N's rebuild hook; it does
;; not call either adjacent map or route through E.
(define-generated-core-representation-maps
  #:s-strategy core-s-representation-strategy
  #:e-strategy core-e-representation-strategy
  #:n-strategy core-n-representation-strategy
  #:Q-SE Q-SE/generated
  #:Q-EN Q-EN/generated
  #:Q-SN Q-SN/generated
  #:composition Q-SN-composition/generated?)

;; Stage carriers separate the focused work from its WorkFocus.  Their maps
;; therefore consume both pieces together so a representation can recover the
;; one possible world's complete supply before rebuilding either piece.  The
;; direct S-to-N map does not route through E.
(define (Q-SE/focus/generated focused focus)
  (q-focus-rebuild/generated/e
   (q-focus-export/generated/s focused focus)))

(define (Q-EN/focus/generated focused focus)
  (q-focus-rebuild/generated/n
   (q-focus-export/generated/e focused focus)))

(define (Q-SN/focus/generated focused focus)
  (q-focus-rebuild/generated/n
   (q-focus-export/generated/s focused focus)))

(define (Q-SN/focus-composition/generated? focused focus)
  (match-define (list e-focused e-focus)
    (Q-SE/focus/generated focused focus))
  (equal?
   (Q-SN/focus/generated focused focus)
   (Q-EN/focus/generated e-focused e-focus)))
