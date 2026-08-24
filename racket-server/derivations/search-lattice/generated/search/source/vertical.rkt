#lang racket

(require "s.rkt"
         "e.rkt"
         "n.rkt")

(provide Q-SE/R/search
         Q-EN/R/search
         Q-SN/R/search
         Q-SN/R-composition/search?
         Q-SE/focus/search
         Q-EN/focus/search
         Q-SN/focus/search
         Q-SN/focus-composition/search?
         Q-SE/root-focus/search
         Q-EN/root-focus/search
         Q-SN/root-focus/search
         Q-SN/root-focus-composition/search?
         Q-SE/failure-focus/search
         Q-EN/failure-focus/search
         Q-SN/failure-focus/search
         Q-SN/failure-focus-composition/search?
         Q-SE/terminal/search
         Q-EN/terminal/search
         Q-SN/terminal/search
         Q-SN/terminal-composition/search?)

;; Each direct map crosses the complete joint Search view.  In particular,
;; S-to-N never decodes to E; the factored route is a separate obligation.
(define (Q-SE/R/search frontier)
  (q-rebuild/generated/search/e
   (q-export/generated/search/s frontier)))

(define (Q-EN/R/search frontier)
  (q-rebuild/generated/search/n
   (q-export/generated/search/e frontier)))

(define (Q-SN/R/search frontier)
  (q-rebuild/generated/search/n
   (q-export/generated/search/s frontier)))

(define (Q-SN/R-composition/search? frontier)
  (equal? (Q-SN/R/search frontier)
          (Q-EN/R/search (Q-SE/R/search frontier))))

(define (Q-SE/focus/search focused focus)
  (q-focus-rebuild/generated/search/e
   (q-focus-export/generated/search/s focused focus)))

(define (Q-EN/focus/search focused focus)
  (q-focus-rebuild/generated/search/n
   (q-focus-export/generated/search/e focused focus)))

(define (Q-SN/focus/search focused focus)
  (q-focus-rebuild/generated/search/n
   (q-focus-export/generated/search/s focused focus)))

(define (Q-SN/focus-composition/search? focused focus)
  (match-define (list e-focused e-focus)
    (Q-SE/focus/search focused focus))
  (equal? (Q-SN/focus/search focused focus)
          (Q-EN/focus/search e-focused e-focus)))

(define (Q-SE/root-focus/search frontier spine)
  (q-root-focus-rebuild/generated/search/e
   (q-root-focus-export/generated/search/s frontier spine)))

(define (Q-EN/root-focus/search frontier spine)
  (q-root-focus-rebuild/generated/search/n
   (q-root-focus-export/generated/search/e frontier spine)))

(define (Q-SN/root-focus/search frontier spine)
  (q-root-focus-rebuild/generated/search/n
   (q-root-focus-export/generated/search/s frontier spine)))

(define (Q-SN/root-focus-composition/search? frontier spine)
  (match-define (list e-frontier e-spine)
    (Q-SE/root-focus/search frontier spine))
  (equal? (Q-SN/root-focus/search frontier spine)
          (Q-EN/root-focus/search e-frontier e-spine)))

(define (Q-SE/failure-focus/search summary focus)
  (q-failure-focus-rebuild/generated/search/e
   (q-failure-focus-export/generated/search/s summary focus)))

(define (Q-EN/failure-focus/search summary focus)
  (q-failure-focus-rebuild/generated/search/n
   (q-failure-focus-export/generated/search/e summary focus)))

(define (Q-SN/failure-focus/search summary focus)
  (q-failure-focus-rebuild/generated/search/n
   (q-failure-focus-export/generated/search/s summary focus)))

(define (Q-SN/failure-focus-composition/search? summary focus)
  (match-define (list e-summary e-focus)
    (Q-SE/failure-focus/search summary focus))
  (equal? (Q-SN/failure-focus/search summary focus)
          (Q-EN/failure-focus/search e-summary e-focus)))

(define (Q-SE/terminal/search terminal)
  (q-terminal-rebuild/generated/search/e
   (q-terminal-export/generated/search/s terminal)))

(define (Q-EN/terminal/search terminal)
  (q-terminal-rebuild/generated/search/n
   (q-terminal-export/generated/search/e terminal)))

(define (Q-SN/terminal/search terminal)
  (q-terminal-rebuild/generated/search/n
   (q-terminal-export/generated/search/s terminal)))

(define (Q-SN/terminal-composition/search? terminal)
  (equal? (Q-SN/terminal/search terminal)
          (Q-EN/terminal/search (Q-SE/terminal/search terminal))))
