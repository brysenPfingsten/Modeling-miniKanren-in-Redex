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
         Q-SN/focus-composition/generated?
         Q-SE/root-focus/generated
         Q-EN/root-focus/generated
         Q-SN/root-focus/generated
         Q-SN/root-focus-composition/generated?
         Q-SE/failure-focus/generated
         Q-EN/failure-focus/generated
         Q-SN/failure-focus/generated
         Q-SN/failure-focus-composition/generated?
         Q-SE/terminal/generated
         Q-EN/terminal/generated
         Q-SN/terminal/generated
         Q-SN/terminal-composition/generated?)

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

;; Root-frontier focus is separate from work focus so independently expanded
;; Redex languages rebuild their own opaque root hole instead of sharing one
;; row's hole object.
(define (Q-SE/root-focus/generated frontier spine)
  (q-root-focus-rebuild/generated/e
   (q-root-focus-export/generated/s frontier spine)))

(define (Q-EN/root-focus/generated frontier spine)
  (q-root-focus-rebuild/generated/n
   (q-root-focus-export/generated/e frontier spine)))

(define (Q-SN/root-focus/generated frontier spine)
  (q-root-focus-rebuild/generated/n
   (q-root-focus-export/generated/s frontier spine)))

(define (Q-SN/root-focus-composition/generated? frontier spine)
  (match-define (list e-frontier e-spine)
    (Q-SE/root-focus/generated frontier spine))
  (equal?
   (Q-SN/root-focus/generated frontier spine)
   (Q-EN/root-focus/generated e-frontier e-spine)))

;; A compressed failure carries the summary rather than a materialized Dead
;; node.  Map that summary jointly with its possible-world focus; do not invent
;; a Dead wrapper merely to reuse the ordinary focused-work hook.
(define (Q-SE/failure-focus/generated summary focus)
  (q-failure-focus-rebuild/generated/e
   (q-failure-focus-export/generated/s summary focus)))

(define (Q-EN/failure-focus/generated summary focus)
  (q-failure-focus-rebuild/generated/n
   (q-failure-focus-export/generated/e summary focus)))

(define (Q-SN/failure-focus/generated summary focus)
  (q-failure-focus-rebuild/generated/n
   (q-failure-focus-export/generated/s summary focus)))

(define (Q-SN/failure-focus-composition/generated? summary focus)
  (match-define (list e-summary e-focus)
    (Q-SE/failure-focus/generated summary focus))
  (equal?
   (Q-SN/failure-focus/generated summary focus)
   (Q-EN/failure-focus/generated e-summary e-focus)))

;; Final carriers use the representation's terminal view directly.  This is
;; distinct from applying the whole-frontier Q map to a terminal by accident.
(define (Q-SE/terminal/generated terminal)
  (q-terminal-rebuild/generated/e
   (q-terminal-export/generated/s terminal)))

(define (Q-EN/terminal/generated terminal)
  (q-terminal-rebuild/generated/n
   (q-terminal-export/generated/e terminal)))

(define (Q-SN/terminal/generated terminal)
  (q-terminal-rebuild/generated/n
   (q-terminal-export/generated/s terminal)))

(define (Q-SN/terminal-composition/generated? terminal)
  (equal?
   (Q-SN/terminal/generated terminal)
   (Q-EN/terminal/generated (Q-SE/terminal/generated terminal))))
