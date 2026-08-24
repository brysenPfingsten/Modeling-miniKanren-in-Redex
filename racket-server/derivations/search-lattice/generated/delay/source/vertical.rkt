#lang racket

(require "s.rkt"
         "e.rkt"
         "n.rkt")

(provide Q-SE/R/delay
         Q-EN/R/delay
         Q-SN/R/delay
         Q-SN/R-composition/delay?
         Q-SE/focus/delay
         Q-EN/focus/delay
         Q-SN/focus/delay
         Q-SN/focus-composition/delay?
         Q-SE/root-focus/delay
         Q-EN/root-focus/delay
         Q-SN/root-focus/delay
         Q-SN/root-focus-composition/delay?
         Q-SE/failure-focus/delay
         Q-EN/failure-focus/delay
         Q-SN/failure-focus/delay
         Q-SN/failure-focus-composition/delay?
         Q-SE/terminal/delay
         Q-EN/terminal/delay
         Q-SN/terminal/delay
         Q-SN/terminal-composition/delay?)

;; These maps cross representations only through the joint neutral views
;; exported by the two Delay sources.  The direct S-to-N maps never route
;; through E; composition is checked separately.
(define (Q-SE/R/delay frontier)
  (q-rebuild/generated/delay/e
   (q-export/generated/delay/s frontier)))

(define (Q-EN/R/delay frontier)
  (q-rebuild/generated/delay/n
   (q-export/generated/delay/e frontier)))

(define (Q-SN/R/delay frontier)
  (q-rebuild/generated/delay/n
   (q-export/generated/delay/s frontier)))

(define (Q-SN/R-composition/delay? frontier)
  (equal? (Q-SN/R/delay frontier)
          (Q-EN/R/delay (Q-SE/R/delay frontier))))

(define (Q-SE/focus/delay focused focus)
  (q-focus-rebuild/generated/delay/e
   (q-focus-export/generated/delay/s focused focus)))

(define (Q-EN/focus/delay focused focus)
  (q-focus-rebuild/generated/delay/n
   (q-focus-export/generated/delay/e focused focus)))

(define (Q-SN/focus/delay focused focus)
  (q-focus-rebuild/generated/delay/n
   (q-focus-export/generated/delay/s focused focus)))

(define (Q-SN/focus-composition/delay? focused focus)
  (match-define (list e-focused e-focus)
    (Q-SE/focus/delay focused focus))
  (equal? (Q-SN/focus/delay focused focus)
          (Q-EN/focus/delay e-focused e-focus)))

(define (Q-SE/root-focus/delay frontier spine)
  (q-root-focus-rebuild/generated/delay/e
   (q-root-focus-export/generated/delay/s frontier spine)))

(define (Q-EN/root-focus/delay frontier spine)
  (q-root-focus-rebuild/generated/delay/n
   (q-root-focus-export/generated/delay/e frontier spine)))

(define (Q-SN/root-focus/delay frontier spine)
  (q-root-focus-rebuild/generated/delay/n
   (q-root-focus-export/generated/delay/s frontier spine)))

(define (Q-SN/root-focus-composition/delay? frontier spine)
  (match-define (list e-frontier e-spine)
    (Q-SE/root-focus/delay frontier spine))
  (equal? (Q-SN/root-focus/delay frontier spine)
          (Q-EN/root-focus/delay e-frontier e-spine)))

(define (Q-SE/failure-focus/delay summary focus)
  (q-failure-focus-rebuild/generated/delay/e
   (q-failure-focus-export/generated/delay/s summary focus)))

(define (Q-EN/failure-focus/delay summary focus)
  (q-failure-focus-rebuild/generated/delay/n
   (q-failure-focus-export/generated/delay/e summary focus)))

(define (Q-SN/failure-focus/delay summary focus)
  (q-failure-focus-rebuild/generated/delay/n
   (q-failure-focus-export/generated/delay/s summary focus)))

(define (Q-SN/failure-focus-composition/delay? summary focus)
  (match-define (list e-summary e-focus)
    (Q-SE/failure-focus/delay summary focus))
  (equal? (Q-SN/failure-focus/delay summary focus)
          (Q-EN/failure-focus/delay e-summary e-focus)))

(define (Q-SE/terminal/delay terminal)
  (q-terminal-rebuild/generated/delay/e
   (q-terminal-export/generated/delay/s terminal)))

(define (Q-EN/terminal/delay terminal)
  (q-terminal-rebuild/generated/delay/n
   (q-terminal-export/generated/delay/e terminal)))

(define (Q-SN/terminal/delay terminal)
  (q-terminal-rebuild/generated/delay/n
   (q-terminal-export/generated/delay/s terminal)))

(define (Q-SN/terminal-composition/delay? terminal)
  (equal? (Q-SN/terminal/delay terminal)
          (Q-EN/terminal/delay (Q-SE/terminal/delay terminal))))
