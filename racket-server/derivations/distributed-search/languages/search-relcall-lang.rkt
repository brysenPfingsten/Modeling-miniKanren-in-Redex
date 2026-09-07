#lang racket

(require redex/reduction-semantics
         "../../../src/search-lattice/languages/search-relcall-lang.rkt"
         "./search-lang.rkt")

(provide distributed-search-relcall-lang)

(check-redundancy #t)

(define-union-language distributed-search-relcall-lang
  search-relcall-lang
  distributed-search-lang)
