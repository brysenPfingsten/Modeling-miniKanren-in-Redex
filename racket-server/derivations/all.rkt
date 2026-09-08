#lang racket/base

;; Selected S reference correspondence and aligned native S/E/N matrix,
;; including full relation programs. Alternative semantic accounts have their
;; own gate in experiments/all.rkt.
(require (submod "constructor-tests.rkt" test)
         "s-reference/all.rkt"
         "matrix/all.rkt"
         (submod "test-support/helpers-tests.rkt" test)
         (submod "test-support/runtime-test-support.rkt" test)
         (submod "layout-tests.rkt" test))
