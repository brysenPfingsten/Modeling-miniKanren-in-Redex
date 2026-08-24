#lang racket

(require "s.rkt"
         "e.rkt"
         "n.rkt")

(provide Q-SE/R/disjunction
         Q-EN/R/disjunction
         Q-SN/R/disjunction
         Q-SN/R-composition/disjunction?
         Q-SE/focus/disjunction
         Q-EN/focus/disjunction
         Q-SN/focus/disjunction
         Q-SN/focus-composition/disjunction?
         Q-SE/root-focus/disjunction
         Q-EN/root-focus/disjunction
         Q-SN/root-focus/disjunction
         Q-SN/root-focus-composition/disjunction?
         Q-SE/failure-focus/disjunction
         Q-EN/failure-focus/disjunction
         Q-SN/failure-focus/disjunction
         Q-SN/failure-focus-composition/disjunction?
         Q-SE/terminal/disjunction
         Q-EN/terminal/disjunction
         Q-SN/terminal/disjunction
         Q-SN/terminal-composition/disjunction?)

;; These direct maps cross representations only through the joint neutral
;; views exported by the selected Disjunction sources.  S-to-N never routes
;; through E; the two routes are compared separately.
(define (Q-SE/R/disjunction frontier)
  (q-rebuild/generated/disjunction/e
   (q-export/generated/disjunction/s frontier)))

(define (Q-EN/R/disjunction frontier)
  (q-rebuild/generated/disjunction/n
   (q-export/generated/disjunction/e frontier)))

(define (Q-SN/R/disjunction frontier)
  (q-rebuild/generated/disjunction/n
   (q-export/generated/disjunction/s frontier)))

(define (Q-SN/R-composition/disjunction? frontier)
  (equal? (Q-SN/R/disjunction frontier)
          (Q-EN/R/disjunction (Q-SE/R/disjunction frontier))))

(define (Q-SE/focus/disjunction focused focus)
  (q-focus-rebuild/generated/disjunction/e
   (q-focus-export/generated/disjunction/s focused focus)))

(define (Q-EN/focus/disjunction focused focus)
  (q-focus-rebuild/generated/disjunction/n
   (q-focus-export/generated/disjunction/e focused focus)))

(define (Q-SN/focus/disjunction focused focus)
  (q-focus-rebuild/generated/disjunction/n
   (q-focus-export/generated/disjunction/s focused focus)))

(define (Q-SN/focus-composition/disjunction? focused focus)
  (match-define (list e-focused e-focus)
    (Q-SE/focus/disjunction focused focus))
  (equal? (Q-SN/focus/disjunction focused focus)
          (Q-EN/focus/disjunction e-focused e-focus)))

(define (Q-SE/root-focus/disjunction frontier spine)
  (q-root-focus-rebuild/generated/disjunction/e
   (q-root-focus-export/generated/disjunction/s frontier spine)))

(define (Q-EN/root-focus/disjunction frontier spine)
  (q-root-focus-rebuild/generated/disjunction/n
   (q-root-focus-export/generated/disjunction/e frontier spine)))

(define (Q-SN/root-focus/disjunction frontier spine)
  (q-root-focus-rebuild/generated/disjunction/n
   (q-root-focus-export/generated/disjunction/s frontier spine)))

(define (Q-SN/root-focus-composition/disjunction? frontier spine)
  (match-define (list e-frontier e-spine)
    (Q-SE/root-focus/disjunction frontier spine))
  (equal? (Q-SN/root-focus/disjunction frontier spine)
          (Q-EN/root-focus/disjunction e-frontier e-spine)))

(define (Q-SE/failure-focus/disjunction summary focus)
  (q-failure-focus-rebuild/generated/disjunction/e
   (q-failure-focus-export/generated/disjunction/s summary focus)))

(define (Q-EN/failure-focus/disjunction summary focus)
  (q-failure-focus-rebuild/generated/disjunction/n
   (q-failure-focus-export/generated/disjunction/e summary focus)))

(define (Q-SN/failure-focus/disjunction summary focus)
  (q-failure-focus-rebuild/generated/disjunction/n
   (q-failure-focus-export/generated/disjunction/s summary focus)))

(define (Q-SN/failure-focus-composition/disjunction? summary focus)
  (match-define (list e-summary e-focus)
    (Q-SE/failure-focus/disjunction summary focus))
  (equal? (Q-SN/failure-focus/disjunction summary focus)
          (Q-EN/failure-focus/disjunction e-summary e-focus)))

(define (Q-SE/terminal/disjunction terminal)
  (q-terminal-rebuild/generated/disjunction/e
   (q-terminal-export/generated/disjunction/s terminal)))

(define (Q-EN/terminal/disjunction terminal)
  (q-terminal-rebuild/generated/disjunction/n
   (q-terminal-export/generated/disjunction/e terminal)))

(define (Q-SN/terminal/disjunction terminal)
  (q-terminal-rebuild/generated/disjunction/n
   (q-terminal-export/generated/disjunction/s terminal)))

(define (Q-SN/terminal-composition/disjunction? terminal)
  (equal? (Q-SN/terminal/disjunction terminal)
          (Q-EN/terminal/disjunction (Q-SE/terminal/disjunction terminal))))
