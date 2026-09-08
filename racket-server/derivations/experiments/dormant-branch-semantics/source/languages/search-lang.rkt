#lang racket

(require redex/reduction-semantics
         "./delay-lang.rkt"
         "./disj-lang.rkt")

(provide search-lang)

(check-redundancy #t)

;; Search is exactly the additive carrier union. Rail extends this language
;; with the right-active carrier used only by that scheduler.
(define-union-language search-lang
  delay-lang
  disj-lang)
