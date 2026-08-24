#lang racket

(require "../../../framework/core-stage-schema.rkt"
         (prefix-in source: "../source/vertical.rkt")
         (prefix-in s: "s.rkt")
         (prefix-in e: "e.rkt")
         (prefix-in n: "n.rkt"))

(provide
 (rename-out [source:Q-SE/R/search Q-SE/R/stages/search]
             [source:Q-EN/R/search Q-EN/R/stages/search]
             [source:Q-SN/R/search Q-SN/R/stages/search]
             [source:Q-SN/R-composition/search?
              Q-SN/R-composition/stages/search?])
 Q-SE/D/stages/search Q-SE/Z/stages/search Q-SE/M/stages/search
 Q-SE/B/stages/search Q-SE/Big/stages/search
 Q-EN/D/stages/search Q-EN/Z/stages/search Q-EN/M/stages/search
 Q-EN/B/stages/search Q-EN/Big/stages/search
 Q-SN/D/stages/search Q-SN/Z/stages/search Q-SN/M/stages/search
 Q-SN/B/stages/search Q-SN/Big/stages/search
 Q-SE/decompose-commutes/stages/search?
 Q-SE/refocus-commutes/stages/search?
 Q-SE/machineize-commutes/stages/search?
 Q-SE/compress-commutes/stages/search?
 Q-SE/big-commutes/stages/search?
 Q-EN/decompose-commutes/stages/search?
 Q-EN/refocus-commutes/stages/search?
 Q-EN/machineize-commutes/stages/search?
 Q-EN/compress-commutes/stages/search?
 Q-EN/big-commutes/stages/search?
 Q-SN/decompose-commutes/stages/search?
 Q-SN/refocus-commutes/stages/search?
 Q-SN/machineize-commutes/stages/search?
 Q-SN/compress-commutes/stages/search?
 Q-SN/big-commutes/stages/search?
 Q-SN/D-composition/stages/search?
 Q-SN/Z-composition/stages/search?
 Q-SN/M-composition/stages/search?
 Q-SN/B-composition/stages/search?
 Q-SN/Big-composition/stages/search?)

;; The phase-map declarations are structurally repeated for the three direct
;; representation edges.  Each invocation still emits five distinct primary
;; maps; none decodes through an earlier stage.
(define-syntax-rule
  (define-search-representation-edge
    source-row target-row
    Q-R Q-focus Q-root-focus Q-failure-focus Q-terminal
    Q-D D-commutes?
    Q-Z Z-commutes?
    Q-M M-commutes?
    Q-B B-commutes?
    Q-Big Big-commutes?)
  (begin
    (define-decomposition-representation-map
      #:source source-row #:target target-row
      #:Q-R Q-R #:Q-focus Q-focus #:Q-root-focus Q-root-focus
      #:Q-terminal Q-terminal #:Q-D Q-D #:commutes D-commutes?)
    (define-refocused-representation-map
      #:source source-row #:target target-row
      #:Q-D Q-D #:Q-focus Q-focus #:Q-root-focus Q-root-focus
      #:Q-terminal Q-terminal #:Q-Z Q-Z #:commutes Z-commutes?)
    (define-machine-representation-map
      #:source source-row #:target target-row
      #:Q-Z Q-Z #:Q-focus Q-focus #:Q-root-focus Q-root-focus
      #:Q-terminal Q-terminal #:Q-M Q-M #:commutes M-commutes?)
    (define-compressed-representation-map
      #:source source-row #:target target-row
      #:Q-M Q-M #:Q-focus Q-focus #:Q-root-focus Q-root-focus
      #:Q-failure-focus Q-failure-focus #:Q-terminal Q-terminal
      #:Q-B Q-B #:commutes B-commutes?)
    (define-fixed-point-representation-map
      #:source source-row #:target target-row
      #:Q-B Q-B #:Q-terminal Q-terminal
      #:Q-Big Q-Big #:commutes Big-commutes?)))

(define-search-representation-edge
  s:search/staged-row/S e:search/staged-row/E
  source:Q-SE/R/search source:Q-SE/focus/search
  source:Q-SE/root-focus/search source:Q-SE/failure-focus/search
  source:Q-SE/terminal/search
  Q-SE/D/stages/search Q-SE/decompose-commutes/stages/search?
  Q-SE/Z/stages/search Q-SE/refocus-commutes/stages/search?
  Q-SE/M/stages/search Q-SE/machineize-commutes/stages/search?
  Q-SE/B/stages/search Q-SE/compress-commutes/stages/search?
  Q-SE/Big/stages/search Q-SE/big-commutes/stages/search?)

(define-search-representation-edge
  e:search/staged-row/E n:search/staged-row/N
  source:Q-EN/R/search source:Q-EN/focus/search
  source:Q-EN/root-focus/search source:Q-EN/failure-focus/search
  source:Q-EN/terminal/search
  Q-EN/D/stages/search Q-EN/decompose-commutes/stages/search?
  Q-EN/Z/stages/search Q-EN/refocus-commutes/stages/search?
  Q-EN/M/stages/search Q-EN/machineize-commutes/stages/search?
  Q-EN/B/stages/search Q-EN/compress-commutes/stages/search?
  Q-EN/Big/stages/search Q-EN/big-commutes/stages/search?)

(define-search-representation-edge
  s:search/staged-row/S n:search/staged-row/N
  source:Q-SN/R/search source:Q-SN/focus/search
  source:Q-SN/root-focus/search source:Q-SN/failure-focus/search
  source:Q-SN/terminal/search
  Q-SN/D/stages/search Q-SN/decompose-commutes/stages/search?
  Q-SN/Z/stages/search Q-SN/refocus-commutes/stages/search?
  Q-SN/M/stages/search Q-SN/machineize-commutes/stages/search?
  Q-SN/B/stages/search Q-SN/compress-commutes/stages/search?
  Q-SN/Big/stages/search Q-SN/big-commutes/stages/search?)

(define (Q-SN/D-composition/stages/search? value)
  (equal? (Q-SN/D/stages/search value)
          (Q-EN/D/stages/search (Q-SE/D/stages/search value))))

(define (Q-SN/Z-composition/stages/search? value)
  (equal? (Q-SN/Z/stages/search value)
          (Q-EN/Z/stages/search (Q-SE/Z/stages/search value))))

(define (Q-SN/M-composition/stages/search? value)
  (equal? (Q-SN/M/stages/search value)
          (Q-EN/M/stages/search (Q-SE/M/stages/search value))))

(define (Q-SN/B-composition/stages/search? value)
  (equal? (Q-SN/B/stages/search value)
          (Q-EN/B/stages/search (Q-SE/B/stages/search value))))

(define (Q-SN/Big-composition/stages/search? value)
  (equal? (Q-SN/Big/stages/search value)
          (Q-EN/Big/stages/search (Q-SE/Big/stages/search value))))
